********************************
/* 0. Program: NSW Ex Addict */
********************************

/*
Hollister, Robinson G., Peter Kemper, and Rebecca A. Maynard.
"The national supported work demonstration." (1984).
Chapter: Kemper P., David A. Long and Craig Thorton.
"A Benefit-Cost Analysis of the Supported Work Experiment."
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local tax_rate_assumption = "$tax_rate_assumption" //takes value paper internal, continuous
if "`tax_rate_assumption'" == "continuous" {

	local tax_rate_cont = $tax_rate_cont
}
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

local net_transfers = "$net_transfers" //takes value yes if adjustments for changes in net transfers
local wtp_valuation = "$wtp_valuation" //takes on value of "program effects", "program cost" or "transfers"


*********************************
/* 2. Causal Inputs from Paper */
*********************************

* None of the relevant causal estimates reported in the paper include standard errors.

local static_tax_fe = 553 // KLT Page 256, Table 8.5.
*Participant short-term tax payment due to program participation.

local static_welfare_fe = -219 // KLT Page 256, Table 8.5.
*Participant short-term change in welfare receipt due to program participation.

local initial_earnings = 304 // KLT Page 256, Table 8.5.
*Participant short-term earnings gain due to program partcipation.

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local usd_year = 1976

*Use ages from AFDC sample as no direct ages for ex addicts
local mean_age = 33
local program_year = 1976

local program_cost = 4153 // Kemper, Long, Thornton (1984) Page 256, Table 8.5.
*Figure for net cost to "non-participant."

local program_pay = 2489 // Kemper, Long, Thornton (1984) Page 256, Table 8.5.
*Figure for net cost to "participant."

local alt_program_admin =  168 // Kemper, Long, Thornton (1984) Page 256, Table 8.5.
*Cost to the government of other training programs foregone when individuals enroll in NSW.
local alt_program_training = 32 // Kemper, Long, Thornton (1984) Page 256, Table 8.5.
*Reductions in payments to individuals from training programs foregone when individuals enroll in NSW.

local earn_impact_obs = `initial_earnings' + `program_pay'

*No direct income observed but aimed at AFDC eligible so use federal poverty line
deflate_to `usd_year', from(1978) //Convert from Kemper, Long & Thornton (1984)
local deflate_fpl = r(deflator)
*No direct income observed but aimed at AFDC eligible so use federal poverty line
local cfactual_income = 6612*`deflate_fpl' // 1978 FPL for family of 4 with 2 children, from Census source in get_tax_rate.ado. Date only goes back to 1978, so we deflate to 1976


*********************************
/* 4. Intermediate Calculations */
*********************************

*Use assumptions to determine fiscal externality rate
if "`tax_rate_assumption'" == "paper internal" {
	local fe_rate = (`static_tax_fe')/(`earn_impact_obs')
}

if "`tax_rate_assumption'" == "continuous" {
	local fe_rate = `tax_rate_cont'
}

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `cfactual_income', ///
		include_transfers(no) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`program_year') /// year of income measurement
		program_age(`mean_age') ///
		earnings_type(household) // individual or household

	local fe_rate = r(tax_rate)
}


*Calculate Total Transfers if net transfers are included in WTP
local change_transfers = -`earn_impact_obs'*`fe_rate'
if "`net_transfers'" == "yes" {
	local change_transfers = `change_transfers' + `static_welfare_fe' - `alt_program_training'
}

**************************
/* 5. Cost Calculations */
**************************

local fe = -`earn_impact_obs'*`fe_rate' + `static_welfare_fe' - `alt_program_admin'

local total_cost = `program_cost' + `fe'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	local WTP = `earn_impact_obs' + `change_transfers'
}

if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost'
}

if "`wtp_valuation'" == "reduction private spending" {
	*This is something of a lower bound: participant values at value of alternate
	*programs, i.e. what they were willing to forego
	local WTP =  `alt_program_admin' +  `alt_program_training'
}

if "`wtp_valuation'" == "lower bound" {
	local WTP = 0.01*`program_cost'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `mean_age'
global age_benef_`1' = `mean_age'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_income' *r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `program_year'
global inc_age_stat_`1' = `mean_age'

global inc_benef_`1' = `cfactual_income'*r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `program_year'
global inc_age_benef_`1' = `mean_age'
