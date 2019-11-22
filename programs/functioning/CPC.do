********************************************
/* 0. Program: Chicago Child Parent Center*/
********************************************

/*Reynolds, Arthur J., Judy A. Temple, Dylan L. Robertson, and Emily A. Mann.
"Age 21 cost-benefit analysis of the Title I Chicago child-parent centers."
Educational Evaluation and Policy Analysis 24, no. 4 (2002): 267-303.

Reynolds, A. J., Temple, J. A., Ou, S. R., Arteaga, I. A., & White, B. A. (2011).
"School-based early childhood education and age-28 well-being: Effects by timing,
dosage, and subgroups."
Science, 333(6040), 360-364.

NOTE: Unless noted, all figures are in 1998 USD and discounted to age 3

Also, unless 2011 is explicitly referenced to, Reynolds et al. refers to the 2002 paper.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local wage_growth_rate = $wage_growth_rate
local program_type = "$program_type" // options are "preschool," "school age," and "extended"
local net_transfers = "$net_transfers" // "yes" or "no"
local proj_age = $proj_age //takes on age at end of projection
local proj_type = "$proj_type"
local tax_rate_assumption = "$tax_rate_assumption"
local tax_rate_cont = $tax_rate_cont
local reynolds_adjustment = "$reynolds_adjustment"
local other_benefits = "$other_benefits" // option to include benefits to parents and crime victims as well as children
local exclude_crim_just = "$exclude_crim_just" //option to exclude criminal justice costs
local wtp_valuation = "$wtp_valuation"
local payroll_assumption = "no" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"

******************************
/* 2. Estimates from Paper */
******************************

/*
*Reynolds et al. 2002, Table 4 Differences

if "`program_type'" == "ps"{
	*All of these values are differences between preschool group and comparison group

    /*Grade retention by age 15, percent (i.e. xx% --> .xx)*/
	local grade_retention = -0.154
	local grade_retention_p = runiform(0, 0.001) // "<.001". We have a range for the p-value so we assume a uniform dis. over that range.

	/*Number of years of special education from ages 6 to 19*/
	local special_educ = -0.70
	local special_educ_p = 0.06

	/*Indicated report of abuse/neglect from ages 4 to 17, percent (i.e. xx% --> .xx)*/
	local child_maltreatment = -0.053
	local child_maltreatment_p = runiform(0,0.001) //"<.001"

	/*Number of petitions to juvenile court*/
	local n_petitions_juv_court = -0.33
	local n_petitions_juv_court_p = 0.02

	/*High school completion by age 20, percent (i.e. xx% --> .xx)*/
	local hs_completion = 0.112
	local hs_completion_p = 0.01

}

if "`program_type'" == "sa"{
	*All of these values are differences between school age group and comparison group

	/*Grade retention by age 15, percent (i.e. xx% --> .xx)*/
	local grade_retention = -0.105
	local grade_retention_p = 0.001

	/*Number of years of special education from ages 6 to 19*/
	local special_educ = -0.48
	local special_educ_p = 0.08

	/*Indicated report of abuse/neglect from ages 4 to 17, percent (i.e. xx% --> .xx)*/
	local child_maltreatment = -0.014
	local child_maltreatment_p = 0.35

	/*Number of petitions to juvenile court*/
	local n_petitions_juv_court = -0.02 //
	local n_petitions_juv_court_p = 0.84

	/*High school completion by age 20, percent (i.e. xx% --> .xx)*/
	local hs_completion = 0.004
	local hs_completion_p = 0.91
}

if "`program_type'" == "ext"{
	*All of these values are differences between extended intervention group and nonextended

	/*Grade retention by age 15, percent (i.e. xx% --> .xx)*/
	local grade_retention = -0.104
	local grade_retention_p = 0.001

	/*Number of years of special education from ages 6 to 19*/
	local special_educ = -0.67
	local special_educ_p = 0.080

	/*Indicated report of abuse/neglect from ages 4 to 17, percent (i.e. xx% --> .xx)*/
	local child_maltreatment = -0.033
	local child_maltreatment_p = 0.024

	/*Number of petitions to juvenile court*/
	local n_petitions_juv_court = -0.14
	local n_petitions_juv_court_p = 0.320

	/*High school completion by age 20, percent (i.e. xx% --> .xx)*/
	local hs_completion = 0.047
	local hs_completion_p = 0.193
}
*/


