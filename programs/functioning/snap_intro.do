********************************
/* 0. Program: SNAP Intro    */
********************************

/*

Bailey, Hoynes, Rossin-Slater and Walker (2019) 
Is the social safety net a long term investment? Large scale evidence from the 
food stamps program

Hilary Williamson Hoynes and Diane Whitmore Schanzenbach (2012) 
"Work incentives and the Food Stamp Program" 
Journal of Public econ

Almond, D. and H. Hoynes and D. W. Schanzenbach (2011)
"Inside the War on Poverty: The Impact of Food Stamps on Birth Outcomes"

Hilary Hoynes, Diane Whitmore Schanzenbach, and Douglas Almond (2016) 
"Long-Run Impacts of Childhood Access to the Safety Net"
[to see how PSID vs administrative works]

*/

********************************
/* 1. Pull Global Assumptions */
********************************

local proj_type = "$proj_type" // "growth forecast"
local proj_age = $proj_age
local discount_rate = $discount_rate
local correlation = $correlation
local tax_rate_assumption = "$tax_rate_assumption" //"continuous" or "cbo"
if "`tax_rate_assumption'" == "continuous" {
	local tax_rate = $tax_rate_cont
	local tax_rate_parent = $tax_rate_cont
}
local VSL_2012_USD = ${VSL_2012_USD} //in millions
local include_VSL = "$include_VSL"
local QALY_2012_USD = ${QALY_2012_USD} //in thousands
local include_QALY = "$include_QALY"
local include_crime = "$include_crime"
local wtp_valuation = "$wtp_valuation"
local population = "$population" //combined, pre-school


******************************
/* 2. Estimates from Paper */
******************************
/*
local ch_log_earn_itt = 0.0114 //Bailey et al (2019) appendix table 2
local ch_log_earn_itt_se = 0.0034
local no_HS_par_earning_itt = -219 //Hoynes et al 2012 Table 1
local no_HS_par_earning_itt_se = 966
* impact on infant mortality, per 1000 live births
local neo_mort_itt =  -.197 //Almond et al (2011) Appendix table 10
local neo_mort_itt_se = .150 
local ch_earnings_itt = 3610 //Hoynes et al (2016) Table 4 
local ch_earnings_itt_se = 5064
local survive_2012 =  0.0007
local survive_202_se = 0.0003
local not_incarcerated =  0.0008
local not_incarcerated_se = 0.0004
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
* Ages
local age_stat = 32.135 // Hoynes et al (2016) Table 1
local age_kid = (0+5)/2 // effects on kids are for families with kids aged below 5

*USDA Report: Characteristics of Supplemental Nutrition Assistance Program Households: Fiscal Year 2015
local prop_to_kids_0_5 = 0.35 // https://fns-prod.azureedge.net/sites/default/files/ops/Characteristics2015.pdf table A1
local num_preschool_kids = 6119 // https://fns-prod.azureedge.net/sites/default/files/ops/Characteristics2015.pdf table 3.5
local num_hh_with_preschool = 4651 // https://fns-prod.azureedge.net/sites/default/files/ops/Characteristics2015.pdf table A1

local snap_participation_0_5 = 0.16 // Bailey et al (2019) appendix figure 2, number for <5 yo

local part_rate_par_earn = 0.06 //Hoynes et al 2012 table 1
local part_rate_white_mort = .13 //take up rate in the mortality paper
local part_rate_black_mort = .41 //take up rate in mortality paper 

local parent_income = 23473 // Hoynes et al. 2016 table 1

local average_snap_pp_78 = 26.77 // per month, https://fns-prod.azureedge.net/sites/default/files/pd/SNAPsummary.pdf
local avg_hh_size_no_HS = 3.29 //Hoynes and Schanzenbach (2009), Appendix Table 1

local WTP_1_USD_snap = 1 //Hoynes and Schanzenbach (2009) find that most people were inframarginal, so this suggests they value it like cash 

*Equivalent variation adjustment 
*NOTE: Adjustment only used as lower bound b/c Hoynes and Schanzenbach (2009) find that most people were inframarginal
local ev = .65 // Whitmore (2002) ("What Are Food Stamps Worth" WP)

local perc_parents_w_birth = 0.065 // assumption based on Currie & Gruber (1994)
/* "6.5% had a child in any given year during our sample period, so that about 11.4% of women 
in the relevant age range were pregnant at some point during the year"
Currie & Gruber 1994 p16 */

