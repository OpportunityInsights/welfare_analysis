*****************************
/* 0. Program: Head Start */
*****************************

/*
Johnson, Rucker C., and C. Kirabo Jackson. 2019. "Reducing Inequality through Dynamic Complementarity: Evidence from Head Start and Public School Spending." American Economic Journal: Economic Policy, 11 (4): 310-49.


*/



********************************
/* 1. Pull Global Assumptions */
********************************

local proj_age = $proj_age
local tax_rate_assumption = "$tax_rate_assumption" //takes value continuous or cbo
local tax_rate_cont = $tax_rate_cont
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no" 
local wtp_valuation = "$wtp_valuation" //"post tax", "cost" or "lower bound"
local discount_rate = $discount_rate
local model = "$model"


*****************************
/* 2. Estimates from Paper */
*****************************


local bootstrap = "`2'"

/*
if "`model'" == "DiD-2SLS" {

local earn_effect = .0987 //Table 2
local earn_effect_se = .0190
}

if "`model'" == "2SLS-IV"{

local earn_effect = .1529 //Table 2
local earn_effect_se = .08275
}
*/



*Import estimates from paper, giving option for corrected estimates


if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`model'" == "DiD-2SLS" local local_suffix = "pri"
if "`model'" == "2SLS-IV" local local_suffix = "sec"

if "`bootstrap'" == "yes" {
	if ${draw_number} ==1 {

	preserve
		use "${input_data}/causal_estimates/${folder_name}/draws/${name}.dta", clear
		* keep estimates from the right program
		keep draw_number *_`local_suffix'
		ren *_`local_suffix' *
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
		keep if regexm(estimate, "._`local_suffix'$")
		replace estimate = regexr(estimate, "_`local_suffix'$", "")
		levelsof estimate, local(estimates)
		foreach est in `estimates' {
			qui su pe if estimate == "`est'"
			local `est' = r(mean)
		}
		di "`model'"
	restore
}


****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local usd_year = 2000 //Table 1

*Average bith year of low-income kids in the sample
local avg_birth_year = 1962 //Table 1

*Average age of low-income kids when income observed (range is 20 to 50)
local avg_age_observed = 30.3 //Table 1

*Percent of low income kids who attend Head Start
local percent_treat = .19 //Table 1

local impact_age = floor(`avg_age_observed')

*Average family income of low-income kids when they grow up
loca avg_fam_income = 35372 //Table 1 (avg of treatment and control)

local spend_p_poor_4_yr_old = 4230 //pg. 24

local age_benef = 4 //pg. 8
local age_stat = `age_benef'

local proj_start_age = 18

*Numbers from 1990 Cenus to get wages:HH income ratio 

*Median HH income in 1990, ages 25 to 34
local med_hh_income = 30359 //Table 697                                

*Median individual income for men in 1990, ages 25 to 34
local med_male_income = 21393 //Table 711

*Number of men in 1990
local num_men = 21.3 //Table 711, in millions

*Median individual income for women in 1990, ages 25 to 34
local med_fem_income = 12589 //Table 711

*Number of women in 1990
local num_fem = 21.6 //Table 711, in millions

********************************
/* 4. Intermediate Calculations */
*********************************

local inc_year = `avg_birth_year' + `impact_age'
local project_year = `avg_birth_year' + `proj_start_age'

*Get ratio to scale down HH income to invidual income

local percent_men = `num_men'/(`num_men' + `num_fem')
local percent_women = `num_fem'/(`num_men' + `num_fem')

local avg_med_ind_income = (`percent_men'*`med_male_income')+ (`percent_women'*`med_fem_income')

local scale_factor = `avg_med_ind_income'/`med_hh_income'

*Invidual income at age 30 of low-income kids in the sample
local ind_income_samp = `scale_factor'*`avg_fam_income'

*Invidual income at age 30 of low-income kids who did not attend Head Start
local ind_income_control = `ind_income_samp'/((1-`percent_treat')+(`percent_treat'*(1 + `earn_effect')))

*Number of additional years to disocunt back to from 18
local number_of_years = `impact_age' - `age_benef'

*Project earnings
	est_life_impact `earn_effect', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`ind_income_control') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)
	local total_earn_impact = ((1/(1+`discount_rate'))^`number_of_years') * r(tot_earn_impact_d)
	
	
*Get tax rates 
if "`tax_rate_assumption'" == "continuous"  {
	local tax_rate = `tax_rate_cont'
}

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `ind_income_control', /// earnings for control
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income("yes") /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`inc_year') /// year of income measurement 
		program_age(`impact_age') ///
		earnings_type("individual") // individual or household
	local tax_rate = r(tax_rate)
	di r(pfpl)
}

local total_aft_tax_earnings = (1-`tax_rate')*`total_earn_impact'
local tax_revenue = `tax_rate'*`total_earn_impact'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `spend_p_poor_4_yr_old' //pg. 24

local FE = `tax_revenue'

local total_cost = `program_cost' - `FE'


*************************
/* 6. WTP Calculations */
*************************



if "`wtp_valuation'" == "post tax" {
	local WTP = `total_aft_tax_earnings' 
}

if "`wtp_valuation'" == "cost" 			local WTP = `program_cost'
if "`wtp_valuation'" == "lower bound" 	local WTP = 0.01*`program_cost'



**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `program_cost'
di `tax_revenue'
di `total_cost'
di `WTP'
di `MVPF'

di `earn_effect'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'


global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')

global inc_stat_`1' = `ind_income_control'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `inc_year'
global inc_age_stat_`1' = `avg_age_observed'

global inc_benef_`1' = `ind_income_control'*r(deflator)
global inc_type_benef_`1' ="individual"
global inc_year_benef_`1' = `inc_year'
global inc_age_benef_`1' = `avg_age_observed'
