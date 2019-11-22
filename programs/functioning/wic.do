********************************
/* 0. Program: WIC*/
********************************

/*
Hoynes, H., Page, M., & Stevens, A. H. (2011). Can targeted transfers improve 
birth outcomes?: Evidence from the introduction of the WIC program. Journal of 
Public Economics, 95(7-8), 813-827.

*Provide nutritional supplements and information to low income pregnant and postpartum
*women, infants, and children up to five years old. 

*/

********************************
/* 1. Pull Global Assumptions */
********************************
local tax_rate_assumption = "$tax_rate_assumption"
local samp = "less than HS" //options are "full" sample or "less than HS" sample
local pop_interest = "$pop_interest" // parents or combined
local discount_rate = $discount_rate
if "$tax_rate_assumption" == "continuous" {
	local tax_rate = $tax_rate_cont
	}
local proj_age = $proj_age
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no" 
local ev_adjustment = "$ev_adjustment" //"yes" or "no"
local wtp_valuation =  "$wtp_valuation" 
	
*****************************
/* 2. Estimates from Paper */
******************************

/*
*Effects of WIC on average birth weight 

if "`samp'"== "full"{
local itt = 2.7 //Hoynes et al 2010, Table 3, coeff is 2.3 with state*year FE
local itt_se = 1.22
}
if "`samp'"== "less than HS"{
local itt = 7  //Hoynes et al 2010, Table 4
local itt_se = 2.50
}
*/


/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates.
${folder_name}, being set externally, may vary in order to use pub bias corrected estimates. */
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



*********************************
/* 3. Assumptions from Paper */
*********************************
local usd_year = 1976 

if "`samp'"== "full" local itt = `itt_full'

if "`samp'"== "less than HS" local itt = `itt_less_HS'

//Elasticity of adult earnings with respect to birthweight (Black et al. 2007):
local bw_earnings_effect = 0.12

if "`samp'"== "full"{
	local part_rate = .08 //Hoynes et al 2010, pg. 819
	local mean_birth_wgt = 3316 //Hoynes et al 2010, Table 3
}

if "`samp'"== "less than HS"{
	local part_rate = .30 //Hoynes et al 2010, footnote 22 (note alternative calc method give .18)
	local mean_birth_wgt = 3205 //Hoynes et al 2010, Table 4
}


/* Average WIC mother age : 26 
Source: https://www.census.gov/prod/1/statbrief/sb95_29.pdf */
local mother_age_yrbirth = 26
local age_stat = `mother_age_yrbirth'
local age_kid = 0 //since this is about birth weight

*Monthly program expenditures per person for 1974-1979
*Source: https://fns-prod.azureedge.net/sites/default/files/pd/wisummary.pdf
local exp_mo_74 = 15.68
local exp_mo_75 = 18.58
local exp_mo_76 = 19.60
local exp_mo_77 = 20.80
local exp_mo_78 = 21.99
local exp_mo_79 = 24.09

forval y = 74/79 {
	deflate_to `usd_year', from(19`y')
	local exp_mo_`y' = `exp_mo_`y'' * r(deflator)
}


*Equivalent variation adjustment 
*NOTE: imported from SNAP because we don't have direct estimate for WIC
local ev = .65 // Whitmore (2002) ("What Are Food Stamps Worth" WP)

*********************************
/* 4. Intermediate Calculations */
*********************************

*Get parent income:
/* "Participants must live in households with family incomes below 185% of the poverty
line or become eligible through participation in another welfare program such as 
Medicaid, Temporary Assistance to Needy Families, or Food Stamps." - Hoynes et al. (2011) */
*-> Assume parent HH income at 100% of FPL in 1976
local parent_earn = 5890 // FPL for 4 person (male-head under 65) HH with 2 children in 1976 (1976 USD)
*From  https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-poverty-thresholds.html

*Annual adult earnings effects (in percent):
local TOT = `itt'/`part_rate'
local TOT_div_mean = `TOT'/`mean_birth_wgt'
local wic_earn_effect_pct = `bw_earnings_effect'*`TOT_div_mean'
di `wic_earn_effect_pct'
di `TOT_div_mean'
	
*Compute PDV of children's future earnings gains (discounting back to year of birth):
*Assumptions: earnings impacts begin at age 34 (to match what we do for college), projections
*are from age 18 to `proj_age', children are born in 1976.
est_life_impact `wic_earn_effect_pct', ///
	impact_age(34) project_age(18) end_project_age(`proj_age') ///
	project_year(`=1976+18') usd_year(`usd_year') ///
	income_info(`parent_earn') income_info_type(parent_income) ///
	earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
	percentage(yes) parent_age(`mother_age_yrbirth') parent_income_year(1976)

local child_earn = ((1/(1+`discount_rate'))^18) * r(tot_earn_impact_d)
local prior_earnings = r(cfactual_income)
local inc_year = 2010


di  `wic_earn_effect_pct'
di `child_earn'

* CBO tax rate
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `prior_earnings' , ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`=1976+34') /// year of income measurement 
		program_age(34) ///
		earnings_type(individual) // individual or household
		
	local tax_rate = r(tax_rate)
	di r(quintile)
	di r(pfpl)
}

*Get average annual cost of program from 1974-1979 in 1976 dollars:
local year_cost_pro = 0
forval i = 74/79 {
	local year_cost_pro = `year_cost_pro' + (1/6)*(`exp_mo_`i''*12)
}

di `year_cost_pro'


**************************
/* 5. Cost Calculations */
**************************
if "`pop_interest'"=="combined" {
	local program_cost = `year_cost_pro'
	local total_cost = `program_cost' - `tax_rate'*`child_earn'
}

else if "`pop_interest'"=="parents" {
	local program_cost = `year_cost_pro'
	local total_cost = `program_cost'
}
di `program_cost'

*************************
/* 6. WTP Calculations */
*************************
local WTP_kid = 0

if "`ev_adjustment'" == "yes" local ev_adj = `ev'
else local ev_adj = 1

if "`wtp_valuation'"=="lower bound wtp" local WTP = `ev_adj'*`program_cost' 

else {
	if "`pop_interest'"=="combined" {
		local WTP = `ev_adj'*`program_cost' +  (1-`tax_rate')*`child_earn'
		local WTP_kid = (1-`tax_rate')*`child_earn'
	}
	else if "`pop_interest'"=="parents" {
		local WTP = `ev_adj'*`program_cost' 

	}
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
di `mean_birth_wgt'*`TOT_div_mean'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'

if `WTP_kid'>`=0.5*`WTP'' {
	global age_benef_`1' = `age_kid'
	}
else {
	global age_benef_`1' = `age_stat'
}	


* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `parent_earn' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `usd_year'
global inc_age_stat_`1' =  `age_stat'

if `WTP_kid'>`=0.5*`WTP'' {
	global inc_benef_`1' = `prior_earnings' * r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `inc_year'
	global inc_age_benef_`1' = 34
}
else {
	global inc_benef_`1' = `parent_earn' * r(deflator)
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `usd_year'
	global inc_age_benef_`1' =  `age_stat'
}


