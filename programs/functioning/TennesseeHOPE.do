********************************************
/* 0. Program: Tennessee HOPE Scholarship */
********************************************

/*Bruce, Donald J. and Celeste K. Carruthers. 2014. "Jackpot? The impact of
lottery scholarships on enrollment in Tennesse." Journal of Urban Economics 81:
30-44.*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation" // "post tax" or "cost"

* globals for finding the tax rate.
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}

*Program-specific globals
local separate_cc = "$separate_cc" //yes or no (compute attainment effects on earnings separately for community college)
local val_given_marginal = $val_given_marginal // 0 or 0.5 or 1
local enrollment_time_4yr = $enrollment_time_4yr // number between 2 and 4 years
local enrollment_time_2yr = $enrollment_time_2yr // number between 1 and 2 years


*********************************
/* 2. Estimates from Paper */
*********************************

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
/*
*First-stage effect of ACT threshold on HOPE eligibility for low-GPA sample
local hope_firststage = 0.228 //Bruce and Carruthers 2014, Table 3
local hope_firststage_se = 0.010

*Reduced-form effect of ACT threshold on in-state public community college enrollment
local public_2yr_effect = -0.022 //Bruce and Carruthers 2014, Table 3
local public_2yr_effect_se = 0.011
*/

*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************
local usd_year = 2006 // Assumption that the dollar estimates are based on the the starting year of the sample period under study (2006-2009)

local parent_income = 52000 //Bruce and Carruthers, p. 32

*HOPE scholarship amounts (note: for 2009-10, not including additional optional
*summer credit of $2000) - Bruce and Carruthers, fn. 2
local hope_amt_2006_4yr = 3800
local hope_amt_2007_4yr = 4000
local hope_amt_2008_4yr = 4000
local hope_amt_2009_4yr = 4000

local hope_amt_2006_2yr = 1900
local hope_amt_2007_2yr = 2000
local hope_amt_2008_2yr = 2000
local hope_amt_2009_2yr = 2000

*Mean enrollments in sample - Bruce and Carruthers, Table 3
/*Any HOPE-eligible college*/
local mean_hope_elig = 0.781
/*Public 2-year*/
local mean_public_2yr = 0.285
/*Public 4-year*/
local mean_public_4yr = 0.423
/*In-state private*/
local mean_private =  0.073

local share_private = 0.24 // Bruce and Carruthers, Table 1

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = 2007 //sample enter college in 2006 - 2009
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2014 //sample enter college in 2006 - 2009
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

*********************************
/* 4. Intermediate Calculations */
*********************************

