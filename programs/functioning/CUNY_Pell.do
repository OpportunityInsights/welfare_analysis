/********************************************************************************
0. Program : CUNY Pell Grants
*******************************************************************************/

*Marx, Benjamin M., and Lesley J. Turner. "Borrowing trouble? Human capital  
*investment with opt-in costs and implications for the effectiveness of grant aid." 
*American Economic Journal: Applied Economics 10, no. 2 (2018): 163-201.

*Determine the impact of federal Pell Grants on student borrowing and educational
*attainment at CUNY. 

* 

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
local prog_cost_assumption = "$prog_cost_assumption" 
local outcome_type = "$outcome_type" 
local years_bach_deg = $years_bach_deg
local years_enroll = $years_enroll
local years_reenroll = $years_reenroll

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
*Credit Effects
local credit_effect = 0.223 //Marx and Turner 2018, Table 8
local credit_effect_se = 1.233
Note: We use estimates of the total number of academic credits.
Also, these enrollment effects and credit effects are conditional on applications, 
so the calculations below require an assumption that the provision of benefits 
does not impact application rates.


*Enrollment Effects
local enrollment_effect = 0.014  //Marx and Turner 2018, Table 4
local enrollment_effect_se = 0.007
local reenrollment_1y_effect = 0.012 //Marx and Turner 2018, Table 8
local reenrollment_1y_effect_se = 0.020
local reenrollment_3y_effect = -0.002 //Marx and Turner 2018, Table 8
local reenrollment_3y_effect_se = 0.023
Note: We assume these estimates represent percentage point changes in enrollment, not the 
probability of enrollment conditional on previous enrollment. 


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
/* 3. Exact Inputs and Assumptions from Paper */
*****************************************************

local efc_eligible = 2254 //Marx and Turner 2018, Table 1

*Control Mean Outcomes 
local credits_ineligible = 44.7 //Marx and Turner 2018, Table 8
local enroll_ineligible = 0.629 //Marx and Turner 2018, Table 4
local reenroll_1y_ineligible = 0.79 //Marx and Turner 2018, Table 8
local reenroll_3y_ineligible = 0.67 //Marx and Turner 2018, Table 8

local usd_year = 2012 // Marx and Turner 2018, Table 8
local parent_income = 42522 // Marx and Turner 2018, Table 1

local credits_per_term = 12
*This is an assumption, consistent with Pell credit assumption used in Castleman 
*and Long 2016
 
*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age = 34
local project_year = 2009
	
*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2016 // sample enter college in 2007 - 2011
	
*********************************
/* 4. Intermediate Calculations */
*********************************

*Estimate Earnings Effect Using Credits Earned	
if "`outcome_type'" == "credits earned" {
	*Convert credits impact into equivalent years of schooling 
	local years_impact = `credit_effect'/(`credits_per_term'*2)

	*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
	
	local induced_fraction = (`credit_effect'/(`credits_ineligible' + `credit_effect'))
	/*
	Note: We assume that the number additional credits taken as fraction of the total number
	of credits amongst the treated represents the fraction of individuals who recieved the aid and 
	consequently changed their behavior in response. This is used to determine the willingness to pay 
	in Section 5. 
	*/
}

*Estimate Earnings Effect Using Enrollment and Re-Enrollment
if "`outcome_type'" == "enrollment and reenrollment" {
	
	local years_impact = `enrollment_effect'*`years_enroll' + ///
			`reenrollment_1y_effect'*`years_reenroll' + ///
			`reenrollment_3y_effect'*`years_reenroll'
    /*
	NOTE: This calculation assumes that the enrollment effect and the re-enrollment effects occur for 
	different populations. That is, some number of students are induced to enroll due to Pell Aid, and
	a non-overlapping set of students are induced not to drop out. This distinction is relevant because
	in some cases we assume new enrollees stay in school for 2 years, and so we could not calculate 
	an effect on 2nd year enrollment for that sub-population
	*/
	
	*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
	int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)

	local induced_fraction = (`enrollment_effect'/(`enroll_ineligible'+`enrollment_effect'))
}

