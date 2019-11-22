**********************************************
/* 0. Program: Medicaid Miller Wherry (2018)*/
**********************************************

/*
Dave, D., Decker, S. L., Kaestner, R., & Simon, K. I. (2015)
The effect of medicaid expansions in the late 1980s and early 1990s on the labor
supply of pregnant women
American Journal of Health Economics, 1(2), 165-193.

Miller, S., & Wherry, L. R. (2018).
The long-term effects of early life Medicaid coverage.
Journal of Human Resources, 0816_8173R1.

Currie, J., & Gruber, J. (1996).
Saving babies: The efficacy and cost of recent changes in the Medicaid eligibility
of pregnant women.
Journal of political Economy, 104(6), 1263-1296.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local proj_type = "$proj_type" //"observed", "fixed forecast", "growth forecast"
local wtp_assumption = "$wtp_assumption" // Takes values "parent_crowd_out", "parent_child_mort", and "child_income"

local correlation = $correlation
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local tax_rate_cont = $tax_rate_cont
local tax_rate = $tax_rate_cont
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local discount_rate = $discount_rate
local proj_age = $proj_age
local MW_spec = $MW_spec
local stat_value_life2012 = ${VSL_2012_USD}

/* "perc" or "exp" - determines which approximation method is used for
   causal effects. "perc" is the default. */
local log_calc_method = "$log_calc_method"
assert "`log_calc_method`" != ""

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
local cost_medicaid_per_elig = 202 //Currie and Gruber (JPE, 1996) pg. 1285
local cost_medicaid_per_elig_se = 68
local level_effect_hospital = -.2370 //Miller and Wherry (2018), Table 4 col (1)
local level_effect_hospital_se = .109
/*per 100 pp increase in prenatal eligibility*/
*Later life income benefits
if `MW_spec' == 1 { //This is the specification from Currie Gruber
	local inc_effects_ch_log = .116 //Miller and Wherry (2018), Table 5
	local inc_effects_ch_log_se = .033
}
if `MW_spec' == 2 {
	local inc_effects_ch_log = 0.087 //Miller and Wherry (2018), Table 5
	local inc_effects_ch_log_se = .061
}
if `MW_spec' == 3 {
	local inc_effects_ch_log = .061 //Miller and Wherry (2018), Table 5
	local inc_effects_ch_log_se = .039
}
*Mortality benefits
local infant_mort_effect = -2.822 //Currie and Gruber (1996), Table 3, Column 6
local infant_mort_effect_se =.691
*Effects on mother LFP
local mother_lfp_impact = -0.219 // Dave et al. (2015) table 2
local mother_lfp_impact_se = 0.065
local some_coll_effect = 0.035 // Miller and Wherry (2018), Table 5
local some_coll_effect_se = 0.01

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


*Get right income effect depending on specification used (1 is baseline)
local inc_effects_ch_log = `inc_effects_ch_log_`MW_spec''

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

*Age and year info for growth projections
local first_birth_year = 1979 //Miller and Wherry (2018) pg. 19
local young_age_earn = 23 //Miller and Wherry (2018) pg. 19
local earn_end_year = 2015 //Miller and Wherry (2018) pg. 19
local usd_year = 2011 // Miller & Wherry (2018) base

*Get ages
local age_kid = 0 // unborn
get_mother_age `first_birth_year', yob(`first_birth_year')
local age_parent = r(mother_age)

*mother earnings
local mean_mother_earn = 8541.02 // Dave et al. (2015) table 1
local mother_employed = 0.66  // Dave et al. (2015) table 1
*Dave et al. don't give a USD year, assume 2011 as in Miller-Wherry (2018)

*Later life utilization cost savings
local prob_hospital = .0374 //Miller and Wherry (2018), Table 4, no distribution info
local cost_hospital = 8135 //Miller and Wherry, Appendix pg.6 no distribution info

