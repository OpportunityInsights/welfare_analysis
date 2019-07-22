********************************************
* 0. Program: 2001 EGTRRA
********************************************
/*
Kawano and Weber and Whitten (2016). 
Estimating the elasticity of broad income for high-income taxpayers

Heim (2009) 
The effect of recent tax changes on taxable income: Evidence from a new panel 
of tax returns

Auten, G., Carroll, R., & Gee, G. (2008). 
The 2001 and 2003 tax rate reductions: An overview and estimate of the taxable 
income response. 
National Tax Journal, 345-364.

Burns, S. K., & Ziliak, J. P. (2017). 
Identifying the elasticity of taxable income. 
The Economic Journal, 127(600), 297-329.

Atkinson, A. B., Piketty, T., & Saez, E. (2011). 
Top incomes in the long run of history. 
Journal of economic literature, 49(1), 3-71
*/
********************************
/* 1. Pull Global Assumptions */
*********************************

* Set assumptions that pull in globals.
local paper = lower(subinstr(lower("`1'"), "egtrra01_", "",.))
local state_taxes = "$state_taxes" // "no" or "yes"
local tax_time = "$tax_time" // pre post or avg

*********************************
/* 2. Estimates from Paper */
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

/*
if "`paper'" == "h" { // Heim (2009) 
	local ETI = 0.223 // Table 5, col 2, income > 50,000 spec
	local ETI_se = 0.152
}
if "`paper'" == "acg" { //"auten_carroll_gee_2008"{
	local ETI = 0.389 // table 3
	local ETI_se = 0.075
}
if "`paper'" == "k" { //"kawano_et_al_2016"{
	local ETI = 0.123 // table 2, column (4), permanent elasticity
	local ETI_p = 0.401
	local ETI_t = invnormal(1-`ETI_p')
	local ETI_se = `ETI'/`ETI_t'
}
if "`paper'" == "bz" { //"burns_ziliak_2017"{
	local ETI = 0.431 // table 1
	local ETI_se = 0.245
}
*/


****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

*Use assumptions to determine fiscal externality rate
local marginal_tax_rate_pre = 0.396 
local marginal_tax_rate_post = 0.35
local pareto_lorenz_coeff = 2.55 // Atkinson, Piketty & Saez (2011) figure 12, 2001 value

if "`state_taxes'" == "yes" {
	foreach suff in pre post {
		local marginal_tax_rate_`suff' = `marginal_tax_rate_`suff'' + 0.05
	}
}

local age_stat = 49 // average age among top 5% of earners in the ACS

*********************************
/* 4. Intermediate Calculations */
*********************************

*Calculate implied pareto parameter from coefficient estimate in Akinson et al. (2011)
local pareto_parameter = `pareto_lorenz_coeff' / (`pareto_lorenz_coeff' -1)

*Get average income amongst top bracket
local usd_year = 2001 // nominal for bracket
local top_income_bracket_2001 = 311950 // Tax Foundation (2003)
*https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf

local avg_top_income = `top_income_bracket_2001'*`pareto_lorenz_coeff' // conditional expectation, see Atkinson et ak. for derivation

**************************
/* 5. Cost Calculations */
**************************

local program_cost = 1

if "`method'"!="FE" {
	*Calculate FEs for pre and post periods
	foreach suff in pre post {
		loc FE_`suff' = (`marginal_tax_rate_`suff''/(1-`marginal_tax_rate_`suff''))*`pareto_parameter'*`ETI'
	}
	*Average
	local FE_avg = 0.5 * (`FE_pre' + `FE_post')
	*Choose pre, post or average depending on external assumption
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
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `avg_top_income' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = 2001
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `avg_top_income' * r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = 2001
global inc_age_benef_`1' = `age_stat'