if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`program_type'" == "preschool" local local_suffix = "ps"
if "`program_type'" == "school age" local local_suffix = "sa"
if "`program_type'" == "extended" local local_suffix = "ext"

if "`bootstrap'" == "yes" {
	if ${draw_number} ==1 {

	preserve
		use "${input_data}/causal_estimates/${folder_name}/draws/${name}.dta", clear
		* keep estimates from the right program
		keep draw_number *_`local_suffix'
		ren *_`local_suffix' *
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
		keep if regexm(estimate, "._`local_suffix'$")
		replace estimate = regexr(estimate, "_`local_suffix'$", "")
		levelsof estimate, local(estimates)
		foreach est in `estimates' {
			qui su pe if estimate == "`est'"
			local `est' = r(mean)
		}
		di "`program_type'"
	restore
}

*********************************
/* 3. Assumptions from Paper */
*********************************

local mean_n_juv_arrests = 0.236 //from p. 277

local usd_year 1998 // Reynolds et al. 2002

*Reynolds et al. 2002, Appendix B "Breakdown of Benefits and Costs"
local pv_grade_retent_1yr = 4494
local special_educ_1yr = 5971
local life_earn_hs_v_not = 183183		//PDV in $1998
local life_tax_hs_v_not = 64673 		//NOTE: Paper suggests tax rate is 33.3% but number used here is 35.3%
local life_earn_hs_v_not_alt = 285393	//Undiscounted in $1998
local exp_per_crime_10_18 = 13690
local exp_per_crime_19_44 = 32973
local cost_per_victim_10_18 = 14354
local cost_per_victim_19_44 = 34572
local ch_abuse_negl_per_4_17 = 5623
local ch_abuse_negl_welfare = 8910
local college_pub_exp_2yrs = -3313
local college_priv_exp_2yrs = -1656

*Mean income in control group
deflate_to `usd_year', from(2007) //Reynolds et al. (2011) incomes are in 2007 USD (see supplement page 8=9)
if "`local_suffix'"=="ps" local mean_inc_comp = 10796 * r(deflator) //Reynolds et al. (2011) table 2
if "`local_suffix'"=="sa" local mean_inc_comp = 11278 * r(deflator) //Reynolds et al. (2011) table 2
if "`local_suffix'"=="ext" local mean_inc_comp = 10942 * r(deflator) //Reynolds et al. (2011) table 2

local inc_year = round((2004+2007)/2) //Reynolds et al. (2011) supplementary materials page 9
local kindergarten_year = 1986 //Reynolds et al. (2011) supplementary materials page 4
local year_birth = `kindergarten_year'-5
local inc_age = `inc_year'-`year_birth'

/*1998 present value of time from child care per participant*/
local child_care_per_3_4 = 1657
/*Assumed 540 hours of care (15 hours a week for 1.5 years), at a price of parental
 time of $3.35 per hour in 1986 (local minimum wage). See page 277 for details. */

*Get tax rates:
if "`tax_rate_assumption'" == "paper internal" local tax_rate = 0.353 // Reynolds et al. (2002) p. 298
*NOTE: Paper suggests tax rate is 33.3% but number used is 35.3% when comparing lifetime tax and earnings effects
if "`tax_rate_assumption'" == "continuous" local tax_rate = `tax_rate_cont'
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `mean_inc_comp', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`inc_year') /// year of income measurement
		program_age(`inc_age') ///
		earnings_type(individual) // individual or household
	di r(pfpl)
	local tax_rate = r(tax_rate)
}

if "`program_type'" == "preschool"{
	local mechanical_cost = 6692
	/*Reynolds et al 2002, Table 3; Average weighted cost of program given number
	of years children spent on each program*/

	local child_care_costs = `child_care_per_3_4'

	local fe_adult_justice = 2612
	/*p; No SE for mean # juv arrests (from which this is derived) so using final
	value. Projected based on juvenile arrests, letting it be 80% of the effect
	observed for juvenile arrest, with a 10% rate of desistance per year through
	age 44. See p. 277 for details.*/

	local reduce_crime_loss = `mean_n_juv_arrests'*`cost_per_victim_10_18'
	/*m; Includes costs that violent/property crime victims have saved due to
	reduced juvenile arrests in the sample. See page 277 for details. */

	local reduce_crime_loss_adult = 2739
	/*p; No SE for mean # juv arrests (from which this is derived) so using final
	value. From the text, page 277 -- "Projected savings to victims of adult crime
	were estimated from the present value cost of an adult criminal career ($32,973
	over ages 19–44; Greenwood et al., 1998), based on a target population crime
	rate of 30% and an incidence of arrest that is 80% of juvenile arrest."*/
}

