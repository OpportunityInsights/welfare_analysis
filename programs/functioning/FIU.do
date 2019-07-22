****************************************
/* 0. Program: College GPA Threshold Reduction  */
****************************************

/* Zimmerman, Seth D. "The returns to college admission for academically marginal
 students." Journal of Labor Economics 32, no. 4 (2014): 711-754. */
*https://www.jstor.org/stable/10.1086/676661

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"
local correlation = $correlation
local val_given_marginal = $val_given_marginal 

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption" 
if "`tax_rate_assumption'" == "continuous" local tax_rate = $tax_rate_cont 
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"



********************************************************************************
/* 2. Estimates from Paper 											  */
********************************************************************************
/*
*Estimated  Change in Earnings Years 1-7 after High School
local earning_reduction_1_7 = -12294 //Zimmerman 2014 Table 7b
local earning_reduction_1_7_se = 7380 //Zimmerman 2014 Table 7b
*Estimated  Change in Earnings Years 8-14 after High School
local earnings_8_14_change = 1593 //Zimmerman 2014 Table 5
local earnings_8_14_change_se = 604 //Zimmerman 2014 Table 5

*Increase in State University System Admission 
local admit_sus = 0.234 //Zimmerman 2014 Table 4
local admit_sus_se = 0.021 //Zimmerman 2014 Table 4

*Total Costs over 6 Years
local cost_private_int = 2979 //Zimmerman 2014 Table 7a
local cost_private_int_se = 873 //Zimmerman 2014 Table 7a
local cost_tot_int = 5713 //Zimmerman 2014 Table 7a
local cost_tot_int_se = 3995 //Zimmerman 2014 Table 7a

*Costs from State University School
local cost_tot_sus = 11913 //Zimmerman 2014 Table 7a
local cost_tot_sus_se = 4608 //Zimmerman 2014 Table 7a
local cost_priv_sus = 3327 //Zimmerman 2014 Table 7a
local cost_priv_sus_se = 930 //Zimmerman 2014 Table 7a
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

local usd_year = 2005 // Zimmerman (2014)

local pct_attend_sus = 0.51 // Zimmerman (2014) table 2, labout force sample

*Project length
local quarters_year = 4
local long_length_proj = `proj_age' - 18

*Control Mean Earnings Years 8-14 after High School
*Expected earnings just below the threshold
local earnings_level_8_14_quarterly = 7241 //Zimmerman (2014) p.732
*Earnings 1-7 years after HS. This is a total sample mean (treated+untreated)
local total_earn_1_7 = 94368 // Zimmerman (2014) table 7b

*duration of schooling in years
local school_duration = 4 

*duration of first observation period in years
local short_length = 7

*duration of second observation period in years
local medium_length_start = 8
local medium_length_end = 14

*Age of Projection Start
local proj_start_age = 19 + `medium_length_end' + 1

*Change in State University years enrolled/ Zimmerman(2014) Table 4
local years_change_sus = 0.457

*Change in Community College years enrolled/ Zimmerman(2014) Table 4
local years_change_cc = -0.172



*********************************
/* 4. Intermediate Calculations */
*********************************

*Calculate yearly earnings loss through first 7 years
local earnings_loss_year = `earning_reduction_1_7'/`short_length'