*Sample mean earnings
deflate_to `usd_year', from(2013) // this is given in $2013 (Miller & Wherry pg. 19)
local mean_earn = 32468.54 * r(deflator) //Miller and Wherry (2018), Table 5

*Eligibility and enrollement
/*"We estimate that the percentage eligible rose from 12.4 percent to 43.3 percent
 between 1979 and 1991." - Currie & Gruber (1996) */
local pp_increase_elig = 43.3 - 12.4 //Miller and Wherry (2018), p. 27; from Currie and Gruber (JPE, 1996), figure 1, no se/p/stars
local percent_preg = .114 //Currie and Gruber (JPE, 1996) pg. 1282, no distribution info, back-of-envelope

*Current benefits
/*Currie and Gruber (1996 QJE) estimate that roughly 41.5% in the 'targeted
changes' sample and 66.6% in the 'broad changes' sample would be privately insured.
This suggests roughly 50% of the population made eligible for Medicaid had private
insurance.*/
local crowd_out_pri_insur = .5

/* Note from Section 5.1.1 justifying uncomp_care_sav_percent:
"While precise data on uncompensated care costs of uninsured are not readily
available, here we assume a rough approximation that 50% of the costs of the
uninsured pregnancies by the low-income individuals who obtained coverage
through Medicaid are paid by the government. This means that half of the cost
outlays to the previously uninsured (which themselves are 50% of the outlays)
is recouped to the government through reductions in uncompensated care. So, the
net cost to the government is $2,830, which is 25% lower than the $3,774
“sticker cost” of the program." */
local uncomp_care_sav_percent = .25 // .25 -> 25 percent

*Age and year info for health projections
local young_age_health = 19 //Miller and Wherry (2018) pg. 15
local health_end_year = 2011 //Miller and Wherry (2018) pg. 15

local percent_cov_public_ins = .5 //assumed, .5 --> 50%
local sample_period_health = 14 //in years
local sample_period_earn = 14 //in years

local adult_start_year_earn = 23 // first year of earnings in Miller and Wherry (2018) sample
local adult_start_year_health = 19 //Miller and Wherry (2018) pg. 15

if "`proj_type'" == "observed"{
	local years_effect_earn = `sample_period_earn'
	local years_effect_health = `sample_period_health'
}
if strpos("`proj_type'", "forecast") {
	local years_effect_health = `proj_age' -`adult_start_year_health'
	local years_effect_earn = `proj_age' -`adult_start_year_earn'
}

