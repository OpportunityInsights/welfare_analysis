********************************
/* 0. Program: SNAP Eligibility for Immigrants */
********************************

*** East (2018) Immigrants’ Labor Supply Response to Food Stamp Access
* Labor economics

* grant SNAP eligibility to single women who are documented immigrants
********************************
/* 1. Pull Global Assumptions */
********************************
local wtp_valuation = "${wtp_valuation}"

local correlation = $correlation
*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
local total_snap_change = 275.3 // East(2018) table 4 col 6
local total_snap_change_se = 121.1 // East(2018) table 4 col 6

local emp_change = -0.048 // East(2018) table 5 column 9
local emp_change_se = 0.022 // East(2018) table 5 column 9

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
local avg_snap_amount = 3317 // East (2018) p19 
local mean_age = 35 // East (2018) table 3 


local hh_inc = 1500/0.15
local usd_year = 2017
/*
"average annual SNAP benefits are about $1,500, or about 15 percent of household 
income among the eligible (Center on Budget and Policy Priorities, 2017)." 
Finkelstein & Notowidigdo (2018)
*/
*Equivalent variation adjustment 
*NOTE: Adjustment only used as lower bound b/c Hoynes and Schanzenbach (2009) find that most people were inframarginal
local ev = .65 // Whitmore (2002) ("What Are Food Stamps Worth" WP)

*********************************
/* 4. Intermediate Calculations */
*********************************
deflate_to 2015, from(`usd_year')

local income_2015 = `hh_inc'*r(deflator)

**************************
/* 5. Cost Calculations */
**************************
local program_cost = `total_snap_change' + `emp_change'*`avg_snap_amount' // remove the behavioural response part
local total_cost = `total_snap_change'
di `emp_change'*`avg_snap_amount' 

*************************
/* 6. WTP Calculations */
*************************

local WTP = `program_cost' // only value the mechanical part
if "`wtp_valuation'" == "lower bound" {
	local WTP = `ev'*`program_cost'
}

**************************
/* 7. MVPF Calculations */
**************************

di `WTP'
di `total_cost'

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'

* pass results back to the wrapper
global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'

global age_stat_`1' = `mean_age'
global age_benef_`1' = `mean_age'

* income globals
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `usd_year'
global inc_age_stat_`1' = `mean_age'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `usd_year'
global inc_age_benef_`1' = `mean_age'

