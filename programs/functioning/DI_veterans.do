/*******************************************************************************
 0. Program: Disability Ins. -- DI eligibility for Vietnam veterans
*******************************************************************************/

/*
Autor, David H., Duggan, M., Greenberg, K., & Lyle, D. S. (2016). 
"The impact of disability benefits on labor supply: Evidence from the VA's 
disability compensation program"
American Economic Journal: Applied Economics, 8(3), 31-68.

Thought experiment:
Provide $1 of DI to vets via this policy
*/


********************************
/* 1. Pull Global Assumptions */
*********************************

local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"

local tax_rate_cont = $tax_rate_cont 


*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
*causal effect of $1 of DI to vets on vet earnings
local earn_reduc =  0.26 // Autor et al (2016) table 8
local earn_reduc_se =  0.09 // Autor et al (2016) table 8
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
	local estimates_list ${estimates_${name}} 
	foreach var in `estimates_list' {
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

local avg_year_of_birth = 1948 // Autor et al (2016) table 1
local year_of_policy = 2001 //approx, really 2001+

local avg_age = `year_of_policy'-`avg_year_of_birth'

local age_stat = `avg_age'
local age_benef = `age_stat' // single beneficiary

local usd_year = 2014 // Autor et al (2016) table 8 footnotes
local income_year = 1998 // Autor et al (2016) table 8

local prior_earnings = 44729 // Autor et al (2016) table 8

*********************************
/* 4. Intermediate Calculations */
*********************************

if "`tax_rate_assumption'" == "cbo"{
get_tax_rate `prior_earnings', ///
	include_transfers(yes) ///
	include_payroll(`payroll_assumption') /// "yes" or "no"
	forecast_income(no) /// "yes" or "no"
	usd_year(`usd_year') /// USD year of income
	inc_year(`income_year') /// year of income measurement 
	earnings_type(individual) ///
	
local tax_rate_cont = r(tax_rate)	
di r(quintile)
di r(pfpl)
}
* get 2015 income for wrapper
deflate_to 2015, from(`usd_year')
local income_2015 = `prior_earnings'*r(deflator)
**************************
/* 5. Cost Calculations */
**************************

local program_cost = 1

local total_cost = `program_cost' + `tax_rate_cont'*`earn_reduc'

*************************
/* 6. WTP Calculations */
*************************

local WTP = `program_cost'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

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
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `income_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `income_year'
global inc_age_benef_`1' = `age_benef'

