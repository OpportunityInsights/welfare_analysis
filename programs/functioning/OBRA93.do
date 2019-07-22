********************************************
/* 0. Program: Tax Rate - OBRA 1993 - Pre */
********************************************
local bootstrap = "`2'"
/*
Carroll (1998)
Do taxpayers really respond to changes in tax rates? Evidence from the 1993 tax act
US department of the Treasury Office of Tax Analysis

Goolsbee (2000)
What happens when you tax the rich? Evidence from executive compensation

Hall And Liebman (2000)
The taxation of executive compensation
in Tax policy and the Economy

Giertz (2007)
The elasticity of taxable income over the 1980s and 1990s
National Tax Journal

Burns, S. K., & Ziliak, J. P. (2017). 
Identifying the elasticity of taxable income. 
The Economic Journal, 127(600), 297-329.


Kopczuk, W. (2005). Tax bases, tax rates and the elasticity of reported income. 
Journal of Public Economics, 89(11-12), 2093-2119.

Gruber, J., & Saez, E. (2002). The elasticity of taxable income: evidence and 
implications. Journal of public Economics, 84(1), 1-32.

*/
********************************
/* 1. Pull Global Assumptions */
*********************************

* Set assumptions that pull in globals.
local paper = lower(subinstr(lower("`1'"), "obra93_", "",.))
local state_taxes = "$state_taxes" // "no" or "yes"
local tax_time = "$tax_time" // pre post or avg

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
if "`paper'" == "c" { //"carroll_1998"{
	local ETI = 0.38 // Table 6, adjusted taxable income, full model
	local ETI_se = 0.12
}

if "`paper'" == "g" { //"goolsbee_2000"{
	local ETI = 1.224-0.887 //table 3: effects estimated at t, t+1
	local ETI_se_1 = 0.107
	local ETI_se_2 = 0.118
	
	local ETI_se = sqrt(`ETI_se_1'^2 + `ETI_se_2'^2 + `ETI_se_1'*`ETI_se_2')
	*Conservative SE assumption of correlation of one between coefficient estimates
}
if "`paper'" == "hl" { //"hall_liebman_2000_obra93"{
	local ETI = 0.108 - 0.134 //table 9
	local ETI_se_1 = 0.324
	local ETI_se_2 = 0.336
	
	local ETI_se = sqrt(`ETI_se_1'^2 + `ETI_se_2'^2 + `ETI_se_1'*`ETI_se_2')
	*Conservative SE assumption of correlation of one between coefficient estimates
}
if "`paper'" == "giertz" { //"giertz_2007"{
	local ETI = 0.198 //Giertz (2007), Table 8 (Spline controls, taxable income)
	local ETI_se = 0.060
}
if "`paper'" == "bz" { //"burns_ziliak_2017"{
	local ETI = 0.431 // table 1
	local ETI_se = 0.245
}


*/
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
			di "`paper'"
			di "`name'"
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

local marginal_tax_rate_pre = 0.31
local marginal_tax_rate_post = 0.396
local pareto_lorenz_coeff = 2.3 // Atkinson, Piketty & Saez (2011) figure 12, 1993 value

if "`state_taxes'" == "yes" {
	foreach suff in pre post {
		local marginal_tax_rate_`suff' = `marginal_tax_rate_`suff'' + 0.05
	}
}
local age_stat = 49 // average age among top 5% of earners in the acs

*********************************
/* 4. Intermediate Calculations */
*********************************

*Calculate implied pareto parameter from coefficient estimate in Akinson et al.
local pareto_parameter = `pareto_lorenz_coeff' / (`pareto_lorenz_coeff' -1)

*Get average income amongst top bracket
local usd_year = 1993 // nominal for bracket
local top_income_bracket_1993 = 250000  // Tax Foundation (2003)
*https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf

local avg_top_income = `top_income_bracket_1993'*`pareto_lorenz_coeff' // conditional expectation, see Atkinson et al. for derivation

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
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `avg_top_income' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = 1993
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `avg_top_income' * r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = 1993
global inc_age_benef_`1' = `age_stat'
