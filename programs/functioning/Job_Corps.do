***************************
/* 0. Program: Job Corps */
***************************
/*

McConnell, Sheena and Steven Glazerman. 2001. "National Job Corps Study: The
Benefits and Costs of Job Corps." Mathematica Policy Research.

Schochet, Peter Z., John Burghardt, and Sheena McConnell. 2006. "National Job 
Corps Study and Longer-Term Follow-Up Study: Impact and Benefit-Cost Findings
Using Survey and Summary Earnings Records Data." Mathematica Policy Research.

Schochet, Peter Z., John Burghardt, and Sheena McConnell. 2008. "Does Job Corps 
Work? Impact Findings from the National Job Corps Study." American Economic
Review 98 (5): 1864-1886.

Schochet, Peter Z. 2018. "National Job Corps Study: 20-Year Follow-Up Study Using 
Tax Data." Mathematica Policy Research.

* Provide career training and for at risk individuals aged 16-24.

*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate

local tax_rate_assumption = "$tax_rate_assumption" //takes values "continuous", "paper internal"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate = $tax_rate_cont
}
local proj_type = "$proj_type" //takes values "observed", "growth forecast"
local proj_length = "$proj_length" //"observed" or "age65"
local wtp_valuation = "$wtp_valuation" //takes on value of "post tax" or "cost"
local crime_benefits = "$crime_benefits" // yes = include crime externalities in WTP
local short_transfer = "$short_transfer" // yes = include crime externalities in WTP
local correlation = $correlation


if "$wtp_valuation" == "reduction private spending" {
	di in red "Job Corps program not configured for WTP valued as the reduction in private spending"
	exit
}



*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
*a. EARNINGS IMPACTS:
	*SSA/IRS data - Schochet (2018), Table A.2 (estimated impact per participant):
	*NOTE: All values are in 2015 dollars.
	local year0_earnings = -537
	local year0_earnings_se = 86
	local year1_earnings = -355
	local year1_earnings_se = 127
	local year2_earnings = 348
	local year2_earnings_se = 170
	local year3_earnings = 441
	local year3_earnings_se = 206
	local year4_earnings = 85
	local year4_earnings_se = 235
	local year5_earnings = -21
	local year5_earnings_se = 265
	local year6_earnings = 185
	local year6_earnings_se = 349
	local year7_earnings = 234
	local year7_earnings_se = 359
	local year8_earnings = 109
	local year8_earnings_se = 374
	local year9_earnings = 120
	local year9_earnings_se = 392
	local year10_earnings = -32
	local year10_earnings_se = 415
	local year11_earnings = -70
	local year11_earnings_se = 430
	local year12_earnings = -184
	local year12_earnings_se = 449
	local year13_earnings = -124
	local year13_earnings_se = 453
	local year14_earnings = -275
	local year14_earnings_se = 447
	local year15_earnings = 4
	local year15_earnings_se = 458
	local year16_earnings = -168
	local year16_earnings_se = 467
	local year17_earnings = -275
	local year17_earnings_se = 478
	local year18_earnings = 81
	local year18_earnings_se = 490
	local year19_earnings = 412
	local year19_earnings_se = 516
	local year20_earnings = 383
	local year20_earnings_se = 538

	
	*Tax liability 
	local year6_tax = 1
	local year6_tax_se = 52
	
	local year7_tax = -8
	local year7_tax_se = 47
	
	local year8_tax = -43
	local year8_tax_se = 47
	
	local year9_tax = -1
	local year9_tax_se = 50
	
	local year10_tax = 43
	local year10_tax_se = 50
	
	local year11_tax = -25
	local year11_tax_se = 54
	
	local year12_tax = -32
	local year12_tax_se = 56
	
	local year13_tax = 74
	local year13_tax_se = 58
	
	local year14_tax = 6
	local year14_tax_se = 57
	
	local year15_tax = 15
	local year15_tax_se = 65
	
	local year16_tax = -13
	local year16_tax_se = 67
	
	local year17_tax = -10
	local year17_tax_se = 72
	
	local year18_tax = 50
	local year18_tax_se = 77
	
	local year19_tax = 20
	local year19_tax_se = 83
	
	local year20_tax = 71
	local year20_tax_se = 85


*b. OTHER IMPACTS - Schochet et al. (2006), Table B.1:
/*NOTE: Schochet et al. (2006)'s cost-benefit analysis does not include standard
errors. For during-program impacts, we assume that t-stats are the same as the 
year-zero earnings impact from the tax data. For crime-related impacts, we assume
that t-stats are the same as the effect on arrest rates given in Schochet et al. 
(2008)*/

	/*Increased cost of childcare for participants. Note that years 1-4 plus projections 
	are aggregated in this figure, and projections assume 80 percent decay in childcare costs*/ 
	local increase_childcare_personal = 47 + 77 + 14

	/*Increase cost of childcare for gov (technically "rest of society"), note that years 1-4 plus projections 
	are aggregated in this figure, and projections assume 80 percent decay in childcare costs*/ 
	// 
	local increase_childcare_gov = 4 + 19 + 4

	/*From footnote 19: Impacts on crime and the use of other programs and services
	 declined during the 48-month observation period covered by the survey; therefore, 
	 we did not include the possible future benefits of these impacts after the  
	 48-month follow-up period*/

	/*Savings to gov from reduced use of high school and other education/training programs*/
	local reduc_educ = 1189 + 874

	/*Savings to gov from reduced use of public assistance and substance abuse treatment programs*/
	local reduc_pub_assis_admin = 122

	/*Losses to participants from reduced use of public assistance and substance abuse treatment programs*/
	local reduc_pub_assis_personal = 780

	/*Value of the output or services that trainees produce as part of vocational training projects.*/
	local output_prod = 220

	/*Reduction in costs to participants associated with reduced crime against participants*/ 
	local reduc_crime_against_train = 643 
	 
	/*For impacts on crimes committed by participants, Schochet et al. (2006) report
	total costs ($1,240). However, McConnell and Glazerman (2001), Table V.5 breaks
	this total out by admin/victim costs*/
	 
	/*Reduced admin costs associated with crimes comitted by the trainee*/
	local reduc_crime_admin = 324
	
	
	*Estimate standard errors on during-program impacts by using same t-stat as from
	*the year zero earnings impact:
	local year0_earn_t = abs(`year0_earnings'/`year0_earnings_se')
	foreach impact in 	increase_childcare_personal ///
						increase_childcare_gov		///
						reduc_educ					///
						reduc_pub_assis_admin		///
						reduc_pub_assis_personal {
		local `impact'_se = ``impact''/`year0_earn_t'
	di ``impact'_se'
	}
	pause

	*Estimate standard errors on crime-related impacts by using same t-stat as from
	*impact on arrest rates from Schochet et al. (2008):
	local arrest_point_est = -5.2 // Schochet et al. (2008), Table 5
	local arrest_se = 1.2 // Schochet et al. (2008), Table A2
	local arrest_t_stat = abs(`arrest_point_est'/`arrest_se')
	local year0_earn_t = abs(`year0_earnings'/`year0_earnings_se')
	foreach impact in 	reduc_crime_against_train	///
						reduc_crime_admin {
		local `impact'_se = ``impact''/`arrest_t_stat'
	}
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
/* 3. Exact Inputs from Paper  */
*********************************

*Program year:
local job_corps_year = 1995
local usd_year = 1995

*Average participant age - Schochet et al. (2008), Table 1:
local job_corps_age = (16.5 * 0.41) + (18.5 * 0.32) + (22 * 0.27)
local job_corps_age_int = round(`job_corps_age')
di `job_corps_age_int'

*Control group earnings (program year, 2015$) - Schochet (2018), Table A.2:
local contr_year0_earn = 2966
local contr_year2_earn = 6406

*Control group earnings (final observed year, 2015$) - Schochet (2018), Table A.2:
local contr_year20_earn = 16314

*Total government cost of program administration - Schochet et al. (2006), Table B.1:
local program_cost = 16158

*Funding for student pay, food, and clothing during program - Schochet et al. (2006), Table B.1:
local program_transfers = 2314

*Get income in 2015 dollars:
local income_2015 = `contr_year0_earn'



*********************************
/* 4. Intermediate Calculations */
*********************************
*Adjust all observed earnings and tax values for inflation (from 2015$ to 1995$):
deflate_to 1995, from(2015)
forvalues i = 0/20 {
	local year`i'_earnings_adj = `year`i'_earnings' * r(deflator)
	if (`i' == 0 | `i' == 20 | `i' == 2) local contr_year`i'_earn_adj = `contr_year`i'_earn' * r(deflator)
	if (`i' > 5) local year`i'_tax_adj = `year`i'_tax' * r(deflator)
}

*Discount observed earnings impacts back to the program year:
local earn_impact_obs_short = 0
local earn_impact_obs = 0
local tax_impact_obs = 0


forvalues i = 0/5 {
	local earn_impact_obs_short = `earn_impact_obs_short' + (`year`i'_earnings_adj' * ((1/(1+`discount_rate'))^`i'))

}
 

forvalues i = 6/20 {
	local earn_impact_obs = `earn_impact_obs' + (`year`i'_earnings_adj' * ((1/(1+`discount_rate'))^`i'))
	local tax_impact_obs = `tax_impact_obs' + (`year`i'_tax_adj' * ((1/(1+`discount_rate'))^`i'))
}

