/********************************************************************************
0. Program : HOPE Tax Credit and Earnings
*******************************************************************************/

*** Primary Estimates: Turner, Nicholas. "The effect of tax-based federal student aid on college enrollment." (2011).

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type"
local proj_age = $proj_age
local correlation = $correlation
local wtp_valuation = "$wtp_valuation"
local val_given_marginal = $val_given_marginal

*Program Specific Globals
local years_enroll = $years_enroll
local take_up_rate = "$take_up_rate" //
local alt_subsidy =  "$alt_subsidy" //


*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"
local transfer_assumption = "$transfer_assumption"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}

/*
Appendix Alternatives:
1) Costs based on 1,104 rather than the 6.76 times treatment from table 3
2) part time enrollment at 1 year
3) alternate parental income

*/


*********************************
/* 2. Estimates from Paper */
*********************************
/*
Enrollment Effects:
Impact on college enrollment in the first year
year_1_college	0.00235	
year_1_college_se 0.129

Impact on college enrollment in the second year conditional on completing the first
year_2_college 	0.0021
year_2_college_se	0.101

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
/* 3. Assumptions from Paper */
*****************************************************

local usd_year = 1996
local program_year = 1998


local take_up_bound = 0.63 // Turner 2011, Page 844 - Maag and Rohaly (2007)
local parental_earnings = 40000 // Turner 2011, Page 844 
local mean_enroll = 0.3231 // Turner 2011, p. 852 Table 3
local mean_subsidy_1 = 6.76 // Turner 2011, p. 853 Table 4 (in hundreds of dollars)
local mean_subsidy_2 = 6.89 // Turner 2011, p. 853 Table 4 (in hundreds of dollars)

if "`alt_subsidy'" == "yes" {
	local subsidy_cost = 676 // Turner Table 3 
}

if "`alt_subsidy'" == "no" {
	local subsidy_cost = 1104 // Turner Table 2
}

local mean_enroll_y1 = 0.252 // Turner 2011, p. 853 Table 4
local mean_enroll_y2 = 0.6681 // Turner 2011, p. 853 Table 4


*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = 1999
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 1999 // sample enter college in 2007 - 2011
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

*********************************
/* 4. Intermediate Calculations */
*********************************


// Control enroll
local control_enroll_y1 = `mean_enroll_y1' - `mean_subsidy_1'*`year_1_college'
local control_enroll_y2 = `mean_enroll_y2' - `mean_subsidy_2'*`year_2_college'
local years_impact = `subsidy_cost'*(`year_1_college' + `year_2_college'*`years_enroll')/100

*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
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
 *Calculating revenue effects and post tax earnings impacts
	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'

	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`parental_earnings') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(`project_year') percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-18)) //discounting back to dollars in year of age 18

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
else {
	di as err "Only growth forecast allowed"
	exit
}

**************************
/* 5. Cost Calculations */
**************************
*Discounting for costs:
local years_enroll_disc = 0
local end = ceil(`years_enroll') + 1

// Note that for this program the years_enroll applies for those in their second year of college (only affects persistence), so we discount starting from i=2 instead of i=1
forval i=2/`end' {
	local years_enroll_disc = `years_enroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_enroll' - floor(`years_enroll')
if `partial_year' != 0 {
	local years_enroll_disc = `years_enroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}
di `year_1_college'
di `mean_subsidy'

local years_impact_disc = `year_1_college'*`mean_subsidy_1'+`year_2_college'*`years_enroll_disc'*`mean_subsidy_2'


local control_mean_1 = `mean_enroll_y1' - `mean_subsidy_1'*`year_1_college'
local control_mean_2 =  `mean_enroll_y2' - `mean_subsidy_2'*`year_2_college'

local program_cost_unscaled = `subsidy_cost'*(`control_mean_1'+`year_1_college') + `subsidy_cost'*`control_mean_1'*(`control_mean_2' + `year_2_college'*`years_enroll_disc') // Second year enrollment effect is estimated for the subset of individuals who complete their first year of college.
local program_cost = `subsidy_cost'*(`control_mean_1') + `subsidy_cost'*`control_mean_1'*(`control_mean_2')

if "`take_up_rate'" == "part" {
	local program_cost_unscaled = `subsidy_cost'*(`control_enroll_y1'*`take_up_bound'+`year_1_college') ///
	+ `subsidy_cost'*`control_enroll_y1'*(`control_enroll_y2'*`take_up_bound' + `year_2_college'*`years_enroll_disc') // Second year enrollment effect is estimated for the subset of individuals who complete their first year of college.
}

*Calculate Cost of Additional enrollment
cost_of_college, year(`program_year') state(`any') name(`any')
local cost_of_college = r(cost_of_college)
local tuition = r(tuition)
local priv_cont =  `years_impact_disc'*(`tuition'-`subsidy_cost')
local enroll_cost = `years_impact_disc'*(`cost_of_college') - `priv_cont' // Yearly Costs of those induced to enroll, minus the effective family contribution
/* Note: We assume that additional schooling due to increased credits has costs
that scale as a fraction of yearly educational expenditures. */

local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = `total_earn_impact_aftertax' - `priv_cont'
	*Uninduced value at program cost
	local wtp_not_induced = `subsidy_cost'*`control_mean_1'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `years_impact'*`subsidy_cost'*`val_given_marginal'
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `subsidy_cost'*`control_mean_1'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

*Locals for Appendix Write-Up
di `MVPF'
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
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
di `increase_taxes_enrollment'
di `increase_taxes_attainment'
di `years_impact'

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
global inc_year_stat_`1' = `impact_year_pos'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year_pos'
global inc_age_benef_`1' = `impact_age_pos'
