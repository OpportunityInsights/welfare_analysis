***********************************************************
/* 0. Program: HOPE Credit and Lifetime Learners Credit*/
***********************************************************

/*Long, Bridget T. "The impact of federal tax credits for higher education expenses."
In College choices: The economics of where to go, when to go, and how to pay for it,
pp. 101-168. University of Chicago Press, 2004.*/

********************************
/* 1. Pull Global Assumptions */
********************************

*Project-Wide Globals
local discount_rate = $discount_rate
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"
local val_given_marginal = $val_given_marginal
local eitc_93_mvpf = $eitc_93_mvpf
local obra_93_mvpf = $obra_93_mvpf

*Program-Specific Globals
local tax_fe = "$tax_fe"
local years_enroll = $years_enroll

* globals for finding the tax rate.
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"
local transfer_assumption = "$transfer_assumption"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}

*********************************
/* 2. Inputs from Paper */
*********************************
/*
local attendance_odds	0.9342
local attendance_odds_se	0.044137554
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
/* 3. Assumptions from the Paper */
****************************************************
local attendance_control = 0.463 //%Enrolled in college who are elgible for tax credit Long 2004, Table 3.10

local claim_rate = .2108 //  Long 2004, Table 3.8. Measures fraction of eligible individuals who claimed the credit.


/*
Calculate credit-weighted average income of recipients using Long 2004, table 3.3 ($45208.041)
*/
local parental_earnings = (59744/4896215)*5000 + (689679/4896215)*15000 + (772886/4896215)*25000 + (1300231/4896215)*35000 + (1328260/4896215)*62500 + (718376/4896215)*87500


local average_credit_claimed = 728 // Long 2004, Table 3.3

local usd_year = 1998 //

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = 1998
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2005
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

local parent_age = 55 //This is an arbitrary assumption that filers who claim the credit are an average of 55 years old

****************************************************
/* 4. Intermediate Calculations */
****************************************************

local impact_attendance = `attendance_odds'*`attendance_control' - `attendance_control' // Convert odds ratio to percentage point change in attendance

local years_impact = `impact_attendance'*`years_enroll'

*Projecting change in earnings
if "`proj_type'" == "growth forecast" {

	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

	*Estimating the short run decrease in earnings
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parental_earnings') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(`project_year') percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, because it'll give them a high MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age') // age we're projecting from
	  local tax_rate_shortrun = r(tax_rate)
	}

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'
	
	*Estimating the long run increase in earnings
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`parental_earnings') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(`project_year') percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-18))

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year_pos') /// year of income measurement
		earnings_type(individual) /// individual, because that's what's produced by int_outcome
		program_age(`impact_age_pos') // age we're projecting from
	  local tax_rate_longrun = r(tax_rate)
	}

	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = (1-`tax_rate_longrun') * `total_earn_impact_pos'

	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
}

**************************
/* 5. Cost Calculations */
**************************
*Discounting for costs:
local years_enroll_disc = 0
di `years_enroll'

local end = ceil(`years_enroll')
forval i=1/`end' {
	local years_enroll_disc = `years_enroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_enroll' - floor(`years_enroll')
if `partial_year' != 0 {
	local years_enroll_disc = `years_enroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}
local years_impact_disc = `impact_attendance'*`years_enroll_disc'


local credits_cost = `average_credit_claimed'*`claim_rate'*`attendance_control' + `impact_attendance'*`average_credit_claimed' // odds of attending college multiplied by odds of claiming credit if enrolled multiplied the average claim by the claim percentage


if "`tax_fe'" == "lower"{
local credits_cost = `credits_cost'/`eitc_93_mvpf'
}

if "`tax_fe'" == "upper"{
local credits_cost = `credits_cost'/`obra_93_mvpf'
}

/*
Note: In order to be conservative we use four year college costs for all
enrollment changes
*/
cost_of_college, year(`project_year')  type_of_uni("any")
local cost_of_college = r(cost_of_college)
local net_tuition = r(tuition)

local enroll_cost = `years_impact_disc'*(`cost_of_college' - `net_tuition')
local priv_cost = `years_impact_disc'*(`net_tuition' - `average_credit_claimed')

local total_cost = `credits_cost' + `enroll_cost' - `increase_taxes'
local program_cost = `credits_cost'


*************************
/* 6. WTP Calculations */
*************************

/*
For individuals who value the tax credit based on it's long-term impact on earnings,
the tax credit is still valued at cost for all who don't change their behavior. Some
fraction of individuals are induced into college attendance and those individuals
value the benefit based on its impact on post-tax earnings. These calculations assume
the tax credit cannot induce individuals to avoid college.
*/

if "`wtp_valuation'" == "post tax" {

	local WTP_induced = `total_earn_impact_aftertax' - `priv_cost'
	local WTP_uninduced = `average_credit_claimed'*`claim_rate'*`attendance_control'
	local WTP = `WTP_induced' + `WTP_uninduced'

	local WTP_kid = `total_earn_impact_aftertax'

}


/*For individuals who value the tax credit at cost, the value is simply the size
of their reduction in taxes. The same is true when examining only observed benefits
rather than projected benefits.
*/
if "`wtp_valuation'" == "cost" {

	local WTP_induced = `impact_attendance'*`average_credit_claimed'*`val_given_marginal'
	local WTP_uninduced = `average_credit_claimed'*`claim_rate'*`attendance_control'
    local WTP = `WTP_induced' + `WTP_uninduced'

	local WTP_kid = 0

}


*Determine beneficiary age
local age_stat = `parent_age'
local age_kid = (18+22)/2 // college age kids
local WTP_kid = `total_earn_impact_aftertax'
if `WTP_kid'>`=`WTP'*0.5' local age_benef = `age_kid'
else local age_benef = `parent_age'



* get income in 2015 dollars
deflate_to 2015, from(`usd_year')
local deflator = r(deflator)
local parent_income_2015 = `deflator'* `parental_earnings'
local kid_income_2015 = `deflator'*`counterfactual_income_longrun'


**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'

di `MVPF'
di `impact_attendance'
di `attendance_odds'
di `attendance_control'
di `tax_value'
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost'
di `enroll_cost'
di `increase_taxes'
di `years_impact'

di `total_cost'
di `MVPF'
di "`tax_fe'"
di `tax_cost'



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
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals




global inc_stat_`1' = `parent_income_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `project_year'
global inc_age_stat_`1' = `parent_age'

if `age_benef' == `age_kid' {
	global inc_benef_`1' = `kid_income_2015'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `impact_year_pos'
	global inc_age_benef_`1' = `impact_age_pos'
}
else {
	global inc_benef_`1' = `parent_income_2015'
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `project_year'
	global inc_age_benef_`1' = `parent_age'
}
