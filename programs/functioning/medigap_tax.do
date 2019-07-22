/*******************************************************************************
 0. Program: Medigap
*******************************************************************************/

/*
Cabral, Marika, and Neale Mahoney. 2019
"Externalities and Taxation of Supplemental Insurance: A Study of Medicare and 
Medigap." 
American Economic Journal: Applied Economics, 11 (2): 37-73.

Thought experiment:
Go from a 5% to a 0% tax on Medigap.
*/


********************************
/* 1. Pull Global Assumptions */
*********************************

*None needed

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
*All impacts relate to hypothetical 5% tax in table 9 


local tax_impact = 39 // Cabral & Mahoney (2019) table 9

local medicare_savings = 60 // Cabral & Mahoney (2019) table 9

local aggt_cost_impact = `tax_impact' + `medicare_savings' // Cabral & Mahoney (2019) table 9

*Get SE for cost impact:
/*
Combining the standard errors associated with our demand and cost estimates, we 
calculate that the standard error of our baseline estimate of 4.3 percent total 
savings is 1.7 percentage points - Cabral & Mahoney (2019) pg. 67
*/
*So take t-stat from this:
local aggt_cost_impact_t = 4.3/1.7
local aggt_cost_impact_se = `aggt_cost_impact' / `aggt_cost_impact_t'

*/

/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates.
${folder_name}, being set externally, may vary in order to use pub bias corrected estimates. */

*This inputs the agg cost impact that is computed as the sum of tax impact and medicare savings
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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local tax_increment = 0.05

local medigap_share = 0.44 // Cabral & Mahoney (2019) table 9

local medigap_premium = 1779 // Cabral & Mahoney (2019) table 9

local p_65_74 = 0.517 // Cabral & Mahoney (2019) table 2
local p_75_84 = 0.367 // Cabral & Mahoney (2019) table 2
local p_85_plus = 0.117 // Cabral & Mahoney (2019) table 2

local log_med_inc_65_74 = 10.35 // Cabral & Mahoney (2019) table 3 - 2005 USD
local log_med_inc_75_plus = 10.02 // Cabral & Mahoney (2019) table 3 - 2005 USD
local income_year = 2000 // income info comes from the 2000 census

*********************************
/* 4. Intermediate Calculations */
*********************************

local mechanical_impact = `medigap_premium'*`medigap_share'*`tax_increment'


local avg_age = 	`p_65_74'*(65+74)/2 + ///
					`p_75_84'*(75+84)/2 + ///
					`p_85_plus'*(85+90)/2 // max age of 90 is our assumption, consistent with Finkelstein medicare paper
					
local age_stat = `avg_age'
local age_benef = `age_stat'

local median_inc = exp(`log_med_inc_65_74')*`p_65_74' + exp(`log_med_inc_75_plus')*(`p_75_84'+`p_85_plus')

* inflation adjust
deflate_to 2015, from(2005)
local med_inc_2015 = `median_inc'*r(deflator)
**************************
/* 5. Cost Calculations */
**************************

local program_cost = `mechanical_impact'

local total_cost = `aggt_cost_impact'

*************************
/* 6. WTP Calculations */
*************************

local WTP = `mechanical_impact' // envelope theorem

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
global inc_stat_`1' = `med_inc_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `income_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `med_inc_2015'
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `income_year'
global inc_age_benef_`1' = `age_stat'

