/*******************************************************************************
0. Program :  Tennessee Pell grants
*******************************************************************************/

/*
Carruthers, C. K., & Welch, J. G. (2019). 
"Not whether, but where? Pell grants and college choices." 
Journal of Public Economics, 172, 1-19.

*Use discontinuity in Pell Grant eligibility to determine grant impacts on enrollment.

*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" 
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type" 
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation" 
local val_given_marginal = $val_given_marginal 

local tax_rate_assumption = "$tax_rate_assumption" 
local payroll_assumption = "$payroll_assumption" 
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}

local pell_cost = "$pell_cost"
local cc_vs_4yr_effect = "$cc_vs_4yr_effect"
local years_enroll_4yr = $years_enroll_4yr
local years_enroll_cc = $years_enroll_cc


*********************************
/* 2. Estimates from Paper */
*********************************


/*
local enroll_effect_4yr_pub_tn = -0.0092
local enroll_effect_4yr_pub_tn_se = 0.0123

local enroll_effect_4yr_pub = 0.00245
local enroll_effect_4yr_pub_se = 0.00454

local enroll_effect_4yr_priv = 0.000514
local enroll_effect_4yr_priv_se = 0.00795

local enroll_effect_2yr_pub_tn = 0.00226
local enroll_effect_2yr_pub_tn_se = 0.0119

local enroll_effect_2yr_pub = 0.00157
local enroll_effect_2yr_pub_se = 0.00454

local enroll_effect_2yr_priv = 0.00136
local enroll_effect_2yr_priv_se = 0.00158

local net_price_effect = 98.91
local net_price_effect_se = 95.5

local out_state_tuit_fees_effect = 145
local out_state_tuit_fees_effect_se = 121.4

local in_state_tuit_fees_effect = 153.9
local in_state_tuit_fees_effect = 151.8

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

local year_policy = round((2006+2009)/2) // sample period
local usd_year = round((2006+2009)/2) // sample period

local pell_discontinuity_value = 481 // Carruthers & Welch (2019) page 8

local efc_discontinuity_level = 3850 // Carruthers & Welch (2019) page 3

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = `year_policy' // policy change is for 2005 winners
local impact_year = `project_year' + `impact_age'-`proj_start_age'
	
*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `project_year' + `proj_start_age_pos'-`proj_start_age'
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'
	
local p_attend_college = 0.805 // Carruthers & Welch (2019) table 1, column 4 (bandwidth restricted sample)

local p_2yr_tn = 0.374 		// Carruthers & Welch (2019) table 2, column 2 (bandwidth restricted sample)
local p_4yr_tn = 0.442 		// Carruthers & Welch (2019) table 2, column 2 (bandwidth restricted sample)
local p_4yr_priv = 0.125 	// Carruthers & Welch (2019) table 2, column 2 (bandwidth restricted sample)
local p_2yr_not_tn = 0.014 	// Carruthers & Welch (2019) table 2, column 2 (bandwidth restricted sample)
local p_4yr_not_tn = 0.038 	// Carruthers & Welch (2019) table 2, column 2 (bandwidth restricted sample)
local p_for_profit = 0.004 	// Carruthers & Welch (2019) table 2, column 2 (bandwidth restricted sample)


local p_2yr = `p_2yr_tn'+`p_2yr_not_tn'+`p_for_profit'
local p_4yr = `p_4yr_tn'+`p_4yr_priv'+`p_4yr_not_tn'

local p_in_state = `p_2yr_tn'+`p_4yr_tn'
local p_out_state = `p_2yr_not_tn'+`p_4yr_not_tn'


*US Department of Education Pell end-of-year report 2009/10
*https://www2.ed.gov/finaid/prof/resources/data/pell-2009-10/pell-eoy-09-10.pdf
*As discontinuity is some -> zero pell take roughly p90 of family income from table 11
*p90 falls within $40k-$50k
deflate_to `usd_year', from(2010)
local parent_income = 45000*r(deflator)

* impact of changing Pell threshold by 1 dollar on total undergraduate aid
local fut_pell_1 = 1.04 // Carruthers & Welch (2019) Page 7
local fut_pell_2 = 0.88 
local fut_pell_3 = 0.12 

get_mother_age `year_policy', yob(`=`year_policy'-18')
local parent_age = r(mother_age)

*********************************
/* 4. Intermediate Calculations */
*********************************

*Four year impact
local enroll_effect_4yr = `enroll_effect_4yr_pub_tn' + `enroll_effect_4yr_pub' + `enroll_effect_4yr_priv'
local years_effect_4yr = `enroll_effect_4yr'*`years_enroll_4yr'

*Two year impact
local enroll_effect_2yr = `enroll_effect_2yr_pub_tn' + `enroll_effect_2yr_pub' + `enroll_effect_2yr_priv'
local years_effect_2yr = `enroll_effect_2yr'*`years_enroll_cc'

local years_effect_tot = `years_effect_2yr' + `years_effect_4yr'

