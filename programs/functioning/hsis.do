************************************************
/* 0. Program: Head Start (Impact Study) */
************************************************

/*
Kline, Patrick, and Christopher R. Walters. 
"Evaluating public programs with close substitutes: The case of Head Start." 
The Quarterly Journal of Economics 131, no. 4 (2016): 1795-1848.
https://academic.oup.com/qje/article/131/4/1795/2468877
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local wage_growth_rate = $wage_growth_rate //set in default assumptions file
local tax_rate_assumption = "$tax_rate_assumption" //takes value "paper internal", "continuous", or "cbo"
local tax_rate_cont = $tax_rate_cont

local proj_type = "$proj_type" //takes value paper internal or growth forecast 
local proj_age = $proj_age //takes on age at end of projection
local net_transfers = "$net_transfers" //takes value yes if adjustments for changes in net transfers/taxes
local wtp_valuation = "$wtp_valuation"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

*Options specific to this program
local rationing = "$rationing" // Takes values "yes" or "no"
/* With rationing = spots opening up in other pre-K programs as some of those 
former students shift into Head Start */

local incl_parents = "$incl_parents"  // Takes values "yes" or "no"
* yes = Parents value, no = Parents don't value

******************************
/* 2. Estimates from Paper */
******************************

/*
local test_score_effect = 0.247 // Kline and Walters (2016), Table II; causal effect on test scores (SD)
local test_score_effect_se = 0.031 

*Effect on Test Scores for Head Start Lottery Compliers -- Movers from Home Care 
*to Other Pre-K Programs (subLATE, Heckman Selection)
local score_home_prek = 0.294 // Kline and Walters (2016), p. 1840, second paragraph (no SE given)
*/

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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local impact_year = 2002  //Kline and Walters (2016) p 1800
local program_year = 2002  //Kline and Walters (2016) p 1800
local usd_year = 2002 // align with program year

local prop_head_start_from_other = 0.338 // Table 3
/* Kline and Walters (2016), Table III; proportion of head start enrollment drawn
form other pre-K programs shares of offered and nonoffered students attending 
Head Start, other center-based preschools, and no preschool, separately by year
and age cohort, weighted by the reciprocal of the probability of a child’s 
experimental assignment. */
 
*Marginal Cost of Head Start Enrollment
deflate_to `usd_year' , from(2013)
local head_start_enroll_cost = 8000 * r(deflator)
*Kline and Walters (2016), Table IV and Appendix D; from DHHS 2013 Head Start Fact Sheet
di `head_start_enroll_cost'

local alt_prek_marginal_cost = 0.75 
/* Kline and Walters (2016), Appendix D.3 pg. 17; Authors also calculate MVPFs assuming a 
pessimistic scenario of 0.5 and a benchmark of 0. We take their preferred assumption.*/

local avg_applicant_age = 3.4 // Kline and Walters (2016), Table IV and Appendix D
local age_benef = `avg_applicant_age'
local age_stat = `age_benef' // in kind benefit to kid

*% earnings impact of a 1𝜎 increase in test scores - Kline and Walters (2016) Table IV & Table A.IV
local val_1SD_inc_score = 0.1 
/* "Conservative" assumption made by the authors based on the range of estimates 
presented in Table A.IV, Appendix D
Chetty et al. (2011) experimental = 0.13; "" observational = 0.18; 
Heckman et al. (2010) males = 0.24 ; "" females = 0.292 */

*Average Present Discounted Value of Earnings in the U.S. (Age 12, 2010 USD)
deflate_to `usd_year', from(2010)
local disc_val_earn_us = 522000 * r(deflator)
*Kline and Walters (2016), Table IV and Appendix D; from Chetty et al. (2011)
local chetty_discount_rate = 0.03 // Kline and Walters 2016, Table IV

*Average Earnings of Head Start parents relative to average U.S. taxpayer
local rel_earn_head_start = 0.46 
*Kline and Walters (2016), Table IV and Appendix D; from DHHS 2013 Head Start Fact Sheet

*Intergenerational income elasticity
local igen_inc_elast = 0.4 // Kline and Walters (2016), Table IV and Appendix D; from Lee and Solon (2009)
/* Note: Mention in footnote that Chetty et al. (2014) find that the IGE is roughly 
constant at 0.414 for families between 10-90th percentile of the income distribution, 
but smaller for people in the tenth percentile. Given the IGE weighs parental income 
relative to average US income, a lower IGE would imply higher lifetime earnings from 
Head Start. */

*Proportion of parents who would switch from no preschool when offered head start
local crowd_out_parent_care = 0.550 - 0.095 // Table 3

*Get income of parents
*Parent average % of federal poverty line
local parent_pfpl = 0.892 // Kline and Walters 2016, Table I
*% of two parent households
local pct_2_par = 0.497  // Kline and Walters 2016, Table I
*Federal poverty lines
local fpl_2002_fam_4 = 18244 // FPL for family of 4, 2 kids in 2002, from Census source in get_tax_rate.ado
local fpl_2002_fam_3 = 14494 // FPL for family of 3, 2 kids in 2002, from Census source in get_tax_rate.ado

********************************
/* 4. Intermediate Calculations */
*********************************

*Estimate average parent income
local parent_inc = `parent_pfpl' * (`pct_2_par'*`fpl_2002_fam_4' + (1-`pct_2_par')*`fpl_2002_fam_3')

