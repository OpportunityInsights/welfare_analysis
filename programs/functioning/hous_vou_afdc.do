***********************************************************
/* 0. Program: Housing Vouchers: Mills/Wood			 */
***********************************************************


/*
Wood, M., Turnham, J., & Mills, G. (2008). Housing affordability and family
wellbeing: Results from the housing voucher evaluation. Housing Policy Debate,
19(2), 367-412.
Mills, G., Gubits, D., Orr, L., Long, D., Feins, J., Kaul, B., ... & Jones, A. (2006).
Effects of housing vouchers on welfare families.
Washington, DC: US Department of Housing and Urban Development, Office of Policy
Development and Research.
[abt associates]
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local ev_correction = "$ev_correction" // "yes" or "no"

*'global' globals
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo": for cbo, see section 4
if "`tax_rate_assumption'" == "continuous" local tax_rate = $tax_rate_cont
local correlation = $correlation
local wtp_valuation = "$wtp_valuation" // "cost" or "post tax"
local proj_type = "$proj_type" // "growth forecast" or "no kids"
if "`proj_type'" == "growth forecast" local forecast_assumption = "yes"
if "`proj_type'" == "no kids" local forecast_assumption = "no"

local disc_rate = $discount_rate
local discount_rate = $discount_rate
local proj_age = $proj_age
local years_enroll = $years_enroll
local value_transfer = "$value_transfer"

local payroll_assumption = "$payroll_assumption"

******************************
/* 2. Estimates from Paper */
******************************
/*
*Aggregate 7/2 years earnings impact estimate
local earn_impact_total = -1218 // Mills et al. exhibit 4.9
local earn_impact_total_se = 1120 // Mills et al. exhibit 4.9

*Aggregate 7/2 years food stamps & tanf impact
local food_stamp_tanf_impact = 1918 // Mills et al. exhibit 4.18
local food_stamp_tanf_impact_se = 579 // Mills et al. exhibit 4.18

local tanf_impact = 739 // Mills et al. exhibit 4.16
local tanf_impact_se = 339 // Mills et al. exhibit 4.16

*impacts on child college attendance
local college_impact = 0.000 // Mills et al. exhibit 6.3
local college_impact_se = 0.001 // 0.000 in Mills et al. exhibit 6.31

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


*********************************
/* 3. Assumptions from Paper */
*********************************
local age_stat = 30.7 // mills et al exhibit 1.2
local age_kid = 6.0 // Mills et al exhibit 6.1

local usd_year = 2006 //assume same year as 2006 publication of abt associates report
local income_year = 2002 //year from median half-year,  Mills et al. exhibit 4.9

local years_vouchers = 4 // program operated 2000-2004
/*
The program operated for four years, but the earnings impacts were calculated in
half years that did not fully line up to the start of and end of that period. In
order to avoid an extrapolation without basis in evidence we measure costs based
on four years of transfers and measure earnings impacts and transfer changes based
on the three and a half years observed.
*/

/*
"The dollar value of the voucher was high for some families and more modest for others,
but on average was more than $500 a month." - Wood et al. pg. 400 footnote 33
We consequently assume that the value is between $500 and $600 at $550.

We prefer this estimate of the value of the voucher to the nationwide average of
$456 reported in Mills et al. 2006
*/
local voucher_cost = 550*12

*Total income over 7 half years: convert to yearly
local control_mean_earn = 2*(19532/7) //Mills et al. exhibit 4.9

local num_kids = 2 // Assumed

/*
"Reeder (1985) estimates the ratio of mean benefit to mean subsidy for housing
vouchers to be around 0.83, so that the average equivalent variation of a housing
voucher for our sample is $6,860 per year." - Jacob & Luidwig pg. 281
*/
local benefit_ratio = 0.83
if "`ev_correction'" == "yes" local ev_coeff = `benefit_ratio'
else local ev_coeff = 1

**********************************
/* 4. Intermediate Calculations */
**********************************

*Convert estimates over entire sample period to yearly averages
*(7 half years in sample period)
local food_stamp_tanf_impact = `food_stamp_tanf_impact'/(7/2)
local earn_year_impact = `earn_impact_total'/(7/2)
/*
Note: Values are split evenly to preserve SEs on total sum. The result
is more conservative given the decline in earnings changes over time.
*/

local years_impact = `college_impact'*`years_enroll'

