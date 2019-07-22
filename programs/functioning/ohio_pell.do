/********************************************************************************
0. Program : Pell Grants in Ohio
*******************************************************************************/

/* Bettinger, E. (2004). How financial aid affects persistence.
In College choices: The economics of where to go, when to go, and how to pay for
it (pp. 207-238). University of Chicago Press.
*/

* Use discontinuities in Pell Grant eligibility to determine impacts on persistent
* student enrollment. 

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption"
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type"
local proj_age = $proj_age
local correlation = $correlation
local wtp_valuation = "$wtp_valuation"
local val_given_marginal = $val_given_marginal

*Program Specific Globals
local years_reenroll = $years_reenroll

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"
local transfer_assumption = "$transfer_assumption"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}


*********************************
/* 2. Estimates from Paper */
*********************************

/*

local withdrawal_effect = -0.064 // Bettinger (2004) Table 5.3 effect of Pell Grant increases on pr that student withdraws, for 4-year students
local withdrawal_effect_se = 0.003 //Bettinger (2004) Table 5.3 effect of Pell Grant increases on pr that student withdraws, for 4-year students


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


*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************
local program_year = 2000
local usd_year = 2000 //Bettinger (2004) doesn't mention inflation adjustment but data is from 1999-2001
local withdrawal_avg = 0.201 // Bettinger (2004) table 5.1 average of a dummy for leaving higher ed after one year (for students at 4year institutions)
local age_benef = 18.8 // Bettinger (2004) table 5.1 4 year college
* estimate average efc for all Pell grant dependent recipients from table 2B of
* https://www2.ed.gov/finaid/prof/resources/data/1998-1999pell.pdf
* use 1998-1999 because the reports for 1999-2001 are unavailable
local avg_efc = 0 * (0.243 + 0.154) + 100*0.066 + 300*0.047 + ///
	500 *0.045 + 700*0.046 + 900*0.045+ 1100*0.045 + 1300*0.043 + 1500*0.043 + ///
	1700*0.041 + 1900*0.041 + 2100*0.038 + 2300*0.037 + 2500*0.034 + 2700*0.031


local parent_income = 21863 // average family income of dependent Pell
* recipients in 1998-1999 ( the report for 1999-2000 is unavailable)
*p7: https://www2.ed.gov/finaid/prof/resources/data/1998-1999pell.pdf


*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 19 // this is about reenrollment into second year so people are ~19
local proj_short_end = 24
local impact_age = 21
local project_year = `program_year'
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `program_year' +`proj_start_age_pos' - 19
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

*********************************
/* 4. Intermediate Calculations */
*********************************
deflate_to `usd_year', from(1999)
local parent_income = `parent_income'*r(deflator)
local avg_efc = `avg_efc'*r(deflator)
/* Probability that a non treated student drops out is p. Probability that a treated
student (one that receives an extra $1000) drops out is p + withdrawal_effect
(where withdrawal effect is negative). So the treat - control difference in pr
of reenrollment is 1-(p+withdrawal_effect) - (1-p) = -withdrawal_effect
*/
* Thus:
local years_impact = -`withdrawal_effect'*`years_reenroll'

	*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)


local induced_fraction = (-`withdrawal_effect'/(1 - `withdrawal_avg' - `withdrawal_effect'))


*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(1999) percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, because this will give an artificially high MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age') // age at income measurement
	  local tax_rate_shortrun = r(tax_rate)
	}

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'

	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(1999) percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-18))

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings to get a realistic lifetime MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year_pos') /// year of income measurement
		earnings_type(individual) /// individual, because that is what int_outcome produces
		program_age(`impact_age_pos') // age we're projecting from
	  local tax_rate_longrun = r(tax_rate)
	}

	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = (1-`tax_rate_longrun') * `total_earn_impact_pos'

	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
}
else {
	di as err "Only growth forecast allowed"
	exit
}

**************************
/* 5. Cost Calculations */
**************************
*Discounting for costs:
local years_reenroll_disc = 0
local end = ceil(`years_reenroll')
forval i=1/`end' {
	local years_reenroll_disc = `years_reenroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_reenroll' - floor(`years_reenroll')
if `partial_year' != 0 {
	local years_reenroll_disc = `years_reenroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}
local years_impact_disc = -`withdrawal_effect'*`years_reenroll_disc'
 
	
local program_cost = 1000

if "${got_ohio_pell_costs}"!="yes" {
	cost_of_college, year(`program_year') state(OH) type_of_uni("rmb")
	global ohio_pell_cost_of_college = r(cost_of_college)
	global got_ohio_pell_costs yes
}
local cost_of_college = $ohio_pell_cost_of_college

*Calculate Cost of Additional enrollment
local priv_cost_impact = `years_impact_disc' * `avg_efc' // Assume private costs are determined by the estimated family contribution
local enroll_cost = `years_impact_disc'*(`cost_of_college') - `priv_cost_impact' // Yearly Costs of those induced to enroll, minus the effective family contribution
/* Note: We assume that additional schooling due to increased credits has costs
that scale as a fraction of yearly educational expenditures. */

local total_cost = `program_cost' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = `total_earn_impact_aftertax' - `priv_cost_impact'
	*Uninduced value at program cost
	local wtp_not_induced = `program_cost'*(1 - `induced_fraction')
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `induced_fraction'*`program_cost'*`val_given_marginal'
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `program_cost'*(1 - `induced_fraction')
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

*Locals for Appendix Write-Up 
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost'
di `priv_cost_impact'
di `increase_taxes'
di `enroll_cost'
di `total_cost'


****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'
di `increase_taxes_enrollment'
di `increase_taxes_attainment'
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `priv_cost_impact'
di `increase_taxes'
di `enroll_cost'
di `induced_fraction'


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_benef'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `impact_year_pos'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year_pos'
global inc_age_benef_`1' = `impact_age_pos'
