/********************************************************************************
0. Program : Georgia Hope Scholarship
*******************************************************************************/
/*
Primary: Cornwell, C., Mustard, D., & Sridhar, D. (2006). The enrollment effects of merit-based financial aid: Evidence from Georgia’s HOPE Scholarship. Journal of Labor Economics 24: 761–86
- Secondary: Cornwell:  The Effects of Merit-Based Financial Aid on Course Enrollment, Withdrawal and Completion in College
*/
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
local dont_pay_private = $dont_pay_private
*program specific globals
local years_enroll = $years_enroll
local years_enroll_cc = $years_enroll_cc

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
*Enrollment effects for different types of institutions / Cornwell et al (2006) Table 3
local enroll_effect_4_year_pub =	0.086
local enroll_effect_4_year_priv =	0.132
local enroll_effect_2_year_pub =	-0.045

*The effect on the number of Georgia residents who leave the state for college / Cornwell et al (2006) Table 4 - 
local leavers =	-560

*/
/*Import estimates from paper, giving option for corrected estimates.
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

local initial_enrollment_4_year_pub = 20726 //Cornwell et al (2006) table 2
local initial_enrollment_4_year_priv = 9297 //Cornwell et al (2006) table 2
local initial_enrollment_2_year_pub = 15565 //Cornwell et al (2006) table 2

local usd_year = 1998 // Cornwell et al (2006)

local prop_private_4 = 30098/(30098+ 257211) // table 1 proportion of HOPE students at 4 year institutions attending private universities

local program_year = (1993+1997)/2 //Cornwell et al (2006)


/* Median household income by state from US Census:
http://www2.census.gov/programs-surveys/cps/tables/time-series/historical-income-households/h08.xls
No information on parental income in the paper, but the scholarship has no income restrictions.
So take median hh income in 1995 (the program year) */
deflate_to `usd_year', from(1995)
local dummy_income = 0

local total_recipients_93_99 = 257211 + 56829 + 30098 // Cornwell et al (2006) Table 1 Sum of public 4 years, private 4 years and public 2 years to match enrollment effects

local total_aid_93_99 = (503.71+ 50.83 + 81.67)*1000000 // Cornwell et al (2006)  Table 1 - sum of pub 4 years, pub 2 years and priv 4 years aid amounts
local program_cost_unscaled = `total_aid_93_99'/`total_recipients_93_99' // total aid per year
local grant_per_year = `total_recipients_93_99'/7 //average number of recipients per year 

local grant_4yr = ((81.67+503.71)*1000000)/(30098 + 257211) //average size of yearly grant for four year schools: Cornwell et al (2006)  Table 1
local grant_cc = (50.82*1000000)/56829  //average size of yearly grant for four year schools: Cornwell et al (2006)  Table 1
local grant_private = (81.67*1000000)/30098  //average size of yearly grant for four year privates: Cornwell et al (2006)  Table 1
local grant_4yr_public = 503.71  * 1000000 / 257211
local grant_4yr_private =  81.67  * 1000000 / 30098

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local project_year = `program_year'
local impact_age_neg = 21

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `program_year' + `proj_start_age_pos' - 18

*********************************
/* 4. Intermediate Calculations */
*********************************

*First, we convert the enrollment effect to the percentage increase in enrollment
local enroll_effect_4_year_pub = exp(`enroll_effect_4_year_pub') - 1
local enroll_effect_4_year_priv = exp(`enroll_effect_4_year_priv') - 1
local enroll_effect_2_year_pub = exp(`enroll_effect_2_year_pub') - 1

local induced_enrollees_4_years_pub = `enroll_effect_4_year_pub'*`initial_enrollment_4_year_pub' 
local induced_enrollees_4_years_priv = `enroll_effect_4_year_priv'*`initial_enrollment_4_year_priv'
local induced_enrollees_4_years = `induced_enrollees_4_years_pub' + `induced_enrollees_4_years_priv'

local induced_enrollees_2_years = `enroll_effect_2_year_pub'*`initial_enrollment_2_year_pub'
/* 
Note enroll_effect_4_year_pub is the %impact on number of first-time
Freshmen in Georgia 4 year public Colleges. We multiply this by the initial enrollment number
to get the number of Freshmen induced to enroll, and then do the same thing for private
institutions. 
Estimation is restricted to 4-year public, 4-year private and 2-year schools because
those are the cases where initial enrollment is provided
*/

*make one year control mean 
local years_impact_4_years = (`induced_enrollees_4_years'*`years_enroll' + `leavers'*`years_enroll')/(`grant_per_year' - `induced_enrollees_4_years' - `induced_enrollees_2_years')
local years_impact_2_years = (`induced_enrollees_2_years'*`years_enroll_cc')/(`grant_per_year' - `induced_enrollees_4_years' - `induced_enrollees_2_years')
local years_impact_4_years_pubonly = (`induced_enrollees_4_years_pub'*`years_enroll' + `leavers'*`years_enroll')/(`grant_per_year' - `induced_enrollees_4_years' - `induced_enrollees_2_years')
local years_impact_4_years_privonly = (`induced_enrollees_4_years_priv'*`years_enroll')/(`grant_per_year' - `induced_enrollees_4_years' - `induced_enrollees_2_years')


/*
Note: We assume here that those who would have left the state to go to college would have received the same level of education. We do not extrapolate 
to the population of non first immediate enrollees becuase no information is provided on that group. We also do not reduce the effect by the population
of out of state residents. This effect is insignificant and there is no intuitive justification as to why out of state enrollment should rise. 
*/
local outcome_4_years attainment
local outcome_2_years ccattain

local total_earn_impact = 0
local increase_taxes = 0
local total_earn_impact_aftertax = 0

foreach type in 4 2 {
*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
	int_outcome, outcome_type("`outcome_`type'_years'") impact_magnitude(`years_impact_`type'_years') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)


	*Now forecast % earnings decrease in the short run
	if "`proj_type'" == "growth forecast" {
		est_life_impact `pct_earn_impact_neg', ///
			impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
			project_year(`project_year') usd_year(`usd_year') ///
			income_info(`dummy_income') income_info_type(none) ///
			earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
			earn_series(.) percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, because it'll give them a high MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year'+`impact_age_neg'-`proj_start_age'') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age_neg') // age we're projecting from
	  local tax_rate_shortrun = r(tax_rate)
	}

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg =  (1-`tax_rate_shortrun') * `total_earn_impact_neg'
	
	*Forecase earnings increase in the long run
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`dummy_income') income_info_type(none) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		earn_series(.) percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-18))

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos'') /// year of income measurement
		earnings_type(individual) /// individual, because that's what's produced by int_outcome
		program_age(`impact_age_pos') // age of income measurement
	  local tax_rate_longrun = r(tax_rate)
	}

	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = (1-`tax_rate_longrun') * `total_earn_impact_pos'

	local total_earn_impact = `total_earn_impact' + `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes' + `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax'+ `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
}
else {
	di as error "Only growth forecast allowed"
}

}

**************************
/* 5. Cost Calculations */
**************************
*Discounting for costs:
*4-Year School
	local years_enroll_disc = 0
	local end = ceil(`years_enroll')
	forval i=1/`end' {
		local years_enroll_disc = `years_enroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll' - floor(`years_enroll')
	if `partial_year' != 0 {
		local years_enroll_disc = `years_enroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}

