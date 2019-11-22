********************************************
/* 0. Program: Social Security Benefits  */
********************************************

/*Dynarski, Susan M. "Does aid matter? Measuring the effect of student aid on college attendance and completion." American Economic Review 93, no. 1 (2003): 279-288.*/

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"

local val_given_marginal = $val_given_marginal

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
    local tax_rate_longrun  = $tax_rate_cont
    local tax_rate_shortrun = $tax_rate_cont
}

*Program-Specific Globals
local outcome_type = "$outcome_type"
local years_enroll = $years_enroll
local private_costs_gov = "$private_costs_gov"
local aid_crowd_out = "$aid_crowd_out"
local benefit_level = "$benefit_level"

******************************
/* 2. Estimates from Paper */
******************************

/*Years Attended School Impact
local years_imp = 0.679 //Dynarski 2000, Table 3
local years_imp_se = 0.399

Results here use the "lower bound" specification in Dynarski (2003). They could be replaced with alternate specifications such as "exclude attriters" or "asignn last value"
also found in Table 3. The same specification is used for the enrollment
impact below.

*Enrollment Impact
local enroll_imp = 0.224 //Dynarski 2000, Table 3
local enroll_imp_se = 0.106

*/

*Import estimates from paper, giving option for corrected estimates
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

local usd_year = 2000 // Dynarski (2003) deflation p. 279

*Benefit Details
if "`benefit_level'"=="full"{
	*
	local benefit_amount = 6700
}
else if "`benefit_level'"=="partial"{
	local benefit_amount = 4700
}
else {
        di as err "Benefit level must be specified as either full or partial."
        exit
}
* Other Aid benefits
local pell_grant_aid = 2000 // Dynarski (2003) p. 280, average Pell Grant aid.

*Assumptions of Age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = 1981
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 1988
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

*Tuition Costs
local pub_tuition = 1900 // Dynarski (2003). page 280
local private_tuition = 7100 // Dynarski (2003), page 280

*Public School Enrollment
local public_enroll_frac = 7908/(7908 + 2044)
/*
This is an estimate of the fraction of students enrolled in public school. The
Data comes from historical CPS figures on college enrollment. See Table A7 at:
https://www.census.gov/data/tables/time-series/demo/school-enrollment/cps-historical-time-series.html
*/

local year_per_enroll = `years_imp'/`enroll_imp' // Used to determine baseline number of years per enrollee

*Enrollment Rate Without Treatment
local base_enrollment = 0.352 // Dynarski (2003) Table 1, SE: 0.066. Note: This figure is the rate of enrollment amongst those with deceased parents once the program is eliminated. We could also estimate the base enrollment rate by taking the pre-treatment rate and subtracting out the treatment effect.

*Household Income Levels
local hh_income = 50842 // Dynarski (2003) Table 1. SE 788. Note: This is the level of household income amongst those without deceased parents. This figure is used because it is our best approximation of the household income of families with a deceased parent in the years before the death.

*********************************
/* 4. Intermediate Calculations */
*********************************

if "`outcome_type'" == "years" {

local years_impact = `years_imp'


    *Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
    int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
    local pct_earn_impact_pos = r(prog_earn_effect_pos)
    local pct_earn_impact_neg = r(prog_earn_effect_neg)

    /*
    NOTE: No private costs are added here as benefit levels of $6700 exceed the costs
    of public universities and nearly all private schoools as well.
    */

}

if "`outcome_type'" == "enrollment" {

    *Convert initial enrollment into total years of schooling
    local years_impact = `enroll_imp' * `years_enroll'

    *Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
    int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
    local pct_earn_impact_pos = r(prog_earn_effect_pos)
    local pct_earn_impact_neg = r(prog_earn_effect_neg)

    /*
    NOTE: No private costs are added here as benefit levels of $6700 exceed the costs
    of public universities and nearly all private schoools as well.
    */


}

