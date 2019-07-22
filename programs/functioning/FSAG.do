********************************************************
/* 0. Program: Florida Student Access Grant (FSAG) */
********************************************************

/*Primary Estimates: Castleman, Benjamin L., and Bridget Terry Long. "Looking beyond enrollment: The causal effect of need-based grants on college access, persistence, and 
graduation." Journal of Labor Economics 34, no. 4 (2016): 1023-1073. */

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local proj_type = "$proj_type" 
local proj_age = $proj_age
local correlation = $correlation
local wtp_valuation = "$wtp_valuation" 
local val_given_marginal = $val_given_marginal 

*Program-Specific Globals
local prog_cost_assumption = "$prog_cost_assumption" 
local outcome_type = "$outcome_type" 
local years_bach_deg = $years_bach_deg
local years_enroll = $years_enroll

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_long  = $tax_rate_cont
	local tax_rate_short = $tax_rate_cont
}


******************************
/* 2. Estimates from Paper */
******************************
/*
*Impact on Credits Earned 
local cred_4yr = 4.366 //Castleman and Long 2016, Table 4
local cred_4yr_se = 1.937 

*Impact on College Enrollment  
local ever_enroll_effect =  0.025 //Castleman and Long 2016, Table 3
local ever_enroll_effect_se = 0.019

*Impact on BA Completion 
local BA_7yrs = .052 //Castleman and Long 2016, Table 5
local BA_7yrs_se = .021 


local FSAG_amount = 511.928 // Average amount conditional on eligibility in fall 2000, Castleman and Long 2016 Table A6. Full explanation, Page 1031
local FSAG_amount_se = 24.90
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


*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************
*Mean cumulative credit completion after 4 years in analytic sample
local sample_mean_cred = 45.13 // table 4 

*Value of FSAG in 2000 constant dollars
local FSAG_eligibility = 1300 // Grant Amount Upon Receipt, Castleman and Long 2016 Page 1025 
local usd_year = 2000

*Mean Parental Income Close to RD Cutoff
local parent_income = 28035 //Castleman and Long 2016, Table 1

*Effective Family Contribution at Threshold
local efc_level = 1590 // Castleman and Long 2016  Page 1025

*Mean enrollment probability 
local sample_mean_enroll = 0.8 //Castleman and Long 2016, Table 3

local percent_tuition = .57 // Castleman and Long 2016, Page 1025

local min_val_Pell = 1750 // Castleman and Long 2016, Page 1025

local bright_futures_val = 1700 // Castleman and Long 2016, Page 1031
local bright_futures_val_frac = 0.7 // Castleman and Long 2016, Page 1031
local bright_futures_val_high = 2500 // Castleman and Long 2016, Page 1031
local bright_futures_val_high_frac = 0.3 // Castleman and Long 2016, Page 1031
local bright_futures_prop = 0.3 // Castleman and Long 2016, Page 1031

local credits_per_term = 12 //Castleman and Long 2016, Footnote 30 
local sem_per_year = 2 //assumed

*Assumptions of Age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 34
local project_year = 2000 

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2007 

*********************************
/* 4. Intermediate Calculations */
*********************************

*Control Mean Estimates
local mean_cred_4yr = `sample_mean_cred' - (`cred_4yr'/2) 
local mean_enroll = `sample_mean_enroll' - (`ever_enroll_effect'/2) 
/*
Note: It is assumed half the sample is in the control, so the control 
mean is the total mean minus half the treatment effect.
*/


*Estimate Earnings Effect Using Credits Earned
if "`outcome_type'" == "credits earned" {
	
	*Convert credits impact into equivalent years of schooling 
	local years_impact = `cred_4yr'/(`credits_per_term'*2)

	*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
	
	local induced_fraction = (`cred_4yr'/(`mean_cred_4yr'+`cred_4yr'))
	/*
	Note: We assume that the number additional credits taken as fraction of control
	mean credits represents the fraction of individuals who recieved the aid who changed
	their behavior in response. This is used to determine the willingness to pay 
	in Section 5. 
	*/
	
}

