***************************************************
/* 0. Program: SNAP FinkNoto: Info and Assistance*/
***************************************************

*Finkelstein, Amy and Notowidigdo, Matthew J. 2018. "Take-up and Targeting: Experimental 
* Evidence from SNAP." NBER Working Paper No. 24652. http://www.nber.org/papers/w24652


* Provide information and application assistance to individuals likely eligible for SNAP

/*NOTE: the paper separates recipients into two groups, based on the level of benefits received. Thus we calculate costs and WTP separately for each, and aggregate these at the end.
From pg. 35: "To simplify the parameterization of the model, we collapse the distribution of
benefits to be only one of two possible levels: either the minimum benefit of $16
per month [low-benefit] or $178 / month [high-benefit](which is the mean benefit
for the approximately 80 percent of control group enrollees who do not receive the minimum.)"*/
********************************
/* 1. Pull Global Assumptions */
********************************
 
local WTP_for_SNAP = ${WTP_for_SNAP} // WTP for $1 in SNAP benefits
local wtp_valuation = "${wtp_valuation}"


******************************
/* 2. Estimates from Paper */
******************************

*Effect on SNAP Take-Up for the information and assistance treatment group

/*Difference between treatment and control percent applying to SNAP where xx% --> .xx
local effect_take_up = 0.238 - 0.077 // Finkelstein and Notowidigo 2018, Table 2, row 2
local effect_take_up_p = runiform(0, 0.001) // "<.001"
local effect_take_up_n_treat = 10629
local effect_take_up_n_control = 10630
local effect_take_up_t = invnormal(1-`effect_take_up_p'/2)
local effect_take_up_se = `effect_take_up'/`effect_take_up_t'

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
local age_stat = 68.83 // Finkelstein and Notowidigdo (2019) table 1

local reduc_app_cost = 75 //Assumption explained Finkelstein and Notowidigdo (2018) p. 35
/*From pg. 35: "Given that applying takes the individual five hours (Ponza et al. 1999),
if we (generously) assume the value of time for this low-income elderly population is
roughly twice the minimum wage of $7.25 per hour, this implies the private (time) cost
 of applying is about $75"*/

local months_benefit = 36 //Finkelstein and Notowidigdo (2019) pg. 11
/*From pg. 11:  Once deemed eligible, an elderly household is certified to receive
SNAP benefits for 36 months, although there are exceptions that require earlier
re-certification */

local prob_benefit = .75 //Finkelstein and Notowidigdo (2018) p. 35 (assumed)
/*From pg. 35: "To calculate expected benefits from applying, we assume that the
probability of rejection is 0.25 for both types (the rejection rate for the controls)." */

/*Note that all recipients who do not recieve the minimum benefit ($16) (low-benefit type) are
considered the high-benefit type (who recieve an average benefit of $178). Appendix Table 6
provides the percent of marginal recipients and inframarginal recipients who are the low-benefit,
and as such we can infer the corresponding percentages for the high-benefit type given
the binary categories defined in the model. */

local marginal_low = 0.453 // Finkelstein and Notowidigdo (2019), Table A7, pg. A22
local marginal_high = 0.547 // Finkelstein and Notowidigdo (2019), Table A7, pg. A22

local application_rate_assist = 0.238 //Finkelstein and Notowidigo (2019) Table 2

local mispercep_low = .83 //Assumption explained Finkelstein and Notowidigdo (2019) p. 28
local mispercep_high = .98 //Assumption explained Finkelstein and Notowidigdo (2019) p. 28


*Costs to government

local annual_admin_cost = 267 //Isaacs (2008), Finkelstein and Notowidigdo (2019) p. 27 (by application not recipient)

*Amount of dollars in SNAP benefits recieved 
local month_benefit_low = 16 //Assumption explained Finkelstein and Notowidigdo (2018) p. 35
local month_benefit_high = 178 //Assumption explained Finkelstein and Notowidigdo (2018) p. 35

**********************************
/* 4. Intermediate Calculations */
**********************************

/*Effect on SNAP Take-Up adjusted for benefit type*/
local effect_take_up_adj_low = `effect_take_up'*`marginal_low'
local effect_take_up_adj_high = `effect_take_up'*`marginal_high'


/*Total cost of providing SNAP benefits, excluding admin costs*/
local tot_cost_prov_low = `month_benefit_low'*`months_benefit'
local tot_cost_prov_high = `month_benefit_high'*`months_benefit'

/*Benefit amount adjusted by probability of recieving benefit*/
local expected_benefit_low = `prob_benefit'*`tot_cost_prov_low'
local expected_benefit_high = `prob_benefit'*`tot_cost_prov_high'

/*Expected benefit adjusted by amount that people are WTP for $1 in SNAP benefits*/
local expected_benefit_low_adj = `prob_benefit'*`WTP_for_SNAP'*`tot_cost_prov_low'
local expected_benefit_high_adj = `prob_benefit'*`WTP_for_SNAP'*`tot_cost_prov_high'

*Effect of Experiment on Expected Benefits, Inclusive of Misperceptions
/*Information Effect = Expected Benefit * Misperception * Effect on Marginal;
 Assistance Effect = Reduction in Cost * (Fraction Inframarginal + Effect on Marginal)*/
local benefit_effect_info_low = `mispercep_low'*`expected_benefit_low_adj'*`effect_take_up_adj_low'
local benefit_effect_info_high = `mispercep_high'*`expected_benefit_high_adj'*`effect_take_up_adj_high'

local benefit_effect_assist = `reduc_app_cost'*`application_rate_assist'
/*"The term dc/dT is the (money-metric) change in application costs from the intervention, and it is scaled by the
number of total applicants (both infra-marginal and marginal) of either type (i.e., this is the
overall application rate in this treatment arm). Finkelstein and Notowidigdo (2019) p30 */

*Effect of Experiment on Expected Total Costs, Inclusive of Misperceptions
/*Cost Effect = (Expected Benefit + Government Cost) * Effect on Marginal*/
local total_cost_low = (`expected_benefit_low'+`annual_admin_cost')*`effect_take_up_adj_low'
local total_cost_high = (`expected_benefit_high'+`annual_admin_cost')*`effect_take_up_adj_high'


local hh_inc = 1500/0.15
local usd_year = 2017
/*
"average annual SNAP benefits are about $1,500, or about 15 percent of household
income among the eligible (Center on Budget and Policy Priorities, 2017)."
Finkelstein & Notowidigdo (2018)
*/

**************************
/* 5. Cost Calculations */
**************************

local total_cost = `total_cost_low' + `total_cost_high'

local program_cost = `total_cost'

*************************
/* 6. WTP Calculations */
*************************

local WTP = `benefit_effect_info_low' +  ///
	`benefit_effect_info_high' + `benefit_effect_assist'

if "`wtp_valuation'" == "lower bound" {
	// no clear lower bound on valuation, choose valuation at 1% of program cost	
	local WTP = 0.01*`program_cost'
}
**************************
/* 7. MVPF Calculations */
**************************

di `WTP'
di `total_cost'

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

disp `program_cost'
disp `total_cost'
disp `WTP'
disp `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'

global age_stat_`1' = `age_stat'
global age_benef_`1' = 	`age_stat'

* income globals
deflate_to 2015, from(`usd_year')

global inc_stat_`1' = `hh_inc' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `usd_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `hh_inc' * r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `usd_year'
global inc_age_benef_`1' =  `age_stat'
