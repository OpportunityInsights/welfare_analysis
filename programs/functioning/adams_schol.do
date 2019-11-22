/*******************************************************************************
0. Program :  Massachusetts Adams Scholarship
*******************************************************************************/

/*
Goodman, J. (2008). 
"Who merits financial aid?: Massachusetts' Adams scholarship."
Journal of public Economics, 92(10-11), 2121-2131.

Cohodes, S. R., & Goodman, J. S. (2014). 
"Merit aid, college quality, and college completion: Massachusetts' Adams 
scholarship as an in-kind subsidy."
American Economic Journal: Applied Economics, 6(4), 251-85.

Adams scholarship grants full coverage of tuition at public colleges in MA to 
students above a given academic performance threshold.
*/


********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" 
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type" 
local proj_age = $proj_age
local correlation = $correlation
local wtp_valuation = "$wtp_valuation" 
local val_given_marginal = $val_given_marginal 
local p_priv_costs_to_govt = ${p_priv_costs_to_govt} 
local tax_rate_assumption = "$tax_rate_assumption" 
local payroll_assumption = "$payroll_assumption" 
local years_enroll_cc = ${years_enroll_cc}
local years_graduate_cc = ${years_graduate_cc}
local years_enroll_4yr = ${years_enroll_4yr}
local years_bach_4yr = ${years_bach_4yr}

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
*All from Cohodes & Goodman (2014) table 4:
local enroll_4yr = 0 
local enroll_4yr_se = .007
local enroll_2yr = .007
local enroll_2yr_se = .005
local enroll_adams_4yr = .063
local enroll_adams_4yr_se = .01
local enroll_non_adams_4yr = -.062
local enroll_non_adams_4yr_se = .011
local graduate_4yr = -.025
local graduate_4yr_se = .009
local graduate_2yr = 0 
local graduate_2yr_se = .004
local graduate_adams_4yr = .029
local graduate_adams_4yr_se = .008
local graduate_non_adams_4yr = -.053
local graduate_non_adams_4yr_se = .01

*/

*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************

local year_reform = 2005 // Class of 2005 was first year of Adams scholarships
local usd_year = 2004 //Cohodes & Goodman (2014), Notes of Table 2

*Costs from Cohodes & Goodman (2014) Table 2:
local cost_u_mass = 14606
local tuition_u_mass = 1438
local cost_state = 11224
local tuition_state = 850
local cost_non_adams = 28867
local tuition_non_adams = 19588
local tuition_fees_umass = 1438 + 6164
local grant_umass = 6649
local tuition_fees_state = 850 + 3741
local grant_state = 5711
local tuition_fees_non_adams = 19588 + 666
local grant_non_adams = 14142

*Community College Costs
local adams_cc_tuition = 831 // Cohodes and Goodman, Footnote 17
	
*Fraction induced in various college types
local frac_enroll_umass = 0.04/0.069 // Cohodes & Goodman (2014) Table A.2
local frac_enroll_state = 0.029/0.069