*Estimate Earnings Effect Using Enrollment 
if "`outcome_type'" == "enrollment and graduation" {
	
	*Convert initial enrollment into total years of schooling
	local years_impact = `years_enroll'*`ever_enroll_effect' + `years_bach_deg'*`BA_7yrs'
	/*
	Note: We assume the new individuals induced to enroll are distinct from those who are induced to 
	graduate. In both cases we assume that enrollment and graduation are associated with a fixed number
	of years of additonal schooling. Those years of additional schooling are determine by the locals
	`years_enroll' and 'years_bach_deg'.
	*/

	*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
	
	*Calculate the fraction of enrolled individuals who are induced to change behavior
	local induced_fraction = (`BA_7yrs' + `ever_enroll_effect')/(`mean_enroll' + `ever_enroll_effect')
	
}


*Estimate Long-Run Earnings Effect Using Growth Forecast Method
if "`proj_type'" == "growth forecast" {
	
	*Initial Earnings Decline 		
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`proj_start_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(2000) percentage(yes)
		
	local total_earn_impact_neg = r(tot_earn_impact_d)
	local counterfactual_income_short = r(cfactual_income) // For CBO tax rates.

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_short', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(no) /// don't forecast short-run earnings, because it'll give them a high MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`project_year') /// year of income measurement
		 earnings_type(individual) /// individual, because that's what's produced by int_outcome
		 program_age(`proj_start_age') // age we're projecting from
	  local tax_rate_short = r(tax_rate)
	}
	local increase_taxes_neg = `tax_rate_short' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = `total_earn_impact_neg' - `increase_taxes_neg'
	
	*Earnings Gain
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`proj_start_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(2000) percentage(yes)
	
	local total_earn_impact_pos = ((1/(1+`discount_rate'))^7) * r(tot_earn_impact_d)
	local counterfactual_income_long = r(cfactual_income) // For CBO tax rates.

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_long', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`project_year_pos') /// year of income measurement
		 earnings_type(individual) /// individual, because that's what's produced by int_outcome
		 program_age(`proj_start_age_pos') // age we're projecting from
	  local tax_rate_long = r(tax_rate)
	}
	local increase_taxes_pos = `tax_rate_long' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = `total_earn_impact_pos' - `increase_taxes_pos'
	
	*Combine Estimates
	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
	

}
di `total_earn_impact'
di `increase_taxes'
else {
	di as err "Only growth forecast allowed"
	exit
}
	
* get income in 2015 usd 
deflate_to 2015, from(`usd_year')
local deflator = r(deflator)
local income_2015 = `deflator'*`counterfactual_income_long'	

**************************
/* 5. Cost Calculations */
**************************
*Discounting for cost calculations:
	*Enrollment:
	local years_enroll_disc = 0
	local end = ceil(`years_enroll')
	forval i=1/`end' {
		local years_enroll_disc = `years_enroll_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll' - floor(`years_enroll')
	if `partial_year' != 0 {
		local years_enroll_disc = `years_enroll_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}

	*Graduation (to be conservative, assuming additional years end in year 6 given Table 5):
	local years_bach_deg_disc = 0
	local start =  floor(6-`years_bach_deg') + 1
	forval i =`start'/6 {
		local years_bach_deg_disc = `years_bach_deg_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_bach_deg' - floor(`years_bach_deg')
	if `partial_year' != 0 {
		local years_bach_deg_disc = `years_bach_deg_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`start'-1))
	}

if "`outcome_type'" == "credits earned" {
	*For all cost-of-enrollment effects based on credits, we conservatively assume 
	*that they occur at the beginning of the program:
	local years_impact_disc = `years_impact'
}
if "`outcome_type'" == "enrollment and graduation" {
	local years_impact_disc = `years_enroll_disc'*`ever_enroll_effect' + `years_bach_deg_disc'*`BA_7yrs'
}
	
	
local program_cost =  `FSAG_amount' + /// Year 1
					  `FSAG_amount'*0.36*(1/(1+`discount_rate')) +  /// Year 1
					  `FSAG_amount' * 0.21* (1/(1+`discount_rate'))^2 + ///
					  `FSAG_amount' * 0.21* (1/(1+`discount_rate'))^3
/*
Note: This is an estimates of the persistence of costs given the description 
provided in Castleman and Long 2016. The paper explains on Page 1058 that "Only
36% of students who got FSAG in their first year of college also receive it in 
their second year. By 4 years after high school,only 21% of eligible students 
receive the grant." It is not entirely clear whether the 21% figure refers to 
the fraction of initial students who receive the grant, but we make that 
assumption here. We make that assumption because the size of the initial grant 
is $1,300 and the average amount per eligibile recipient is $511. By that 
interpretation, only 39% of eligible students receive the grant in year 1. If 
that were the case and only 36% of students received their grants in years 1 and
2, that would imply that only 14% of eligible students received that grant in 
the second year. That number is clearly inconsistent with the notion that 21% of
eligible students recieved the grant in year 4. 
*/


*Calculate cost of additional enrollment
cost_of_college, year(2000) state("FL") type_of_uni("rmb")
local cost_of_college_2000_fl_rmb = `r(cost_of_college)'
local priv_cost_impact = `years_impact_disc' * `efc_level' // Assume private costs are determined by the EFC
/*
Note: We conservatively assume that the school pays for all costs of enrollment, 
except for the effective family contribution. The evidence in Table 3 suggests all
enrollment effects occur at four-year public colleges in Florida. 
*/
if "`outcome_type'" == "credits earned" {
	local enroll_cost = `years_impact_disc'*(`cost_of_college_2000_fl_rmb') - `priv_cost_impact' // Yearly Costs of those induced to enroll, minus effective family contribution
}
if "`outcome_type'" == "enrollment and graduation" {
	*Account for Double Counting Costs in Enrollment Case 
	local enroll_cost = `years_impact_disc'*(`cost_of_college_2000_fl_rmb') - `priv_cost_impact' - `program_cost'*`ever_enroll_effect'
	/*
	Note: This calculation is made to avoid double counting costs. The cost of providing 
	the FSAG to new enrollees is implicitly included in the total government expenditures
	on their education. This adjustment is not made for those receiving additional credits
	or those who increase their graduation rate because that increase in schooling may
	have occured in the year after the FSAG was granted. We avoid the double-count
	correction in those cases in order to be conservative about costs. 
	*/
}

if "`prog_cost_assumption'" == "less conservative" {
	local enroll_cost = `years_impact_disc' * `min_val_Pell' + /// impact on Pell grants
						`years_impact_disc' * `bright_futures_prop' * (`bright_futures_val'*`bright_futures_val_frac' + `bright_futures_val_high'*`bright_futures_val_high_frac')
	/*
	Note: Here we assume that the only fiscal costs of additional enrollment come from the additional cost 
	of providing Pell Grants and State Specific Aid.  
	*/
}

local FE = `enroll_cost' - `increase_taxes'

local total_cost = `program_cost' + `FE'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
		local wtp_induced = `total_earn_impact_aftertax' - `priv_cost_impact'
		
		local wtp_not_induced = `program_cost'*(1 - `induced_fraction')
		/*
		Note: Willingness to pay is determined by costs for those who don't change 
		their behavior. We get this from 1 minus the fraction of inividuals induced
		to change their behavior. 
		*/

		local WTP = `wtp_induced' + `wtp_not_induced'

}

if "`wtp_valuation'" == "cost" {
	local wtp_not_induced = `program_cost'*(1 - `induced_fraction')
	
	local wtp_induced =  `induced_fraction'*`program_cost'*`val_given_marginal'
	/*
	Willingness to pay amongst the induced is determined by the cost of the initial grant and the addition costs 
	crowded in. All of this is valued at some fraction of its complete value given that these indiviuals engage
	in a behavioral response to access the grants. 
	*/
	
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
di  `years_impact'/`induced_fraction' // baseline enrollment
di `program_cost'*(1 - `induced_fraction') // Mechanical Cost 
di  `program_cost'*(`induced_fraction') // Behavioral Cost Program
di 	`enroll_cost' // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_long' // Income Counter-Factual


*Locals for Appendix Write-Up 
di `tax_rate_long'
di `total_earn_impact_aftertax'
di `priv_cost_impact'
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
di `increase_taxes'
di `total_earn_impact'
di `WTP' / `program_cost'
di 	`induced_fraction'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

* income globals
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year_pos'
global inc_age_stat_`1' = `proj_start_age_pos'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_year_pos'
global inc_age_benef_`1' = `proj_start_age_pos'