*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	local impact_age_neg = 21
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_income_year(2012) percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, this would give an artificially high MTR 
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year'+`impact_age_neg'-`proj_start_age'') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`impact_age_neg') // age of income measurement
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
		forecast_income(yes) /// forecast long-run earnings to get a realistic lifetime MTR
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos'') /// year of income measurement
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
*Discounting for cost calculations:
foreach type in enroll reenroll_1yr  reenroll_3yr {
	if "`type'" == "enroll" {
		local end = ceil(`years_enroll')
		local partial_year = `years_enroll' - floor(`years_enroll')

	}
	else {
		local end = ceil(`years_reenroll')
		local partial_year = `years_reenroll' - floor(`years_reenroll')		

	}
	

	local years_`type'_disc = 0
	forval i=1/`end' {
		local years_`type'_disc = `years_`type'_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	if `partial_year' != 0 {
		local years_`type'_disc = `years_`type'_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}
	
	if "`type'" == "reenroll_3yr" { 
		local years_`type'_disc = `years_`type'_disc' * (1)/((1+`discount_rate')^(2))
	}
}


if "`outcome_type'" == "credits earned" {
*For all cost-of-enrollment effects based on credits, we conservatively assume 
*that they occur at the beginning of the program:
	local years_impact_disc = `years_impact'
}
if "`outcome_type'" == "enrollment and reenrollment" {
		local years_impact_disc = `enrollment_effect'*`years_enroll_disc' + ///
			`reenrollment_1y_effect'*`years_reenroll_1yr_disc' + ///
			`reenrollment_3y_effect'*`years_reenroll_3yr_disc'
}
	
local program_cost_unscaled = 1000 
local program_cost = 1000*(1-`induced_fraction')
di (1-`induced_fraction')



deflate_to `usd_year', from(`project_year')
local deflator = r(deflator)

*Calculate Cost of Additional enrollment
if "${got_CUNY_Pell_costs}"!="yes" {
	cost_of_college, year(`project_year') state("NY") name("cuny city college")
	global cost_of_college_CUNY_Pell = r(cost_of_college)*`deflator'
	
	global got_CUNY_Pell_costs yes
	}
	
	local cost_of_college = $cost_of_college_CUNY_Pell
	
local priv_cost_impact = `years_impact_disc' * `efc_eligible' // Assume private costs are determined by the effective family contribution
/* Note: We assume that additional schooling due to increased credits has costs 
that scale as a fraction of yearly educational expenditures. */

if "`outcome_type'" == "credits earned" {
	local enroll_cost = `years_impact_disc'*(`cost_of_college') - `priv_cost_impact' // Yearly Costs of those induced to enroll, minus the effective family contribution
}
if "`outcome_type'" == "enrollment and reenrollment" {
	local enroll_cost = `years_impact_disc'*(`cost_of_college') - `priv_cost_impact' - `program_cost_unscaled'*`induced_fraction'
}
/*
Note: This calculation is made to avoid double counting costs. The cost of providing 
the additional aid to new enrollees is implicitly included in the total government 
expenditures on their education. This adjustment is not made for those receiving 
additional credits or those who re-enroll because that increase in schooling may 
have occured in the year after the initial Pell Aid was granted. We avoid the 
double-count correction in those cases in order to be conservative about costs. 
*/

local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'

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

****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'


*Locals for Appendix Write-Up 
di `tax_rate_longrun'
di `total_earn_impact_aftertax'
di `priv_cost_impact'
di `WTP'
di `program_cost'
di `enroll_cost'
di `increase_taxes'
di `total_cost'
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
global inc_year_stat_`1' = `=`project_year_pos'+(`impact_age_pos'-`proj_start_age_pos')'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=`project_year_pos'+(`impact_age_pos'-`proj_start_age_pos')'
global inc_age_benef_`1' = `impact_age_pos'