if "`proj_type'" == "growth forecast" {
	*Initial Earnings Decline
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`proj_start_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`hh_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)
	local total_earn_impact_neg = r(tot_earn_impact_d)
	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(no) /// don't forecast short-run earnings, because it'll give them a high MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`impact_year') /// year of income measurement
		 earnings_type(individual) /// individual
		 program_age(`impact_age') // age we're projecting from
	  local tax_rate_shortrun = r(tax_rate)
	}

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = `total_earn_impact_neg' - `increase_taxes_neg'

	*Earnings Gain
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`proj_start_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`hh_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)
	local total_earn_impact_pos = ((1/(1+`discount_rate'))^7) * r(tot_earn_impact_d)
	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`impact_year_pos') /// year of income measurement
		 earnings_type(individual) /// individual
		 program_age(`impact_age_pos') // age we're projecting from
	  local tax_rate_longrun = r(tax_rate)
	}

	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = `total_earn_impact_pos' - `increase_taxes_pos'

	*Combine Estimates
	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
}

    else {
        di as err "Only growth forecast allowed"
        exit
}

*Calculate Fraction of Benefit that Remains after Tuition
local priv_enroll_frac = 1 - `public_enroll_frac'
local college_cost = `public_enroll_frac'*`pub_tuition' + `priv_enroll_frac'*`private_tuition'
local benefit_remain = max(6700 - `college_cost',0)
/*
Note: This calculation is performed because the benefit is contingent on enrollment but the benefit amount may exceed the cost of tuition. As a result any money not spend on tuition is merely considered a transfer to the individual.
*/

**************************
/* 5. Cost Calculations */
**************************

*Calculate Costs of Tuition and Other Federal Expenditures
local years_enroll_disc = 0
local end = ceil(`years_enroll')
forval i=1/`end' {
    local years_enroll_disc = `years_enroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_enroll' - floor(`years_enroll')
if `partial_year' != 0 {
    local years_enroll_disc = `years_enroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}

*Note: Our cost of college calculator has a year range that starts at 1987
*but the appropriate year here is 1981.
cost_of_college, year(`project_year') type_of_uni("rmb") // we focus here on the cost of for four year enrollment. Average duration of induced enrollees is 3 years and two year schooling not discussed in paper.
local cost_of_college = `r(cost_of_college)'

if "`outcome_type'" == "years" {
    *For all cost-of-enrollment effects based on credits, we conservatively assume
    *that they occur at the beginning of the program:
    local years_impact_disc = `years_imp'
}
if "`outcome_type'" == "enrollment" {
    local years_impact_disc = `enroll_imp' * `years_enroll_disc'
}

if "`private_costs_gov'" == "no" {
    local new_enroll_cost = (`cost_of_college' - `pub_tuition')*`public_enroll_frac'*`years_impact_disc'
}
if "`private_costs_gov'" == "yes" {
    local avg_tuition = `public_enroll_frac'*`pub_tuition' + (1-`public_enroll_frac')*`private_tuition'
    local new_enroll_cost = (`cost_of_college' - `avg_tuition')*`years_impact_disc'
}


if "`aid_crowd_out'"=="yes" {
    * As an alterantive specification, we assume that the absence of the SS Benefit leads students to seek other forms of government aid. We make the conservative assumption that all students who would have been awarded Pell grants, so the baseline program cost is the benefit amount net of this other form of aid.
    local program_cost = `years_enroll_disc'*(`benefit_amount'-`pell_grant_aid')*`base_enrollment'
}
else {
    local program_cost = `years_enroll_disc'*`benefit_amount'*`base_enrollment'
}



local program_cost_unscaled = `program_cost' + `benefit_amount'*`years_impact_disc'
local FE = `new_enroll_cost' - `increase_taxes'

local total_cost = `program_cost_unscaled' + `FE'

*************************
/* 6. WTP Calculations */
*************************

*Calculate WTP based on valuation assumption
if "`wtp_valuation'" == "post tax"{
    local WTP_induced = `total_earn_impact_aftertax' + `benefit_remain'*`years_impact'
    local WTP_non_induced = `program_cost'
    local WTP = `WTP_induced' + `WTP_non_induced'
}

if "`wtp_valuation'" == "cost"{
    local WTP_induced =  (`program_cost_unscaled'-`program_cost')*`val_given_marginal'
    local WTP_non_induced = `program_cost'
    local WTP = `WTP_induced' + `WTP_non_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

di `years_imp'
di `total_earn_impact_aftertax_pos'
di  `total_earn_impact_aftertax'
di `increase_taxes'
di `new_enroll_cost'

/*
Figures for Attainment Graph
*/
di `years_impact' //enrollment gain
di  `base_enrollment' // baseline enrollment
di `program_cost' // Mechanical Cost
di `benefit_amount'*`years_impact' // Behavioral Cost Program
di `new_enroll_cost'
di `WTP_induced' //WTP induced
di `WTP_non_induced' //WTP Non-Induced
di  `counterfactual_income_longrun' // Income Counter-Factual
di `years_enroll_disc'
di (`cost_of_college' - `private_tuition')*`priv_enroll_frac'*`years_impact_disc'


*Locals for Appendix Write-Up
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost_unscaled'
di `priv_cost_impact'
di `increase_taxes'
di `enroll_cost'
di `total_cost'
di `years_impact'
di `benefit_remain'*`years_impact'
di `program_cost'
di `total_earn_impact_aftertax'

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
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption


* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_longrun'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year_pos'
global inc_age_stat_`1' = `proj_start_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun'*r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year_pos'
global inc_age_benef_`1' = `impact_age_pos'