*Combine u-mass and other state:
local cost_adams = (`frac_enroll_umass'*`cost_u_mass' + `frac_enroll_state'*`cost_state')
local tuition_adams = (`frac_enroll_umass'*`tuition_u_mass' + `frac_enroll_state'*`tuition_state')
local net_tuition_fees_adams = ((`tuition_fees_umass' - `grant_umass')*`frac_enroll_umass') + ((`tuition_fees_state' - `grant_state')*`frac_enroll_state') 
local net_tuition_fees_umass = (`tuition_fees_umass' - `grant_umass')
local net_tuition_fees_non_adams = `tuition_fees_non_adams' - `grant_non_adams'


*Get proportion in each category from Cohodes & Goodman table 4:
*These values correspond to students just below the threshold.
local p_adams_enroll = 0.292
local p_adams_grad = 0.184
local p_non_adams_enroll = 0.547
local p_2yr = 0.073
local p_2yr_grad = 0.031
local p_2yr_pub = 0.031 	// Goodman (2008) table 3 - 2004 numbers for would-be scholarship winners, not available in Cohodes & Goodman

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local impact_age_neg = 21
local project_year = 2005 // policy change is for 2005 winners
	
*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = `project_year' + `proj_start_age_pos'-`proj_start_age'
	
*********************************
/* 4. Intermediate Calculations */
*********************************

*CC impact
local years_effect_2yr = `enroll_2yr'*`years_enroll_cc' + ///
						`graduate_2yr'*`years_graduate_cc'

*Four year impact
local years_effect_4yr = `enroll_4yr'*`years_enroll_4yr' + ///
						`graduate_4yr'*`years_bach_4yr'

local years_effect_tot = `years_effect_2yr' + `years_effect_4yr'


*Calculate Initial Earnings Decline in Years 1-7 and Subsequent Earnings Gain
if "$cc_vs_4yr_effect"=="same" {
	int_outcome, outcome_type(attainment) impact_magnitude(`years_effect_tot') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
}
if "$cc_vs_4yr_effect"=="different" {
	int_outcome, outcome_type(attainment) impact_magnitude(`years_effect_4yr') usd_year(`usd_year')
	local pct_earn_impact_neg = r(prog_earn_effect_neg)
	local pct_earn_impact_pos = r(prog_earn_effect_pos)
	
	int_outcome, outcome_type(ccattain) impact_magnitude(`years_effect_2yr') usd_year(`usd_year')
	local pct_earn_impact_neg = `pct_earn_impact_neg' + r(prog_earn_effect_neg)
	local pct_earn_impact_pos = `pct_earn_impact_pos' + r(prog_earn_effect_pos)
}

*People are induced both to switch to adams 4 years or to enroll in 2 year programs.
local pct_induced = (`enroll_2yr' + `enroll_adams_4yr') / (`p_adams_enroll'+`enroll_adams_4yr' + `p_2yr' + `enroll_2yr')
*Thus think of completion as a downstream result of the initial enrollment choice,
*i.e. the scholarship per se does not affect completion, it's the quality of college,
*affected by enrollment changes, that is important, as Cohodes & Goodman argue

*Now forecast % earnings changes across lifecycle
if "`proj_type'" == "growth forecast" {
	
	
	*Calculate Earnings Decline in Years 1-7 After Enrollment
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) ///
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
			program_age(`impact_age_neg') // age of income measurement
		local tax_rate_shortrun = r(tax_rate)
	}
		
	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'
		
	*Calculate Earnings Gain from Year 8 After Enrollment onward
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) ///
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
		program_age(`impact_age_pos') // age of income measurement
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

*Get tuition and total costs if globals not already in memory:
if "${got_adams_costs}"!="yes" {
	deflate_to `usd_year', from(`year_reform')
	local deflator = r(deflator)
	cost_of_college, year(`year_reform') state(MA) type_of_uni(community)
	global adams_cc_cost_of_college = r(cost_of_college)*`deflator'
	global adams_cc_net_tuition = r(tuition)*`deflator'
	
	cost_of_college, year(`year_reform') state(MA) type_of_uni(masters)
	global adams_mast_cost_of_college = r(cost_of_college)*`deflator'
	global adams_mast_tuition = r(tuition)*`deflator'
	global fte_adams_mast = r(fte_count)
	di ${fte_adams_mast}
	di ${adams_mast_cost_of_college}
	di `deflator'
	
	cost_of_college, year(`year_reform') state(MA) type_of_uni(bachelors)
	global adams_bach_cost_of_college = r(cost_of_college)*`deflator'
	global adams_bach_tuition = r(tuition)*`deflator'
	global fte_adams_bach = r(fte_count)
	di `fte_adams_mast'
	di `adams_bach_cost_of_college'
	
	/* This cost_of_college call includes the entire UMass system from the Delta Cost project.
	   One of the "child" institutions is the central office (166665 IPEDS unitid). We include
	   this as the education-related expenditures of the central office are related to the 
	   enrolment in the rest of the system. For reference, the education-related expenditures
	   of the central office make up around 5% of the total education-related expenditures of
	   the system 
	*/
	cost_of_college, state(MA) year(`year_reform') name("university of massachusetts-boston")
	global adams_umass_cost_of_college = r(cost_of_college)*`deflator'
	global adams_umass_tuition = r(tuition)*`deflator'
	
	global adams_bm_cost_of_college = ((${adams_mast_cost_of_college}*${fte_adams_mast}) + (${adams_bach_cost_of_college}*${fte_adams_bach}))/(${fte_adams_bach} + ${fte_adams_mast})
	global adams_cost_of_college = ((${adams_umass_cost_of_college}*`frac_enroll_umass')) + ((${adams_bm_cost_of_college}*`frac_enroll_state'))

	global got_adams_costs yes
}
di ${adams_bm_cost_of_college}
di ${adams_umass_cost_of_college}
di `frac_enroll_umass'
di `frac_enroll_state'
di ${adams_cost_of_college}
	
di ${adams_bach_tuition} // cost_of_college
di ${adams_bach_cost_of_college} // cost_of_college
di ${adams_mast_tuition} // cost_of_college
di ${adams_mast_cost_of_college} // cost_of_college
di `tuition_fees_state' // Cohodes & Goodman
di `cost_state' // Cohodes & Goodman

di ${adams_umass_tuition} // cost_of_college
di ${adams_umass_cost_of_college} // cost_of_college
di `tuition_fees_umass' // Cohodes & Goodman
di `cost_u_mass' // Cohodes & Goodman

di `tuition_fees_umass' - `grant_umass'

di `cost_adams'
di `net_tuition_fees_adams'
di `cost_non_adams'
di `net_tuition_fees_non_adams'
di `cost_u_mass'
di `net_tuition_fees_umass'

*First, compute a discounted version of `year_effect' above that captures the timing 
*of various costs/savings to the government from behavioral changes based on 
*assumptions about years of schooling:
*a) 2-year:
	*Enrollees:
	local disc_2yr_enroll = 0
	local end = ceil(`years_enroll_cc')
	forval i=1/`end' {
		local disc_2yr_enroll = `disc_2yr_enroll' + (`enroll_2yr')/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_cc' - floor(`years_enroll_cc')
	if `partial_year' != 0 {
		local disc_2yr_enroll = `disc_2yr_enroll' - (1-`partial_year')*(`enroll_2yr')/((1+`discount_rate')^(`end'-1))
	}

	*Graduates:
	local disc_2yr_grad = 0
	local start =  floor(2-`years_graduate_cc') + 1
	forval i =`start'/2 {
		local disc_2yr_grad = `disc_2yr_grad' + (`graduate_2yr')/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_graduate_cc' - floor(`years_graduate_cc')
	if `partial_year' != 0 {
		local disc_2yr_grad =  `disc_2yr_grad' - (1-`partial_year')*(`graduate_2yr')/((1+`discount_rate')^(`start'-1))
	}
	
	*Total:
	local years_effect_2yr_disc = `disc_2yr_enroll' + `disc_2yr_grad'
	
*b) 4-year (overall, Adams, and non-Adams):
foreach type in 4yr adams_4yr non_adams_4yr {
	*Enrollees:
	local disc_`type'_enroll = 0
	local end = ceil(`years_enroll_4yr')
	forval i=1/`end' {
		local disc_`type'_enroll = `disc_`type'_enroll' + (`enroll_`type'')/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_4yr' - floor(`years_enroll_4yr')
	if `partial_year' != 0 {
		local disc_`type'_enroll = `disc_`type'_enroll' - (1-`partial_year')*(`enroll_`type'')/((1+`discount_rate')^(`end'-1))
	}

	*Graduates:
	local disc_`type'_grad = 0
	local start =  floor(4-`years_bach_4yr') + 1
	forval i =`start'/4 {
		local disc_`type'_grad = `disc_`type'_grad' + (`graduate_`type'')/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_bach_4yr' - floor(`years_bach_4yr')
	if `partial_year' != 0 {
		local disc_`type'_grad = `disc_`type'_grad' - (1-`partial_year')*(`graduate_`type'')/((1+`discount_rate')^(`start'-1))
	}
	
	*Total:
	local years_effect_`type'_disc = `disc_`type'_enroll' + `disc_`type'_grad'
}


*Get direct cost of scholarship (it pays tuition in full):
*a) CC cost: 2 years for uninduced, discounted years effect for induced
	/*
	Note: For the uninduced population, we assume here that all who graduate receive 
	two years of the Adams Scholarship. 
	We assume that those who enroll but do not graduate recieve one year of the scholarship. 
	We also assume here all eligible 2-year public school attendees receive the scholarship. 
	*/	
	/*Fraction of 2-year students starting/graduating*/
	local fraction_grad_2y = `p_2yr_grad'/`p_2yr'
	local fraction_start_2y = ((`p_2yr' - `p_2yr_grad')/`p_2yr')
	/*Cost calc*/
	local cost_uninduced_cc = 0
	forval i = 1/2 {
		if `i' == 1 {
			local cost_uninduced_cc = `cost_uninduced_cc' + ///
				(`adams_cc_tuition'*`p_2yr_pub')/((1+`discount_rate')^(`i'-1))
		}
		if `i' == 2 {
			local cost_uninduced_cc = `cost_uninduced_cc' + ///
				(`adams_cc_tuition'*`p_2yr_pub'*`fraction_grad_2y')/((1+`discount_rate')^(`i'-1))

		}
	}
	
	*Add induced cost
	local cost_cc = `cost_uninduced_cc' + `years_effect_2yr_disc'*`adams_cc_tuition'

*b) 4-year cost:  4 years for uninduced, discounted years effect for induced
	/*
	Note: We assume here that all who graduate receive four years of the Adams Scholarship. 
	We assume that those who enroll but do not graduate recieve two years of the scholarship.
	*/
	local fraction_grad_4y = (`p_adams_grad'/`p_adams_enroll')
	local fraction_start_4y = ((`p_adams_enroll'-`p_adams_grad')/`p_adams_enroll')
	local cost_uninduced_4yr = 0
	forval i = 1/4 {
		local cost_uninduced_4yr = `cost_uninduced_4yr' + ///
			`tuition_adams'*(`p_adams_enroll'*`fraction_grad_4y')/((1+`discount_rate')^(`i'-1))
	}
	forval i = 1/2 {
		local cost_uninduced_4yr = `cost_uninduced_4yr' + ///
			`tuition_adams'*(`p_adams_enroll'*`fraction_start_4y')/((1+`discount_rate')^(`i'-1))
	}

	*Add induced cost
	local cost_4yr = `cost_uninduced_4yr' + `years_effect_adams_4yr_disc' * `tuition_adams'


*costs to govt of additional time spent at 4 year colleges:
local enroll_cost_adams_4yr = `years_effect_adams_4yr_disc'*(${adams_cost_of_college} -`net_tuition_fees_adams' - `tuition_adams')* `p_priv_costs_to_govt'

di `enroll_cost_adams_4yr'
di `years_effect_adams_4yr_disc'
di (${adams_cost_of_college}-`net_tuition_fees_adams')
di `net_tuition_fees_adams'

*Assume non-Adams colleges cost the same to the govt as u-mass
local enroll_cost_non_adams_4yr = (`years_effect_non_adams_4yr_disc'*(${adams_umass_cost_of_college}-`net_tuition_fees_non_adams')) * `p_priv_costs_to_govt' 

di `enroll_cost_non_adams_4yr'
di `years_effect_non_adams_4yr_disc'
di (${adams_umass_cost_of_college}-`net_tuition_fees_non_adams')
di `net_tuition_fees_non_adams'

*costs to govt of additional time spent at 2 year colleges:
local enroll_cost_2yr = `years_effect_2yr_disc'* (${adams_cc_cost_of_college}-${adams_cc_net_tuition}) * `p_priv_costs_to_govt'

	
*Measure Private Contribution Changes
local private_adams = `years_effect_adams_4yr_disc'*(`net_tuition_fees_adams' - `tuition_adams')
di `years_effect_adams_4yr_disc'
di `net_tuition_fees_adams'
di (`net_tuition_fees_adams' - (`tuition_u_mass'*`frac_enroll_umass'))
/*
Note: This is private costs of attending an adams school determined by the net tuition and fees minus
the cost of the adams scholarship. In cases where the value is negative, this is because grant
aid subsidizing living expenses or other costs outside tuition and fees. 
*/
local private_non_adams = `years_effect_non_adams_4yr_disc'*`net_tuition_fees_non_adams'