local avg_earnings_psid = 24495 //Hoynes et al (2016) Table 4 Y-mean

local years_effect = 6 // Bailey et al. 2019 -- Observed Mortality in 2012 conditional on being alive in 2000
local court_cost = 9264 // Heckman et al. 2010, Appendix Table H.14 
local incarceration_cost = 15934 // Heckman et al. 2010, Appendix Table H.14
local parole_cost = 6841 // Heckman et al. 2010, Appendix Table H.14
local years_incarcerated = 20 // Assumption of very high incarceration duration given the age of observed incarceration

local part_rate_ch_earn_psid = .43 //Hoynes et al (2016) p. 919 (for child earnings paper)
local expos_high_part_psid = .338 //Hoynes et al (2016) Table 1 


**********************************
/* 4. Intermediate Calculations */
**********************************
* get deflators
deflate_to 2005, from(1978)
local deflator_05_78 = r(deflator)
deflate_to 2005, from(2012)
local deflator_05_12 = r(deflator)
deflate_to 2005, from(2016)
local deflator_05_06 = r(deflator)

local parent_income_year = (1968+1978)/2 // Hoynes and Schanzenbach 2012 table 1 notes
local tax_rate_year = 1978 // get_tax_rate can't handle pre 1978
local usd_year = 2005 // hoynes and schanzenbach 2012

