/********************************************************************************
0. Program : Community College Texas: Tuition Prices and District annexation
*******************************************************************************/

*** Primary Estimates: Denning, Jeffrey T. "College on the Cheap: Consequences of Community College Tuition Reductions" American Economic Journal: Applied Economics 9 no. 2 (2017): 155-188.

/*
 Another paper that looks at the impact of community colleges in-distriction tuition in Texas is:
McFarlin, McFarlin, Pacro Martorell, and Brian McCall (2017). "Do Public Subsidies Improve College Attainment and Labor Market Outcomes? Evidence from Community College Taxing District Expansions".
This work is explicit in its overlap with Denning (2017). "This paper builds on Denning (2017), who also used this approach to examine the effect of CCTD annexation on college outcomes in Texas. We replicate the key finding of his study..." (p.4). The additional estimates performed in McFarlin et al. (2017) either (i) do not provide additional welfare-relevant information given our interpretation of the Denning (2017) estimates or (ii) cannot be interpreted causally due to potential violation of identification assumptions (e.g., the presence of pre-trends in looking tuition reduction on future earnings).
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
local outcome_type = "$outcome_type" // can be either "enrollment" or "credits attempted"
local year_8_effect = $year_8_effect
local split_cc_bach = $split_cc_bach
local attempted_hrs_compl = $attempted_hrs_compl // fraction of credit hours attempted that are completed. Only important when the outcome_type is credit hours
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
//The following are community college enrollment effects, cc_enroll_y, where y is the number of years after HS graduation (year 0 is for HS seniors at the time annexation).

* Immediate Enrollment in cc goes up by 3.2 percentage points post-annexation
local cc_enroll_0_effect = 0.032 //Denning 2017 Table 6 Col. 4
local cc_enroll_0_effect_se = 0.0059 //Denning 2017 Table 6 Col. 4

local cc_enroll_1_effect = 0.036 //Denning 2017 Table 7 Col. 1
local cc_enroll_1_effect_se = 0.0098  //Denning 2017 Table 7 Col. 1


local cc_enroll_2_effect = 0.027  //Denning 2017 Table 7 Col. 2
local cc_enroll_2_effect_se = 0.0061  //Denning 2017 Table 7 Col. 2


local cc_enroll_3_effect = 0.024  //Denning 2017 Table 7 Col. 3
local cc_enroll_3_effect_se = 0.0061  //Denning 2017 Table 7 Col. 3


local cc_enroll_4_effect = 0.0095  //Denning 2017 Table 7 Col. 4
local cc_enroll_4_effect_se = 0.0051  //Denning 2017 Table 7 Col. 4


local cc_enroll_5_effect = 0.0083  //Denning 2017 Table 7 Col. 5
local cc_enroll_5_effect_se = 0.0044  //Denning 2017 Table 7 Col. 5


local cc_enroll_6_effect = 0.014  //Denning 2017 Table 7 Col. 6
local cc_enroll_6_effect_se = 0.0036  //Denning 2017 Table 7 Col. 6


local univ_enroll_0_effect = -0.00045 //Denning 2017 Table 6 Col. 4
local univ_enroll_0_effect_se = 0.0094 //Denning 2017 Table 6 Col. 4

local univ_enroll_1_effect = 0.010 //Denning 2017 Table 7 Col. 1
local univ_enroll_1_effect_se = 0.0062 //Denning 2017 Table 7 Col. 1


local univ_enroll_2_effect = 0.0082 //Denning 2017 Table 7 Col. 2
local univ_enroll_2_effect_se = 0.0076 //Denning 2017 Table 7 Col. 2


local univ_enroll_3_effect = 0.0089 //Denning 2017 Table 7 Col. 3
local univ_enroll_3_effect_se = 0.0079 //Denning 2017 Table 7 Col. 3


local univ_enroll_4_effect = 0.017 //Denning 2017 Table 7 Col. 4
local univ_enroll_4_effect_se = 0.0065 //Denning 2017 Table 7 Col. 4


local univ_enroll_5_effect = 0.0068 //Denning 2017 Table 7 Col. 5
local univ_enroll_5_effect_se = 0.0038 //Denning 2017 Table 7 Col. 5


local univ_enroll_6_effect = 0.0082 //Denning 2017 Table 7 Col. 6
local univ_enroll_6_effect_se = 0.0027 //Denning 2017 Table 7 Col. 6

local grant_aid_decrease = 172.2 // Denning 2017, Table 4 Col 3. 
local grant_aid_decrease_se = 125.9 // Denning 2017, Table 4 Col 3. 

/* Estimates for education attainment beyond 6 years -- graduation rates.

GRAD EFFECTS BEYOND 6 years: grad  univ in 8 - grad  univ in 6 estimates
*/
local univ_grad_in_8_effect = 0.0078 //Denning 2017 Online Appexndix Table A4 Col. 3
local univ_grad_in_8_effect_se = 0.0069 //Denning 2017 Online Appexndix Table A4 Col. 3

