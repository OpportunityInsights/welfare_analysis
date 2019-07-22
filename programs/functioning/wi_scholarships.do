/********************************************************************************
0. Program : Wisconsin Private Scholarships
*******************************************************************************/

/*
  Goldrick-Rab, Sara, Robert Kelchen, Douglas N. Harris, and James Benson.
  "Reducing income inequality in educational attainment: Experimental evidence
  on the impact of financial aid on college completion."
  American Journal of Sociology 121, no. 6 (2016): 1762-1817.
  
* Provide need-based grants to college students from low-income familes in Wisconsin.  
  
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

*program specific globals
local prog_cost_assumption = "$prog_cost_assumption"


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
local credit_effect_cohort_1 = 0.9 //Goldrick-Rab et al (2016) table 5, cumulative effect
local credit_effect_cohort_1_se = 1.7 //Goldrick-Rab et al (2016) table 5, cumulative effect

local credit_effect_cohort_2_3 = 2.1 //Goldrick-Rab et al (2016) table 5, cumulative effect
local credit_effect_cohort_2_3_se = 0.7 //Goldrick-Rab et al (2016) table 5, cumulative effect

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
local cohort_1_n = 475  //Goldrick-Rab et al (2016) table 5
local cohort_2_3_n = 1035 //Goldrick-Rab et al (2016) table 5

local program_year  = (2008 + 2010)/2 // Goldrick-Rab et al (2016) p1772
local usd_year = `program_year' // no inflation adjustment mentioned in the paper

local efc = 1631 //Goldrick-Rab et al (2016) table 2 - note this is only for cohort 1, not available for cohorts 2 and 3

local credits_control_cohort_1 = 65.8 //Goldrick-Rab et al (2016) table 5
local credits_control_cohort_2_3 = 57.6 //Goldrick-Rab et al (2016) table 5

local parent_income = 29918 //Goldrick-Rab et al (2016) table 2 - note this is only for cohort 1, not available for cohorts 2 and 3

local annual_grant = 3500 //Goldrick-Rab et al (2016) p. 1772

* % of treatment group which received the grant, by semester - from Goldrick-Rab et al (2016) table 5
local receipt_sem_1 = 0.91
local receipt_sem_2 = 0.88
local receipt_sem_3 = 0.69
local receipt_sem_4 = 0.64
local receipt_sem_5 = 0.49 
local receipt_sem_6 = 0.45 

local credits_per_term = 12
*This is an assumption, consistent with Pell credit assumption used in Castleman
*and Long 2016

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = `program_year' + `proj_start_age' - 18
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `program_year' + `proj_start_age_pos' - 18
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

*********************************
/* 4. Intermediate Calculations */
*********************************
di "(`cohort_1_n'*`credit_effect_cohort_1' 	+ `cohort_2_3_n'*`credit_effect_cohort_2_3')/(`cohort_1_n'+ `cohort_2_3_n')"
* get average credit effect over 3 cohorts
local credit_effect = (`cohort_1_n'*`credit_effect_cohort_1' ///
	+ `cohort_2_3_n'*`credit_effect_cohort_2_3')/(`cohort_1_n'+ `cohort_2_3_n')

local credits_control = (`cohort_1_n'*`credits_control_cohort_1' ///
	+ `cohort_2_3_n'*`credits_control_cohort_2_3')/(`cohort_1_n'+ `cohort_2_3_n')


*Estimate Earnings Effect Using Credits Earned
	*Convert credits impact into equivalent years of schooling
	local years_impact = `credit_effect'/(`credits_per_term'*2)

	*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
	local tot_cost_impact = r(total_cost)

	local induced_fraction = (`credit_effect'/(`credits_control' + `credit_effect'))
	/*
	Note: We assume that the number of additional credits taken as fraction of the total number
	of credits amongst the treated represents the fraction of individuals who recieved the aid and
	consequently changed their behavior in response. This is used to determine the willingness to pay
	in Section 5.
	*/




*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(`program_year') percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, because this will give an artificially high MTR.
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
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(2012) percentage(yes)

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
local program_cost_unscaled = 0
* we have receipt rates per semester - add them up and discount them back to the first semester
forval i =1/4 {
	local program_cost_unscaled = `program_cost_unscaled' + 0.5*`annual_grant'*`receipt_sem_`i''*(1/(1+`discount_rate'))^((`i'-1)/2)
}
// The third year cohort were not observed for the fifth and sixth semesters, so we weight the additions by the fraction of individuals for which the 5th and 6th semesters are observed (assuming that half of the second wave belongs to cohort 3)
local cohort_56_sem = (`cohort_1_n'+0.5*`cohort_2_3_n')/(`cohort_1_n'+`cohort_2_3_n')
forval i =5/6 {
	local program_cost_unscaled = `program_cost_unscaled' + 0.5*`cohort_56_sem'*`annual_grant'*`receipt_sem_`i''*(1/(1+`discount_rate'))^((`i'-1)/2)
}

*For all cost-of-enrollment effects based on credits, we conservatively assume 
*that they occur at the beginning of the program:
local years_impact_disc = `years_impact'

*Calculate Cost of Additional enrollment
if "${got_wi_scholarships_costs}"!="yes" {
	cost_of_college, year(`program_year') state("WI")
	global cost_of_college_wi_scholarships = r(cost_of_college)
	
	global got_wi_scholarships_costs yes 
	}

local cost_of_college = $cost_of_college_wi_scholarships
	
local priv_cost_impact = `years_impact_disc' * `efc' // Assume private costs are determined by the effective family contribution
local enroll_cost = `years_impact_disc'*(`cost_of_college') - `priv_cost_impact' - `program_cost_unscaled'*`induced_fraction' // Yearly Costs of those induced to enroll, minus the effective family contribution
/* Note: We assume that additional schooling due to increased credits has costs
that scale as a fraction of yearly educational expenditures. */

local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'
local program_cost = `program_cost_unscaled'*(1 - `induced_fraction')

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = `total_earn_impact_aftertax' - `priv_cost_impact'
	*Uninduced value at program cost
	local wtp_not_induced = `program_cost_unscaled'*(1 - `induced_fraction')
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `induced_fraction'*`program_cost_unscaled'*`val_given_marginal'
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `program_cost_unscaled'*(1 - `induced_fraction')
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
di `years_impact' //enrollment gain
di  `credits_control'/(`credits_per_term'*2) // baseline enrollment
di `program_cost_unscaled'*`induced_fraction' // Mechanical Cost
di `program_cost_unscaled'*(1-`induced_fraction') // Behavioral Cost Program
di 	`enroll_cost' // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up 
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost_unscaled'
di `increase_taxes'
di `enroll_cost'
di `total_cost'


****************
/* 8. Outputs */
****************

di `program_cost_unscaled'
di `total_cost'
di `WTP'
di `MVPF'
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `enroll_cost'
di `increase_taxes'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `=`project_year_pos'+(``impact_age_pos''-`proj_start_age_pos')'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year_pos'
global inc_age_benef_`1' = `impact_age_pos'