*Getting the tax rate
if "`tax_rate_assumption'" == "cbo" {
	get_tax_rate `parent_income', ///
		include_transfers(no) include_payroll($payroll_assumption) ///
		forecast_income(no) ///
		usd_year(`usd_year') ///
		inc_year(`tax_rate_year') ///
		earnings_type(individual) ///
		program_age(`=round(`age_stat')') 
		di r(pfpl)
		local tax_rate_parent = r(tax_rate)
}
di `tax_rate_parent'

*Adjust ITT figure for parents by participation to estimate TOT
local no_HS_par_earning_tot = `no_HS_par_earning_itt'/`part_rate_par_earn'
local tax_parents = `no_HS_par_earning_tot'*`tax_rate_parent'
di `tax_parents'

if "$kid_est_source"=="admin" {
	*Adjust ITT figure for children by participation to estimate TOT
	local ch_log_earn_tot = `ch_log_earn_itt'/`snap_participation_0_5'
	local ch_log_earn_tot_per_yr = `ch_log_earn_tot'/6 // children in sample have 6 years of SNAP exposure, want effect of one year

	if "`proj_type'" == "growth forecast" {
		local impact_age = 34
		local project_age = 18

		local project_year = `parent_income_year' + `project_age' - 5/2
		
		est_life_impact `ch_log_earn_tot_per_yr', ///
			impact_age(`impact_age') project_age(`project_age') end_project_age(`proj_age') ///
			project_year(`=round(`project_year')') usd_year(`usd_year') ///
			income_info(`parent_income') income_info_type(parent_income) ///
			earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
			percentage(yes) parent_age(`=round(`age_stat')') parent_income_year(`parent_income_year') ///
			max_age_obs(`=2000-1961') // oldest age in sample for 2000 census
			
		local child_earn = ((1/(1+`discount_rate'))^(`project_age' - 5/2)) * r(tot_earn_impact_d)
		local cfactual_income = r(cfactual_income)
		
			*Get tax rate for children
		if "`tax_rate_assumption'" ==  "cbo" {
			get_tax_rate `cfactual_income', ///
				include_transfers(yes) include_payroll($payroll_assumption) ///
				forecast_income(yes) ///
				usd_year(`usd_year') ///
				inc_year(`=round(`project_year' + `impact_age'- `project_age')') ///
				earnings_type(individual) ///
				program_age(`impact_age') 
				
			local tax_rate = r(tax_rate)
			local pfpl = r(pfpl)
		}
		
		local after_tax_ch_earn = (1-`tax_rate') * `child_earn'
		local tax_ch = `tax_rate' * `child_earn'
		
	}
}

if regexm("${kid_est_source}","psid") {
	*Adjust ITT figure for children by participation to estimate TOT
	local ch_earnings_tot_no_HS = `expos_high_part_psid'*`ch_earnings_itt' / ///
			`part_rate_ch_earn_psid' //treatment-on-treated calc


	if "`proj_type'" == "growth forecast" {
		local impact_age = 32 // table 1 in 2016 paper
		local project_age = 18

		local project_year = `parent_income_year' + `project_age' - 5/2
		
		est_life_impact `ch_earnings_tot_no_HS', ///
			impact_age(`impact_age') project_age(`project_age') end_project_age(`proj_age') ///
			project_year(`=round(`project_year')') usd_year(`usd_year') ///
			income_info(`parent_income') income_info_type(parent_income) ///
			earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
			parent_age(`=round(`age_stat')') parent_income_year(`parent_income_year')
			
		local child_earn = ((1/(1+`discount_rate'))^(`project_age' - 5/2)) * r(tot_earn_impact_d)
		local cfactual_income = r(cfactual_income)
		
		*Get tax rate for children
		if "`tax_rate_assumption'" ==  "cbo" {
			get_tax_rate `cfactual_income', ///
				include_transfers(yes) include_payroll($payroll_assumption) ///
				forecast_income(yes) ///
				usd_year(`usd_year') ///
				inc_year(`=round(`project_year' + `impact_age'- `project_age')') ///
				earnings_type(individual) ///
				program_age(`impact_age') 
				
			local tax_rate = r(tax_rate)
			local pfpl = r(pfpl)
		}

		local after_tax_ch_earn = (1-`tax_rate') * `child_earn'
		local tax_ch = `tax_rate' * `child_earn'
	}
}

local pre_school_per_hh = `num_preschool_kids'/`num_hh_with_preschool'

* Mortality effects -- neonatal 
local part_rate_mort = (`part_rate_white_mort' + `part_rate_black_mort')/2 
local mort_tot  = `neo_mort_itt' / `part_rate_mort'
local VSL_impact = -1000000* `VSL_2012_USD'* `deflator_05_12'*`mort_tot'/1000
di `VSL_impact'

* Mortality effects -- longevity
local survive_tot = `survive_2012'/`snap_participation_0_5'
local survive_tot_yr = `survive_tot'*`years_effect'
local survive_totl_yr_per_yr = `survive_tot_yr'/6 // children in sample have 6 years of SNAP exposure, want effect of one year
local QALY_impact = `QALY_2012_USD'* `deflator_05_12'*`survive_totl_yr_per_yr'*1000

*Crime Effects 
local incarcerated_per = `not_incarcerated'/`snap_participation_0_5'
local incar_per_yr = `incarcerated_per'/6 // children in sample have 6 years of SNAP exposure, want effect of one year
local cost_incar = `deflator_05_06'*`incar_per_yr'*(`court_cost' + `parole_cost' + (`incarceration_cost'*`years_incarcerated'))


**************************
/* 5. Cost Calculations */
**************************

local program_cost = `average_snap_pp_78'*12*`avg_hh_size_no_HS'*`deflator_05_78'
di "`average_snap_pp_78'*12*`avg_hh_size_no_HS'*`deflator_05_78'"
di `program_cost'

di `program_cost'
di `program_cost'*4.8/6
di `no_HS_par_earning_tot'

local FE = `tax_parents' 
di `tax_parents' 
di `FE'/`program_cost'
di `ch_log_earn_tot_per_yr'
di `tax_ch'/`program_cost'

di `prop_to_kids_0_5'*`tax_ch'* `pre_school_per_hh'/`program_cost'

di "`prop_to_kids_0_5'*`tax_ch'* `pre_school_per_hh'"

if "`population'" == "combined" {
	local FE = `FE' + `tax_ch'* `pre_school_per_hh'*`prop_to_kids_0_5'
	}
	if "`population'" == "preschool" {
	local FE = `FE' + `tax_ch'* `pre_school_per_hh'
	}

if "`include_crime'" == "yes"{
local FE = `FE' + `perc_parents_w_birth'*6*`cost_incar' //multiply incarceration costs by sample fraction
}


local total_cost = `program_cost' - `FE'
*FE per dollar from kids directly:
di (-`tax_ch'* `pre_school_per_hh' )/`program_cost'
*Overall FE per dollar weighted
di (`prop_to_kids_0_5'*`tax_ch'* `pre_school_per_hh' + `tax_parents')/`program_cost'

*************************
/* 6. WTP Calculations */
*************************

local WTP_adult = `WTP_1_USD_snap'*(`program_cost' + `no_HS_par_earning_tot'*0.3)
local WTP_kid = 0 

if "`include_VSL'" == "yes"{
local WTP_kid = `WTP_kid' + `perc_parents_w_birth'*`VSL_impact'
}

if "`include_QALY'" == "yes"{
 local WTP_kid = `WTP_kid' + `perc_parents_w_birth'*`QALY_impact'*6 //adjust for 6 ages of children where the effect could be observed
}

if "`wtp_valuation'" == "post tax"  {
	if "`population'" == "combined" {
		local WTP_kid = `WTP_kid' + `after_tax_ch_earn'* `pre_school_per_hh'*`prop_to_kids_0_5'
	}
	if "`population'" == "preschool" {
		local WTP_kid = `WTP_kid' + `after_tax_ch_earn'* `pre_school_per_hh'
	}
}

if "`wtp_valuation'" == "lower bound"  {
	local WTP_adult = `ev'*(`program_cost' + `no_HS_par_earning_tot'*0.3)
	local WTP_kid = 0
}
local WTP = `WTP_adult' + `WTP_kid'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'
di `total_cost'
di `WTP_adult'

di `program_cost'
di `no_HS_par_earning_tot'
di `tax_parents'
di `tax_rate_parent'
di `tax_parents'/`program_cost'

di `prop_to_kids_0_5'
di `pre_school_per_hh'
di `tax_ch'/`program_cost'
di `prop_to_kids_0_5'*`tax_ch'* `pre_school_per_hh'/`program_cost'

di `no_HS_par_earning_tot'*0.3
di `no_HS_par_earning_tot'*0.3/`program_cost'
di `WTP_adult'/`total_cost'

di `prop_to_kids_0_5'
di `pre_school_per_hh'
di `after_tax_ch_earn'/`program_cost'
di `prop_to_kids_0_5'*`after_tax_ch_earn'* `pre_school_per_hh'/`program_cost'



di `perc_parents_w_birth'
di `VSL_impact'
di `perc_parents_w_birth'*`VSL_impact'
di (`perc_parents_w_birth'*`VSL_impact')/`program_cost'
di `QALY_impact'
di `perc_parents_w_birth'*`QALY_impact'*5
di (`perc_parents_w_birth'*`QALY_impact'*5)/`program_cost'

di ((`perc_parents_w_birth'*`VSL_impact') + (`perc_parents_w_birth'*`QALY_impact'*5))/`program_cost'

di `incarcerated_per'
di `incarcerated_per'/6
di `cost_incar'
di `perc_parents_w_birth'*6*`cost_incar'
di (`perc_parents_w_birth'*6*`cost_incar')/`program_cost'


****************
/* 8. Outputs */
****************



di `total_cost'
di `total_cost' / `program_cost'
di `WTP'
di `MVPF'


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
if `WTP_kid'>`WTP'-`WTP_kid' {
	global age_benef_`1' = `age_kid'
	}
else {
	global age_benef_`1' = `age_stat'
}	


* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `parent_income'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `tax_rate_year'
global inc_age_stat_`1' =  `age_stat'

if `WTP_kid'/`WTP'>0.5 {
	global inc_benef_`1' = `cfactual_income'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = round(`project_year') +`impact_age' - `project_age'
	global inc_age_benef_`1' = `impact_age'
}
else {
	global inc_benef_`1' = `parent_income'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `tax_rate_year'
	global inc_age_benef_`1' =  `age_stat'
}

