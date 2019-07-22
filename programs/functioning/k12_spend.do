********************************************************
/* 0. Program: K-12 School Spending */
********************************************************

/*
Jackson, C. Kirabo, Rucker C. Johnson, and Claudia Persico. "The effects of 
school spending on educational and economic outcomes: Evidence from school 
finance reforms." The Quarterly Journal of Economics 131, no. 1 (2015): 157-218.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local proj_age = $proj_age //takes on age at end of projection, baseline 65
local tax_rate_assumption = "$tax_rate_assumption" //takes value "cbo", "continuous"
local tax_rate_cont = $tax_rate_cont //baseline .2
local discount_rate = $discount_rate //baseline .03
local proj_type = "$proj_type" // only option is "growth forecast"
local wtp_valuation = "$wtp_valuation" //options are  "after-tax income" or "at cost"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

local earners_per_fam = $earners_per_fam //Earners per family
*NOTE: For baseline, we assume 1.302 earners per family. This is derived from
*http://www.aei.org/publication/explaining-us-income-inequality-by-household-demographics-2017-edition-2/, averaging
*the number of earners per household within each quintile ((0.41+0.94+1.37+1.73+2.06)/5).

******************************
/* 2. Estimates from Paper */
******************************
/*
/*A 1% increase in spending is associated with a .7743% increase in wages between ages 20-45*/
local ln_wage_effect = .7743 //Jackson et al. (2016) Table 4 on pg. 198
local ln_wage_effect_se = .1959 //Jackson et al. (2016) Table 4 on pg. 198
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
local USD_year = 2000 //Jackson et al. (2016) Table 1 on pg. 166

local years_ed = 12 //Jackson et al. (2016) abstract

local avg_spend_per_pup = 4800 //Jackson et al. (2016) Table 1 on pg. 166

local school_age_min = 5 //Jackson et al. (2016) Table 1 on pg. 166
local school_age_max = 17 //Jackson et al. (2016) Table 1 on pg. 166

local age_min = 20 //Jackson et al. (2016) Table 4 on pg. 198
local age_max = 45 //Jackson et al. (2016) Table 4 on pg. 198

local year_min = 1968 //Jackson et al. (2016) Table 4 on pg. 198
local year_max = 2011 //Jackson et al. (2016) Table 4 on pg. 198

*Family/individual income at age 30:
local family_inc_30 = 49308 //Jackson et al. (2016) Table 1
local indiv_inc_30 = `family_inc_30'/`earners_per_fam'

local avg_yr_birth = 1969 //Jackson et al. (2016) Table 1

local family_inc = 49308 //Jackson et al. (2016) Table 1


*********************************
/* 4. Intermediate Calculations */
*********************************

local mean_age = (`age_min'+`age_max')/2
local mean_school_age = (`school_age_min'+`school_age_max')/2
local mean_school_age_round = round(`mean_school_age')

local age_benef = `mean_school_age'
local age_stat = `age_benef'

local age_observed = round(`mean_age')
local proj_start_age = `age_min' 

local mean_year = (`year_min'+`year_max')/2
local proj_year = round(`year_min')
local years_back_to_spend = `proj_start_age' - `mean_school_age_round'

local avg_tot_spend_pp = `avg_spend_per_pup'*`years_ed'
local one_dollar_percent = 1/`avg_tot_spend_pp'
local pct_earn_impact = `ln_wage_effect'*`one_dollar_percent'

if "`proj_type'" == "growth forecast"{
	est_life_impact `pct_earn_impact', ///
		impact_age(30) project_age(`proj_start_age') ///
		end_project_age(`proj_age') project_year(`proj_year') usd_year(`USD_year') ///
		income_info(`indiv_inc_30') income_info_type(counterfactual_income) /// 
		earn_method(multiplicative) tax_method(off) transfer_method(off) ///
		percentage(yes) max_age_obs(`age_max')
		
	local cfactual_income = `r(cfactual_income)'
	local earn_proj = ((1/(1+`discount_rate'))^`years_back_to_spend') * r(tot_earn_impact_d)
	local total_earn_impact = `earn_proj'
	
}
else {
	di as err "Only growth forecast allowed"
	exit
}

if "`tax_rate_assumption'" ==  "continuous" local tax_rate = `tax_rate_cont' 
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `indiv_inc_30', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`USD_year') /// USD year of income
		inc_year(`=`avg_yr_birth' + 30') /// year of income measurement 
		program_age(30) ///
		earnings_type(individual) // individual or household
	local tax_rate = r(tax_rate)
	di r(quintile)
	di r(pfpl)
}	

local increase_taxes = `tax_rate' * `total_earn_impact'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = 1

local total_cost = `program_cost' - `increase_taxes'
di `increase_taxes'
di `total_cost'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax"{ 
	local WTP = `total_earn_impact'-`increase_taxes'
}  
if "`wtp_valuation'" == "cost"{ 
	local WTP = `program_cost'
} 
if "`wtp_valuation'" == "lower bound"{ 
	local WTP = `program_cost'*0.01
} 
**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'


****************
/* 8. Outputs */
****************


di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'


* income globals
deflate_to 2015, from(`USD_year')
global inc_stat_`1' = `indiv_inc_30'* r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `avg_yr_birth' + 30
global inc_age_stat_`1' =  30

global inc_benef_`1' = `indiv_inc_30'* r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `avg_yr_birth' + 30
global inc_age_benef_`1' = 30