local univ_grad_in_6_effect = 0.0033 //Denning 2017 Online Appexndix Table A4 Col. 2
local univ_grad_in_6_effect_se = 0.0075 //Denning 2017 Online Appexndix Table A4 Col. 2

local cost_decrease = 1140 // Denning 2017 Table 4 Col. 2
local cost_decrease_se = 53
// Denning 2017, Table 4. average size of tuitition price reduction

local frac_in_district = 0.55  // Denning Table 4 Col 2 (p.173)
local frac_in_district_se = .022
/*Note: the above estimate is an upper bound for eligibility: this is the 
estimated fraction of people who changed from out-of-district to in-district
 upon annexation. */

/* Appendix: \Effect of Credit hours attempted
An alternative estimate of enrollment is the credits attempted.
1 semester = 12 credits
"Unfortunately, the data on credits attempted does not extend 2
far enough to consider credits attempted at universities after 8 years which would give students
more time to transfer from community colleges."

*/
local univ_cred_att_6 = 0.53 // Denning (2017) OA Table A2. Total increase in credits attempted after 6 years at 4-year colleges.
local univ_cred_att_6_se = 1.34

local cc_cred_att_6 = 2.15
local cc_cred_att_6_se = 0.25
*/

*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************
local usd_year =  2012  

*We assume that evey year we see a student enrolled in college they complete that year
local cc_enroll_years = 1
local univ_enroll_years = 1

local grant_mean = 322.7 //Denning 2017 Table 4, Col. 3
local cc_tuition_price = 1160 // Denning 2017, Table 3

local credits_per_term = 12 // Denning 2017 definition of yearly tuition: 2 semesters of 12 credits