*Estimate parent age 
get_mother_age `program_year', yob(`=round(`program_year'-`avg_applicant_age')')
local mother_age = r(mother_age)

*Use parent income to predict child income at age 18 via est_life_impact
est_life_impact 1, ///
	impact_age(18) project_age(18) project_year(`=round(`impact_year'+18-`avg_applicant_age')') ///
	income_info(`parent_inc') income_info_type(parent_income) ///
	parent_age(`mother_age') parent_income_year(`program_year') ///
	earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
	end_project_age(`proj_age') usd_year(`usd_year')  // 18 is smallest impact age you can use
local cfactual_inc_18 = r(cfactual_income)

*Get tax rates
if "`tax_rate_assumption'" == "paper internal"	local tax_rate = 0.35 //Kline and Walters (2016), Table IV and Appendix D; from CBO (2012)
if "`tax_rate_assumption'" == "continuous"		local tax_rate = `tax_rate_cont'
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `cfactual_inc_18', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`=round(`impact_year'+18-`avg_applicant_age')') /// year of income measurement 
		program_age(18) ///
		earnings_type(individual) // individual or household
		
	local tax_rate = r(tax_rate)
}

*Earnings projections to replicate Kline and Walters MVPF calculation.
if "`proj_type'" == "paper internal" {
	
	*NOTE: Kline and Walters use a present-discounted lifetime earnings figure 
	//from Chetty et al. (2011) that uses a 3% discount rate for the lifetime 
	//earnings of parents of Head Start participants. To allow for the 
	//ability to use a different discount rate, we assume that the Chetty et al.
	//figure comes from a lifetime earnings path with the same shape as the path
	//used for our earnings projections (in est_life_impact.ado. (The  Chetty et 
	//al. figure is discounted back to age 12, so we also discount back to the
	//program year.)
	local chetty_disc_year = 12
	
	if `discount_rate' == `chetty_discount_rate' {
		local disc_val_earn_HSIS_par = `disc_val_earn_us' * (1/(1+`discount_rate')^(`chetty_disc_year'-`avg_applicant_age'))
	}
	
	if `discount_rate' != `chetty_discount_rate' {

		*First, load in earnings path data from ACS file, applying wage growth assumption:
		preserve
		use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear
		qui sum age
		local min_age = r(min)
		local max_age = r(max)
		local earn_total_undisc = 0
		forval i=`min_age'/`max_age' {
			qui sum wag if age==`i'
			local age_`i'_earn = r(mean)*((1 + `wage_growth_rate')^(`i'-`min_age')) 
			local earn_total_undisc = `earn_total_undisc' +  `age_`i'_earn'
		}
		restore
		
		*Next, compute (a) the fraction of total lifetime undiscounted earnings at each
		*age, and (b) the corresponding scalar multiple for converting the Chetty et al. 
		*discounted lifetime earnings figure to one using a potentially different discount rate:
		local disc_chetty = 0
		local disc_new = 0
		forval i=`min_age'/`max_age' {
			local age_`i'_frac = `age_`i'_earn'/`earn_total_undisc'
			local disc_chetty 	= `disc_chetty' + `age_`i'_frac' * (1/(1+`chetty_discount_rate')^(`i'-`chetty_disc_year'))
			local disc_new 		= `disc_new' 	+ `age_`i'_frac' * (1/(1+`discount_rate')^(`i'-`chetty_disc_year'))
		}
	
		*Multiply the Chetty et al. lifetime earnings figure by the scalar and
		*discount back to the program age to get the present-discounted lifetime 
		*earnings value for HSIS parents:
		local disc_val_earn_HSIS_par = `disc_val_earn_us' * (`disc_new'/`disc_chetty') * (1/(1+`discount_rate')^(`chetty_disc_year'-`avg_applicant_age'))
	}

	*Estimated discount lifetime earnings for HSIS participants via intergenerational income elasticity:
	local avg_disc_life_earn_HSIS = (1-((1-`rel_earn_head_start' )*`igen_inc_elast'))*`disc_val_earn_HSIS_par'
	
	*Get impact of test scores on discounted lifetime earnings:
	local life_earn_effect_HSIS = `test_score_effect'*`val_1SD_inc_score'*`avg_disc_life_earn_HSIS'

	*Get impact on earnings of other kids via spots vacated on other programs:
	local life_earn_effect_others = `prop_head_start_from_other'*`score_home_prek' * ///
		`val_1SD_inc_score' * `avg_disc_life_earn_HSIS'

}

*Alternatively, use our own projection methods:
if "`proj_type'" == "growth forecast" {	

	*Project impacts on Head Start participants as well as those subsequently crowded in to other programs:
	foreach effect in test_score_effect score_home_prek {
		*Get earnings impact from test scores:
		int_outcome, outcome_type(test score) impact_magnitude(``effect'') usd_year(`usd_year')
		local test_effect = r(prog_earn_effect)
		local age_start = r(earnings_gain_proj_start)
		
		*Now turn this into a lifetime impact:
		local dollar_effect_18 = `test_effect'*`cfactual_inc_18'
		est_life_impact `dollar_effect_18', impact_age(18) project_age(`age_start') ///
			project_year(`=round(`program_year'+`age_start' -`avg_applicant_age')') ///
			income_info(`cfactual_inc_18') income_info_type(counterfactual_income) ///
			earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
			end_project_age(`proj_age') usd_year(`usd_year') 

		local `effect'_life = r(tot_earn_impact_d) * (1/(1+`discount_rate'))^(`age_start' - `avg_applicant_age')
	}	

	local life_earn_effect_HSIS = `test_score_effect_life'
	local life_earn_effect_others =  `prop_head_start_from_other'*`score_home_prek_life'
}

*Tax impacts:
local govt_tax_rev = `tax_rate'*`life_earn_effect_HSIS'
local govt_rev_ration = `tax_rate'*`life_earn_effect_others'


**************************
/* 5. Cost Calculations */
**************************

*Cost saving from moving to head start, i.e. reduction in spend at other programs
local savings_shift_to_head_start = `prop_head_start_from_other' * `alt_prek_marginal_cost' * `head_start_enroll_cost'

local program_cost = `head_start_enroll_cost'

if "`rationing'" == "no" {
	local FE = `govt_tax_rev' + `savings_shift_to_head_start'
	/* In this scenario kids shifting to head start from other programmes
	causes a net reduction in kids enrolled in other programs */
}

if "`rationing'" == "yes" {
	local FE = `govt_tax_rev' + `govt_rev_ration'
	/* In this scenario the movement of kids into head start from other programmes
	causes spaces to open up in other programmes which are then taken. */
}

local total_cost = `program_cost' - `FE'


*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Earnings effects on head start kids always valued
	local WTP = (1-`tax_rate')*`life_earn_effect_HSIS'
	
	*If we assume rationing then earnings effects from other spots are also valued
	if "`rationing'" == "yes" local WTP = `WTP' + (1-`tax_rate')*`life_earn_effect_others'
	
	*If parents value transfer then add that too
	if "`incl_parents'" == "yes" {
		*Parents who move from own childcare value reduction in own costs
		local WTP = `WTP' + `crowd_out_parent_care'*`head_start_enroll_cost'
		*If there is rationing then other parents value moving from own childcare too
		if "`rationing'" == "yes" { 
			local WTP = `WTP' + `prop_head_start_from_other'*`alt_prek_marginal_cost'*`head_start_enroll_cost'
		}
	}
}

if "`wtp_valuation'" == "cost" local WTP = `program_cost'

if "`wtp_valuation'" == "reduction private spending" {
	local WTP = `crowd_out_parent_care'*`head_start_enroll_cost'
	if "`rationing'" == "yes" { 
		local WTP = `WTP' + `prop_head_start_from_other'*`alt_prek_marginal_cost'*`head_start_enroll_cost'
	}
}


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
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_inc_18' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = round(`program_year'+18-`avg_applicant_age')
global inc_age_stat_`1' = 18 

global inc_benef_`1' = `cfactual_inc_18' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = round(`program_year'+18-`avg_applicant_age')
global inc_age_benef_`1' = 18



