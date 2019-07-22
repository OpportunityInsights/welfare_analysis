**************************
/* 0. Program: Year Up  */
**************************

/*Fein, David and Jill Hamadyk. 2018. "Bridging the Opportunity Divide for
Low-Income Youth: Implementation and Early Impacts of the Year Up Program"
OPRE Report No. 2018-65.
https://www.yearup.org/wp-content/uploads/2018/06/Year-Up-PACE-Full-Report-2018.pdf.*/
** Appendix: https://www.yearup.org/wp-content/uploads/2018/06/Year-Up-PACE-Appendices-2018.pdf

*NOTES: In addition to the earnings impacts we consider, the intermediate Year Up
*		evaluation contains impact estimates for a survey-based measure of whether
*		participants are in a household receiving public assistance - we ignore
*		this for now to get a lower-bound MVPF. Fein and Hamadyk also find
*		positive impacts on cumulative college credits received; no impact on college
*		completion; and a positive impact on the likelihood of having a professional
*		credential. Again, to get a lower-bound MVPF, we assume that all of these
*		effects are fully reflected in earnings impacts as of the latest year
*		of the evaluation.

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" //takes values "continuous", "cbo"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate = $tax_rate_cont
}
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local proj_type 	= "$proj_type" //takes values "observed", "growth forecast"
local proj_length 	= "$proj_length" //"observed", "8yr", "21yr", or "age65"
local wtp_valuation = "$wtp_valuation" //takes on value of "post tax" or "cost"


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
*Earnings impacts for years 0-2 since random assignment (Exhibit 6-1)
//NOTE: In table in paper, program year is labeled as "Year 1" - switching to "Year 0"
//		to make discounting easier below. Assuming these impacts are in nominal
//		dollars, since there is no mention of inflation adjustment in paper.

local year0_earnings = -5338
local year0_earnings_se = 238

local year1_earnings = 5181
local year1_earnings_se = 474

local year2_earnings = 7011
local year2_earnings_se = 619
*/


*********************************
/* 3. Exact Inputs from Paper  */
*********************************


*Earnings impact estimates are measured in time since random assignment, which
*occurred over 2013 and 2014 (see Executive Summary p. ii). For now, treating
*2013 as the first year of the program.
local program_year = 2013

*For age of participants, no direct average in paper - using shares for subgroups
*for all participants (Exhibit 3-2) - ends up being almost exactly 21 (midpoint
*of age range for program recruitment [18-24]):
local program_age = (19 * 0.428) + (22.5 * 0.572)

*Total program cost (Exhibit 4-1):
local program_cost = 28290

*Student stipends during program (Exhibit 4-1; assuming these are non-taxable):
local program_transfers = 6614

*Get deflators:
forval i = 2013/2016 {
	deflate_to `program_year', from(`i')
	local defl_`i'_`program_year' = r(deflator)
}

*Control group earnings in final year of evaluation (Exhibit 6-1)
local control_group_earnings_year2 = 17400 * `defl_2016_2013'




**********************************
/* 4. Intermediate Calculations */
**********************************


*Inflation-adjust all earnings impacts so that they are in `program_year' dollars:
forval i= 0/2 {
	local year = `program_year' + `i'
	local year`i'_earnings_adj =  `year`i'_earnings' * `defl_`year'_`program_year''
}

*Discount observed inflation-adjusted earnings impacts back to year of program:
local obs_earn_impact = 0
forvalues i = 0/2 {
	local obs_earn_impact = `obs_earn_impact' + (`year`i'_earnings_adj' * ((1/(1+`discount_rate'))^`i'))
}

*Earnings projections (for forecasts, using inflation-adjusted year-2 earnings impact):
local proj_start_age = round(`program_age') + 3
local year2_age = round(`program_age') + 2
local project_year = `program_year' + 3
if "`proj_length'" == "8yr"		local proj_end_age = `proj_start_age'+4
if "`proj_length'" == "21yr"	local proj_end_age = `proj_start_age'+17
if "`proj_length'" == "age65"	local proj_end_age = 65

local usd_year = `program_year'

if "`proj_type'" == "observed"{
	local earn_proj = 0
}

if "`proj_type'" == "growth forecast" {

	est_life_impact `year2_earnings_adj', ///
		impact_age(`year2_age') project_age(`proj_start_age') end_project_age(`proj_end_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`control_group_earnings_year2') income_info_type(counterfactual_income) /// from control group income in final year of evaluation
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method)

	local earn_proj = ((1/(1+`discount_rate'))^3) * r(tot_earn_impact_d) // Discount earnings projection back to year of program.
}

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `control_group_earnings_year2' , /// annual control mean earnings
		inc_year(`project_year') /// year of income measurement
		include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
		include_transfers("yes") /// not accounted for separately
		usd_year(`usd_year') /// usd year of income
		forecast_income(yes) /// if childhood program where need lifecycle earnings, yes
		earnings_type(individual) /// optional option, only if info provided. default is 4
		program_age(`year2_age') // this corresponds to year 7

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
	local WTP = `program_transfers' + `total_earn_impact'*(1-`tax_rate')
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

*store outputs in local for wrapper
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global WTP_`1' = `WTP'
global age_stat_`1' = `program_age'
global age_benef_`1' = `program_age'



* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `control_group_earnings_year2'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `program_year'+2
global inc_age_stat_`1' = `year2_age'

global inc_benef_`1' = `control_group_earnings_year2'*r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `program_year'+2
global inc_age_benef_`1' = `year2_age'
