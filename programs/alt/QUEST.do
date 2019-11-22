********************************
/* 0. Program: Project Quest  */
********************************

/*
Roder, Anne and Mark Elliot. 2019. "Nine Year Gains: Project QUEST's Continuing Impact"
Economic Mobility Corporation.
https://economicmobilitycorp.org/wp-content/uploads/2019/04/NineYearGains_web.pdf
*/

********************************
/* 1. Pull Global Assumptions */
********************************
local discount_rate = $discount_rate
assert `discount_rate' != .
local tax_rate_assumption = "$tax_rate_assumption" //takes values "continuous", "cbo"
assert "`tax_rate_assumption'" != ""
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate = $tax_rate_cont
	assert "`tax_rate'" != ""
}
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
assert "`payroll_assumption'" != ""
local proj_type 	= "$proj_type" //takes values "observed", "growth forecast"
assert "`proj_type'" != ""
local proj_length 	= "$proj_length" //"observed", "8yr", "21yr", or "age65"
assert "`proj_length'" != ""
local wtp_valuation = "$wtp_valuation" //takes on value of "post tax" or "cost"
assert "`wtp_valuation'" != ""

************************************
/* 2. Estimated Inputs from Paper */
************************************

*Import estimates from paper, giving option for corrected estimates
if "`1'" != "" global name = "`1'"
local bootstrap  = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
	if ${draw_number} ==1 {
		preserve
			use "${input_data}/causal_estimates/${folder_name}/draws/${name}.dta", clear
			qui ds draw_number, not
			global estimates_${name} = r(varlist)
			mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
		restore
	}
	local ests ${estimates_${name}}
	foreach var in `ests' {
		matrix temp = draws_${name}["${draw_number}", "`var'"]
		local `var' = temp[1,1]
	}
}
if "`bootstrap'" != "yes" {
	preserve
		import delimited "${input_data}/causal_estimates/${folder_name}/${name}.csv", clear
		levelsof estimate, local(estimates)
		foreach est in `estimates' {
			qui su pe if estimate == "`est'"
			local `est' = r(mean)
		}
	restore
}


/*
*Earnings impacts for years 1-9 since random assignment. From Figure 1

local year1_earnings = -1801
local year2_earnings = -2369
local year3_earnings = 1881
local year4_earnings = 3925
local year5_earnings = 3980
local year6_earnings = 4691
local year7_earnings = 2176
local year8_earnings = 2952
local year9_earnings = 5239
*/

************************************
/* 2. Exact Inputs from Paper */
************************************

*Earnings impact estimates are measured in time since random assignment, which
*occurred over 2006-2008 (pg2). For now, treating 2006 as the first year of the program.
local program_year = 2006


* Average age of program participant (pg 3)
local program_age = 30


*Total program cost (pg 11)
// this is the 22% of total cost spent on tuition and the 23% spent on student support

local program_cost = 10501 
local program_transfers = (.22 + .23) * `program_cost'


*Get deflators:
forval i = 2007/2015 {
	deflate_to `program_year', from(`i')
	local defl_`i'_`program_year' = r(deflator)
}


*Control group earnings in final year of evaluation (Figure 4, pg5)
local control_group_earnings_year9 = 28404 * `defl_2015_2006'



**********************************
/* 4. Intermediate Calculations */
**********************************

*Inflation-adjust all earnings impacts so that they are in `program_year' dollars:
forval i= 1/9 {
	local year = `program_year' + `i'
	local year`i'_earnings_adj =  `year`i'_earnings' * `defl_`year'_`program_year''
}


*Discount observed inflation-adjusted earnings impacts back to year of program:
local obs_earn_impact = 0
forvalues i = 1/9 {
	local obs_earn_impact = `obs_earn_impact' + (`year`i'_earnings_adj' * ((1/(1+`discount_rate'))^`i'))
}


*Earnings projections 
local proj_start_age = `program_age' + 10
local year9_age = `program_age' + 9
local project_year = `program_year' + 10
if "`proj_length'" == "21yr"	local proj_end_age = `proj_start_age' + 11
else if "`proj_length'" == "age65"	local proj_end_age = 65



local usd_year = `program_year'

if "`proj_type'" == "observed"{
	local earn_proj = 0
}



if "`proj_type'" == "growth forecast" {

	est_life_impact `year9_earnings_adj', ///
		impact_age(`year9_age') project_age(`proj_start_age') end_project_age(`proj_end_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`control_group_earnings_year9') income_info_type(counterfactual_income) /// from control group income in final year of evaluation
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method)

	local earn_proj = ((1/(1+`discount_rate'))^9) * r(tot_earn_impact_d) // Discount earnings projection back to year of program.
}



if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `control_group_earnings_year9' , /// annual control mean earnings
		inc_year(`project_year') /// year of income measurement
		include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
		include_transfers("yes") /// not accounted for separately
		usd_year(`usd_year') /// usd year of income
		forecast_income(yes) /// if childhood program where need lifecycle earnings, yes
		earnings_type(individual) /// optional option, only if info provided. default is 4
		program_age(`year9_age') // last observed age

	local tax_rate = r(tax_rate)
}


*Compute total earnings impacts (observed plus projected) and corresponding
*increase in taxes:
local total_earn_impact = `obs_earn_impact' + `earn_proj' // Pre-tax earnings impact
local increase_taxes = `tax_rate' * `total_earn_impact'



**************************
/* 5. Cost Calculations */
**************************

local FE = `increase_taxes'

local total_cost = `program_cost' - `FE'





*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	local WTP = `total_earn_impact'*(1-`tax_rate')
}

if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost' // Under this specification, we assume that individuals value the program at the program cost.
}
if "`wtp_valuation'" == "lower bound" {
	local WTP = 0.01*`program_cost'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'


****************
/* 8. Outputs */
****************

*display outputs
di `MVPF'
di `WTP'
di `total_cost'
di `program_cost'
di `FE'

di `total_earn_impact'






