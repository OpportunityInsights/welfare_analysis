****************************************
/* 0. Program: Childhood Medicaid 1983 */
****************************************
/*
Card, David and Lara D. Shore-Sheppard. 
"USING DISCONTINUOUS ELIGIBILITY RULES TO IDENTIFY THE EFFECTS OF THE FEDERAL MEDICAID EXPANSIONS ON LOW-INCOME CHILDREN"
 The Review of Economics and Statistics, August 2004, 86(3): 752–766 

Lo Sasso, Anthony T., and Dorian G. Seamster. 
"How federal and state policies affected hospital uncompensated care provision 
in the 1990s." 
Medical Care Researc and Review 64, no. 6 (2007): 731-744.
http://journals.sagepub.com/doi/pdf/10.1177/1077558707305940

Wherry, Laura R., and Bruce D. Meyer. 
"Saving teens: using a policy discontinuity to estimate the effects of Medicaid eligibility." 
Journal of Human Resources (2016).
https://muse.jhu.edu/article/629231/pdf
(Appendix) https://uwpress.wisc.edu/journals/pdfs/JHRv51n03_article02_MeyerWherry_Appendix.pdf

Wherry, Laura R., Sarah Miller, Robert Kaestner, and Bruce D. Meyer. 
"Childhood Medicaid Coverage and Later-Life Health Care Utilization." 
Review of Economics and Statistics 100, no. 2 (2018): 287-302.
https://www.mitpressjournals.org/doi/pdf/10.1162/REST_a_00677
(Appendix) http://laurawherry.com/papers/Wherryetal_Appendix.pdf


*Thought experiment:
A Black child being born on October 1, 1983 instead of September 30, 1983.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local proj_type = "$proj_type" //takes value observed or fixed forecast (growth forecast is not relevant since no earnings)
local correlation = $correlation
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"

local vsl = ${VSL_2012_USD} // mi
local vsl_assumption = "$vsl_assumption" // include vsl in MVPF, yes or no

local wherry_et_al_spec = "$wherry_et_al_spec"

**Check that options are set in a way that corresponds to the logic of this program (25 years)
if "`proj_type'" != "observed" & "`proj_type'" != "fixed forecast" {
	di in red "`proj_type' is not a valid option for Child Medicaid 83"
	exit
}

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*

//0 = $1 of spending valued at $1, .6 = $1 of spending valued at 1/1.6
local moral_hazard_rate = 0.6  //Card and Shore-Sheppard (2004)
local moral_hazard_rate_se = .31

if "`wherry_et_al_spec'"=="cct_bw_selector" {
	*All estimates from CCT bandwidth selector specs
	*Causal Effect of Expanded Eligibility (being born post oct 1 1983) on Medicaid Coverage (Ages 8-14)
	local percent_increase_coverage = 0.077 //Table 2
	local percent_increase_coverage_se = (0.145 - 0.009)/(1.96*2) // From 95% C.I.

	*Causal Effect of Expanded Eligibility (being born post oct 1 1983) on Age 25 Publicly-Insured Hospitalization Costs
	local effect_pi_hosp_cost = -0.164 // Appendix Table 24
	local effect_pi_hosp_cost_se = (0.030 - -0.358)/(1.96*2) // From 95% C.I.

	*Causal Effect of Expanded Eligibility (being born post oct 1 1983) on Age 25 Publicly-Insured ED Costs
	local effect_pi_ed_cost = -0.049 // Appendix Table 24
	local effect_pi_ed_cost_se = (0.042 - -0.141)/(1.96*2) // From 95% C.I.
}

if "`wherry_et_al_spec'"=="ik_bw_selector" {
	*All estimates from IK bandwidth selector specs
	*Causal Effect of Expanded Eligibility (being born post oct 1 1983) on Medicaid Coverage (Ages 8-14)
	local percent_increase_coverage = 0.051 //Table 2
	local percent_increase_coverage_se = (0.099 - 0.003)/(1.96*2) // From 95% C.I.

	*Causal Effect of Expanded Eligibility (being born post oct 1 1983) on Age 25 Publicly-Insured Hospitalization Costs
	local effect_pi_hosp_cost = -0.158 // Appendix Table 24
	local effect_pi_hosp_cost_se = (-0.004 - -0.312)/(1.96*2) // From 95% C.I.

	*Causal Effect of Expanded Eligibility (being born post oct 1 1983) on Age 25 Publicly-Insured ED Costs
	local effect_pi_ed_cost = -0.043 // Appendix Table 24
	local effect_pi_ed_cost_se = (0.042 - -0.129)/(1.96*2) // From 95% C.I.
}

*LoSasso and Seamster (2007):
*Effect of Public Health Insurance Eligibility on Uncompensated Care Costs per Capita (2000USD)
local uncomp_care_raw = -12.847 // 2000 USD. LoSasso and Seamster (2007), Table 2.
local uncomp_cate_raw_se = 8.366

*Effect on Annual Mortality Rates for Black children (Per 10,000 People)
local effect_annual_mort = -0.443 //Meyer and Wherry (2016), Table 3; Black children, linear, four-year window
local effect_annual_mort_se = 0.126 

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
		drop *_pe
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
* keep the estimates from the relevant spec:
local suff = subinstr("`wherry_et_al_spec'", "_bw_selector", "",.)
foreach est in percent_increase_coverage effect_pi_hosp_cost effect_pi_ed_cost {
	local `est' = ``est'_`suff''
}

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

*Percent Gaining Eligibility
local percent_gain_elig = .1725 //Wherry et al (2018), Table 1, number for Black children

*Average Cumulative Gain in Eligibility Years (NHIS Est.)
local avg_gain_elig_years = 0.87  //Wherry et al (2018), Table 1, number for Black children

*cost per year of enrollment per child in 1991 (1991 USD)
local cost_medicaid_per_year_enroll = 902 // Wherry et al (2018), p. 14, footnote 31 (this is cost per child enrolled in Medicaid in 1991)

*Use assumptions to determine fiscal externality rate

****Number of 25 year old blacks (2009 Census)
local 25_yo_blacks = 617000 // 2009 Census; Wherry et al (2018), footnote 30
*% of ED and/or hospitalization costs that are publicly insured
local perc_pi_cost = .55 
/* Comes from Wherry et al. (2015) working paper version of Wherry et al. (2018); 
On page 28 they suggest 41% and 69% of the cost is borne by the govt. They dont 
provide the details on the calculation, so we take the midpoint of 55%.
*/