if "`program_type'" == "school age"{
	local mechanical_cost = 2981
	/*Reynolds et al 2002, Table 3; Average weighted cost of program given number
	of years children spent on each program */

	local child_care_costs = 0

	local fe_adult_justice = 0
	//p

	local reduce_crime_loss = -`n_petitions_juv_court'*`exp_per_crime_10_18'
	/*m; Includes costs that violent/property crime victims have saved due to
	reduced juvenile arrests in the sample. See page 277 for details. */

	local reduce_crime_loss_adult = 158
	/*p; No SE for mean # juv arrests (from which this is derived) so using final
	value. From the text, page 277 -- "Projected savings to victims of adult crime
	were estimated from the present value cost of an adult criminal career ($32,973
	over ages 19–44; Greenwood et al., 1998), based on a target population crime
	rate of 30% and an incidence of arrest that is 80% of juvenile arrest."*/
}

if "`program_type'" == "extended"{
	local mechanical_cost = 4057
	/*Reynolds et al 2002, Table 3; Average weighted cost of program given number
	of years children spent on each program  */
	local child_care_costs = `child_care_per_3_4'*.99336

	local fe_adult_justice = 1108
	//p

	local reduce_crime_loss = 2368
	// Formula gives different estimate... `mean_n_juv_arrests'*`cost_per_victim_10_18'
	/*m; Includes costs that violent/property crime victims have saved due to reduced
	juvenile arrests in the sample. See page 277 for details. m*/

	local reduce_crime_loss_adult = 1369
	/*p; No SE for mean # juv arrests (from which this is derived) so using final
	value. From the text, page 277 -- "Projected savings to victims of adult crime
	were estimated from the present value cost of an adult criminal career
	($32,973 over ages 19–44; Greenwood et al., 1998), based on a target population
	crime rate of 30% and an incidence of arrest that is 80% of juvenile arrest." */
}

local fe_juv_justice = -`n_petitions_juv_court'*`exp_per_crime_10_18'
/*m; Based on number of petitions to juvenile court. Includes administrative and
correctional expenditures (national rate of adjudication).
One year of cost savings assumed at age 14 (mean age from court reports).
Correctional costs may include incarceration, probation or community correction.
See pages 276-277 for details */

local reynolds_discount_rate = 0.03 // Reynolds et al. 2002, Pg 294

**********************************
/* 4. Intermediate Calculations */
**********************************