*Get counterfactual yearly incomes
*8-14 is simply as income is reported below threshold
local cfactual_inc_8_14 = `earnings_level_8_14_quarterly'*4
di `cfactual_inc_8_14'
*Income 1-7 is sample mean. Net out LATE earnings effect multiplied by % attending SUS
*to get an estimate of counterfactual income given no SUS attendance.
local cfactual_inc_1_7 = (`total_earn_1_7'/7) - (`pct_attend_sus'*`earnings_loss_year')
di `cfactual_inc_1_7'


*Calculated discounted sum of yearly earnings loss, assuming they are spread equally over those 7 years 
*Information to split out the timing of earnings losses is not available. 
local short_earning = 0
forvalues a = 19/`=19+`short_length'-1'{
	local short_earning = `short_earning' + `earnings_loss_year'*(1/((1+`discount_rate')^(`a'-18)))
}

di `=19+`short_length'-1'

*Calculated discounted sum of yearly earnings gain, assuming they are spread evenly over years 8-14. 
local year_earning_gain = `earnings_8_14_change'*`quarters_year'
di `year_earning_gain'

local medium_earning = 0
forvalues a = `=19+`short_length''/`=19+`medium_length_end''{
	local medium_earning = `medium_earning' + `year_earning_gain'*(1/((1+`discount_rate')^(`a'-18)))
}

di `=19+`medium_length_end''

*Estimate Long-Run Earnings Effect Using Growth Forecast Method 
if "`proj_type'" == "growth forecast" {
	local project_year = round(`=(1996 + 1997 + 1999 + 2000 + 2001 + 2002 + 2004)/7',1) + `medium_length_end' + 2
	/*
	"I have data on seven cohorts of
	students (twelfth-graders in 1996, 1997, 1999, 2000, 2001, 2002, and 2004,
	where years refer to the spring of the academic year)"
	*/
	local impact_age = round(`=19+((`short_length'+`medium_length_end')/2)',1) //halfway through 8-14 period
		
	est_life_impact `year_earning_gain', /// take years 8-14 average gain
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`cfactual_inc_8_14') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		max_age_obs(`=19 + `medium_length_end'')
		
		return list
		
	
	di r(cfactual_fraction)
	local cfactual_fraction = r(cfactual_fraction)
	di r(pct_increase)
	local pct_increase = r(pct_increase)
	
	*Discount earnings impact back to 18
	local long_earning = ((1/(1+`discount_rate'))^(`proj_start_age' -18)) * r(tot_earn_impact_d)
	di `long_earning'

}

di `short_earning'
di `medium_earning'
di `long_earning'



*Get tax rate
if "`tax_rate_assumption'" ==  "cbo" {
	*Get tax rate for short_earning
	get_tax_rate `cfactual_inc_1_7' , /// counterfactual earnings 1-7 yrs post 
			inc_year(`=round(`project_year'-(7/2)-7)') /// Average year of income measurement
			usd_year(`usd_year') ///
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) /// 
			earnings_type(individual) ///
			forecast_income(yes) ///
			program_age(`=`impact_age'-7')

	local tax_rate_short = r(tax_rate)

	*Get tax rate for medium_earning
	get_tax_rate `cfactual_inc_8_14' , /// counterfactual earnings 8-14 yrs post 
		inc_year(`=round(`project_year'-(7/2))') /// Average year of income measurement
		usd_year(`usd_year') ///
		include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
		include_transfers(yes) ///
		earnings_type(individual) ///
		program_age(`impact_age')		forecast_income(no) ///

		
	local tax_rate_medium = r(tax_rate)

	*Get tax rate for long_earning
	get_tax_rate `cfactual_inc_8_14' , /// counterfactual earnings 8-14 yrs post 
		inc_year(`=round(`project_year'-(7/2))') /// Average year of income measurement
		usd_year(`usd_year') ///
		include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
		include_transfers(yes) /// 
		earnings_type(individual) ///
		forecast_income(yes) ///
		program_age(`impact_age')
		
	local tax_rate_long = r(tax_rate)
}

if "`tax_rate_assumption'" ==  "continuous" {
	foreach length in short medium long {
		local tax_rate_`length' = `tax_rate'
	}
}

di `tax_rate_short'
di `tax_rate_medium'
di `tax_rate_long'


di 	`proj_start_age'

*Calculate Total Earnings Effect and Incorporate Taxes
local total_earn_impact = 0
local tax_impact = 0
foreach length in short medium long {
	local total_earn_impact = `total_earn_impact'+``length'_earning'
	local tax_impact = `tax_impact'+(`tax_rate_`length''*``length'_earning')
	
	di `total_earn_impact'
	di `tax_impact'

}


*Calculate costs from internal paper estimates
local tot_priv_cost = `cost_private_int'
local net_pub_cost = `cost_tot_int' - `cost_private_int'
local net_sus_cost = `cost_tot_sus' - `cost_priv_sus'
local tot_sus_cost = `cost_tot_sus'



*Costs are Divided Amongst Four Years and Discounted Appropriately
local portion_priv = `tot_priv_cost'/4
local portion_pub = `net_pub_cost'/4
local portion_prog = `net_sus_cost'/4
local portion_tot_sus = `tot_sus_cost'/4
local portion_priv_sus = `cost_priv_sus'/4

local discount_priv = 0
local discount_pub = 0
local discount_prog = 0
local discount_tot_sus = 0
local discount_priv_sus = 0

forvalues a = 18/21 {
	local discount_priv = `discount_priv' + `portion_priv'*(1/((1+`discount_rate')^(`a'-18)))
	local discount_pub = `discount_pub' + `portion_pub'*(1/((1+`discount_rate')^(`a'-18)))
	local discount_prog = `discount_prog' + `portion_prog'*(1/((1+`discount_rate')^(`a'-18)))
	local discount_tot_sus = `discount_tot_sus' + `portion_tot_sus'*(1/((1+`discount_rate')^(`a'-18)))
	local discount_priv_sus = `discount_priv_sus' + `portion_priv_sus'*(1/((1+`discount_rate')^(`a'-18)))
}

**************************
/* 5. Cost Calculations */
**************************

*Program cost is direct cost to SUS system
local program_cost = `discount_prog'


*Total cost accounts for cost savings at other colleges and impact of taxes
local total_cost = `discount_pub' - `tax_impact'



di `tax_impact'
di `total_cost'
di `discount_priv'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	local WTP_induced = `total_earn_impact' -`tax_impact' - `discount_priv'
	local WTP_non_induced = 0
	local WTP = `WTP_induced' + `WTP_non_induced'
}

if "`wtp_valuation'" == "cost" {
	local WTP_induced = `program_cost' * `val_given_marginal'
	local WTP_non_induced = 0
	local WTP = `WTP_induced' + `WTP_non_induced'
}

if "`wtp_valuation'" == "private_cost" {
	local WTP = `discount_priv'
}

/*
Note: All new enrollees are definitionally marginal in this set-up because
the conceptual experiment is a loosening of the GPA constraint. If you're not 
marginal then you get nothing.
*/

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

/*
Figures for Attainment Graph 
*/
di `years_change_sus' - `years_change_cc' //enrollment gain
di  0 // baseline enrollment
di  0 // Mechanical Cost 
di  0 // Behavioral Cost Program
di 	`discount_prog' // Behavioral Cost Crowd-In
di `WTP_induced' //WTP induced
di `WTP_non_induced' //WTP Non-Induced
di 	`cfactual_inc_8_14' // Income Counter-Factual

*Appendix Values
di `short_earning' + `medium_earning'
di `short_earning' + `medium_earning'+ `long_earning'
di `short_earning'
di `short_earning'*(1-`tax_rate_short')
di `tax_rate_long'
di `discount_priv'
di `WTP'
di `tax_impact'
di `program_cost'
di `total_cost'
di `MVPF'


****************
/* 8. Outputs */
****************

di `MVPF'
di `WTP'
di `program_cost'
di `total_cost'
di `tax_impact'
di `discount_pub'
di `discount_prog'

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global WTP_`1' = `WTP'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_inc_8_14' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `=round(`project_year'-(7/2))'
global inc_age_stat_`1' = `impact_age'

global inc_benef_`1' = `cfactual_inc_8_14' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=round(`project_year'-(7/2))'
global inc_age_benef_`1' = `impact_age'


*********************************
/* 9.	    Cost by age    	   */
*********************************
local short_sum = 0
local medium_sum = 0 
local long_sum = 0
forvalues k = 0/`proj_age'{
	local j = `k' - 1
	
	if `k' < 18 global y_`k'_cost_`1' = 0
		
	*College years
	if `k' == 18 global y_`k'_cost_`1' = `portion_pub'
	
	if inrange(`k',19,21) {
		global y_`k'_cost_`1' = ${y_`j'_cost_`1'} + `portion_pub'*(1/((1+`discount_rate')^(`k'-18))) - ///
			`earnings_loss_year'*(1/((1+`discount_rate')^(`k'-18)))*`tax_rate_short'
		local short_sum = `short_sum'+	`earnings_loss_year'*(1/((1+`discount_rate')^(`k'-18)))*`tax_rate_short'
	}
	
	*Short earnings
	if inrange(`k',22,`=18+`short_length'') {
		global y_`k'_cost_`1' = ${y_`j'_cost_`1'} - ///
			`earnings_loss_year'*(1/((1+`discount_rate')^(`k'-18)))*`tax_rate_short'
		local short_sum = `short_sum'+	`earnings_loss_year'*(1/((1+`discount_rate')^(`k'-18)))*`tax_rate_short'

	}
	
	*Medium earnings
	if inrange(`k',`=18+`short_length'+1',`=`proj_start_age'-1') {
		global y_`k'_cost_`1' = ${y_`j'_cost_`1'} - ///
			`year_earning_gain'*(1/((1+`discount_rate')^(`k'-18)))*`tax_rate_medium'
		local medium_sum = `medium_sum'+`year_earning_gain'*(1/((1+`discount_rate')^(`k'-18)))*`tax_rate_medium'
		
		di `medium_sum'
		

	}

	
	*Projected earnings
	if inrange(`k',`proj_start_age',`proj_age') {
		global y_`k'_cost_`1' = ${y_`=`proj_start_age'-1'_cost_`1'} - ///
			((1/(1+`discount_rate'))^(`proj_start_age'-18))*`tax_rate_long'*${aggt_earn_impact_a`k'} 
	}
	di "Age `k': ${y_`k'_cost_`1'}"
}


*Components for cost:
di "Program cost: `program_cost'"
di "Total FIU cost: `discount_tot_sus'"
di "Student contribution: `discount_priv_sus'"
di "Impact on net public spending: `=`discount_pub'-`program_cost''"
di "Years 1-7 tax impact: `short_sum'"
di "Years 8-14 tax impact: `medium_sum'"
di "Projected tax impact: `=((1/(1+`discount_rate'))^(`proj_start_age'-18))*`tax_rate_long'*${aggt_earn_impact_a65}'"


*Components for WTP:
global fiu_lbwtp = `discount_priv'
global fiu_priv_cost = `discount_priv'
global fiu_short_post_tax = (1-`tax_rate_short')*`short_earning'
global fiu_med_post_tax =  (1-`tax_rate_medium')*`medium_earning'
global fiu_long_post_tax = (1-`tax_rate_long')*`long_earning'
di `short_earning'
di `medium_earning'
di `long_earning'

*Components for cost decomposition
global fiu_prog_cost = `program_cost'
global fiu_total_cost = `discount_tot_sus'
global fiu_student_contribution = `discount_priv_sus'
global fiu_net_pub_spend = `=`discount_pub'-`program_cost''
global fiu_tax_short = `short_sum'
global fiu_tax_med = `medium_sum'
global fiu_tax_proj = `=((1/(1+`discount_rate'))^(`proj_start_age'-18))*`tax_rate_long'*${aggt_earn_impact_a65}'



*Components for ACS forecast:
global fiu_earn_loss_year =  `earnings_loss_year'
global fiu_earn_gain_year =   `year_earning_gain'
global fiu_cfactual_inc =  `cfactual_inc_8_14'



***Outputs for paper (section 3.1)
***Cost
	*initial cost,  university system's educational expenditures on each marginal admit to FIU.
	di `discount_tot_sus'
	*private student contributions
	di `discount_priv_sus'
	*what the gov would have paid to support cc education
	di `=`discount_pub'-`program_cost''
	* upfront government cost per admitted student
	di `discount_tot_sus' - `discount_priv_sus' + `=`discount_pub'-`program_cost''
	*earnings fall in first 7 years after admission
	di `short_earning'
	*tax rate on short term earnings
	di `tax_rate_short'
	*reduction in gov revenue attributed to short term earnings reduction
	di `tax_rate_short'*`short_earning'
	*medium term earnings increase
	di `medium_earning'
	*increase in gov rev due to increase in medium term earnings increase
	di `tax_rate_medium'*`medium_earning'
	*net cost after 13 years
	di (`discount_tot_sus' - `discount_priv_sus' + `=`discount_pub'-`program_cost'') -(`tax_rate_short'*`short_earning') - (`tax_rate_medium'*`medium_earning')
	
	*counterfactual income
	di `cfactual_inc_8_14' 
	*cfactual income percent of mean earnings 
	di `cfactual_fraction'
	*amount more that treated group earns
	di `year_earning_gain'
	*estimated discounted earnings increase through age 65
	di `long_earning'
	*long run fiscal externality
	di `long_earning'*`tax_rate_long'
	*net cost
	di `total_cost'
	
*** WTP
	*Tuition and fee payments
	di `discount_priv'
	*earnings fall in first 7 years after admission
	di `short_earning'*(1-`tax_rate_short')
	*earnings rise in years 8-14
	di `medium_earning'*(1-`tax_rate_medium')
	*long run earnings gain
	di `long_earning'*(1-`tax_rate_long')
	*total willingness to pay 
	di - `discount_priv' + `short_earning'*(1-`tax_rate_short') + `medium_earning'*(1-`tax_rate_medium') + `long_earning'*(1-`tax_rate_long')
	
	
	
	
	
	
	
