/*******************************************************************************
 0. Program: SSI with impacts on children
*******************************************************************************/

/*
Deshpande, M. (2016)
"Does welfare inhibit success? The long-term effects of removing low-income youth 
from the disability rolls" 
American Economic Review, 106(11), 3300-3330.
*/

/*NOTE: We perform a static MVPF calculation using Deshpande's annual-average 
results since the relative magnitudes of the SSI and earnings effects are essentially 
constant (earnings effect is roughly 1/3 of the SSI effect in Fig. 5) 
sufficiently far into adulthood.*/

********************************
/* 1. Pull Global Assumptions */
********************************
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"
local wtp_valuation = "$wtp_valuation"
local tax_rate_cont = $tax_rate_cont 
local correlation = $correlation

*Program-specific globals
local insur_val = "$insur_val" // "yes" or "no" toggle for valuation of reduction in income volatility

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
*NOTE: All estimates from Deshpande (2016) relate to removal from SSI at age-18 review.
local ssi_impact = -7886 // Deshpande (2016) table 4
local ssi_impact_se = 276 // Deshpande (2016) table 4

local earn_impact = 3001 // Deshpande (2016) table 4
local earn_impact_se = 1421 // Deshpande (2016) table 4

local di_impact = -551 // Deshpande (2016) table 4
local di_impact_se = 350 // Deshpande (2016) table 4
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

local age_stat = 18 // removal happens at age 18
local control_mean_ssi = 4055 // Deshpande (2016) table 4
local control_mean_earn = 4222 // Deshpande (2016) table 4
local control_mean_di = 688 // Deshpande (2016) table 4

*Only mechanical size of the transfer is valued. Therefore, we subtract the size 
*of the transfer that is increased due to reductions in earnings
local earn_disregard = 0.5

*Deshpande's results are pooled for 1997-2012 (cf. Table 4), so taking midpoint.
local inc_year = 2004
local usd_year = 2004

*Additional WTP from insurance value of SSI
if "`insur_val'" == "yes" local insur_val_premium = 0.15 // Deshpande (2016) pg. 3327
if "`insur_val'" == "no" local insur_val_premium = 0

**********************************
/* 4. Intermediate Calculations */
**********************************

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `control_mean_earn' , ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`inc_year') /// year of income measurement 
		earnings_type(individual) // individual or household
	local tax_rate_cont = r(tax_rate)
	di r(quintile)
	di r(pfpl)
}

**************************
/* 5. Cost Calculations */
**************************

local program_cost = -`ssi_impact' - (`earn_disregard'*`earn_impact')

local FE = -`di_impact' + `earn_impact'*`tax_rate_cont'

local total_cost = -`ssi_impact' + `FE'

di	(`earn_disregard'*`earn_impact')
di 	`ssi_impact'
di `total_cost'/`program_cost'
*************************
/* 6. WTP Calculations */
*************************

* thought experiment is NOT removing someone at 18, so SSI receipt increases and 
* earnings don't increase, relative to being removed
local WTP = (1+`insur_val_premium') * ((-`ssi_impact') - (`earn_disregard'*`earn_impact'))
di "(1+`insur_val_premium') * (-`ssi_impact') - (`earn_disregard'*`earn_impact')"

if "`wtp_valuation'" == "lower bound" local WTP = -`ssi_impact' - (`earn_disregard'*`earn_impact')

*************************
/* 7. MVPF Calculation */
*************************

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
global age_benef_`1' = 	`age_stat' 

* income globals
global inc_stat_`1' = `control_mean_earn'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `inc_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `control_mean_earn'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `inc_year'
global inc_age_benef_`1' = `age_stat'