****Hospital
*Total Hospitalization Costs Observed for 25-year-old Black patients in-sample (2009 USD, mi)
local obs_hosp_cost = 88 //2009 USD. Footnote 29
*% 25-year old Black patients in-sample (relative to national)
local perc_black_samp_hosp = 0.38 //Wherry et al (2018), footnote 29

****Emergency Department
*Total ED Costs Observed for 25-year-old Black patients in-sample (2009 USD, mi)
local obs_ed_cost = 28 // 2009 USD. Wherry et al (2018), NBER WP version, p.27, footnote 24
*% 25-year old Black patients in-sample (relative to national)
local perc_black_samp_ed = 0.21 //Wherry et al (2018), NBER WP version, p.27, footnote 24

local percFPL = 1 /* "Children in families with incomes at or just below
the poverty line gained close to five additional years of eligibility if they were born in
October 1983 rather than just one month before." Wherry and Meyer p 558 */
local fpl_h4_c2_1991 13812 //change in eligibility happens when children are around 8
*********************************
/* 4. Intermediate Calculations */
*********************************
*Get ages
local age_kid = (14+8)/2 //Meyer and Wherry (2016) pg. 558

* Inflation adjust costs
foreach year in 1991 2000 2009 {
	deflate_to 2012, from(`year')
	local deflate_`year' = r(deflator)
	}
local cost_medicaid_per_year_enroll = `cost_medicaid_per_year_enroll'*`deflate_1991'
di `cost_medicaid_per_year_enroll'
local uncomp_care_year_elig = `uncomp_care_raw'*`deflate_2000' 
di `uncomp_care_year_elig'
local obs_hosp_cost = `obs_hosp_cost'*`deflate_2009'
di `obs_hosp_cost'
local obs_ed_cost = `obs_ed_cost'*`deflate_2009'
di `obs_ed_cost'

*Mechanical Cost of Medicaid Expansion
local take_up_rate = `percent_increase_coverage'/`percent_gain_elig'
di `take_up_rate'
local cost_per_child_year_elig = `cost_medicaid_per_year_enroll'*`take_up_rate'
di `cost_per_child_year_elig'

*Later Life Utilization Cost Savings: Hospital & Emergency Department
foreach type in hosp ed {
	local total_`type'_cost = `obs_`type'_cost'*`perc_pi_cost'*1000000 //Total Publicly-insured Hospitalization (ED) Costs in-sample (2012 USD)

	* per capita: first adjust for the fact that the sample does not cover the entire US, then divide by total number of Black 25 yo in the US
	local per_capita_pi_`type'_cost = (`total_`type'_cost'/`perc_black_samp_`type'')/`25_yo_blacks'
	
	local `type'_cost_year  = `per_capita_pi_`type'_cost'*`effect_pi_`type'_cost' //Annual Reduction in Publicly-Insured Hospitalization (ED) Costs (2012USD)
	}

di `hosp_cost_year'
di `ed_cost_year'
	
* get income level of the kids 
* use est life impact to estimate the kids incomes in adulthood based on their childhood household inc
* note that we only use the counterfactual incomes 
local parent_income_1991 = `percFPL'*`fpl_h4_c2_1991'
local parent_income_year = 1991
local usd_year = 1991
local kid_income_age = 34 // arbitrary
local kid_income_year = `parent_income_year' + `kid_income_age' - 8 // kids are about 8 in 1991
est_life_impact 0.1, ///
		impact_age(`kid_income_age') project_age(`kid_income_age') end_project_age(`=`kid_income_age'+1') ///
		project_year(`kid_income_year') usd_year(`usd_year') ///
		income_info(`parent_income_1991') income_info_type(parent_income) ///
		percentage("yes") parent_income_year(`parent_income_year') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method)
local kid_income_1991 = r(cfactual_income)
* now inflation adjust
deflate_to 2015, from(`usd_year')
local kid_income_2015 = `kid_income_1991'*r(deflator)

**************************
/* 5. Cost Calculations */
**************************

/* discounted costs for a child eligible for 7 years (from ages 8 to 14) - 
 adjusted for the fact the average gain in eligibility years per child was 0.87 in total pop, not 7 
 (spread over 7 years for discounting)*/
local program_cost = 0
forvalues j = 1/7{
	local program_cost_a`=`j'+7' = (`avg_gain_elig_years'/7)*(`cost_per_child_year_elig'/(1+`discount_rate')^(`j'-1))
	local program_cost = `program_cost' + `program_cost_a`=`j'+7''
}

di `program_cost'


/* treat reductions in uncompensated care in the same way as program costs above:
Start with effect of mc eligibility on UC costs, calculated discounted value over the
7 years of increased eligibility, and scale by the average gain in eligibility years per child relative to 7
*/
local uncomp_care_tot = 0
forvalues j = 1/7{
	local uncomp_care_a`=`j'+7' = (`avg_gain_elig_years'/7)*(`uncomp_care_year_elig'/(1+`discount_rate')^(`j'-1))
	local uncomp_care_tot = `uncomp_care_tot' + `uncomp_care_a`=`j'+7''
}

di `uncomp_care_tot'

* without projection: take into account hospital and ED cost reductions only for age 25
if "`proj_type'" == "observed"{
	local total_cost = `program_cost' + `uncomp_care_tot' + (`hosp_cost_year'+`ed_cost_year')*(1/(1+`discount_rate')^(25 - 8))
	local hosp_cost_a25 = `hosp_cost_year'
	local ed_cost_a25 = `ed_cost_year'
	if `proj_age'>25 {
		forval i = 26/`proj_age' {
			local hosp_cost_a`i' = 0
			local ed_cost_a`i' = 0
		}	
		}
	}

* fixed forecast for hospital and ED costs (assume the age 25 cost savings are repeated every year from 25 onwards):
if "`proj_type'" == "fixed forecast" {
	local total_hosp_cost = 0
	local total_ed_cost = 0
	if `proj_age'>=25 {
		forval i = 25/`proj_age' {
			local hosp_cost_a`i' = `hosp_cost_year'*(1/(1+`discount_rate')^(`i' - 8))
			local total_hosp_cost = `total_hosp_cost' + `hosp_cost_a`i''
			local ed_cost_a`i' = `ed_cost_year'*(1/(1+`discount_rate')^(`i' - 8))
			local total_ed_cost = `total_ed_cost' + `ed_cost_a`i''
		}
	}
	local total_cost = `program_cost' + `uncomp_care_tot' + `total_hosp_cost' + `total_ed_cost'
}
global observed_`1' = 25

*************************
/* 6. WTP Calculations */
*************************
/*Expected Value from mortality reductions at ages 15 to 18 (Discounted back to 1st year of spending)
(note the annual mortality effect is already the effect of being born post oct 1 1983, as desired)
*/
local disc_ev_life = 0
if "`vsl_assumption'" == "yes"{
di `effect_annual_mort'
di `vsl'
di -(`effect_annual_mort'/10000)*`vsl'*1000000
	forval i = 15/18 {
		local disc_ev_life = `disc_ev_life' -(`effect_annual_mort'/10000)*`vsl'*1000000*(1/(1+`discount_rate')^(`i'- 8))
	}
}
di `disc_ev_life'

/*
Insurance value: program cost adjusted for moral hazard minus benefits that would 
have otherwise been obtained through uncompensated care
*/
local ins_value = `program_cost'/(1+`moral_hazard_rate')+`uncomp_care_tot' 
di `ins_value'

if "`wtp_valuation'" == "post tax" {
	local WTP = `ins_value' + `disc_ev_life'
}
if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost'
}
if "`wtp_valuation'" == "reduction private spending" {
	local WTP = `ins_value'
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
global age_stat_`1' = `age_kid'
global age_benef_`1' = `age_kid'
* income globals
global inc_stat_`1' = `kid_income_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `kid_income_year'
global inc_age_stat_`1' = `kid_income_age'

global inc_benef_`1' = `kid_income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `kid_income_year'
global inc_age_benef_`1' = `kid_income_age'


forvalues k = 0/`proj_age'{
	if `k'<8 {
		global y_`k'_cost_`1' = 0
	}
	
	if `k'>=8 & `k' <= 14 {
		global y_`k'_cost_`1' =  ${y_`=`k'-1'_cost_`1'} + `program_cost_a`k'' + `uncomp_care_a`k''
	}
	if `k' >14 & `k' <25 {
		global y_`k'_cost_`1' =  ${y_`=`k'-1'_cost_`1'}
	}
	if `k'>=25 {
		global y_`k'_cost_`1' =  ${y_`=`k'-1'_cost_`1'} + `hosp_cost_a`k'' + `ed_cost_a`k''
	}
di `k'
di ${y_`k'_cost_`1'}
}

