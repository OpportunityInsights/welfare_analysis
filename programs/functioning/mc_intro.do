***************************************
/* 0. Program: Medicaid Intro */
***************************************

/*Goodman-Bacon, Andrew.
The long-run effects of childhood insurance coverage:
Medicaid implementation, adult health, and labor market outcomes.
No. w22899. National Bureau of Economic Research, 2017.
https://cdn.vanderbilt.edu/vu-my/wp-content/uploads/sites/2318/2019/04/14141045/medicaid_longrun_ajgb.pdf

These calculations exclusively use Goodman-Bacon (2017) table 9. These estimates
are discounted sums so we cannot vary interest rates here.
*/

********************************
/* 1. Pull Global Assumptions */
********************************


*********************************
/* 2. Estimates from Paper */
*********************************

/*
*Total FE
local total_FE = 383.31 // Goodman-Bacon (2017) table 9
*Get FE standard error from pctiles of public return
*Assume normality even though CIs are from bootstrap distribution
local pub_return_pe = 0.83
local pub_return_p5 = -0.74
local pub_return_p95 = 2.32
local pub_return_se = (`pub_return_p95'-`pub_return_p5')/(invnormal(0.95)*2)
local pub_return_t = `pub_return_pe'/`pub_return_se'
local total_FE_t = `pub_return_t'
local total_FE_se = `total_FE'/`total_FE_t'
di `total_FE_se'
*/

/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates.
${folder_name}, being set externally, may vary in order to use pub bias corrected estimates. */
*Import estimates from paper, giving option for corrected estimates
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

*Total medicaid outlays
local medicaid_outlays = 463.98 // Goodman-Bacon (2017) table 9

*Change in transfers
local transfer_change = -236.61 // Goodman-Bacon (2017) table 9

*Change in welfare (change in transfers + value of QALYs)
local change_in_welfare = 825.70 // Goodman-Bacon (2017) table 9
*We assume the welfare change is non-stochastic for simplicity, with the FE being
*the only component we take draws of

local age_kid = (0+18)/2 // looks at expansions throughout childhood

local intro_year = round((1970+1966)/2) // program introduction is 1966-1970

*Get mother age at birth then add kid age
get_mother_age `intro_year', yob(`intro_year')
local age_parent = r(mother_age) + `age_kid'

*********************************
/* 4. Intermediate Calculations */
*********************************

local usd_year = 2015 // Goodman-Bacon pg. 25

*Impacts here are on AFDC eligibles
*Approximate income of parents at 100% of FPL
deflate_to 2015, from(1965)
local parent_earn = 3223 *r(deflator) // FPL for 4 person HH in 1965
*U.S. Bureau of the Census, Income, Poverty, and Health Insurance Coverage in
*the United States: 2008; 2010; 2012. Web: www.census.gov.
di `parent_earn'

*Child income
local child_inc = 31917 // Goodman-Bacon table 8, 2000-2015
local child_inc_year = round((2015+2000)/2)
local child_inc_age = `child_inc_year'-`intro_year'
di `child_inc_age'

**************************
/* 5. Cost Calculations  */
**************************

local program_cost = `medicaid_outlays'

local total_cost = `program_cost' - `total_FE'

*************************
/* 6. WTP Calculations */
*************************

if "$wtp_assumption"=="normal" {
	local WTP = `change_in_welfare'
}
if "$wtp_assumption"=="lower bound" {
	local WTP = `medicaid_outlays' + `transfer_change'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 9. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global observed_`1' = 49
global age_stat_`1' = `age_parent'
global age_benef_`1' = `age_kid'


* income globals

global inc_stat_`1' = `parent_earn'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = 1965
global inc_age_stat_`1' = `age_parent'

global inc_benef_`1' = `child_inc'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `child_inc_year'
global inc_age_benef_`1' = `child_inc_age'