local years_effect = `proj_age' - 23

*********************************
/* 4. Intermediate Calculations */
*********************************

*Inflation adjust Currie & Gruber estimates from 1986 to 2011 dollars
deflate_to `usd_year', from(1986)
local cost_medicaid_per_elig = `cost_medicaid_per_elig'*r(deflator)

*Adjust VSL
deflate_to `usd_year', from(2012)
local stat_value_life = 1000000*`stat_value_life2012'*r(deflator)

*Age and year calcs for projections
local earn_begin_year = `first_birth_year'+`young_age_earn'
local old_age_earn = `earn_end_year' - `first_birth_year'
local avg_age_earn = round((`young_age_earn' + `old_age_earn')/2)
local proj_start_age = `old_age_earn'+1
local earn_year = round((`earn_begin_year' + `earn_end_year')/2)
local proj_year = `earn_end_year'+1

*Age and year calcs for health effects
local old_age_health = `health_end_year' - `first_birth_year'
local avg_age_health = round((`young_age_health'+`old_age_health')/2)

*Mechanical costs
local cost_per_child_unadjusted = `cost_medicaid_per_elig'/`percent_preg' //this is the 3774

*plus adjustment for costs that would be covered by govt. anyway
local cost_per_child_elig_adjusted = `cost_per_child_unadjusted'*(1 - `uncomp_care_sav_percent')

*Later life utilization cost savings
local avg_cost_hospital = `cost_hospital'*`prob_hospital'
local year_save_hospital = -`level_effect_hospital'*`avg_cost_hospital'
local gov_yr_save_hospital = `year_save_hospital'*`percent_cov_public_ins'

local cost_hospital_d = `cost_hospital'/(1+`discount_rate')^(`avg_age_health')
local avg_cost_hospital_d = `cost_hospital_d'*`prob_hospital'
local year_save_hospital_d = -`level_effect_hospital'*`avg_cost_hospital_d'
local gov_yr_save_hospital_d = `year_save_hospital_d'*`percent_cov_public_ins'

*Child income effects
if "`log_calc_method'" == "perc" {
	local cfactual_earn = `mean_earn' / (1 + (`pp_increase_elig' / 100) * ///
						  `inc_effects_ch_log')

	local income_effect_level= `inc_effects_ch_log' * `cfactual_earn'
}
else if "`log_calc_method'" == "exp" {
	local log_mean_earn = log(`mean_earn')
	local log_cfactual_earn = `log_mean_earn' - ///
							  (`pp_increase_elig' / 100) * ///
							  `inc_effects_ch_log'
	local cfactual_earn = exp(`log_cfactual_earn')
	*30% increase in eligibility -> 30% of sample treated
	local income_effect_level = exp(`log_cfactual_earn' + ///
									`inc_effects_ch_log') - ///
								`cfactual_earn'
}
else exit 9

di `usd_year'

*Get tax rate for kids
if "`tax_rate_assumption'"=="cbo" {
	get_tax_rate `mean_earn' , ///
		inc_year(`earn_year') /// Average year of income measurement
		usd_year(`usd_year') ///
		include_transfers(yes) ///
		include_payroll("`payroll_assumption'") ///
		forecast_income(yes) ///
		program_age(`avg_age_earn') ///
		earnings_type(individual)

	local tax_rate = r(tax_rate)
	local parent pfpl = r(pfpl)
}

*Get implied cost increase to govt from college attendance
if "${got_mw_cost}"!="yes" {
	cost_of_college , year(`=`first_birth_year'+18')
	global mw_year_college_cost  = r(cost_of_college)
	global mw_tuition_cost = r(tuition)
	global got_mw_cost = "yes"
}
*Assume 2 years on average for those induced to attend some college
deflate_to `usd_year', from(`=`first_birth_year'+18')
local govt_college_cost = (${mw_year_college_cost}-${mw_tuition_cost})*2*`some_coll_effect'* ///
	r(deflator)*(1/(1+`discount_rate')^18)
local priv_college_cost = (${mw_tuition_cost})*2*`some_coll_effect'* ///
	r(deflator)*(1/(1+`discount_rate')^18)
di `some_coll_effect'
di `govt_college_cost'
di `priv_college_cost'
di `=`first_birth_year'+18'
di ${mw_year_college_cost} - ${mw_tuition_cost}
di `govt_college_cost'

*Crowding out
local save_crowd_out = `crowd_out_pri_insur'*`cost_per_child_unadjusted'

*Mortality
local VSL_benefits = -`stat_value_life'*(`infant_mort_effect'/1000)

*Mother LFP impacts (contemporaneous as effect is whilst pregnant)
local mean_earn_working = `mean_mother_earn' / `mother_employed'
local mother_earn_effect = `mean_earn_working' * `mother_lfp_impact'

local inc_year_mother = `first_birth_year' + 1 // fpl not available for 1979

*Get tax rate for mothers
if "`tax_rate_assumption'"=="cbo" {
	get_tax_rate `mean_earn_working' , ///
		inc_year(`inc_year_mother') /// Average year of income measurement
		usd_year(`usd_year') ///
		include_transfers(yes) ///
		include_payroll("`payroll_assumption'") ///
		forecast_income(yes) ///
		program_age(`age_parent') ///
		earnings_type(individual)

	local tax_rate_mother = r(tax_rate)
	di r(pfpl)
}

else local tax_rate_mother = `tax_rate_cont'

local mother_tax_impact = `tax_rate_mother'*`mother_earn_effect'

*Intermediate calculations based on type and length of projection
local earn_impact_obs = 0
forval i = `adult_start_year_earn'/`=`adult_start_year_earn' + `sample_period_earn' - 1' {
	local earn_impact_obs = `earn_impact_obs'+`income_effect_level'/((1+`discount_rate')^(`i'))
}

*Observed only:
if "`proj_type'" == "observed"{
	forval j = 0/`=`adult_start_year_earn'-1' {
		local FE_tax_`j' = 0
	}
	forval j = 0/`=`adult_start_year_health'-1' {
		local FE_hospital_`j' = 0
	}
	forvalues j = `adult_start_year_earn'/`=`adult_start_year_earn' + `sample_period_earn''{
		local FE_tax_`j' = `FE_tax_`=`j'-1'' + (`tax_rate')*`income_effect_level'/((1+`discount_rate')^`j')
	}
	forvalues j = `adult_start_year_health'/`=`adult_start_year_health' + `sample_period_health''{
		local FE_hospital_`j' = `FE_hospital_`=`j'-1'' + `gov_yr_save_hospital'/(1+`discount_rate')^(`j')
	}

	local FE = `FE_tax_`=`adult_start_year_earn' + `sample_period_earn''' + ///
		`FE_hospital_`=`adult_start_year_health' + `sample_period_health'''

	local earn_impact = `earn_impact_obs'
}


*growth forecast to `proj_age':
if "`proj_type'" == "growth forecast" {
	di `mean_earn'
	di `income_effect_level'
	di `avg_age_earn'-`proj_start_age'+`proj_year'

	est_life_impact `income_effect_level', ///
		impact_age(`avg_age_earn') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`proj_year') usd_year(`usd_year') ///
		income_info(`cfactual_earn') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		max_age_obs(`=`adult_start_year_earn'+`sample_period_earn'-1')

	local years_back_to_spend = `proj_start_age' + 1

	local earn_proj = (((1/(1+`discount_rate'))^`years_back_to_spend') * r(tot_earn_impact_d))
	local increase_taxes_proj = `tax_rate' * `earn_proj'

	*Get fiscal externalities by year for graphs
	forval j = 0/100 {
		local FE_tax_`j' = 0 //just to avoid missing local errors - gets ovewritten where appropriate
	}
	local end = min(`=`proj_start_age'-1', `proj_age')
	forval j = `adult_start_year_earn'/`end' {
		local FE_tax_`j' = `FE_tax_`=`j'-1'' + `tax_rate'*`income_effect_level'/(1+`discount_rate')^(`j')
	}
	forvalues j = `proj_start_age'/`proj_age'{
		local FE_tax_`j' = `FE_tax_`=`proj_start_age'-1'' + ///
			`tax_rate'* ${aggt_earn_impact_a`j'}*(1/(1+`discount_rate'))^`years_back_to_spend'
	}

	local FE_tax_long = `increase_taxes_proj' + `FE_tax_`=`proj_start_age'-1''

	local earn_impact = `earn_impact_obs' + `earn_proj'
}

*Forecast health effects forwards
if "`proj_type'" == "growth forecast" {
	local begin_health_proj = `adult_start_year_health' + `sample_period_health'

	local FE_hospital_long = 0
	forval j = 0/`=`adult_start_year_health'-1' {
		local FE_hospital_`j' = 0
	}

	forvalues j = `adult_start_year_health'/`proj_age'{
		local FE_hospital_long = `FE_hospital_long' + `gov_yr_save_hospital'/(1+`discount_rate')^(`j')
		local FE_hospital_`j' = `FE_hospital_long'
	}

	local FE = `FE_tax_long' + `FE_hospital_long'
}

*Add tax impacts of mother labour supply changes
local FE = `FE' + `mother_tax_impact'

*Add college costs
local FE = `FE' - `govt_college_cost'
di `govt_college_cost'
di `FE_tax_`=`proj_start_age'-1''
di `proj_start_age'

**************************
/* 5. Cost Calculations */
**************************

local care_cost = `cost_per_child_elig_adjusted'
local total_cost = `care_cost' - `FE'

local program_cost = `cost_per_child_unadjusted'
di `total_cost'

*************************
/* 6. WTP Calculations */
*************************
di `save_crowd_out'
di `VSL_benefits'
di (1-`tax_rate')*(`earn_impact'-`earn_impact_obs')
di (1-`tax_rate')*`earn_impact_obs'

if "`wtp_assumption'" == "parent_crowd_out"{
	local WTP = `save_crowd_out'
	local WTP_kid = 0
}

if "`wtp_assumption'" == "parent_child_mort"{
	local WTP = `save_crowd_out' + `VSL_benefits'
	local WTP_kid = `VSL_benefits'
}

if "`wtp_assumption'" == "child_income"{
	local WTP = `save_crowd_out' + `VSL_benefits' + (1-`tax_rate')*`earn_impact' - `priv_college_cost'
	local WTP_kid = `VSL_benefits' + (1-`tax_rate')*`earn_impact' - `priv_college_cost'
}

local age_stat = `age_parent'
if `WTP_kid'>`=`WTP'*0.5' local age_benef = `age_kid'
else local age_benef = `age_parent'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

di `total_cost'/`program_cost'
di `total_cost'/`cost_per_child_unadjusted'
di `MVPF'
di `total_cost'
di `program_cost'
di `WTP'

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global full_cost_pp_`1' = `cost_per_child_unadjusted'
global program_cost_`1' = `program_cost'
global observed_`1' = `adult_start_year' + `sample_period_earn'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')

global inc_stat_`1' = `mean_mother_earn' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `first_birth_year'
global inc_age_stat_`1' = `age_parent'

if `WTP_kid'>`=`WTP'*0.5' {
	global inc_benef_`1' = `cfactual_earn' * r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `project_year'+`avg_age_earn'-`proj_start_age'
	global inc_age_benef_`1' = `avg_age_earn'
}
else {
	global inc_benef_`1' = `mean_mother_earn' * r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `first_birth_year'
	global inc_age_benef_`1' = `age_parent'
}

**************************
/* 8.   Cost Graphs     */
**************************

forval i = 0/`proj_age' {
	global y_`i'_cost_`1' = `cost_per_child_elig_adjusted' - `mother_tax_impact' - `FE_tax_`i'' - `FE_hospital_`i''
	di `i'
	di "Year `i' cost: ${y_`i'_cost_`1'}"
	di "FE_tax_`i' : `FE_tax_`i''"
	di "FE_hospital_`i' : `FE_hospital_`i''"
}


*Numbers for text
di `cost_medicaid_per_elig' //adjusted
di `cost_per_child_unadjusted' // scale by % pregnant
di `cost_per_child_unadjusted'/0.34 // scale takeup rate

di `mean_earn_working' //mother earn if working
di `mother_earn_effect' //impact on mother earnings
di `mother_tax_impact'

di `cost_per_child_elig_adjusted' // cost adjusting for uncompensated care savings to govt

*Cost globals for decomposition
global mw_eligibility_adjustment = `cost_per_child_unadjusted' - `cost_per_child_elig_adjusted'
global mw_mum_tax_impact =  `mother_tax_impact' // total tax impact
global mw_unadjusted_cost = `cost_per_child_unadjusted'
global mw_hosp_cost= `FE_hospital_long'
global mw_college_cost = `govt_college_cost'
global mw_tax_save = `FE_tax_long'

*WTP globals for decomposition
global mw_wtp = `WTP'
global mw_par_crowd_out = `save_crowd_out'
global mw_vsl_ben = `VSL_benefits'
global mw_earn_ben_obs = (1-`tax_rate')*`earn_impact_obs'
global mw_earn_ben_proj = (1-`tax_rate')*`earn_proj'
global mw_coll_priv_cost = `priv_college_cost'

*Estimates for Government cost decomposition
di `cost_per_child_unadjusted'
di `mother_tax_impact'
di  `cost_per_child_unadjusted' - `cost_per_child_elig_adjusted'
di `FE_hospital_long'
di `govt_college_cost'
di `FE_tax_long'
di `total_cost'

di `cost_per_child_elig_adjusted'
di `program_cost'

*Estimates for Willingness to Pay Decomp
di `save_crowd_out'
di `VSL_benefits'
di `priv_college_cost'
di (1-`tax_rate')*`earn_impact_obs'
di (1-`tax_rate')*(`earn_impact'-`earn_impact_obs')
di `WTP'

di `cost_hospital_d'
di `avg_age_health'
di `avg_cost_hospital_d'
di `year_save_hospital_d'
di `gov_yr_save_hospital_d'
di `govt_college_cost'
di `FE_tax_long'

*ACS forecast globals
global mw_inc_effect = `income_effect_level'
global mw_cfactual_inc = `mean_earn'
global mw_impact_age = `avg_age_earn'
