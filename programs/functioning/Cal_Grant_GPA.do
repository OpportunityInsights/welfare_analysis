****************************************
/* 0. Program: Cal Grant GPA 		  */
****************************************

/*
Primary Estimates:
Bettinger, E., Guyppprantz, O., Kawano, L., Sacerdote, B.,& Stevens, M.
"The Long-Run Impacts of Financial Aid: Evidence from California's Cal Grants."
American Economic Journal: Economic Policy (2019).
https://www.aeaweb.org/articles?id=10.1257/pol.20170466
https://ogurantz.github.io/website/Bettinger_2019_AEJ_LongRunImpactsOfFinancialAid.pdf

*/

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption"
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"

local val_given_marginal = $val_given_marginal
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

*Program Specific Globals
local income_measure = "$income_measure"
local years_bach_deg = $years_bach_deg
local years_enroll_bach = $years_enroll_bach
local years_enroll_cc = $years_enroll_cc
local private_costs_gov = "$private_costs_gov"

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
**Estimated effects at GPA threshold**

*Estimated effect on log labor income
local labor_income_log_change = 0.054  //Bettinger et al. 2019, Table 3
local labor_income_log_change_se = 0.019 //Bettinger et al. 2019, Table 3

*Estimated effect on AGI adjusted for household size
local agi_log_change = 0.032 //Bettinger et al. 2019, Table 3
local agi_log_change_se = 0.016 //Bettinger et al. 2019, Table 3

*Cost of Grant
local cost_grant_gpa = 4311.169 //Bettinger et al. 2019, Table 2
local cost_grant_gpa_se = 172.946 //Bettinger et al.  2019, Table 2

*Graduation Effects
local bach_deg_change = 0.046 //Bettinger et al. 2019, Table 2
local bach_deg_change_se = 0.015 //Bettinger et al. 2019, Table 2

*Attendance Effects
local enroll_cc_change = -0.011 //Bettinger et al. 2019 Table 2
local enroll_cc_change_se = 0.011 //Bettinger et al. 2019  Table 2
local enroll_pub_change = 0.001 //Bettinger et al. 2019, Table 2
local enroll_pub_change_se = 0.012 //Bettinger et al. 2019, Table 2
local enroll_priv_change = 0.002 //Bettinger et al. 2019, Table 2
local enroll_priv_change_se = 0.007 //Bettinger et al. 2019, Table 2

* Instructional costs
local inst_cost = 113.158 //Bettinger et al. 2019, Table 4
local inst_cost_se = 94.358 //Bettinger et al. 2019, Table 4

*/

*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************




*Mean Earnings in Sample after 10-14 years -- log income
local mean_earning_gpa = 39014 //Bettinger et al. 2019, Table 1
*Mean Earnings in Sample after 10-14 years -- AGI
local mean_earning_gpa_agi = 45665 //Bettinger et al. 2019, Table 1
/*Mean earnings from Table 1 are used here to avoid the problem of Jensen's inequality
that would come from using the mean of log earnings in Table 3
*/

local control_mean_attend = 0.94 // Bettinger et al. Table 2

*Projection length
local observed_start = 10 // Earnings observed 10 years after HS completion
local observed_end = 14 // Until 14 years after
local year_15_age = round(18.54+15) //Table 1 has mean age at application of 18.54. 15 years after application.

*Estimate year to start projection
local projection_year = round(1999 + 15)
/*The sample consists of people graduating HS between 1998 and 2000 and the projection
starts in their 15th year after graduation. 2013 is the final year of the sample
in the paper, but some individuals may have 14 years of earnings before that point. */

*Estimate USD year as Bettinger et al. do not give one.
local usd_year = 2011
/*The sample consists of people graduating between 1998 and
2000 and the estimates are based on earnings from the 10th through 14th year after
graduation.*/

*********************************
/* 4. Intermediate Calculations */
*********************************