local tax_rate_shortrun = 0
local tax_rate_medrun = 0
local tax_rate_longrun = 0

if "`tax_rate_assumption'" ==  "mixed" {
	  get_tax_rate `contr_year2_earn_adj', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, this would give an artificially high MTR 
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`job_corps_year' + 2') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`=`job_corps_age_int' + 2') // age of income measurement
	  local tax_rate_shortrun = r(tax_rate)
	  
	  get_tax_rate `contr_year20_earn_adj', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// don't forecast short-run earnings, this would give an artificially high MTR 
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`job_corps_year' + 20') /// year of income measurement
		earnings_type(individual) /// individual earnings
		program_age(`=`job_corps_age_int' + 20') // age of income measurement
	  local tax_rate_longrun = r(tax_rate)
}

if "`tax_rate_assumption'" == "continuous" {
		local tax_rate_shortrun = `tax_rate'
		local tax_rate_medrun = `tax_rate'
		local tax_rate_longrun = `tax_rate'

}
	

*Earnings projections:
local year20_age = round(`job_corps_age') + 20
local proj_start_age = round(`job_corps_age') + 21

if "`proj_length'" == "age65"{
local proj_end_age = 65
local project_year = `job_corps_year' + 21
// We assume the last five years are representative of the long run impact
local long_run_earn_impact = (	`year16_earnings_adj' + `year17_earnings_adj' + ///
								`year18_earnings_adj' + `year19_earnings_adj' + ///
								`year20_earnings_adj') / 5

}


if "`proj_type'" == "observed"{
	local earn_proj = 0
}

if "`proj_type'" == "growth forecast" {
	est_life_impact `long_run_earn_impact', ///
		impact_age(`year20_age') project_age(`proj_start_age') end_project_age(`proj_end_age') ///
		project_year(`project_year') usd_year(`job_corps_year') ///
		income_info(`contr_year20_earn_adj') income_info_type(counterfactual_income) /// from control group earnings in year 20
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///	
		max_age_obs(`year20_age')
	
	local earn_proj = ((1/(1+`discount_rate'))^21) * r(tot_earn_impact_d)	
}




**************************
/* 5. Cost Calculations */
**************************

local FE_shortrun = `earn_impact_obs_short'*`tax_rate_shortrun'
local FE_medrun = `tax_impact_obs'
local FE_longrun = `earn_proj'*`tax_rate_longrun'

if "`tax_rate_assumption'" == "continuous" {
local FE_medrun = `earn_impact_obs'*`tax_rate_medrun'
}

local FE = `FE_shortrun' + `FE_medrun' + `FE_longrun' + `output_prod'

local afdc_supp  = `reduc_pub_assis_personal'

di `FE'
if "`short_transfer'" == "yes"{
local FE = `FE' + `afdc_supp' + `reduc_educ' + `reduc_pub_assis_admin' - `increase_childcare_gov'
}

di `FE'
		
if "`crime_benefits'" == "yes" {
	local FE = `FE' + `reduc_crime_admin'
}

local total_cost = `program_cost' - `FE' 




*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax"{

	local total_earn_aftertax = (`earn_impact_obs_short' - `FE_shortrun') + ///
		(`earn_impact_obs' - `FE_medrun') + ///
		(`earn_proj' - `FE_longrun') + `program_transfers' 
	
	if "`crime_benefits'" == "yes" {
		local total_earn_aftertax = `total_earn_aftertax' + `reduc_crime_against_train'
	}

	di `total_earn_aftertax'
	if "`short_transfer'" == "yes" {
		local total_earn_aftertax = `total_earn_aftertax' - `afdc_supp' + `increase_childcare_gov'
	}

	di `total_earn_aftertax'
	local WTP = `total_earn_aftertax'
}

if "`wtp_valuation'" == "cost"{
	local WTP = `program_cost' - `output_prod'
}


if "`wtp_valuation'" == "lower bound"{
	// no clear lower bound on valuation, choose valuation at 1% of program cost
	local WTP = 0.01*`program_cost'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

di `WTP'
di `earn_impact_obs_short'
di `earn_impact_obs'
di `earn_proj'

di `FE_shortrun'
di  `FE_medrun' 
di `FE_longrun'

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
global age_stat_`1' = `job_corps_age'
global age_benef_`1' = `job_corps_age'

* income globals
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `job_corps_year'
global inc_age_stat_`1' = `job_corps_age'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `job_corps_year'
global inc_age_benef_`1' = `job_corps_age'




	*per participant cost
	di `program_cost'
	*mvpf
	di `MVPF'