/*
Note: We use the net cost of community college from the college calculator 
because we do not have an estimate of average grant aid for two year
colleges from the paper.
*/
local private_2y = `years_effect_2yr_disc'*(${adams_cc_net_tuition} - `adams_cc_tuition')

local private_cont = -`private_non_adams' - `private_adams' - `private_2y'
di `private_adams'
di `private_non_adams'
di `private_cont'
di `private_2y'

*Aggregate costs
local program_cost_unscaled = `cost_cc' + `cost_4yr' // direct scholarship cost
local program_cost = `cost_uninduced_cc' + `cost_uninduced_4yr'

local enroll_cost = `enroll_cost_adams_4yr'+`enroll_cost_non_adams_4yr' + `enroll_cost_2yr'

local total_cost = `program_cost_unscaled' + `enroll_cost' - `increase_taxes'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced value at post tax earnings impact
	local wtp_induced = `total_earn_impact_aftertax' + `private_cont'
	*Uninduced value at transfer
	local wtp_not_induced = `cost_uninduced_cc' + `cost_uninduced_4yr'

	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `val_given_marginal' * ( ///
		(`years_effect_adams_4yr_disc'*`tuition_adams') + ///
		(`years_effect_2yr_disc'*`adams_cc_tuition'))
		
	*Uninduced value at transfer
	local wtp_not_induced = `cost_uninduced_cc' + `cost_uninduced_4yr'

	local WTP = `wtp_induced' + `wtp_not_induced'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'
di ${adams_cc_tuition}
di ${adams_cc_net_tuition}

*Appendix Values
di `enroll_cost'
di `years_effect_tot'
di `total_earn_impact_aftertax'
di `enroll_cost_adams_4yr'
di `enroll_cost_non_adams_4yr' 
di `enroll_cost_2yr'
di `enroll_cost_adams_4yr'+`enroll_cost_non_adams_4yr' + `enroll_cost_2yr'
di `increase_taxes'

di ${adams_bm_cost_of_college}
di ${adams_umass_cost_of_college}
di ${adams_cost_of_college}
di `frac_enroll_umass'
di `tuition_fees_state' - `grant_state'
di `net_tuition_fees_umass'
di `net_tuition_fees_adams'

*Components for Cost and WTP Decomposition
di `program_cost_unscaled'
di `enroll_cost'
di `increase_taxes'
di `total_cost'

di `private_cont'
di `total_earn_impact_aftertax'
di `wtp_not_induced'
	
****************
/* 8. Outputs */
****************

di `WTP'
di `program_cost'
di `total_cost'
di `MVPF'
di `increase_taxes'
di `total_earn_impact_aftertax'
di `wtp_not_induced'

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
global inc_year_stat_`1' = `year_reform'+`impact_age_pos'-18
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `year_reform'+`impact_age_pos'-18
global inc_age_benef_`1' = `impact_age_pos'