*Assign appropriate earnings gain based on specification used
if "`income_measure'" == "log income"{ //earnings based on log income
	local earn_prc = exp(`labor_income_log_change') - 1 // convert to % earnings impact
	local mean_earning_comb = `mean_earning_gpa' // combined treatement + control
	local mean_earnings = `mean_earning_comb'*(1-(`earn_prc'/2)) // assume 50% control to get control earnings
}
if "`income_measure'" == "agi"{ //earnings based on household adjusted AGI
	local earn_prc = exp(`agi_log_change') - 1 // convert to % earnings impact
	local mean_earning_comb = `mean_earning_gpa_agi' // combined treatement + control
	local mean_earnings = `mean_earning_comb'*(1-(`earn_prc'/2)) // assume 50% control to get control earnings
}

*Estimate yearly earnings gains based on fixed percentage gain in years 10-14.
local total_earn = 0
forvalues j = `observed_start'/`observed_end'{
	local total_earn = `total_earn' + `earn_prc'*`mean_earnings'*(1/(1+`discount_rate')^`j')
}
di `total_earn'
local total_earn_14y = `total_earn'

/*
Note: Given the results presented in the paper, we make the conservative assumption
that positive earnings gains first emerge in years 10-14. Figure 7 in Bettinger
et al. 2019 shows positive but insignificant point estimates in years 5-9, but
those point estimates and standard errors are not reported in the paper. Given
additional college attendance may produce earnings declines in years 1-4 our
assumption implicitly requires that the earnings declines in years 1-4 offset
the unreported earnings gains in years 5-9.
*/

*Estimate long run earnings effects using our projection method
local earn_proj = 0
if "`proj_type'" == "growth forecast" {

	est_life_impact `earn_prc', ///
		impact_age(`=`year_15_age'-1') project_age(`year_15_age') end_project_age(`proj_age') ///
		project_year(`projection_year') usd_year(`usd_year') ///
		income_info(`mean_earnings') income_info_type(counterfactual_income) ///
		percentage("yes") ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		max_age_obs(`=`year_15_age'-1')

	*Discount back to program receipt
	local earn_proj = r(tot_earn_impact_d)*(1/(1+`discount_rate')^15)

	if "`income_measure'" == "log income" local earnings individual
	if "`income_measure'" == "agi" local earnings household

	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `mean_earnings', /// tax rate explicitly for treated
			inc_year(`=`projection_year'-1') /// from est_life_impact assumptions
			usd_year(`usd_year') ///
			include_transfers(yes) ///
			include_payroll("`payroll_assumption'") ///
			forecast_income(yes) ///
			program_age(`=`year_15_age'-1') ///
			earnings_type("`earnings'") // use household if AGI

		local tax_rate = r(tax_rate)
		local tax_rate_cont = r(tax_rate)
		di r(pfpl)
	}
}
// Total earnings is a combination of observed and projected earnings
local total_earn = `total_earn' + `earn_proj'

*Incorporate taxes into earnings effects
local increase_taxes = `tax_rate_cont' * `total_earn'
local total_earn_impact_aftertax = (1-`tax_rate_cont')*`total_earn'

di `total_earn_impact_aftertax'
di `tax_rate_cont'
di `total_earn'
di `increase_taxes'



**************************
/* 5. Cost Calculations */
**************************

*Calculate Cost of Additional enrollment
cost_of_college, year(2000) state("CA") type_of_uni("rmb")
local cost_of_college_fte_ca_2000_rmb = `r(cost_of_college)'
cost_of_college, year(2000) state("CA") type_of_uni("community")
local cost_of_college_fte_ca_2000_cc = `r(cost_of_college)'
//Note: The sample consists of people graduating HS between 1998 and 2000
local years_enroll_bach_disc = 0
local years_bach_deg_disc = 0
local years_enroll_cc_disc = 0

*4-Year School
*Enrollees:
	local end = ceil(`years_enroll_bach')
	forval i=1/`end' {
		local years_enroll_bach_disc = `years_enroll_bach_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_bach' - floor(`years_enroll_bach')
	if `partial_year' != 0 {
		local years_enroll_bach_disc = `years_enroll_bach_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}

	*Graduates:
	local start =  floor(4-`years_bach_deg') + 1
	forval i =`start'/4 {
		local years_bach_deg_disc = `years_bach_deg_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_bach_deg' - floor(`years_bach_deg')
	if `partial_year' != 0 {
		local years_bach_deg_disc =  `years_bach_deg_disc' - (1-`partial_year')*(`graduate_2yr')/((1+`discount_rate')^(`start'-1))
	}

*2-Year School
*Enrollees:
	local end = ceil(`years_enroll_cc')
	forval i=1/`end' {
		local years_enroll_cc_disc = `years_enroll_cc_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_cc' - floor(`years_enroll_cc')
	if `partial_year' != 0 {
		local years_enroll_cc_disc = `years_enroll_cc_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}


local enroll_cost = `bach_deg_change'*`years_bach_deg_disc'*`cost_of_college_fte_ca_2000_rmb' + ///
	`enroll_pub_change'*`years_enroll_bach_disc'*`cost_of_college_fte_ca_2000_rmb' ///
	+`enroll_cc_change'*`years_enroll_cc_disc'*`cost_of_college_fte_ca_2000_cc'
/*
Note: We assume here that those who receive a bachelors degree are distinct from
those who are new enrollees. We assume that the government covers the full cost
of expenditures for additional bachelors degree enrollees. We also use outside
estimates of the costs of community college and public college enrollment change
so that the cost reductions from moving to community college to four year college
are not over-estimated.

Cal Grant A covers full statewide fees, so we assume that the government pays for
the full cost of additional years of schooling, rather than assuming individuals
contribute to tuition and fees.
*/

local priv_induced_frac = 0
*Incorporate Private College Costs
if "`private_costs_gov'" ==  "yes" {

local enroll_cost = `enroll_cost' + `enroll_priv_change'*`years_enroll_bach_disc'*`cost_of_college_fte_ca_2000_rmb'
local priv_induced_frac = `enroll_priv_change'
/*
Here we assume that when individuals enroll in private universities, that the government
covers costs that exceed the value of the CalGrant. In particular, we assume that the government
costs are equal to the costs in the case where an individual attended a four-year public university.
*/
}

local stayer_cost = `inst_cost'*`control_mean_attend'*`years_enroll_bach_disc'
/*
Note: We incorporate an estimate of the increase in costs for enrollees who switch
schools. Expenditures per FTE may include factors like research costs so we approximate
using instructional expenditures. We use years_enroll_bach_disc to determine the number
of years the costs apply over.
*/
*Program cost is average impact of eligbility on funding received
local program_cost_unscaled = `cost_grant_gpa'
local program_cost = `cost_grant_gpa'*(1 - `bach_deg_change' - `enroll_pub_change' - `enroll_priv_change')
di `program_cost'
di `program_cost_unscaled'
/*
Note: Without information about the years in which the grant funds are recieved, we
take a conservative approach and avoid splitting this total and discounting a
fraction of the costs
*/
*Get fractions induced
local frac_induced = `bach_deg_change' + `enroll_pub_change' + `priv_induced_frac'
local frac_non_induced = 1 - `frac_induced'

*FE from increased enrollment
local enrollment_FE = `enroll_cost'- (`cost_grant_gpa'*`frac_induced')
/* Adjustment is made here to avoid double counting. The average cost per recipient
is used for all individuals who do are not induced into attending four year
public colleges or receiving bachelors degrees. We assume these gropus are distinct.
This is adjustment is made because the supplemental costs of their enrollment
already includes the Cal Grant amount. */


*FE from increased tax payments
local tax_FE  = -`increase_taxes'

*Calculate total costs adjusting for tax revenue
local total_cost = `program_cost_unscaled' + `enrollment_FE' + `tax_FE' + `stayer_cost'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Those induced value at post tax earnings impacts, those not value at transfer
	local WTP_induced = `total_earn_impact_aftertax'
	local WTP_non_induced = `frac_non_induced'*`cost_grant_gpa'
	local WTP = `WTP_induced' + `WTP_non_induced'

}

if "`wtp_valuation'" == "cost" {
	*Non-induced value at transfer 1:1
	local WTP_non_induced = `cost_grant_gpa'*`frac_non_induced'
	*Induced value at potentially lower fraction `val_given_marginal'
	local WTP_induced = `val_given_marginal'*`cost_grant_gpa'*`frac_induced'
	*Combine
	local WTP = `WTP_non_induced' + `WTP_induced'
}
/*
Note: It is assumed here that all individuals who are not induced to attend or recieve
a bachelors degree due to the Cal Grant value the grant at cost. It is assumed
that all who are induced value at either some fraction between 0 and 1 or the post
tax earnings effect.
*/

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

di `MVPF'
di `WTP'
di `total_cost'
di `WTP_non_induced'

/*
Figures for Attainment Graph
*/
di `bach_deg_change'*`years_bach_deg' //enrollment gain
di  1 // baseline enrollment -- this is one because cost are measured relative to crossing the threshold
di `cost_grant_gpa'*`frac_non_induced' // Mechanical Cost
di `cost_grant_gpa'*`frac_induced' // Behavioral Cost Program
di 	`enrollment_FE' // Behavioral Cost Crowd-In
di `WTP_induced' //WTP induced
di `WTP_non_induced' //WTP Non-Induced
di 	`mean_earnings' // Income Counter-Factual


*Locals for Appendix Write-Up
di `total_earn_14y'
di `earn_proj'
di `tax_rate'
di `WTP'
di `program_cost'
di `enrollment_FE'
di `stayer_cost'
di `increase_taxes'
di 	`total_cost'



global MVPF_`1' = `MVPF'
global WTP_`1' = `WTP'
global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption


*Components for Cost and WTP Decomposition
global cal_gpa_grant = `cost_grant_gpa'
global cal_gpa_ed_exp = `enrollment_FE'
global cal_gpa_14y_tax = `total_earn_14y'*`tax_rate_cont'
global cal_gpa_life_tax = -1*`tax_FE' - ${cal_gpa_14y_tax}
global cal_gpa_cost = `total_cost'

di `program_cost'
di `enrollment_FE'
di `total_earn_14y'*`tax_rate_cont'
di -1*`tax_FE' - ${cal_gpa_14y_tax}
di `total_cost'

di `total_earn_impact_aftertax'
di `WTP_non_induced'
di `WTP'


* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `mean_earning_gpa' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `=`projection_year'-1'
global inc_age_stat_`1' = `=`year_15_age'-1'

global inc_benef_`1' = `mean_earning_gpa' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=`projection_year'-1'
global inc_age_benef_`1' = `=`year_15_age'-1'
