********************************************************
/* 0. Program: Kalamzoo Promise  */
********************************************************

/* 
Bartik, Timothy J., Brad Hershbein, and Marta Lachowska. "The effects of the
Kalamazoo Promise Scholarship on college enrollment, persistence, and 
completion." (2017).

Bartik, Timothy J., Brad Hershbein, and Marta Lachowska. "The merits of universal 
scholarships: Benefit-cost evidence from the Kalamazoo Promise." 
Journal of Benefit-Cost Analysis 7, no. 3 (2016): 400-433.

*Provide college tuition subsidies to Kalamazoo Puplic Schools graduates. 

*/

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
local college_cost = "$college_cost" 
local selective_earnings = "$selective_earnings"

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
*Credits effects
local credit_effect_4 = 6.56 //pg. 33
local credit_effect_4_se = 3.36 //pg. 33

*Flagship enrollment effect
local selective = 0.066
local selective_se = 0.019

*Enrollment effects
local enroll_effect_12_mon = 0.059 // Bartik et al. 2017, Table 3
local enroll_effect_12_mon_se = 0.041 // Bartik et al. 2017, Table 3

local enroll_effect_4yr = 0.089 // Bartik et al. 2017, Table 3
local enroll_effect_4yr_se = 0.039 // Bartik et al. 2017, Table 3

*credentials effects
local BA_effect = 0.074 //pg. 36
local BA_effect_se = 0.040 //pg. 36
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

*********************************
/* 3. Assumptions from Paper */
*********************************
local usd_year = 2012

local program_year = 2006 // pg. 14 - first cohort to receive the kalamazoo promise

local pv_per_hs_grad = 17620 // pg. 18 - 2012 dollars and 3% discount rate
/* "During the six years after high school graduation, the average present value of 
Promise scholarship spending per Promise-eligible graduate is $17,620." - pg. 18. 
Administrative costs from Bartik et al. 2016, page 25 */

local avg_credits_4yrs = 46.59 // pg. 33
local base_enroll =  0.673

local credits_per_term = 12 // Bartik et al. 2017, Page 17

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 21
local project_year = 2006 // first promise cohort graduates Kalamazoo HS in 2006
local impact_year = `project_year' + `impact_age'-`proj_start_age'

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2013 // first promise cohort graduates Kalamazoo HS in 2006
local impact_year_pos = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'

local selective_years = 2 // Hoekstra 2009, Table 1
/*
Note: The estimates from Hoekstra 2009 suggest that attending a flagship university
increases earnings by approximately 20%. (The values vary by specification). For simplicity, 
we translate this into the approximate number of additional years of average schooling 
that would produce such an effect. This allows us to apply the same uncertainty to this
earnings effect and the other college earnings effects incorporated from Zimmerman. 
*/

*********************************
/* 4. Intermediate Calculations */
*********************************

*Estimate Earnings Effect Using Credits
di `credit_effect_4'
local years_impact = `credit_effect_4' / (`credits_per_term'*2)
local years_impact_earn = `years_impact'

local induced_fraction = `credit_effect_4' / (`avg_credits_4yrs'+`credit_effect_4')

if "`selective_earnings'" == "yes" {
	local years_impact_earn = `years_impact_earn' + `selective'*`selective_years'
	local induced_fraction = `induced_fraction' + (`selective'/`base_enroll')
}


/*
Note: We assume here that those induced into a more selective school are distinct
from those induced to attend more school. This conservatively increases our estimate 
of the induced fraction.
*/

*Get parent age
get_mother_age 2006, yob(`=2006-18')
local mother_age = r(mother_age)

********************************************
/* 4a. Project from intermediate outcomes */
********************************************

*Convert intermediate outcome to an earnings effect
int_outcome, outcome_type(attainment) impact_magnitude(`years_impact_earn') usd_year(`usd_year') 
local pct_earn_impact_neg = r(prog_earn_effect_neg)
local pct_earn_impact_pos = r(prog_earn_effect_pos)

di `pct_earn_impact_neg'
di `pct_earn_impact_pos'
di "`tax_rate_assumption'"

