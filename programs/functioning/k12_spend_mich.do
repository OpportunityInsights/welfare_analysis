********************************************************
/* 0. Program: K-12 School Spending (Hyman) 		  */
********************************************************

/*
Hyman, J. (2017). 
"Does money matter in the long run? Effects of school spending on educational attainment."
American Economic Journal: Economic Policy, 9(4), 256-80.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local proj_age = $proj_age //takes on age at end of projection, baseline 65
local tax_rate_assumption = "$tax_rate_assumption" //takes value "cbo" or "continuous"
if "$tax_rate_assumption" =="continuous" local tax_rate = $tax_rate_cont
local discount_rate = $discount_rate //baseline .03
local proj_type = "$proj_type" // "growth forecast"
local wtp_valuation = "$wtp_valuation" // "post tax" or "lower bound"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

local years_enroll = $years_enroll //years of additional attainment associated with college enrollment

******************************
/* 2. Estimates from Paper */
******************************

/*
*Enrollment effect - Hyman (2017), Table 4, Column 4:
local enroll_effect = 0.03
local enroll_effect_se = 0.014 
*/

if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
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
	local est_list ${estimates_${name}}
	foreach var in `est_list' {
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

*********************************
/* 3. Assumptions from Paper */
*********************************

local usd_year = 2012 // Hyman (2017)

local years_ed = 4 // Hyman (2017): "I focus on spending and allowance between grades four and seven"

local avg_spend_per_pup = 9797 // Hyman (2017) table 1

local year_reform = 1994

local avg_year = (1994+2000)/2 // Hyman (2017) table 1 notes

local age_min = 9 	//4th grade
local age_max = 12	//7th grade
local avg_age = (`age_min'+`age_max')/2
local avg_age_int = round(`avg_age')

local avg_local_median_hh_inc = 60537 // Hyman (2017) table 1

/* Hyman (2017):
The instrument is the average allowance during grades four through seven
(also in thousands of 2012 dollars).
*/
local spend_change = 4000

**********************************
/* 4. Intermediate Calculations */
**********************************

*Get earnings impact corresponding to college impact:
local years_impact = `enroll_effect'*`years_enroll'
int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year') 
local pct_earn_impact_neg = r(prog_earn_effect_neg)
local pct_earn_impact_pos = r(prog_earn_effect_pos)

*Project earnings impact over the lifecycle
if "`proj_type'" == "growth forecast" {
	*Initial earnings decline
	local proj_start_age = 18
	local proj_short_end = 24
	local impact_age = 34 // as we use mobility estimate to get kid income at 34 from parent income
	local project_year = `year_reform'+`proj_start_age'-`avg_age_int'
	
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`avg_local_median_hh_inc') income_info_type(parent_income) ///
		parent_income_year(`avg_year') ///
		earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
		percentage(yes)
		
	local total_earn_impact_neg = r(tot_earn_impact_d)*(1/(1+`discount_rate')^(`proj_start_age'-`avg_age_int'))
	local cfactual_inc_neg = r(cfactual_income)
		
	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `cfactual_inc_neg' , /// annual control mean earnings 
			inc_year(`=round(`project_year'-`proj_start_age'+`impact_age')') /// year of income measurement 
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) ///
			usd_year(`usd_year') /// usd year of income 
			forecast_income(no) /// if childhood program where need lifecycle earnings, yes
			earnings_type(individual) // optional option, only if info provided. default is 4 
		
		local tax_rate = r(tax_rate)
	}	
	
	local increase_taxes_neg = `tax_rate' * `total_earn_impact_neg'
	
	*Later earnings increase
	local proj_start_age = 25
	local impact_age = 34
	local project_year = `year_reform'+`proj_start_age'-`avg_age_int'
		
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`avg_local_median_hh_inc') income_info_type(parent_income) ///
		parent_income_year(`avg_year') ///
		earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
		percentage(yes)
		
	local total_earn_impact_pos = r(tot_earn_impact_d)*(1/(1+`discount_rate')^(`proj_start_age'-`avg_age_int'))
	local cfactual_inc_pos = r(cfactual_income)

	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `cfactual_inc_pos' , /// annual control mean earnings 
			inc_year(`=round(`project_year'-`proj_start_age'+`impact_age')') /// year of income measurement 
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) ///
			usd_year(`usd_year') /// usd year of income 
			program_age(`impact_age') /// age of program beneficiaries when income is measured 
			forecast_income(yes) /// 
			earnings_type(individual)
			
		local tax_rate = r(tax_rate)
	}	
		
	local increase_taxes_pos = `tax_rate' * `total_earn_impact_pos'

	*Combine Estimates
	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact' - `increase_taxes'
}
else {
	di as err "Only growth forecast allowed"
	exit
}

*Get implied cost increases from college attendance
if "$got_hyman_cost"!="yes" {
	cost_of_college , year(`=round(`year_reform'+18-`avg_age_int')') state(MI)
	global hyman_college_cost = r(cost_of_college)
	global hyman_tuition_cost = r(tuition)
	global got_hyman_cost = "yes"
}
deflate_to `usd_year', from(`=round(`year_reform'+18-`avg_age_int')')
local govt_college_cost = 0
local priv_college_cost = 0
forval i = 1/`years_enroll'{
	local govt_college_cost = `govt_college_cost' + (${hyman_college_cost} - ${hyman_tuition_cost})*(`enroll_effect')* ///
													r(deflator)*(1/(1+`discount_rate')^(18-`avg_age_int'+`i'-1))
	local priv_college_cost = `priv_college_cost' + (${hyman_tuition_cost})*(`enroll_effect')* ///
													r(deflator)*(1/(1+`discount_rate')^(18-`avg_age_int'+`i'-1))
}

**************************
/* 5. Cost Calculations */
**************************

*Spread spending over four years
local program_cost = 0
forval i = 1/4 {
	local program_cost = `program_cost' + (`spend_change'/4)/((1+`discount_rate')^(`i'-1))
}

local total_cost = `program_cost' - `increase_taxes' + `govt_college_cost'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" { 
	local WTP = `total_earn_impact_aftertax' -`priv_college_cost'
}  

if "`wtp_valuation'" == "cost" local WTP = `program_cost'

if "`wtp_valuation'" == "lower bound" local WTP = `program_cost'*0.01

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `total_earn_impact'
di `total_earn_impact_aftertax'
di `priv_college_cost'
di `govt_college_cost'
di `increase_taxes'
di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `avg_age'
global age_benef_`1' = `avg_age'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_inc_pos'* r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `year_reform'+`impact_age'-`avg_age_int'
global inc_age_stat_`1' =`impact_age'

global inc_benef_`1' = `cfactual_inc_pos'* r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `year_reform'+`impact_age'-`avg_age_int'
global inc_age_benef_`1' = `impact_age'