*Set ages
if "`program_type'" == "preschool" local age_benef = (3+5)/2 // Reynolds et al. 2002 pg. 268
if "`program_type'" == "school age" local age_benef = (6+9)/2 // Reynolds et al. 2002 pg. 268
if "`program_type'" == "extended" local age_benef = (3+9)/2 // Reynolds et al. 2002 pg. 268
local age_stat = `age_benef' // in kind transfer to kid

*Earnings projections:
if "`proj_type'" == "paper internal" {
	*Paper internal projection:

	*NOTE: Reynolds uses a present-discounted lifetime earnings figure
	//that uses a 3% discount rate. To allow for the
	//ability to use a different discount rate, we assume that the
	//figure comes from a lifetime earnings path with the same shape as the path
	//used for our earnings projections (in est_life_impact.ado.

	*Earnings estimates for hs v not seem to take earnings between ages 18 and 65 (Reynolds p276)
	local min_age = 18
	local max_age = 65
	local reynolds_disc_year = 3

	*First, load in earnings path data from ACS file, applying wage growth assumption:
	preserve
	use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear
	qui sum age
	local earn_total_undisc = 0
	forval i=`min_age'/`max_age' {
		qui sum wag if age==`i'
		local age_`i'_earn = r(mean)*((1 + `wage_growth_rate')^(`i'-`min_age'))
		local earn_total_undisc = `earn_total_undisc' +  `age_`i'_earn'
	}
	restore

	*Next, compute (a) the fraction of total lifetime undiscounted earnings at each
	*age, and (b) the corresponding scalar multiple for converting the Reynolds
	*discounted lifetime earnings figure to one using a potentially different discount rate:
	local disc_reynolds = 0
	local disc_new = 0
	forval i=`min_age'/`max_age' {
		local age_`i'_frac = `age_`i'_earn'/`earn_total_undisc'
		local disc_reynolds = `disc_reynolds' 	+ `age_`i'_frac' * (1/(1+`reynolds_discount_rate')^(`i'-`reynolds_disc_year'))
		local disc_new 		= `disc_new' 		+ `age_`i'_frac' * (1/(1+`discount_rate')^(`i'-`reynolds_disc_year'))
	}

	*Next, potentially adjust Reynolds lifetime earnings figure due to confusion based on footnote 6 in
	*the paper and Appendix Table B. It is clear that $183,183 (`life_earn_hs_v_not')
	*is a discounted figure that has discounted $285,393 back to age 3 from age 18,
	*but it is unclear whether $285,393 (`life_earn_hs_v_not_alt') has been
	*discounted back to age 18 or not.
	if "`reynolds_adjustment'" == "yes" {
		local reynolds_disc_earn = `life_earn_hs_v_not'
		*This formulation assumes the $285k figure is discounted back to age 18
	}
	if "`reynolds_adjustment'" == "no" {
		local reynolds_disc_earn = `life_earn_hs_v_not_alt'*`disc_reynolds'
		*This formulation assumes the $285k figure is undiscounted
	}

	*Multiply the Reynolds lifetime earnings figure by the scalar to get the present-discounted lifetime
	*earnings value:
	local disc_earn = `reynolds_disc_earn' * (`disc_new'/`disc_reynolds')

	*Determine earnings increase
	local increased_earn = `hs_completion'*`disc_earn'
	/*p; Page 276 for details. Based on differences from high school completion between
	groups. Based on lifetime earnings for Black workers aged 25-29 by educational
	group by Census. Adjusted by the above procedure. */

}