if "`proj_type'" == "growth forecast" {
		
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info_type(none) income_info(.) ///
		earn_series(.) /// 
		parent_age(`mother_age') parent_income_year(`project_year') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)
		
	return list
		
		
	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)
	
	di `counterfactual_income_shortrun'
	di `total_earn_impact_neg'
	
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, this will give an artificially high MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`impact_year') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age') // age we're projecting from
	  local tax_rate_shortrun = r(tax_rate)
	}
		
	di `tax_rate_shortrun'
	
	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = `total_earn_impact_neg' - `increase_taxes_neg'

			
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info_type(none) income_info(.) ///
		earn_series(.) ///
		parent_age(`mother_age') parent_income_year(`project_year') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)
		
	return list

	
	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = ((1/(1+`discount_rate'))^7) * r(tot_earn_impact_d)
	
	di `counterfactual_income_longrun'
	

	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `counterfactual_income_longrun' , /// annual control mean earnings 
			inc_year(`impact_year_pos') /// year of income measurement 
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) /// include in assumptions file (y/n)
			usd_year(`usd_year') /// usd year of income 
			program_age(`impact_age_pos') /// age of program beneficiaries when income is measured 
			forecast_income(yes) /// if childhood program where lifecycle earnings needed, yes
			earnings_type(individual) //
		
			local tax_rate_longrun = r(tax_rate)
		
		di `tax_rate_longrun'
		
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



**************************
/* 5. Cost Calculations */
**************************
*Discounting program costs:
/*
Note: In undiscounting the costs we assume they are spread equally over the 6 years, which leads to a 
conservatively high annual cost estimate.
*/
local disc_scale_factor = 	(1/(1 +(1+`discount_rate')+(1+`discount_rate')^2+(1+`discount_rate')^3 + (1+`discount_rate')^4 +(1+`discount_rate')^5)) / ///
							(1/(1 + (1.03)+(1.03)^2+(1.03)^3 + (1.03)^4 +(1.03)^5))
local program_cost_unscaled = `pv_per_hs_grad'*`disc_scale_factor'
local program_cost_admin = `program_cost_unscaled'*0.036 // Adjustment for administrative costs Bartik et al. 2016, pg 420

deflate_to `usd_year', from(`program_year')
local deflator = r(deflator)

*Since all cost-of-enrollment effects are based on credits, we conservatively assume 
*that they occur at the beginning of the program:
*Calculate Cost of Additional enrollment
if "${got_kalamazoo_costs}"!="yes" {
	cost_of_college, year(`program_year') state("MI") name(`any')
	global cost_of_college_kalamazoo = r(cost_of_college)*`deflator'
	global tuition_kalamazoo = r(tuition)*`deflator'
	
	global got_kalamazoo_costs yes
	}
local cost_of_college = $cost_of_college_kalamazoo
local tuition = $tuition_kalamazoo
	
di `tuition'
di `cost_of_college'
local public_savings = `tuition'*`years_impact'

local enroll_cost = `years_impact'*(`cost_of_college')

local program_cost = `program_cost_unscaled'*(1-`induced_fraction') 

if "`college_cost'" == "low"{
local program_cost = `tuition'*(1-`induced_fraction')
}
/*
Note: In this alternate specification we assume the cost of the program is just
the average net tuition of four year enrollees, rather than the observed $17,000.
This is under the assumption that this is a first dollar scholarship and funds
would have been provided to these individuals via other means. 
*/


local total_cost = `program_cost' + `program_cost_admin' +  `enroll_cost' - `increase_taxes' 

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax benefits, non-induced 1:1 program_cost
	local WTP_induced = `total_earn_impact_aftertax'
	local WTP_non_induced = `program_cost' 
	local WTP = `WTP_induced' + `WTP_non_induced'
}


if "`wtp_valuation'" == "cost" {
	*Induced value at val_given_marginal, non-induced 1:1 program_cost
	local WTP_induced = `induced_fraction' * `val_given_marginal' * (`program_cost'/(1-`induced_fraction'))
	local WTP_non_induced = `program_cost' 
	local WTP = `WTP_induced' + `WTP_non_induced'
}



**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

/*
Figures for Attainment Graph 
*/
di `years_impact_earn' //enrollment gain -- in case of selective earnings gain that includes selective move
di  `years_impact_earn'/(`induced_fraction') // baseline enrollment
di `program_cost' // Mechanical Cost 
di (`program_cost_unscaled'*`induced_fraction')  // Behavioral Cost Program
di 	`enroll_cost' - (`program_cost_unscaled'*`induced_fraction') // Behavioral Cost Crowd-In
di `WTP_induced' //WTP induced
di `WTP_non_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up 
di `tax_rate_shortrun'
di `tax_rate_longrun'
di `total_earn_impact_aftertax'
di `WTP'
di `enroll_cost' - (`program_cost_unscaled' - `program_cost')
di `program_cost'
di `program_cost'
di `priv_cost_impact'
di `enroll_cost'
di `increase_taxes'
di `total_cost'
di `years_impact'
di `cost_of_college'
di `program_cost'*`induced_fraction'


****************
/* 8. Outputs */
****************

global program_cost_`1' = `program_cost' + `program_cost_admin'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption


* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_shortrun' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year'+`impact_age'-`proj_start_age'
global inc_age_stat_`1' = `impact_age'

global inc_benef_`1' = `counterfactual_income_shortrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_year'+`impact_age'-`proj_start_age'
global inc_age_benef_`1' = `impact_age'

di	`MVPF'