*2-Year School
	local years_enroll_cc_disc = 0
	local end = ceil(`years_enroll_cc')
	forval i=1/`end' {
		local years_enroll_cc_disc = `years_enroll_cc_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_cc' - floor(`years_enroll_cc')
	if `partial_year' != 0 {
		local years_enroll_cc_disc = `years_enroll_cc_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}
local years_impact_4_years_disc = `years_impact_4_years'*(`years_enroll_disc'/`years_enroll')
local years_impact_4_years_pub_disc = `years_impact_4_years_pubonly'*(`years_enroll_disc'/`years_enroll')
local years_impact_4_years_priv_disc = `years_impact_4_years_privonly'*(`years_enroll_disc'/`years_enroll')
local years_impact_2_years_disc = `years_impact_2_years'*(`years_enroll_cc_disc'/`years_enroll_cc')


*Calculate Cost of Additional enrollment
if "${got_georgiahope_costs}"!="yes" {
	deflate_to `usd_year', from(`program_year')
    local deflator = r(deflator)
	cost_of_college, year(`program_year') state(GA) type_of_uni("rmb")
	global georgiahope_cost_of_coll = r(cost_of_college)*`deflator'
	global georgiahope_tuition_coll = r(tuition)*`deflator'
	cost_of_college, year(`program_year') state(GA) type_of_uni(community)
	global georgiahope_cc_cost_of_coll = r(cost_of_college)*`deflator'
	global georgiahope_cc_tuition_coll = r(tuition)*`deflator'
	global got_georgiahope_costs yes
}
local cost_of_college = $georgiahope_cost_of_coll
local tuition = $georgiahope_tuition_coll
local cc_cost_of_college = $georgiahope_cc_cost_of_coll
local cc_tuition = $georgiahope_cc_tuition_coll

local induced_prog_cost = `grant_4yr_private'*`years_impact_4_years_priv_disc'+`grant_4yr_public'*`years_impact_4_years_pub_disc' + `grant_cc'*`years_impact_2_years_disc' 
local program_cost = `program_cost_unscaled' - `induced_prog_cost'

if `dont_pay_private' == 1 {
local enroll_cost = `years_impact_4_years_pub_disc'*`cost_of_college' +`years_impact_2_years_disc'*`cc_cost_of_college' - `induced_prog_cost' // Yearly Costs of those induced to enroll
}
else {
local enroll_cost = `years_impact_4_years_disc'*`cost_of_college' + `years_impact_2_years_disc'*`cc_cost_of_college' - `induced_prog_cost'
}


local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = `total_earn_impact_aftertax' 
	*Uninduced value at program cost
	local wtp_not_induced = `program_cost'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}


if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `induced_prog_cost'*`val_given_marginal'
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `program_cost'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

/*
Figures for Attainment Graph
*/
di `years_impact_4_years' + `years_impact_2_years' //enrollment gain
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up 
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost'
di `priv_cost_impact'
di `increase_taxes'
di `enroll_cost'
di `total_cost'
di `induced_enrollees_4_years_pub'
di `induced_enrollees_4_years'
di `induced_enrollees_2_years'
di `years_impact_4_years'
di `total_recipients'

di `grant_4yr'
di `grant_4yr_private'
di `grant_4yr_public'
di `grant_4yr_private'*`years_impact_4_years_priv_disc'+`grant_4yr_public'*`years_impact_4_years_pub_disc'
di `grant_4yr'*`years_impact_4_years_disc'

di `years_impact_4_years_priv_disc'
di `years_impact_4_years_pub_disc'
di `years_impact_4_years_disc'
di `years_impact_4_years_pubonly'
di `years_impact_4_years_privonly'
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


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_longrun' * r(deflator)
// note 2 year and 4 year attendees have same counterfactual income. This is not ideal but we don't have better information.
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `=`project_year_pos'+(``impact_age_pos''-`proj_start_age_pos')'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=`project_year_pos'+(``impact_age_pos''-`proj_start_age_pos')'
global inc_age_benef_`1' = `impact_age_pos'
