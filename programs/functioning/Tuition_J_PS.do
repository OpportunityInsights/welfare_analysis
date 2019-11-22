******************************************************************
/* 0. Program: College Tuition Deduction -- Joint Phase Start*/
******************************************************************
/*Hoxby, Caroline M., and George B. Bulman. "The effects of the tax deduction for postsecondary tuition:
Implications for structuring tax-based aid." Economics of Education Review 51 (2016): 23-60..*/

/*LaLumia, Sara. "Tax preferences for higher education and adult college enrollment."
National Tax Journal 65, no. 1 (2012): 59-90. */

*Evaluate the impact of claiming tuition tax deduction on college attendance, student
*status, college type, tuition paid, and student loans.

********************************
/* 1. Pull Global Assumptions */
********************************
*Project-Wide Globals
local discount_rate = $discount_rate
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"
local val_given_marginal = $val_given_marginal

*Program-Specific Globals
local omit_edu_cost = "$omit_edu_cost"
local tax_fe = "$tax_fe"
local years_enroll = $years_enroll
local eitc_93_mvpf = $eitc_93_mvpf
local obra_93_mvpf = $obra_93_mvpf

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
local impact_attendance = -0.003 //Hoxby and Bulman 2016, Table 5
local impact_attendance_se = 0.006 //Hoxby and Bulman 2016, Table 5

local deduction_claim = 1023 //Hoxby and Bulman 2016, Table 3
local deduction_claim_se = 24 //Hoxby and Bulman 2016, Table 3

local core_edu_cost  = 215 //Hoxby and Bulman 2016, Table 8
local core_edu_se = 178 //Hoxby and Bulman 2016, Table 8

local net_tuition_paid = 171 //Hoxby and Bulman 2016, Table 8
local net_tuition_paid_se = 152 //Hoxby and Bulman 2016, Table 8

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

****************************************************
/* 3. Assumptions from the Paper */
****************************************************

local parental_earnings = 130000 //Hoxby and Bulman 2016, Table 1
local mtr = 0.28 //Hoxby and Bulman 2016, pg 33

local ed_resources = (17753+18426)/2 //Hoxby and Bulman 2016, Table 1
local tuition = (13236+15169)/2  //Hoxby and Bulman 2016, Table 1
local usd_costs = 2004  //Hoxby and Bulman 2016, Table 1


local usd_year = 2006

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 34
local project_year =  2006
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2013
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

local parent_age = 55 //Assume that filers who claim the credit are an average of 55 years old


****************************************************
/* 4. Intermediate Calculations */
****************************************************

local years_impact = `impact_attendance'*`years_enroll'


/*
This section calculates the long-term changes to government costs and individual earnings that come about
as the result of higher college attendance.
*/

if "`proj_type'" == "growth forecast" {

	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parental_earnings') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(`project_year') percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)



	* Get marginal tax rate using counterfactual earnings, if using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, this would give an artificially high MTR
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age') // age we're projecting from
	  local tax_rate_shortrun = r(tax_rate)
	}

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'

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
		forecast_income(yes) /// forecast long-run earnings to get a realistic lifetime MTR
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
local years_enroll_disc = 0
local end = ceil(`years_enroll')
forval i=1/`end' {
	local years_enroll_disc = `years_enroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_enroll' - floor(`years_enroll')
if `partial_year' != 0 {
	local years_enroll_disc = `years_enroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}
local years_impact_disc = `impact_attendance'*`years_enroll_disc'



di `deduction_claim'
di `mtr'

*The value of the deduction to the individual is the size of the deduction multiplied by their marginal tax rate.
local tax_cost = `deduction_claim'*`mtr'
if "`tax_fe'" == "lower"{
local tax_cost = `tax_cost'/`eitc_93_mvpf'
}

if "`tax_fe'" == "upper"{
local tax_cost = `tax_cost'/`obra_93_mvpf'
}

local pub_cost_school = `ed_resources' - `tuition'
deflate_to `usd_year', from(`usd_costs')
local deflator = r(deflator)
local enroll_cost = `years_impact_disc'*`pub_cost_school'*`deflator'
local priv_cost = `years_impact_disc'*`tuition'*`deflator'

* local total_cost = `tax_cost' + `enroll_cost' - `increase_taxes'
if "`omit_edu_cost'" == "no" {
	local edu_cost = `core_edu_cost' - `net_tuition_paid'
}
if "`omit_edu_cost'" == "yes" {
	local edu_cost = 0
}

local total_cost = `tax_cost' + `enroll_cost' + `edu_cost' - `increase_taxes'

local program_cost = `deduction_claim'*`mtr'

*************************
/* 6. WTP Calculations */
*************************

/*
For individuals who value the tax deduction based on it's long-term impact on earnings,
the tax deduction is still valued at cost for all who don't change their behavior. Some
fraction of individuals are induced into college attendance and those individuals
value the benefit based on its impact on post-tax earnings. These calculations assume
the tax deduction cannot induce individuals to avoid college.
*/
if "`wtp_valuation'" == "post tax"{
	local uninduced = 1-`impact_attendance'
	local WTP_induced = `total_earn_impact_aftertax' - `priv_cost'
	local WTP_uninduced = `deduction_claim'*`uninduced'*`mtr'
	local WTP = `WTP_induced' + `WTP_uninduced'

	local WTP_kid = `total_earn_impact_aftertax' - `priv_cost' //used to determine the age of the economic beneficiaries
}


/*For individuals who value the tax deduction at cost, the value is simply the size
of their reduction in taxes. In particular, that value is the size of the deduction
multiplied by their marginal tax rate. The same is true when examining only observed benefits
rather than projected benefits.
*/
if "`wtp_valuation'" == "cost" {
	local uninduced = 1-`impact_attendance'
	local WTP_induced = `deduction_claim'*`impact_attendance'*`mtr'*`val_given_marginal'
	local WTP_uninduced = `deduction_claim'*`uninduced'*`mtr'
	local WTP = `WTP_induced'  + `WTP_uninduced'

	local WTP_kid = 0 //used to determine the age of the economic beneficiaries
}


*Determine beneficiary age
local age_stat = `parent_age'
local age_kid = (18+22)/2 // college age kids
if `WTP_kid'>`=`WTP'*0.5' local age_benef = `age_kid'
else local age_benef = `parent_age'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'

*Locals for Appendix Write-Up
di `MVPF'
di `deduction_claim'
di `impact_attendance'
di `tax_value'
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `total_earn_impact_aftertax'
di `priv_cost'
di `mtr'
di `program_cost'
di `enroll_cost'
di `increase_taxes'
di `edu_cost'
di `total_cost'
di `MVPF'
di "`tax_fe'"
di `tax_cost'
di "`omit_edu_cost'"


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
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `parental_earnings'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year'
global inc_age_stat_`1' =  `age_stat'

if `WTP_kid'>`=`WTP'*0.5' {
	global inc_benef_`1' = `counterfactual_income_longrun'*r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `impact_year_pos'
	global inc_age_benef_`1' = `impact_age_pos'
}
else {
	global inc_benef_`1' = `parental_earnings'*r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `project_year'
	global inc_age_benef_`1' =  `parent_age'
}
