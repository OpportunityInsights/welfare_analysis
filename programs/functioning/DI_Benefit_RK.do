/*******************************************************************************
 0. Program: Disability Ins. -- Benefit Regression Kink
*******************************************************************************/

/*
Gelber, Alexander, Timothy J. Moore, and Alexander Strand. 
"The Effect of Disability Ins. Payments on Beneficiaries' Earnings."
American Economic Journal: Economic Policy 9, no. 3 (2017): 229-61.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************
local tax_rate_assumption = "$tax_rate_assumption" //takes value paper internal or cont, See Output_Wrapper.do for additional documentation
local tax_rate_cont = $tax_rate_cont 
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

*********************************
/* 2. Estimates from Paper */
*********************************
/*
local earning_impact_y4 = -0.2020 // Gelber et al. 2017, Table 4
local earning_impact_y4_se = 0.0258 // Gelber et al. 2017, Table 4
Note: Calculations here focus on the earnings impact in the fourth year. The results
are quite stable across years 1-4. */

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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local avg_benefit = 1 //marginal policy

local age_stat = 49.8 // Gelber et al. 2017, Table 1
local age_benef = `age_stat' // single beneficiary

local prior_earnings = 36680 // Gelber et al. 2017, Table 1
local usd_year 2013 // Gelber et al. 2017, page 230
local inc_year 2004 // Gelber et al. 2017, Table 1: 2001-2007

*********************************
/* 4. Intermediate Calculations */
*********************************

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `prior_earnings' , ///
		include_transfers(yes) /// not included separately
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no" -> want the tax rate for this specific point in time not lifetime average
		usd_year(`usd_year') /// USD year of income
		inc_year(`inc_year') /// year of income measurement 
		earnings_type(individual) // individual or household
		local tax_rate_cont = r(tax_rate)
		di r(quintile)
		di r(pfpl)
}
di `earning_impact_y4'

local fe = -`earning_impact_y4'*`tax_rate_cont'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `avg_benefit'

local total_cost = `program_cost' + `fe'

*************************
/* 6. WTP Calculations */
*************************

local WTP = `avg_benefit'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'
di `MVPF'

*****************
/* 8. Outputs */
*****************
global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `prior_earnings' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `inc_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `prior_earnings' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `inc_year'
global inc_age_benef_`1' = `age_benef'
