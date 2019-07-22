**********************************************************************
/* 0. Program: National Spending Change */
**********************************************************************
/*Deming, David, and Chris Walters. "The impacts of state budget cuts on postsecondary attainment.""
 NBER Working Paper 23736 (2018).*/

* Earlier version:
/*Deming, David, and Chris Walters. "The impacts of price and spending subsidies
 on US postsecondary attainment." NBER Working Paper 23736 (2017).*/
 
* Examine the impact of state budget cuts on postsecondary enrollment and degree
* completion in the US. 


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
local delta_costs = "$delta_costs"

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"
local transfer_assumption = "$transfer_assumption"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}






******************************
/* 2. Estimates from Paper */
******************************

/*
	local effect_t_0 = .304 //Deming and Walters (2018) Table A6
	local effect_t_0_se = .131 //Deming and Walters (2018) Table A6

	local effect_t_1 = .796 //Deming and Walters (2018) Table A6
	local effect_t_1_se = .181 //Deming and Walters (2018) Table A6

	local effect_t_2 = .845 //Deming and Walters (2018) Table A6
	local effect_t_2_se = .207 //Deming and Walters (2018) Table A6

	local effect_t_3 = .830 //Deming and Walters (2018) Table A6
	local effect_t_3_se = .207 //Deming and Walters (2018) Table A6


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

*********************************
/* 3. Assumptions from Paper */
*********************************
*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = 2001 // average of start year 1990 and end year 2013
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2008
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'


local usd_year = 2001 // Assumption based on the midpoint of the sample period


/*Scale factor to adjust for serial correlation*/
local scale_factor = 2.02 //Deming and Walters (2017) pg. 20 footnote 19. 
//Note that there is 0.55 persistence of the budget shock into the next period, 
//which means that the effect must be scaled down by 1+ 0.55 + 0.55^2 + 0.55^3 = 2.02.
/*
We only observe years t through t+3, so we use the referenced 0.55 scale factor
*/

// The spending avg is based on tuitition for selective 4 year, nonselective 4 year, 
// and community colleges for 1990 and 2013. Sample used in Deming and Walters (2018), Table A1
local enroll_4yr_sel_1990 = 21278
local enroll_4yr_nonsel_1990 = 9306
local enroll_cc_1990 = 3626
local enroll_4yr_sel_2013 = 25865
local enroll_4yr_nonsel_2013 = 11752
local enroll_cc_2013 = 5451
local enroll_all4yr = `enroll_4yr_sel_1990'+`enroll_4yr_nonsel_1990' + `enroll_4yr_sel_2013'+`enroll_4yr_nonsel_2013'
local enroll_allcc = `enroll_cc_1990' + `enroll_cc_2013'
local enroll_all = `enroll_all4yr' + `enroll_allcc'


local tuition_4yr_sel_1990 = 4978
local tuition_4yr_nonsel_1990 = 3267
local tuition_cc_1990 = 1027
local tuition_4yr_sel_2013 = 15953
local tuition_4yr_nonsel_2013 = 8418
local tuition_cc_2013 = 2381

local tuition_avg = (`tuition_4yr_sel_1990'*`enroll_4yr_sel_1990' + ///
	`tuition_4yr_nonsel_1990'*`enroll_4yr_nonsel_1990' + ///
	`tuition_cc_1990'*`enroll_cc_1990' + `tuition_4yr_sel_2013'*`enroll_4yr_sel_2013' + ///
	`tuition_4yr_nonsel_2013'*`enroll_4yr_nonsel_2013' + `tuition_cc_2013'*`enroll_cc_2013') /`enroll_all'


// "cost_Avg = spend_avg"
local cost_4yr_sel_1990 = 31946
local cost_4yr_nonsel_1990 = 16147
local cost_cc_1990 = 5672
local cost_4yr_sel_2013 = 45584
local cost_4yr_nonsel_2013 = 20172
local cost_cc_2013 = 7441

local spend_avg = (`cost_4yr_sel_1990'*`enroll_4yr_sel_1990' + ///
	`cost_4yr_nonsel_1990'*`enroll_4yr_nonsel_1990' + `cost_cc_1990'*`enroll_cc_1990' + ///
	`cost_4yr_sel_2013'*`enroll_4yr_sel_2013' + `cost_4yr_nonsel_2013'*`enroll_4yr_nonsel_2013' + ///
	`cost_cc_2013'*`enroll_cc_2013') /`enroll_all'


local treatment_spend = 1000



*********************************
/* 4. Intermediate Calculations */
*********************************
/*Add up effects in year t_0, t+1, t+2, and t+3 for a spending change in
year t*/

di `effect_t_0'

local sum_effects = `effect_t_0' + `effect_t_1' + `effect_t_2' + `effect_t_3'

local sum_effects_disc = `effect_t_0' + `effect_t_1'/(1+`discount_rate') + ///
	`effect_t_2'*(1/(1+`discount_rate')^2) + `effect_t_3'*(1/(1+`discount_rate')^3)	

	
/*Adjust for serial correlation*/
local sum_effects_adj = `sum_effects'/`scale_factor'
local sum_effects_adj_disc = `sum_effects_disc'/`scale_factor'


local enroll_change = (`treatment_spend'/`spend_avg')*`sum_effects_adj'


int_outcome, outcome_type(attainment) impact_magnitude(`enroll_change') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) ///
		earn_series(.) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
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
		income_info(.) income_info_type(none) ///
		earn_series(.) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

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
di `enroll_change'
local program_cost_unscaled = `treatment_spend' + (`treatment_spend' * `enroll_change')
local program_cost = `treatment_spend'

local enroll_change_disc = (`treatment_spend'/`spend_avg')*`sum_effects_adj_disc'

// alternative specification -- use costs/tuition in paper
if "`delta_costs'" == "no" {

	local spend_coll = `spend_avg'
	local tuition_coll = `tuition_avg'
	
}

else {
	*Calculate Cost of Additional enrollment
	if "${got_Nat_spend_costs}"!="yes" {
		cost_of_college, year(2001) state(`any') name(`any') type_of_uni("any")
		global Nat_spend_cost_of_coll = r(cost_of_college)
		global Nat_spend_tuition_coll = r(tuition)
		
		global got Nat_spend_costs yes
	}

	local spend_coll = $Nat_spend_cost_of_coll
	local tuition_coll = $Nat_spend_tuition_coll

}




local priv_cont =  (`enroll_change_disc'*`tuition_coll')
local cost_college_change = (`enroll_change_disc'*`spend_coll')

local enroll_cost = `cost_college_change' - `enroll_change_disc'*`treatment_spend'- `priv_cont'


/*Calculate total costs net of fiscal externalities.*/
local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = `total_earn_impact_aftertax' - `priv_cont'
	*Uninduced value at program cost
	local wtp_not_induced = `treatment_spend'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `treatment_spend' * `enroll_change'*`val_given_marginal'
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `treatment_spend'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

/*
Figures for Attainment Graph
*/
di `enroll_change' //enrollment gain
di  1 // baseline enrollment
di `treatment_spend' // Mechanical Cost
di (`treatment_spend' * `enroll_change') // Behavioral Cost Program
di 	`enroll_cost' // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up 
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost'
di `enroll_cost'
di `increase_taxes'
di `total_cost'
di `MVPF'

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
global inc_stat_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `impact_year_pos'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year_pos'
global inc_age_benef_`1' = `impact_age_pos'