*Forecast impact on kids
if "`proj_type'" == "growth forecast" {
	*Forecast impact on average child
	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')

	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

	*Initial Earnings Decline
	local proj_start_age = 18
	local proj_short_end = 24
	local impact_age = 34
	local project_year = 2006 // effects observed as of 2006

	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`control_mean_earn') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)

	local total_earn_impact_neg = r(tot_earn_impact_d)
	local cfactual_inc_kid = r(cfactual_income)

	get_tax_rate `cfactual_inc_kid', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(2018) /// year of income measurement
		earnings_type(individual) ///
		program_age(`impact_age') // age of income measurement

	local tax_rate_kid = r(tax_rate)
	local increase_taxes_neg = `tax_rate_kid' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = `total_earn_impact_neg' - `increase_taxes_neg'

	*Earnings Gain
	local proj_start_age = 25
	local impact_age = 34
	local project_year = 2006+7 // effects observed as of 2006

	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`control_mean_earn') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

	local total_earn_impact_pos = ((1/(1+`discount_rate'))^7) * r(tot_earn_impact_d)
	local increase_taxes_pos = `tax_rate_kid' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = `total_earn_impact_pos' - `increase_taxes_pos'


	*Combine Estimates
	local total_earn_impact = `num_kids' * (`total_earn_impact_neg' + `total_earn_impact_pos')
	local increase_taxes = `num_kids' * (`increase_taxes_neg' + `increase_taxes_pos')
	local total_earn_impact_aftertax = `num_kids' * (`total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg')
}

*Get implied cost increase to govt from college attendance
if "$got_hcv_cost"!="yes" {
	cost_of_college , year(2005)
	global hcv_college_cost = r(cost_of_college)
	global hcv_tuition_cost = r(tuition)

	global got_hcv_cost = "yes"
}

deflate_to `usd_year', from(2005)
local govt_college_cost = (${hcv_college_cost} - ${hcv_tuition_cost})*`years_impact'*r(deflator)*(1/(1+`discount_rate')^(4))

local priv_college_cost = (${hcv_college_cost})*`years_impact'*r(deflator)*(1/(1+`discount_rate')^(4))

*Estimating effects without kids
if "`proj_type'" == "no kids" {
	local total_earn_impact = 0
	local increase_taxes = 0
	local govt_college_cost = 0
	local priv_college_cost = 0

}

local prior_earnings = `control_mean_earn'
local earn_age = round(`age_stat' + 3.5)

if "`tax_rate_assumption'" == "cbo"{
	get_tax_rate `prior_earnings', ///
		include_transfers(no) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`income_year') /// year of income measurement
		earnings_type(household) ///
		program_age(`earn_age') /// age of income measurement
		kids(`num_kids') // number of kids in family

	di `prior_earnings'
	local tax_rate = r(tax_rate)
}



**************************
/* 5. Cost Calculations */
**************************

local program_cost_incl_behav = 0
local tax_impact = 0
local earn_impact_par = 0
local FE = 0

forval i = 1/`years_vouchers' {
	local program_cost_incl_behav = `program_cost_incl_behav' + `voucher_cost'*(1/(1+`disc_rate')^(`i'-1))
	local tax_impact = `tax_impact' + (`tax_rate' * `earn_year_impact') * (1/(1+`disc_rate')^(`i'-1))
	local earn_impact_par = `earn_impact_par' + `earn_year_impact' * (1/(1+`disc_rate')^(`i'-1))
	local FE = `FE' + ((`tax_rate' * `earn_year_impact' ) - `food_stamp_tanf_impact') * (1/(1+`disc_rate')^(`i'-1))
}

*Add one time college cost
local FE = `FE' - `govt_college_cost'
di `tax_impact'

local program_cost = `ev_coeff' * (`program_cost_incl_behav' + ///
					 ((`earn_impact_par' + `tanf_impact') * 0.3))

local total_cost = `program_cost' - `FE'

*add impact on kids:
local total_cost = `total_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************
local WTP_kid = 0
if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost'
	/*
	Program costs are average costs with behavioral responses included. We determine WTP
	based on the mechanical cost. The mechanical cost is the program cost net of 30%
	of the change in adjusted monthly income. Adjusted for monthly income moves by the
	decline in earnings net of the TANF increase.
	*/
	if "`proj_type'" != "no kids"  {
		local WTP = `WTP' + (1-`tax_rate_kid')*`total_earn_impact' - `priv_college_cost'
		local WTP_kid = (1-`tax_rate_kid')*`total_earn_impact' - `priv_college_cost'

		}
	if "`value_transfer'" == "yes"  {
	local WTP = `WTP' + `food_stamp_tanf_impact'
	}
}

if "`wtp_valuation'" == "post tax" {
	local WTP = `ev_coeff'*`program_cost_incl_behav' + (1-`tax_rate')*`earn_impact_par'

	if "`proj_type'" != "no kids"  {
		local WTP = `WTP' + (1-`tax_rate_kid')*`total_earn_impact' - `priv_college_cost'
		local WTP_kid = (1-`tax_rate_kid')*`total_earn_impact' - `priv_college_cost'

		}

	if "`value_transfer'" == "yes"  {
	local WTP = `WTP' + `food_stamp_tanf_impact'
	}

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
di `tax_rate'
di `tax_impact'
di `ev_coeff'*`program_cost'
cap di (1-`tax_rate_kid')*`total_earn_impact'
di `years_impact'
di `earn_impact_par'
di `tanf_impact'
di `program_cost'
di ((`earn_impact_par' + `tanf_impact')*0.3)

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global WTP_kid_`1' = `WTP_kid'

global age_stat_`1' = `age_stat'
if `WTP_kid'>`=0.5*`WTP'' {
	global age_benef_`1' = `age_kid'
	}
else {
	global age_benef_`1' = `age_stat'
}

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `prior_earnings' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `income_year'
global inc_age_stat_`1' = `earn_age'

if `WTP_kid'<=`=0.5*`WTP''  {
	global inc_benef_`1' = `prior_earnings' * r(deflator)
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `income_year'
	global inc_age_benef_`1' = `earn_age'
}
else if `WTP_kid'>`=0.5*`WTP'' {
	global inc_benef_`1' = `cfactual_inc_kid'*r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `project_year'+34-`project_age'
	global inc_age_benef_`1' = 34 // child income is predicted from parent income
}
