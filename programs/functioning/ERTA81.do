****************************************************************
/* 0. Program: Tax Rate - Economic Recovery Act of 1981 - Pre */
****************************************************************
/*

Kopczuk, W. (2005). Tax bases, tax rates and the elasticity of reported income. 
Journal of Public Economics, 89(11-12), 2093-2119.

Gruber, J., & Saez, E. (2002). The elasticity of taxable income: evidence and 
implications. Journal of public Economics, 84(1), 1-32.

Burns and Ziliak (2017) Identifying the elassticity of taxable income
The economic journal

Saez (2003) The effect of marginal tax rates on income: a panel study of bracket creep
JPE
*/
********************************
/* 1. Pull Global Assumptions */
*********************************

* Set assumptions that pull in globals. 
local paper = lower(subinstr(lower("`1'"), "erta81_", "",.))
local state_taxes = "$state_taxes" // "no" or "yes"
local tax_time = "${tax_time}"

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
if "`paper'" == "gs" { //"gruber_saez_2002"{
	local ETI = 0.567 //Gruber and Saez (2002) : taxable income in Table 8 (100K+ income group)
	local ETI_se = 0.298
}
if "`paper'" == "s" { //"saez_2003"{
	local ETI = 0.311 //Saez (2003), Table 5 (Taxable income, itemizers and non-itemizers)
	*See page 39 of Saez Slemrod and Giertz for discussion of 0.42 pre 1986 reform.
	local ETI_se = 0.165
}

if "`paper'" == "k" { //"kopczuk_2005"{
	local ETI = 0.357 //Table 5 (t-1 income >10K)
	*See page 44 of Saez Slemrod and Giertz for discussion of 0.36 post 1986 reform because of expanded base.
	local ETI_se = 0.431 
}
if "`paper'" == "bz" { //"burns_ziliak_2017"{
	local ETI = 0.431 // table 1
	local ETI_se = 0.245
}
*/
if "`1'" != "" global name = regexr(lower("`1'"), "_`paper'$", "")
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
	if ${draw_number} ==1 {
	preserve
		use "${input_data}/causal_estimates/${folder_name}/draws/${name}.dta", clear
		* drop estimates from other papers
		keep draw_number *_`paper'
		ren *_`paper' *
		qui ds draw_number, not 
		global estimates_${name} = r(varlist)
		
		mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
		restore
	}
	foreach var in "${estimates_${name}}" {
		matrix temp = draws_${name}["${draw_number}", "`var'"]
		local `var' = temp[1,1]
	}
}
if "`bootstrap'" != "yes" {
preserve
		import delimited "${input_data}/causal_estimates/${folder_name}/${name}.csv", clear
		* again keep only relevant estimates
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

local marginal_tax_rate_pre = 0.70
local marginal_tax_rate_post = 0.50
local pareto_lorenz_coeff = 1.77 // Atkinson, Piketty & Saez (2011) figure 12, 1981 value

if "`state_taxes'" == "yes" {
	foreach suff in pre post {
		local marginal_tax_rate_`suff' = `marginal_tax_rate_`suff'' + 0.05
	}
}
local age_stat = 49 // average age among top 5% of earners in the acs
local top_bracket_1981 = 215400 //https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf married filing jointly

*********************************
/* 4. Intermediate Calculations */
*********************************

*Calculate implied pareto parameter from coefficient estimate in Akinson et al.
local pareto_parameter = `pareto_lorenz_coeff' / (`pareto_lorenz_coeff' -1)


* If income is pareto distributed (w alpha>1), average income conditional on being above a threshold y_bar
* is y_bar*alpha/(alpha-1)
local avg_income = `top_bracket_1981'*`pareto_lorenz_coeff'
* convert to 2015 usd 
deflate_to 2015, from(1981)
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

