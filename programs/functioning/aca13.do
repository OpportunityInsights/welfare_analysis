********************************************
/* 0. Program: T2013 ACA Surcharge + EGTRRA Expiration
 */
********************************************

/*

Kawano and Weber and Whitten (2016). 
Estimating the elasticity of broad income for high-income taxpayers

Gruber, J., & Saez, E. (2002). The elasticity of taxable income: evidence and 
implications. Journal of public Economics, 84(1), 1-32.

Saez (2017) Taxing the Rich More: Preliminary Evidence from the 2013 Tax Increase
NBER working paper 22798

Hendren (2019) Efficient welfare weights

*/
********************************
/* 1. Pull Global Assumptions */
*********************************

* Set assumptions that pull in globals. 
local paper = lower(subinstr(lower("`1'"), "aca13_", "",.))
local state_taxes ="$state_taxes" // "no" or "yes"
local tax_time = "$tax_time" // pre post or avg
if "`paper'" == "s" local method FE

*********************************
/* 2. Causal Inputs from Paper */
*********************************

*Import estimates from paper, giving option for corrected estimates
if "`1'" != "" global name = regexr("`1'", "_`paper'$", "")
if "`1'" != "" global paper = "`paper'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
	if ${draw_number} ==1 {
		preserve
			use "${input_data}/causal_estimates/${folder_name}/draws/${name}.dta", clear
			* drop estimates from other papers
			local paper = "$paper"
			keep draw_number *_`paper'
			ren *_`paper' *
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
		* again keep only relevant estimates
		local paper = "$paper"
		keep if regexm(estimate, "._`paper'$")
		replace estimate = regexr(estimate, "_`paper'$", "")
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
*Use assumptions to determine fiscal externality rate

local marginal_tax_rate_pre = 0.35
local marginal_tax_rate_post = 0.396
local pareto_parameter = 1.5 // Hendren (2019) "average alpha reaches around 1.5 at the top of the income distribution" p21
* note this the shape parameter of the pareto distribution.
if "`state_taxes'" == "yes" {
	foreach suff in pre post {
		local marginal_tax_rate_`suff' = `marginal_tax_rate_`suff'' + 0.05
	}
}
local age_stat = 49 // average age among top 5% of earners in the acs


local top_bracket_2013 = 450000 //https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf married filing jointly
*********************************
/* 4. Intermediate Calculations */
*********************************
* If income is pareto distributed (w alpha>1), average income conditional on being above a threshold y_bar
* is y_bar*alpha/(alpha-1)
local avg_income = `top_bracket_2013'*`pareto_parameter'/(`pareto_parameter'-1)
* convert to 2015 usd 
deflate_to 2015, from(2013)
local avg_income_2015 = `avg_income'*r(deflator)
**************************
/* 5. Cost Calculations */
**************************

local program_cost = 1

if "`method'"!="FE"{
	foreach suff in pre post {
		loc FE_`suff' = (`marginal_tax_rate_`suff''/(1-`marginal_tax_rate_`suff''))*`pareto_parameter'*`ETI'
	}
	local FE_avg = 0.5 * (`FE_pre' + `FE_post')
	local FE = `FE_`tax_time''
}

local total_cost = `program_cost' - `FE'

*************************
/* 6. WTP Calculations */
*************************

local WTP = 1

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'
di `pareto_parameter'
di `marginal_tax_rate_pre'
di `marginal_tax_rate_post'
di `ETI'
di `FE_pre'
di `FE_post'
di `FE'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_stat'
* income globals
global inc_stat_`1' = `avg_income_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = 2013
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `avg_income_2015'
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = 2013
global inc_age_benef_`1' = `age_stat'