if "`proj_type'" == "growth forecast" {
	*Project observed earnings impact over lifecycle
	local impact_age = `inc_age'

	est_life_impact `annual_inc', /// take years 8-14 average gain
		impact_age(`impact_age') project_age(18) end_project_age(`proj_age') ///
		project_year(`=`inc_year'-`inc_age'+18') usd_year(`usd_year') ///
		income_info(`mean_inc_comp') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		max_age_obs(`inc_age')

	*Discount earnings impact back to age 3 to be consistent with Reynolds et al. (2002) figures
	local increased_earn = ((1/(1+`discount_rate'))^(18-3)) * r(tot_earn_impact_d)
}

*Get implied tax impact:
local fe_tax_earnings = `tax_rate'*`increased_earn'
*Expected discounted impact of HS completion on taxes

*Childhood Effects
local fe_grade_retention = -`grade_retention'*`pv_grade_retent_1yr'
//m; Assumes cost savings from K to 12. See p. 276 for details.

local fe_special_ed = -`special_educ'*`special_educ_1yr'
//m; Assumes cost savings from K to 12. See p. 276 for details.

local fe_child_welfare = -`child_maltreatment'*`ch_abuse_negl_welfare'
/*m; Child welfare and abuse/neglect support include in-home and foster care
services plus admin costs are administering those services. */

local fe_child_abuse = -`child_maltreatment'*`ch_abuse_negl_per_4_17'
/*m; Assumed that these effects occur at age 10 (midpoint of ages 4-17), for one
 year only. Includes victimization costs assocaited with child abuse/neglect.
 See p. 277 for details. */

*Adulthood Effects
local fe_college_tuition = `hs_completion'*`college_pub_exp_2yrs'
/*p; See page 278 for details. Assumed that public pays 2/3 of the cost of tuition.
Tuition costs based on the three most attended colleges in sample. */

local college_tuition_part = `hs_completion'*`college_priv_exp_2yrs'
//p; impact of HS completion on private expenditure on College
di `hs_completion'
di `college_priv_exp_2yrs'
di `college_tuition_part'
di `fe_college_tuition'

if "`exclude_crim_just'" == "no"{
	local FE_total_child = `fe_grade_retention' + `fe_special_ed' + `fe_child_welfare' + ///
		`fe_child_abuse' + `fe_juv_justice'
	local FE_total_adult = `fe_tax_earnings' + `fe_adult_justice' + `fe_college_tuition'
}

if "`exclude_crim_just'" == "yes"{
	local FE_total_child = `fe_grade_retention' + `fe_special_ed' + `fe_child_welfare' ///
		+ `fe_child_abuse'
	local FE_total_adult = `fe_tax_earnings' + `fe_college_tuition'
}

local FE_total = `FE_total_child' + `FE_total_adult'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `mechanical_cost'
local total_cost_child = `program_cost' - `FE_total_child'
local total_cost_adult = `program_cost' - `FE_total_adult'
local total_cost = `program_cost' - `FE_total'
di `total_cost'
di `mechanical_cost'

di `FE_total_child'
di `fe_grade_retention'
di `fe_special_ed'
di `fe_child_welfare'
di `fe_child_abuse'

di `FE_total_adult'
di `fe_tax_earnings'
di `fe_college_tuition'
di `annual_inc'
di `increased_earn'

di `fe_juv_justice'

*************************
/* 6. WTP Calculations */
*************************

/*
NOTE: there is currently no difference between estimates under net_transfers
being yes or no. This is because we always subtract out taxes and there are no
explicit figures for changes in transfers in this context.
*/

if "`wtp_valuation'" == "post tax" {
	if "`other_benefits'" == "no" {
		local WTP = `increased_earn' - `fe_tax_earnings' + `college_tuition_part'
	}
	if "`other_benefits'" == "yes" {
		if "`exclude_crim_just'" == "no"{
			local WTP = `increased_earn' - `fe_tax_earnings' + `college_tuition_part' + ///
				`child_care_costs' + `reduce_crime_loss' + `reduce_crime_loss_adult'
		}
		if "`exclude_crim_just'" == "yes"{
			local WTP = `increased_earn' - `fe_tax_earnings' + `college_tuition_part' + ///
				`child_care_costs'
		}
	}
}

if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost'
}

if "`wtp_valuation'" == "lower bound wtp" {
	local WTP = 0.01*`program_cost'
}
di `increased_earn' - `fe_tax_earnings'
di `college_tuition_part'

di `child_care_costs'
di `reduce_crime_loss' + `reduce_crime_loss_adult'


**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

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
global observed_`1' = 21
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'


* income globals
global inc_stat_`1' = `mean_inc_comp'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `inc_year'
global inc_age_stat_`1' = `inc_age'

global inc_benef_`1' = `mean_inc_comp'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `inc_year'
global inc_age_benef_`1' = `inc_age'
