/********************************************************************************
0. Program : Community College Michigan: Tuition Prices and District annexation
*******************************************************************************/

*** Primary Estimates: Acton, Riley. "Effects of Reduced Community College Tuition on College Choices and Degree Completion." (2018).

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
local outcome_type = "$outcome_type" // "semesters completed", "enrollment and completion"
local cc_enroll_years = $cc_enroll_years
local cc_grad_years = $cc_grad_years
local years_enroll_bach = $years_enroll_bach
local years_grad_bach = $years_grad_bach
local cert_comp_years = $cert_comp_years
local assoc_comp_years = $assoc_comp_years
local split_cc_bach = $split_cc_bach

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

/*
*The following are community college enrollment effects, cc_enroll_y, where y is
*the number of years after HS graduation (year 0 is for HS seniors at the time annexation).

* Semesters of college completed Effect
* The main downside is that we cannot separate out the effects from community college from that of 4-year colleges.
local semesters_college_effect  = 0.206 // Acton 2018 Table 7, Col 1.
local semesters_college_effect_se = 0.062 // Acton 2018 Table 7, Col 1.


* Immediate Enrollment Effects, by types of post-secondary education
* Note that we use Panel B: 2009-2011 cohorts for consistency with the other approach
*Local community college enrollment effects
local loc_cc_enroll_effect = 0.036 // Acton 2018 Table 5, Col. 1
local loc_cc_enroll_effect_se = 0.006 // Acton 2018 Table 5, Col. 1

* community college, non local
local nonloc_cc_enroll_effect = -0.021 // Acton 2018 Table 5, Col. 2
local nonloc_cc_enroll_effect_se = 0.006 // Acton 2018 Table 5, Col. 2

* vocational college (private community colleges)
local voc_c_enroll_effect = -0.004 // Acton 2018 Table 5, Col. 3
local voc_c_enroll_effect_se = 0.001 // Acton 2018 Table 5, Col. 3

* 4-year colleges
local univ_enroll_effect = -0.003 // Acton 2018 Table 5, Col. 4
local univ_enroll_effect_se = 0.005 // Acton 2018 Table 5, Col. 4


* Completion of cert/degrees
local cert_completion_effect = -0.002 // Acton 2018 Table 7, Col 3
local cert_completion_effect_se = 0.003 // Acton 2018 Table 7, Col 3
local assoc_completion_effect = 0.003 // Acton 2018 Table 7, Col 4
local assoc_completion_effect_se = 0.002 // Acton 2018 Table 7, Col 4
local bach_completion_effect = 0.011 // Acton 2018 Table 7, Col 5
local bach_completion_effect_se = 0.005 // Acton 2018 Table 7, Col 5

*/

*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************
local usd_year =  2016 // Acton (2018), Table 1

local cost_decrease = 1000

local in_distr_cost = 2266.56 // Acton 2018 Table 1, Col. 3: Annual In-district enrollment cost
local parental_income = 60000 // Acton 2018 referenced estimate of median HH income for students attending michigan colleges.
local credits_per_term = 12 // Acton 2018 definition of yearly tuition: 2 semesters of 12 credits

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age_neg = 21
local project_year = 2010 // Estimates for 2009-2011

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `project_year'+7

local base_loc_cc = 0.225 // Acton Table 5, Panel B

*********************************
/* 4. Intermediate Calculations */
*********************************
di `nonloc_cc_enroll_effect'
di `voc_c_enroll_effect'
di `loc_cc_enroll_effect'