*Estimate earnings effects for those changing enrollment from 2-year to 4-year schools:
if "`separate_cc'" == "no" 	int_outcome, outcome_type(attainment) 	 impact_magnitude(`enrollment_time_2yr') usd_year(`usd_year')
if "`separate_cc'" == "yes" int_outcome, outcome_type(ccattain) impact_magnitude(`enrollment_time_2yr') usd_year(`usd_year')
local pct_earn_impact_neg_2yr = r(prog_earn_effect_neg)
local pct_earn_impact_pos_2yr = r(prog_earn_effect_pos)
di `enrollment_time_2yr'
di "`separate_cc'"
di `pct_earn_impact_neg_2yr'
di `pct_earn_impact_pos_2yr'

int_outcome, outcome_type(attainment) impact_magnitude(`enrollment_time_4yr') usd_year(`usd_year')
local pct_earn_impact_neg_4yr = r(prog_earn_effect_neg)
local pct_earn_impact_pos_4yr = r(prog_earn_effect_pos)
di `pct_earn_impact_neg_4yr'
di `pct_earn_impact_pos_4yr'

local pct_earn_impact_neg = `pct_earn_impact_neg_4yr' - `pct_earn_impact_neg_2yr'
local pct_earn_impact_pos = `pct_earn_impact_pos_4yr' - `pct_earn_impact_pos_2yr'

*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	di `enrollment_time_4yr'
	di `pct_earn_impact_neg'

	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(2007) percentage(yes)

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

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'

	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(2007) percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-18))

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year_pos') /// year of income measurement
		earnings_type(individual) /// individual, because that's what's produced by int_outcome
		program_age(`impact_age_pos') // age of income measurement
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
*All calculations below on an ITT basis.
*Get average inflation-adjusted annual HOPE scholarship for 2006-09:
foreach x in 2 4 {
	local hope_amt_`x'yr = 0
	forval y = 2006/2009 {
		deflate_to `usd_year', from(`y')
		local hope_amt_`x'yr = `hope_amt_`x'yr' + 0.25*`hope_amt_`y'_`x'yr'*r(deflator)
	}
}
*Compute discounted total cost of HOPE scholarship per recipient (over full span of college):
*Assumption: average scholarship at discontinuity is given by mean shares for sample
*(assuming private schools are 4-year):
foreach y in 2 4 {
	local enrollment_time_`y'yr_disc = 0
	local end = ceil(`enrollment_time_`y'yr')
	forval i=1/`end' {
		local enrollment_time_`y'yr_disc = `enrollment_time_`y'yr_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `enrollment_time_`y'yr' - floor(`enrollment_time_`y'yr' )
	if `partial_year' != 0 {
		local enrollment_time_`y'yr_disc  = `enrollment_time_`y'yr_disc ' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}
}

local avg_total_hope_amt_disc = (`mean_public_2yr'/`mean_hope_elig')*`hope_amt_2yr'*`enrollment_time_2yr_disc' + ///
						  ((`mean_public_4yr' + `mean_private')/`mean_hope_elig')*`hope_amt_4yr'*`enrollment_time_4yr_disc'

*As noted above, assuming takeup is eligibility discontinuity multiplied by share of HOPE-eligible enrollment:
local program_cost_unscaled = `hope_firststage'*`mean_hope_elig'*`avg_total_hope_amt_disc'
local program_cost = (`hope_firststage'*`mean_hope_elig'*`avg_total_hope_amt_disc') - (`hope_firststage'*`avg_total_hope_amt_disc'*(-`public_2yr_effect'))


*Calculate additional college cost of shift in enrollment (per shifter) above actual HOPE scholarship
*received by shifters:
if "${got_tenn_hope_costs}"!="yes" {
	cost_of_college, year(2008) state("TN") type_of_uni("rmb")
	global tn_cost_of_college_4yr = r(cost_of_college)
	global tn_tuition_4yr = r(tuition)
	cost_of_college, year(2008) state("TN") type_of_uni("community")
	global tn_cost_of_college_2yr = r(cost_of_college)
	global tn_tuition_2yr = r(tuition)

	global got_tenn_hope_costs yes
}

*Assumption: shifters always contribute 25% of net tuition and fees.
deflate_to `usd_year', from(2008)
local chg_total_cost_of_college = r(deflator)* (${tn_cost_of_college_4yr}*`enrollment_time_4yr_disc' - ${tn_cost_of_college_2yr}*`enrollment_time_2yr_disc')
local priv_cost_impact = r(deflator)*`share_private'* (${tn_tuition_4yr}*`enrollment_time_4yr_disc' - ${tn_tuition_2yr}*`enrollment_time_2yr_disc')
local enroll_cost = `chg_total_cost_of_college' - `priv_cost_impact' - `enrollment_time_4yr_disc'*`hope_amt_4yr' //Final term is to avoid double-counting HOPE from program cost.

*Compute total cost:
local total_cost = `program_cost_unscaled' + (`enroll_cost' - `increase_taxes')*(-`public_2yr_effect')

*************************
/* 6. WTP Calculations */
*************************
*All calculations below on an ITT basis.
if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact net of private costs incurred
	local wtp_induced = (`total_earn_impact_aftertax' - `priv_cost_impact')*(-`public_2yr_effect')
	*Uninduced value at program cost
	local wtp_not_induced = `avg_total_hope_amt_disc'*(`hope_firststage'*`mean_hope_elig' - (-`public_2yr_effect'))
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced (shifters) value additional transfer at fraction `val_given_marginal'
	local wtp_induced = (-`public_2yr_effect')*((`hope_amt_2yr'*`enrollment_time_2yr_disc') + ///
												`val_given_marginal'*((`hope_amt_4yr'*`enrollment_time_4yr_disc')-(`hope_amt_2yr'*`enrollment_time_2yr_disc')))
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `avg_total_hope_amt_disc'*(`hope_firststage'*`mean_hope_elig' - (-`public_2yr_effect'))
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
di (`enrollment_time_4yr'-`enrollment_time_2yr')*(-`public_2yr_effect') //enrollment gain
di  (`hope_firststage'*`mean_hope_elig' - (-`public_2yr_effect')) // baseline enrollment
di `program_cost_unscaled' - (`enrollment_time_4yr'*`hope_amt_4yr'*(-`public_2yr_effect')) // Mechanical Cost
di (`enrollment_time_4yr'*`hope_amt_4yr'*(-`public_2yr_effect')) // Behavioral Cost Program
di 	`enroll_cost'*(-`public_2yr_effect') // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `WTP'
di `program_cost'
di `priv_cost_impact'
di (`enrollment_time_4yr' - `enrollment_time_2yr')*(-`public_2yr_effect')
di `increase_taxes'*(-`public_2yr_effect')
di (`priv_cost_impact')*(-`public_2yr_effect')
di `enroll_cost'*(-`public_2yr_effect')
di `total_earn_impact_aftertax'*(-`public_2yr_effect')
di `total_cost'
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
