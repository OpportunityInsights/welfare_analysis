
**********************************************************************
/* 0. Program: American Opportunity Tax Credit -- Single Phase Start */
**********************************************************************

/*Bulman, George B., and Caroline M. Hoxby. "The returns to the federal tax
credits for higher education." Tax Policy and Economy 29, no. 1 (2015): 13-88.*/

*Impact of tax credits on college attendance, student status, tuition, and financial aid.

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
local tax_fe = "$tax_fe"
local omit_edu_cost = "$omit_edu_cost"
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
/*
This is coded for dependent filers only. Additional results are available for independent filers.
*/


*********************************
/* 2. Inputs from Paper */
*********************************
/*
local impact_attendance = 0.000043  // Bulman and Hoxby 2015a, Table 14
local impact_attendance_p = runiform(0.05,0.9) //no observable p-value, but permutation test fails at 5% level, very large sample size, so we use z score
local impact_attendance_t_stat = invnormal(1 - `impact_attendance_p'/2)
local impact_attendance_se = abs(`impact_attendance'/`impact_attendance_t_stat')


local tax_value = 0.2019312 // Bulman and Hoxby 2015a, Table 13, adjusted to positive value
local tax_value_p = runiform(0,0.001) //no observable p-value, but permutation test fails at 0.1% level, very large sample size, so we use z score
local tax_value_t_stat = invnormal(1 - `tax_value_p'/2)
local  tax_value_se = abs(`tax_value'/`tax_value_t_stat')

local core_edu_cost = 0.076237 //Bulman and Hoxby 2015a, Table 14, adjusted to positive value. No observable p-value, but permutation test fails at 5% level.
local core_edu_cost_p = runiform(0.05, 0.9)


local net_tuition_paid = 0.158227 //Bulman and Hoxby 2015a, Table 14, adjusted to positive value. No observable p-value, but permutation test fails at 5% level.
local net_tuition_paid = runiform(0.05, 0.9)


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



di `impact_attendance'
****************************************************
/* 3. Assumptions from the Paper */
****************************************************
local parental_earnings = 80000 //lower kink, Bulman and Hoxby 2015a, Table 1
local usd_year = 2011

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year =  2011

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2018

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

* Get marginal tax rate using counterfactual earnings, if  using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, this would give an artificially high MTR 
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year'+`impact_age' - `proj_start_age'') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age') // age at income measurement
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

	* Get marginal tax rate using counterfactual earnings, if using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings to get a realistic lifetime MTR
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year_pos'+`impact_age_pos' - `proj_start_age_pos'') /// year of income measurement
		earnings_type(individual) /// individual, because that is what int_outcome produces
		program_age(`impact_age_pos') // age at income measurement
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

local tax_cost = `tax_value'

if "`tax_fe'" == "lower"{
	local tax_cost = `tax_cost'/`eitc_93_mvpf'
}

if "`tax_fe'" == "upper"{
	local tax_cost = `tax_cost'/`obra_93_mvpf'
}


if "${got_AOTC_S_LK_costs}"!="yes" {
	cost_of_college, year(`project_year') type_of_uni("rmb")
	
	global cost_of_college_AOTC_S_LK = r(cost_of_college)
	global net_tuition_AOTC_S_LK = r(tuition)
	
	global got_AOTC_S_LK_costs yes
	}
	
local cost_of_college = $cost_of_college_AOTC_S_LK
local net_tuition = $net_tuition_AOTC_S_LK


local enroll_cost = `years_impact_disc'*(`cost_of_college' - `net_tuition')
local priv_cost = `years_impact_disc'*`net_tuition'
if "`omit_edu_cost'" == "no" {
	local edu_cost = `core_edu_cost' - `net_tuition_paid'
}
if "`omit_edu_cost'" == "yes" {
	local edu_cost = 0
}

local total_cost = `tax_cost' + `enroll_cost' + `edu_cost' - `increase_taxes'

local program_cost = `tax_value'


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
local uninduced = min(1-`impact_attendance', 1)
if "`wtp_valuation'" == "post tax"{

	local WTP_induced = `total_earn_impact_aftertax' - `priv_cost'
	local WTP_uninduced = `tax_value'*`uninduced'
	local WTP = `WTP_induced' + `WTP_uninduced'

	local WTP_kid = `total_earn_impact_aftertax' - `priv_cost'

}


/*For individuals who value the tax credit at cost, the value is simply the size
of their reduction in taxes. The same is true when examining only observed benefits
rather than projected benefits.
*/
if "`wtp_valuation'" == "cost"{

local WTP_induced =  `tax_value'*(1 - `uninduced')*`val_given_marginal'
local WTP_uninduced = `tax_value'*`uninduced'
local WTP = `WTP_induced'  + `WTP_uninduced'

local WTP_kid = 0

}
di `WTP'

*Determine beneficiary age
local age_stat = `parent_age'
local age_kid = (18+22)/2 // college age kids
if `WTP_kid'>`=`WTP'*0.5' local age_benef = `age_kid'
else local age_benef = `parent_age'


* get 2015 income
deflate_to 2015, from(`usd_year')
local deflator = r(deflator)
local parent_income_2015 = `parental_earnings'*`deflator'
local kid_income_2015 = `counterfactual_income_longrun'*`deflator'
**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'

*Locals for Appendix Write-Up
di `MVPF'
di `impact_attendance'
di `tax_value'
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `total_earn_impact_aftertax'
di `priv_cost'
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
di `impact_attendance'
di `tax_value'

global program_cost_`1' = `tax_value'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
global inc_stat_`1' = `parent_income_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `project_year'
global inc_age_stat_`1' = `age_stat'
if `age_benef' == `parent_age' {
	global inc_benef_`1' = `parent_income_2015'
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `project_year'
	global inc_age_benef_`1' = `age_benef'
}
else {
	global inc_benef_`1' = `kid_income_2015'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `=`project_year_pos'+`impact_age_pos' - `proj_start_age_pos''
	global inc_age_benef_`1' = `impact_age_pos'
}