if "`outcome_type'" == "enrollment and completion"  {
	local tot_cc_enroll_effect = `loc_cc_enroll_effect'+`nonloc_cc_enroll_effect'+`voc_c_enroll_effect'
	local cc_years_impact = (`tot_cc_enroll_effect'*`cc_enroll_years') + (`cert_completion_effect'*`cert_comp_years') + (`assoc_completion_effect'*`assoc_comp_years')
	local univ_years_impact = `univ_enroll_effect'*`years_enroll_bach' + `bach_completion_effect'*`years_grad_bach'
	local years_impact = `cc_years_impact' + `univ_years_impact'

	if `split_cc_bach'==0  {
		int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
		local pct_earn_impact_neg = r(prog_earn_effect_neg)
		local pct_earn_impact_pos = r(prog_earn_effect_pos)
		local tot_cost_impact = r(total_cost)
	}

	if `split_cc_bach'==1  {
		int_outcome, outcome_type(ccattain) impact_magnitude(`cc_years_impact') usd_year(`usd_year')
		local pct_earn_impact_neg_cc = r(prog_earn_effect_neg)
		local pct_earn_impact_pos_cc = r(prog_earn_effect_pos)
		local tot_cost_impact_cc = r(total_cost)
		int_outcome, outcome_type(attainment) impact_magnitude(`univ_years_impact') usd_year(`usd_year')
		local pct_earn_impact_neg_univ = r(prog_earn_effect_neg)
		local pct_earn_impact_pos_univ = r(prog_earn_effect_pos)
		local tot_cost_impact_univ = r(total_cost)

		local tot_cost_impact = `tot_cost_impact_cc'+`tot_cost_impact_univ'
		local pct_earn_impact_pos = `pct_earn_impact_pos_cc'+`pct_earn_impact_pos_univ'
		local pct_earn_impact_neg = `pct_earn_impact_neg_cc'+`pct_earn_impact_neg_univ'
	}

}

if "`outcome_type'" == "semesters completed" {

  	local tot_cc_enroll_effect = `loc_cc_enroll_effect'+`nonloc_cc_enroll_effect'+`voc_c_enroll_effect'
	local years_impact = `semesters_college_effect'/ 2

	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
    local pct_earn_impact_neg = r(prog_earn_effect_neg)
    local pct_earn_impact_pos = r(prog_earn_effect_pos)
    local tot_cost_impact = r(total_cost)
}


*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {


    est_life_impact `pct_earn_impact_neg', ///
        impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
        project_year(`project_year') usd_year(`usd_year') ///
        income_info(`parental_income') income_info_type("parent_income") ///
        earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
        percentage(yes)

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
        program_age(`impact_age_neg')
      local tax_rate_shortrun = r(tax_rate)
    }

    local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
    local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'
    est_life_impact `pct_earn_impact_pos', ///
        impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
        project_year(`project_year_pos') usd_year(`usd_year') ///
        income_info(`parental_income') income_info_type("parent_income") ///
        earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
        percentage(yes)

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
        program_age(`impact_age_pos')
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
 * Calculate cost of additional enrollment
 if "${got_CC_michigan_costs}"!="yes" {
	deflate_to `usd_year', from(`project_year')
	local deflator = r(deflator)

    cost_of_college, year(`project_year') state("MI") type_of_uni("community")
    global CC_michigan_cc_cost_of_coll = r(cost_of_college)*`deflator'
	global CC__michigan_cc_tuition = r(tuition)*`deflator'

    cost_of_college, year(`project_year') state("MI") type_of_uni("rmb")
    global CC_michigan_univ_cost_of_coll = r(cost_of_college)*`deflator'
    global CC_michigan_univ_tuition = r(tuition)*`deflator'

    global got_CC_michigan_costs yes

}
local cost_of_comm_college = $CC_michigan_cc_cost_of_coll
local cc_tuition = $CC__michigan_cc_tuition
local cost_of_bach_college = $CC_michigan_univ_cost_of_coll
local univ_tuition = $CC_michigan_univ_tuition


*Discounting for cost calculations:
*a) 1-year (certificate completion):
	*Completion:
	local cert_comp_years_disc = 0
	local start =  floor(1-`cert_comp_years') + 1
	forval i =`start'/1 {
		local cert_comp_years_disc = `cert_comp_years_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `cert_comp_years' - floor(`cert_comp_years')
	if `partial_year' != 0 {
		local cert_comp_years_disc =  `cert_comp_years_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`start'-1))
	}


*b) 2-year (CC enrollment and associate's completion):
	*Enrollees:
	local cc_enroll_years_disc = 0
	local end = ceil(`cc_enroll_years')
	forval i=1/`end' {
		local cc_enroll_years_disc = `cc_enroll_years_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `cc_enroll_years' - floor(`cc_enroll_years')
	if `partial_year' != 0 {
		local cc_enroll_years_disc = `cc_enroll_years_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}

	*Completion:
	local assoc_comp_years_disc = 0
	local start =  floor(2-`assoc_comp_years') + 1
	forval i =`start'/2 {
		local assoc_comp_years_disc = `assoc_comp_years_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `assoc_comp_years' - floor(`assoc_comp_years')
	if `partial_year' != 0 {
		local assoc_comp_years_disc =  `assoc_comp_years_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`start'-1))
	}


*c) 4-year (bachelor's):
	*Enrollment:
	local years_enroll_bach_disc = 0
	local end = ceil(`years_enroll_bach')
	forval i=1/`end' {
		local years_enroll_bach_disc = `years_enroll_bach_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_bach' - floor(`years_enroll_bach')
	if `partial_year' != 0 {
		local years_enroll_bach_disc = `years_enroll_bach_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}

	*Completion:
	local years_grad_bach_disc = 0
	local start =  floor(4-`years_grad_bach') + 1
	forval i =`start'/4 {
		local years_grad_bach_disc = `years_grad_bach_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_grad_bach' - floor(`years_grad_bach')
	if `partial_year' != 0 {
		local years_grad_bach_disc = `years_grad_bach_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`start'-1))
	}


*Cost of Tuition Deduction for Those Already Going to Enroll
local program_cost = `cost_decrease'*`base_loc_cc'*`cc_enroll_years_disc'

*Cost of Tuition Deduction for New Enrolees
local program_cost_induced = `cost_decrease'*(`base_loc_cc' + `loc_cc_enroll_effect')*`cc_enroll_years_disc'
	di `tot_cc_enroll_effect'
	di `cc_enroll_years_disc'
*Fraction of New Local Enrollees who are new Community college enrollees
*This frac adjusts for people who switch between types of community colleges
local frac_new_enroll = `tot_cc_enroll_effect'/`loc_cc_enroll_effect'


*Calculate Cost of Additional enrollment
// calculate the private cost -- subtract the tuition decline from net tuition, allowing the possibility of negative net tuition and fees
if "`outcome_type'" == "enrollment and completion"  {

	local cc_years_impact_disc = (`tot_cc_enroll_effect'*`cc_enroll_years_disc') + (`cert_completion_effect'*`cert_comp_years_disc') + (`assoc_completion_effect'*`assoc_comp_years_disc')
	local univ_years_impact_disc = `univ_enroll_effect'*`years_enroll_bach_disc'+ `bach_completion_effect'*`years_grad_bach_disc'
	local years_impact_disc = `cc_years_impact_disc' + `univ_years_impact_disc'

	local priv_cost_impact = (`cc_years_impact_disc'*(`cc_tuition' - `cost_decrease'))+(`univ_years_impact_disc'*`univ_tuition')

	local enroll_cost = (`univ_years_impact_disc'*`cost_of_bach_college') + (`cc_years_impact_disc'*`cost_of_comm_college') - `priv_cost_impact' - (`program_cost_induced' - `program_cost')*`frac_new_enroll'
}

if "`outcome_type'" == "semesters completed" {
*For all cost-of-enrollment effects based on semesters, we assume
*that they occur at the beginning of the program:

    local priv_cost_impact = `years_impact' * (`cc_tuition' - `cost_decrease')
	local enroll_cost = `years_impact'*`cost_of_comm_college'- `priv_cost_impact'- (`program_cost_induced' - `program_cost')*`frac_new_enroll' // Assume that all semester credits earned are from community college
}


local total_cost = `program_cost_induced' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
    *Induced value at post tax earnings impact net of private costs incurred
    local wtp_induced = `total_earn_impact_aftertax' - `priv_cost_impact'
    *Uninduced value at program cost
    local wtp_not_induced = `program_cost'
    *Sum
    local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
    *Induced value at fraction of transfer: `val_given_marginal'
    local wtp_induced = (`program_cost_induced' - `program_cost')*`val_given_marginal'
    *Uninduced value at 100% of transfer
    local wtp_not_induced = `program_cost'
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
di `years_impact'
di `cc_years_impact'
di `univ_years_impact'
di `WTP'
di `program_cost'
di `program_cost_induced'
di `enroll_cost'
di `increase_taxes'
di `total_cost'
di `MVPF'
di `years_impact'
di `total_earn_impact_aftertax'
di `priv_cost_impact'
di `univ_impact'
di `univ_tuition'

****************
/* 8. Outputs */
****************

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
global inc_year_stat_`1' = `=`project_year_pos'+(`impact_age_pos'-`proj_start_age_pos')'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=`project_year_pos'+(`impact_age_pos'-`proj_start_age_pos')'
global inc_age_benef_`1' = `impact_age_pos'