*Assumptions of age for Initial Earnings Loss Projection
// Price reduction enacted for districts in years 1999-2010, so choose 2005 as the midpoint
local proj_start_age = 18
local proj_short_end = 24
local impact_age_neg = 21
local project_year = 2005

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `project_year'+7

local post_annexed =.25 // Denning 2017 Table 2

local cc_tot_enrolled = (0.27 - (`cc_enroll_0_effect'*`post_annexed')) + (0.39 - (`cc_enroll_1_effect'*`post_annexed')) + ///
(0.25 - (`cc_enroll_2_effect'*`post_annexed')) + (0.18 - (`cc_enroll_3_effect'*`post_annexed')) + ///
(0.14 - (`cc_enroll_4_effect'*`post_annexed')) + (0.11 - (`cc_enroll_5_effect'*`post_annexed')) + ///
(0.089 - (`cc_enroll_6_effect'*`post_annexed')) // Summed mean community college enrollment from Table 7 with enrollment effect pulled out, Denning (2017).



*********************************
/* 4. Intermediate Calculations */
*********************************

if "`outcome_type'" == "credits attempted" {
    local cc_years_impact = `cc_cred_att_6'*`attempted_hrs_compl'/(`credits_per_term'*2)
    local univ_years_impact = `univ_cred_att_6'*`attempted_hrs_compl'/(`credits_per_term'*2)
    local years_impact = `cc_years_impact' + `univ_years_impact'

}
if "`outcome_type'" == "enrollment" {
    local cc_enroll_effect = `cc_enroll_0_effect' + `cc_enroll_1_effect'+`cc_enroll_2_effect'+`cc_enroll_3_effect'+`cc_enroll_4_effect'+`cc_enroll_5_effect'+`cc_enroll_6_effect'
    local cc_years_impact = `cc_enroll_effect'*`cc_enroll_years'
    local univ_years_impact = (`univ_enroll_0_effect' + `univ_enroll_1_effect'+`univ_enroll_2_effect'+`univ_enroll_3_effect'+`univ_enroll_4_effect'+`univ_enroll_5_effect'+`univ_enroll_6_effect')*`univ_enroll_years' + (`univ_grad_in_8_effect'-`univ_grad_in_6_effect')*`year_8_effect'
    local years_impact = `cc_years_impact' + `univ_years_impact'
}


if `split_cc_bach' ==1 {
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

if `split_cc_bach' == 0 {
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
        income_info(.) income_info_type(none) ///
        earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
        earn_series(HS) percentage(yes)

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
        income_info(.) income_info_type(none) ///
        earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
        earn_series(HS) percentage(yes)

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
*Discounting for cost calculations:
if "`outcome_type'" == "credits attempted" {
	*For all cost-of-enrollment effects based on credits, we conservatively assume 
	*that they occur at the beginning of the program:
    local cc_years_impact_disc = `cc_years_impact'
    local univ_years_impact_disc = `univ_years_impact'
}
if "`outcome_type'" == "enrollment" {
	*Discount enrollment impacts back to year 1:
	foreach type in cc univ {
		local `type'_years_impact_disc = 0
		forval y = 1/6 {
			local end = ceil(``type'_enroll_years')
			forval i=1/`end' {
				local `type'_years_impact_disc = ``type'_years_impact_disc' + (``type'_enroll_`y'_effect')/((1+`discount_rate')^(`i'+`y'-2))
			}
			local partial_year = ``type'_enroll_years' - floor(``type'_enroll_years')
			if `partial_year' != 0 {
				local `type'_years_impact_disc = ``type'_years_impact_disc' - (1-`partial_year')*(``type'_enroll_`y'_effect')/((1+`discount_rate')^(`end'+`y'-2))
			}
		}
	}
	
	*Add in year 8 effect for university enrollment:
	local start =  floor(8-`year_8_effect') + 1
	forval i =`start'/8 {
		local univ_years_impact_disc = `univ_years_impact_disc' + (`univ_grad_in_8_effect'-`univ_grad_in_6_effect')/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `year_8_effect' - floor(`year_8_effect')
	if `partial_year' != 0 {
		local univ_years_impact_disc = `univ_years_impact_disc' - (1-`partial_year')*(`univ_grad_in_8_effect'-`univ_grad_in_6_effect')/((1+`discount_rate')^(`start'-1))
	}
	
}

local program_cost = `cc_tot_enrolled'*`cost_decrease'*`frac_in_district'
local program_cost_unscaled = `program_cost' + (`cost_decrease'*`cc_years_impact_disc')
/*
Note: For cost purposes we assume that 55% of those attending community college 
are receiving in-district tuition but all induced to change behavior are receiving
in district tuition. 
*/
*Calculate Cost of Additional enrollment
 if "${got_CC_texas_costs}"!="yes" {

	deflate_to `usd_year', from(`project_year')
	local deflator = r(deflator)
	
    cost_of_college, year(`project_year') state("TX") type_of_uni("community")
    global CC_texas_cc_cost_of_coll = r(cost_of_college)*`deflator'
	global CC_texas_cc_tuition = r(tuition)*`deflator'

    cost_of_college, year(`project_year') state("TX") type_of_uni("rmb")
    global CC_texas_univ_cost_of_coll = r(cost_of_college)*`deflator'
    global CC_texas_univ_tuition = r(tuition)*`deflator'

    global got_CC_texas_costs yes

}
local cost_of_comm_college = $CC_texas_cc_cost_of_coll
local cost_of_bach_college = $CC_texas_univ_cost_of_coll
local univ_tuition_price = $CC_texas_univ_tuition
local cc_net_tuition = $CC_texas_cc_tuition

local grant_induced = max((`grant_mean' + (`grant_aid_decrease'*`post_annexed'))-(`grant_aid_decrease'/`frac_in_district'),0)

local priv_cost_impact = `univ_years_impact_disc' * `univ_tuition_price' + `cc_years_impact_disc'*(`cc_tuition_price' - `grant_induced')
/*
Note: We get private costs by determining net tuition costs at university plus net tuition at community college with the side of the grant removed. 
*/
local enroll_cost = (`univ_years_impact_disc'*`cost_of_bach_college') + (`cc_years_impact_disc'*(`cost_of_comm_college' - `cost_decrease')) - `priv_cost_impact' 

local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'
di `program_cost_unscaled'
di `enroll_cost'

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
    local wtp_induced = (`program_cost_unscaled'-`program_cost')*`val_given_marginal'
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
di `years_impact'
di `tax_rate_longrun'
di `total_earn_impact_aftertax'
di `priv_cost_impact'
di `WTP'
di `program_cost'
di `cost_decrease'
di `cc_tot_enrolled'
di `frac_in_disctrict'
di `program_cost_induced'
di `enroll_cost' - (`program_cost_induced'-`program_cost')
di `increase_taxes'
di `total_cost'
di `MVPF'
di `increase_taxes_enrollment'
di `increase_taxes_attainment'

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
