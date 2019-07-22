/*******************************************************************************
 0. Program: AFDC term limits, relaxation thereof
*******************************************************************************/

/*
Grogger, J. (2003). 
"The effects of time limits, the EITC, and other policy changes on welfare use, 
work, and income among female-headed families"
Review of Economics and statistics, 85(2), 394-408.

Pavetti, L. (1995). 
"Who is affected by time limits?"
Welfare reform: An analysis of the issues, 31-34.

We estimate the effect of removing the 60 month limit on claiming welfare benefits.
*/


********************************
/* 1. Pull Global Assumptions */
********************************

*"global" globals
local tax_rate_assumption = "$tax_rate_assumption"
if "`tax_rate_assumption'"=="continuous" local tax_rate = $tax_rate_cont 
local correlation = $correlation

*program specific globals
local inc_earnings = "$inc_earnings" // "yes" or "no" toggle inclusion of earnings effects

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
a. Effects of adding term limits on welfare participation for female headed families 
from Grogger (2003) table 2

local welfare_time_coeff =	0.0236	
local welfare_time_coeff_se = 0.0157
local welfare_time_age_int_coeff 0.0066 //age in this case is defined to be years - 13 so is negative for families with young children
local welfare_time_age_int_coeff_se 0.0015 

Effects of adding term limits on earnings
from Grogger (2003) table 2

local earnings_time_coeff	-0.7049
local earnings_time_coeff_se 0.8622
local earnings_time_age_int_coeff 0.0386 //age in this case is defined to be years - 13 so is negative for families with young children	
local earnings_time_age_int_coeff 0.073

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

*******************************
/* 3. Assumptions from Paper */
*******************************

local usd_year = 1998

*Calculate ages
local parent_age = (21.5*0.636 + 27.5*0.183 + 47*0.18)/0.999 // Pavetti (1995) figure 3 
local age_stat = `parent_age'
local age_benef = `age_stat' // no children spillover estimates are presented 

*Change in time and interaction variables from Grogger's regressions between 1999 and 1993
*Note these are from the intro, rather than removal of term limits in order to ensure the policy has a positive WTP
local time_change = 0.961-0.002 // Grogger (2003) foot 19
local time_age_int_change = -6.682 - -0.015 // Grogger (2003) foot 19

*Fraction of AFDC recipients who have been receiving for 60 months prior to reform
local afdc_60_plus = 0.346 // Pavetti (1995) figure 3 

*Baseline utilisation of AFDC from Grogger (2003)
local welfare_utilisation_1993 = 0.331 // Grogger (2003) foot 20

local max_welfare_benefit_1993 = 443*12 // Grogger (2003) table 1.  

**********************************
/* 4. Intermediate Calculations */
**********************************

*impact on claiming of removing term limits
local welfare_impact = -(`time_change'*`welfare_time_coeff' + ///
	`time_age_int_change'*`welfare_time_age_int_coeff')

*% behavioural response on claiming from removing term limits
local pct_use_inc = `welfare_impact'/`welfare_utilisation_1993'

*Earnings impact of removing term limits
local earn_impact = -1000*(`time_change'*`earnings_time_coeff' + ///
	`time_age_int_change'*`earnings_time_age_int_coeff')

local income =13940 // Grogger 2003, table 1, 1996 value
local inc_year = 1996
*Get tax rate
if "`tax_rate_assumption'" == "cbo" {
	get_tax_rate `income', /// Grogger 2003, table 1, 1996 value
		inc_year(`inc_year') ///
		earnings_type(individual) ///
		usd_year(`usd_year') ///
		include_transfers(yes) forecast_income(no) ///
		include_payroll($include_payroll)
		
	local tax_rate = r(tax_rate)
	local pfpl = r(pfpl)
}

* get 2015 income to be passed to wrapper
deflate_to 2015, from(`usd_year')
local income_2015= `income'*r(deflator)
**************************
/* 5. Cost Calculations */
**************************

*Mechanical cost, i.e. families that would go to 60+ absent behavioural response
local program_cost = (`afdc_60_plus'-`pct_use_inc')*`max_welfare_benefit_1993'


*Cost of behavioural response in welfare claiming
local FE = `pct_use_inc'*`max_welfare_benefit_1993'
di `FE'


*Cost of behavioural response in earnings
if "`inc_earnings'"=="yes" {
	local FE = `FE' - `earn_impact'*`tax_rate'
}

local total_cost = `program_cost' + `FE'

*************************
/* 6. WTP Calculations */
*************************
* The WTP is the value at transfer. We do not include the earnings benefits as a result of the envelope theorem 
local WTP = `program_cost' 

*************************
/* 7. MVPF Calculation */
*************************

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
global inc_year_stat_`1' = `inc_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `inc_year'
global inc_age_benef_`1' = `age_stat'




