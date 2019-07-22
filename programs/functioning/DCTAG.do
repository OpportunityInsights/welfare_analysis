********************************************
/* 0. Program: DC College Grant */
********************************************

/*Abraham, Katharine G., and Melissa A. Clark. "Financial aid and students’
college decisions evidence from the District of Columbia Tuition Assistance
Grant Program." Journal of Human resources 41, no. 3 (2006): 578-610. */


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
local wage_growth_rate = $wage_growth_rate

*program specific globals
local val_given_marginal = $val_given_marginal
local years_enroll = $years_enroll 

* globals for finding the tax rate.
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}

******************************
/* 2. Estimates from Paper */
******************************


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

/*
* Enrollment effect
local enrollment_effect = 0.089 // Abraham and Clark 2006, Table 7A, described in p.606
*/
*********************************
/* 3. Assumptions from Paper */
*********************************

local usd_year = 2000

/*Max amount of grant for attending public institution*/
local max_sav_public = 10000 //Abraham and Clark (2006) pg. 605, 2000 USD

/*Max amount of grant for attending qualifying private institution*/
local mx_sav_private = 2500 //Abraham and Clark (2006) pg. 605, 2000 USD

/*Average college cost savings for D.C. residents*/
local avg_saving = 2472 //Abraham and Clark (2006) pg. 605, 2000 USD (see footnote 20 for elaboration)

/*Estimated number of 17-year-olds in D.C.*/
local num_17 = 5321 //Abraham and Clark (2006) pg. 606, 2000 estimate


*%total enrollment in 2002
local total_enroll_2002 = 0.389 //Abraham and Clark (2006) table 7a

*% eligible for funds in 2002
local prob_eligible_2002 = 0.168 //Abraham and Clark (2006) table 7a

/*total tuition subsidy received by students who enrolled as freshmen under the program*/
/*This ignores admin costs*/
local total_sub = 6753782 //Abraham and Clark (2006) pg. 606

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age_neg = 21
local project_year = 1999

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `project_year'+7

// Table 5, Change in Enrollment 98-2002 for DC freshman completing HS, DCTAG eligible
//Note: These are the institutions listed with greatest change, but list is not comprehensive. 

local va_enroll = 92 + 31 + 27 + 17
local nc_enroll = 30 + 11
local md_enroll = 27 + 20 + 13 + 11 - 12
local pa_enroll = 25 + 18
local wi_enroll = 17

local tot_enroll_2000= `va_enroll' + `nc_enroll' + `md_enroll' + `pa_enroll' + `wi_enroll'



*********************************
/* 4. Intermediate Calculations */
*********************************

local years_impact = `enrollment_effect'*`years_enroll'

* Costs
local avg_cost = `total_sub' / `num_17' // average tuition across population of 17 y.o.
local avg_cost_eligible = `total_sub' / (`num_17'*`prob_eligible_2002')

int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
local pct_earn_impact_neg = r(prog_earn_effect_neg) // college_earn_effect_neg
local pct_earn_impact_pos = r(prog_earn_effect_pos) // college_earn_effect_pos

if "`proj_type'" == "growth forecast" {

	*Initial Earnings Decline
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		earn_series(.) percentage(yes)
	di r(tot_earn_impact_d)

	local counterfactual_income_shortrun = r(cfactual_income) // counterfactual income short run
	local total_earn_impact_neg = r(tot_earn_impact_d)
	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(no) /// don't forecast short-run earnings, because that'd give them a high MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`=`project_year'+`impact_age_neg'-`proj_start_age'') /// year of income measurement
		 earnings_type(individual) ///
		 program_age(`impact_age_neg')
	  local tax_rate_shortrun = r(tax_rate)
	}

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun')*`total_earn_impact_neg'

	*Earnings Gain
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		earn_series(.) percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-18))

	* Get tax rate
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos'') /// 
		 earnings_type(individual) ///
		 program_age(`impact_age_pos')
	  local tax_rate_longrun = r(tax_rate)
	}


	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = (1-`tax_rate_longrun')*`total_earn_impact_pos'

	*Combine Estimates
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


*Get cost of college:
if "${got_DCTAG_costs}"!="yes" {
	deflate_to `usd_year', from(`project_year')
	local deflator = r(deflator)
	
	foreach state in va md nc pa wi {
		local abbrev = upper("`state'")
		cost_of_college, year(`project_year') state("`abbrev'") type_of_uni("rmb")
		global DCTAG_cost_of_college_`state' = r(cost_of_college)*`deflator'
		global DCTAG_tuition_`state' = r(tuition)*`deflator'
	}


	global got_DCTAG_costs yes
}
foreach state in va md nc pa wi {
	local cost_of_college_`state' = ${DCTAG_cost_of_college_`state'}
	local tuition_`state' = ${DCTAG_tuition_`state'}
}
local avg_college_cost = 0
local avg_tuition = 0
foreach state in va md nc pa wi {
	local avg_college_cost = `avg_college_cost' + (``state'_enroll'*`cost_of_college_`state'')/(`tot_enroll_2000')
	local avg_tuition = `avg_tuition' + (``state'_enroll'*`tuition_`state'')/(`tot_enroll_2000')
}


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
local years_impact_disc = `enrollment_effect'*`years_enroll_disc'
local induced_fraction = `enrollment_effect'/`prob_eligible_2002'

local program_cost_one_year = `avg_cost'*(1-`induced_fraction')

local priv_cost_impact = `years_impact_disc'*`avg_tuition'
local enroll_cost = `years_impact_disc'*`avg_college_cost' - `priv_cost_impact'

local program_cost = `years_enroll_disc'*`program_cost_one_year'

local total_cost = `program_cost' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	local wtp_induced = `total_earn_impact_aftertax' - `priv_cost_impact'
	local wtp_not_induced = `program_cost'

	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Everyone values at transfer but induced individuals might value at less
	*as their behaviour changed -> envelope theorem
	local wtp_induced = `induced_fraction'*`avg_cost'*`years_enroll_disc'*`val_given_marginal'
	local wtp_not_induced = `program_cost'
	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'
di `MVPF'

*Locals for Appendix Write-Up 
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost'
di `priv_cost_impact'
di `increase_taxes'
di `enroll_cost'
di `total_cost'
di `years_impact'
di `enroll_cost' - `induced_fraction'*`program_cost'



****************
/* 8. Outputs */
****************

di `avg_cost'
di `program_cost_one_year'
di `program_cost'
di `avg_cost_eligible'
di `enrollment_effect'
di `years_impact'
di `increase_taxes'
di `total_earn_impact_aftertax'
di `avg_college_cost'
di `years_impact_disc'


di `counterfactual_income_shortrun'
di `avg_cost_eligible'
di `years_enroll'
di `discounted_years'
di `avg_cost'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

deflate_to 2015, from(`usd_year')
* income globals
global inc_stat_`1' = `counterfactual_income_longrun'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year_pos'+(`impact_age_pos'-`proj_start_age_pos')
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=`project_year_pos'+(`impact_age_pos'-`proj_start_age_pos')'
global inc_age_benef_`1' = `impact_age_pos'