*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
if "`cc_vs_4yr_effect'"=="same" {
	int_outcome, outcome_type(attainment) impact_magnitude(`years_effect_tot') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
}
if "`cc_vs_4yr_effect'"=="different" {
	int_outcome, outcome_type(attainment) impact_magnitude(`years_effect_4yr') usd_year(`usd_year')

	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

	int_outcome, outcome_type(ccattain) impact_magnitude(`years_effect_2yr') usd_year(`usd_year')
	local pct_earn_impact_neg = `pct_earn_impact_neg' + r(prog_earn_effect_neg)
	local pct_earn_impact_pos = `pct_earn_impact_pos' + r(prog_earn_effect_pos)

}

local tot_enroll_efect = `enroll_effect_4yr' + `enroll_effect_2yr'
local pct_induced = `tot_enroll_efect' / `p_attend_college'


*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	*Policy is on margin of some - > zero pell; 1/3 students receive Pell (Bettinger, 2004)
	*Hence p30 is too low as obviously richer people select into being students, approximate
	*with p40
	local parent_rank = 40 
	
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		parent_age(`parent_age') parent_income_year(`year_policy')  ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
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
		parent_age(`parent_age') parent_income_year(`year_policy') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

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

**************************
/* 5. Cost Calculations */
**************************	
*Uninduced (assume 4 year)
local uninduced_cost = 0

if "`pell_cost'" ==  "baseline" {
local uninduced_cost = `pell_discontinuity_value'*(1 + (`fut_pell_1'/(1+`discount_rate')^(1)) + (`fut_pell_2'/(1+`discount_rate')^(2)) + (`fut_pell_3'/(1+`discount_rate')^(3)))
}

if "`pell_cost'" ==  "one year" {
local uninduced_cost = `pell_discontinuity_value'
}

if "`pell_cost'" ==  "full years" {

forval i = 1/4 {
	local uninduced_cost = `uninduced_cost' + `pell_discontinuity_value' * ///
							(`p_4yr'/(`p_2yr'+`p_4yr')) * ///
							(`p_attend_college'-`tot_enroll_efect') / ///
							((1+`discount_rate')^(`i'-1))
	if `i' <= 2 {
		local uninduced_cost = `uninduced_cost' + `pell_discontinuity_value' * ///
							(`p_2yr'/(`p_2yr'+`p_4yr')) * ///
							(`p_attend_college'-`tot_enroll_efect') / ///
							((1+`discount_rate')^(`i'-1))
	}
}

}

*Induced
foreach type in 4yr cc {
	local years_enroll_`type'_disc = 0
	local end = ceil(${years_enroll_`type'})
	forval i=1/`end' {
		local years_enroll_`type'_disc = `years_enroll_`type'_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = ${years_enroll_`type'} - floor(${years_enroll_`type'})
	if `partial_year' != 0 {
		local years_enroll_`type'_disc = `years_enroll_`type'_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}
}
local years_effect_4yr_disc = `enroll_effect_4yr'*`years_enroll_4yr_disc'
local years_effect_2yr_disc = `enroll_effect_2yr'*`years_enroll_cc_disc'

local induced_cost = `pell_discontinuity_value'*(`years_effect_4yr_disc'+`years_effect_2yr_disc')

local program_cost = `uninduced_cost'
local program_cost_unscaled = `induced_cost' + `uninduced_cost'

*Calculate Cost of Additional enrollment
if "${got_tn_costs}"!="yes" {
	cost_of_college, year(`year_policy') state(TN) type_of_uni(community)
	global tn_cc_cost_of_college = r(cost_of_college)
	global tn_cc_tuition = r(tuition)
	
	cost_of_college, year(`year_policy') state(TN) type_of_uni("rmb")
	global tn_rmb_cost_of_college = r(cost_of_college)
	global tn_rmb_tuition = r(tuition)
	
	global got_tn_costs yes
}
local enroll_cost = `years_effect_4yr_disc' * (${tn_rmb_cost_of_college} - `efc_discontinuity_level') + ///
				`years_effect_2yr_disc' * (${tn_cc_cost_of_college} - `efc_discontinuity_level') - ///
				`induced_cost' // net out Pell cost to avoid double counting



/*
Note: We determine cost changes based on the in-state and out of state tuition costs.
*/
local avg_cost_effect = (`out_state_tuit_fees_effect'*`p_out_state' + ///
				`in_state_tuit_fees_effect'*`p_in_state') / ///
				(`p_in_state'+`p_out_state')
				
local switch_cost_gov  = `avg_cost_effect'-`net_price_effect'
local switch_cost_priv = `net_price_effect'

local total_cost = `program_cost_unscaled' + `enroll_cost' + `switch_cost_gov' - `increase_taxes' 

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = `total_earn_impact_aftertax'  - ///
							`years_effect_4yr_disc' * `efc_discontinuity_level' - ///
							`years_effect_2yr_disc' * `efc_discontinuity_level' ///
	
	*Uninduced value at transfer
	local wtp_not_induced = `uninduced_cost'
	
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `val_given_marginal'*`induced_cost'
	
	*Uninduced value at transfer
	local wtp_not_induced =  `uninduced_cost'

	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

/*
Figures for Attainment Graph 
*/
di `years_effect_tot' //enrollment gain
di `p_attend_college' //baseline enrollment
di `uninduced_cost' // Mechanical Cost 
di `induced_cost' // Behavioral Cost Program
di 	`enroll_cost' // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up 
di `years_effect_tot' 
di `years_effect_4yr_disc'
di `years_effect_2yr_disc'
di `tax_rate_longrun'
di `wtp_induced'
di `WTP'
di `total_earn_impact_aftertax'
di `years_effect_4yr_disc' * `efc_discontinuity_level'
di `years_effect_2yr_disc' * `efc_discontinuity_level'
di -`years_effect_4yr_disc' * `efc_discontinuity_level' - `years_effect_2yr_disc' * `efc_discontinuity_level'
di `uninduced_cost'
di `induced_cost'
di 	`enroll_cost'
di `switch_cost_gov'
di `switch_cost_priv'
di `program_cost'
di `increase_taxes'
di `total_cost'



****************
/* 8. Outputs */
****************

di `MVPF'
di `WTP'
di `program_cost'
di `total_cost'
di `MVPF'
di `increase_taxes'
di `uninduced_cost'
di `counterfactual_income_longrun'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_longrun'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `impact_year_pos'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year_pos'
global inc_age_benef_`1' = `impact_age_pos'
