********************************************
/* 0. Program: AFDC - Meyer and Rosenbaum Estimates */
********************************************
/*
Meyer, B. D., & Rosenbaum, D. T. (2001). 
Welfare, the earned income tax credit, and the labor supply of single mothers. 
The quarterly journal of economics, 116(3), 1063-1114.

Currie, Janet and Nancy Cole. 1993. 
"Welfare and Child Health: The Link Between  AFDC Participation and Birth Weight." 
American Economic Review 83 (4): 971-985.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************
local include_kids = "$include_kids"
local discount_rate = $discount_rate
local correlation = $correlation
local tax_rate_assumption = "$tax_rate_assumption" 
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate = $tax_rate_cont
}
local proj_age = $proj_age
local work_start_age 25

*********************************
/* 2. Estimates from Paper */
*********************************
/* a) Effects on labor force participation (LFP) of increasing maximum welfare benefit ($1000)
local lfp_effect = -0.0295 // Meyer and Rosenbaum (2001) Table IV 
local lfp_effect_se = 0.0038

*b) EFFECTS ON CHILD BIRTHWEIGHT
//Effect of AFDC during pregnancy for black children (Table 2, Column 4):
local afdc_bw_effect_bl = 4.567
local afdc_bw_effect_bl_se = 13.319

//Effect of AFDC during pregnancy for poor white children (Table 2, Column 8):
local afdc_bw_effect_wh = 32.002
local afdc_bw_effect_wh_se = 16.110
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



****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local usd_year = 1996 //USD year from Meyer & Rosenbaum (2001)

local taxes_if_work_1988 = 1030 //Meyer and Rosenbaum appendix 2
local welfare_if_work_1988 = 1478 //Meyer and Rosenbaum appendix 2

local welfare_takeup = 0.684 // Blank and Ruggles (1996), Table 1

*1988 USD monthly AFDC average per family (1988)
*WELFARE INDICATORS AND RISK FACTORS: THIRTEENTH REPORT TO CONGRESS. AFDC/TANF PROGRAM DATA (2014)
//https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/afdctanf-program-data
local monthly_afdc = 370 
*convert to 1996 USD
deflate_to `usd_year', from(1988)
local monthly_afdc = `monthly_afdc'*r(deflator)

*1988 USD monthly SNAP benefit PP (1988)
*WELFARE INDICATORS AND RISK FACTORS: THIRTEENTH REPORT TO CONGRESS. APPENDIX A. PROGRAM DATA (2014)
*https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/appendix-program-data
local monthly_snap_pp = 49.80
*convert to 1996 USD
deflate_to `usd_year', from(1988)
local monthly_snap_pp = `monthly_snap_pp'*r(deflator)

local avg_fam_size = 3 //Meyer and Rosenbaum 2001 show that in 1984 the average single mother has 1.681 children

*Assumptions for birthweight-effect calculations:
*Share of black/poor white children in Currie/Cole regression sample [black + poor white] (Table 1):
local currie_cole_share_bl = 346 / (346+ 263)
local currie_cole_share_wh = 1-`currie_cole_share_bl'

*In 1977 dollars (see APPENDIX: DEFINITIONS OF VARIABLES AND SOURCES)
local currie_cole_usd = 1977

*Average per-household-member AFDC benefit amount for mothers of black/white children Currie & Cole 1993 Table 1
*NOTE: For poor white children, using the figures for all white children, since C&C don't report amounts for poor white children only
local currie_cole_afdc_bl = 49
local currie_cole_afdc_wh = 57

*convert to 1996 USD
deflate_to `usd_year', from(`currie_cole_usd')
local currie_cole_afdc_bl = `currie_cole_afdc_bl'*r(deflator)
local currie_cole_afdc_wh = `currie_cole_afdc_wh'*r(deflator)

*Average household size for black/white children Currie & Cole 1993 Table 1
local currie_cole_hhsize_bl = 3.1
local currie_cole_hhsize_wh = 3.456

*Mean birthweight (in ounces) for black/white children Currie & Cole 1993 Table 1
local currie_cole_meanweight_bl = 111.14
local currie_cole_meanweight_wh = 118.39

*Mean family income for black/white children Currie & Cole 1993 Table 1
local currie_cole_meanincome_bl = 3570
local currie_cole_meanincome_wh = 5086
*convert to 1996 USD
deflate_to `usd_year', from(`currie_cole_usd')
local currie_cole_meanincome_bl = `currie_cole_meanincome_bl'*r(deflator)
local currie_cole_meanincome_wh = `currie_cole_meanincome_wh'*r(deflator)

*Mother's age at birth:
local mother_age_yrbirth = 21 //NLSY sample began with women ages 14 to 21 as of 1979; at midpoint
							  //of C&C's 1979-88 sample, this implies median age of roughly 21.

*Elasticity of adult earnings with respect to birthweight (Black et al. 2007):
local bw_earnings_effect = 0.1

*Share of mothers with birth in any given year (Currie and Gruber 1994):
local perc_parents_w_birth = 0.065

*Ackerman, Holtzblatt and Masken (2009), Table 2; Characteristics of Individual in First Year EITC Received
local eitc_single_women = 0.36 

*Calculate ages
local pct_with_kids = 10333/(19311+10333) // Meyer & Rosenbaum table 1, 1992
local age_with_kids = 31.96 // Meyer & Rosenbaum appendix table 2, 1992
local age_no_kids = 28.83 // Meyer & Rosenbaum appendix table 2, 1992
local age_stat = `pct_with_kids'*`age_with_kids' + (1-`pct_with_kids')*`age_no_kids'

local age_kid = 0 // effect is via LBW

*********************************
/* 4. Intermediate Calculations */
*********************************

local program_cost = 1000 

* T(0) is average government revenue for someone on welfare who is not working
local T_0 = -`welfare_takeup'*12*(`monthly_afdc' + `avg_fam_size'*`monthly_snap_pp')

* T(y) is average government revenue for someone on welfare if they are working 
local T_y = `taxes_if_work_1988' - `welfare_if_work_1988'

* The FE of increasing the maximum welfare benefit for single people is (T(y) - T(0)) * (change in LFP)
local FE = -(`T_y' - `T_0')*`lfp_effect'

/*
b) EFFECTS ON CHILDREN'S EARNINGS
As noted above, for earnings projections, we take a weighted average of estimated
treatment effects for black and poor white children - since we use the Black et al.
elasticity of adult earnings with respect to birthweight, the treatment effects
we average are in terms of percent changes in birthweight per dollar of AFDC. Thus,
separately for black/poor white children, we compute:
	i) 		Average annual per-household AFDC  
		NOTES: 	1) 	Assuming that C&C's figures are for 1983 (midpoint of 1979-88
				  	sample range).
				2) 	Because C&C report per-capita AFDC receipt and average HH size, 
					it's technically only correct to get per-HH AFDC by multiplying
					these two averages if either is a constant. However, Table 1 
					suggests that the variance of each of these is relatively small.)
	ii)		Percent change in birthweight.
	iii)	Percent change in birweight per dollar of AFDC (scaling by AFDC amount
			to easily combine with the Meyer/Rosenbaum estimates). 
*/

foreach x in bl wh {
	*AFDC per hh
	local afdc_perhh_`x' = `currie_cole_hhsize_`x''*12*`currie_cole_afdc_`x''
	*% BW effect
	local bw_effect_pct_`x' = `afdc_bw_effect_`x''/`currie_cole_meanweight_`x''
	*% birthweight impact of $1000 (`program_cost') policy
	local bw_effect_pct_afdc_`x' = `program_cost'*`bw_effect_pct_`x''/`afdc_perhh_`x''
}

*Combine estimates to get single treatment effect, then multiply by Black et al.
*estimate to get percent increase in annual adult earnings per dollar of AFDC in utero:
local bw_effect_pct_afdc = 	`currie_cole_share_bl'*`bw_effect_pct_afdc_bl' + ///
							`currie_cole_share_wh'*`bw_effect_pct_afdc_wh'

*Multiply by elasticity of earnings w.r.t BW
local afdc_earn_effect_pct_annual = `bw_earnings_effect'*`bw_effect_pct_afdc'

*Next, compute average parental earnings at year of birth in 1996 dollars:
local parent_earnings_yrbirth = `currie_cole_share_bl'*`currie_cole_meanincome_bl' ///
								+ `currie_cole_share_wh'*`currie_cole_meanincome_wh'

/*Compute PDV of children's future earnings gains (discounting back to year of birth):
Assumption: earnings impacts hit age 34 (to match what we do for college), projections
are from age 25 to `proj_age', children are born in 1983.*/
	local impact_age = 34
	local project_age = 25
	local parent_income_year = 1983
	local project_year = `parent_income_year' + `project_age'
	local usd_year = 1996

if "`include_kids'" == "yes" {

	est_life_impact `afdc_earn_effect_pct_annual', ///
		impact_age(`impact_age') project_age(`project_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`parent_earnings_yrbirth') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes) parent_age(`mother_age_yrbirth') parent_income_year(`parent_income_year')
	
	local child_earn = ((1/(1+`discount_rate'))^25) * r(tot_earn_impact_d)
	local cfactual_income = r(cfactual_income)
	
	*Get tax rate for children
	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `cfactual_income', ///
			include_transfers(yes) include_payroll($payroll_assumption) ///
			forecast_income(yes) ///
			usd_year(`usd_year') ///
			inc_year(`=`project_year' + `impact_age'- `project_age'') ///
			earnings_type(individual) ///
			program_age(`impact_age') 
			
		local tax_rate = r(tax_rate)
	}
}

* 2015 income to be passed to wrapper
deflate_to 2015, from(`usd_year')
local deflator = r(deflator)
local parent_income_2015 = `parent_earnings_yrbirth'*`deflator'
if "`include_kids'" =="yes" local kid_income_2015 =`cfactual_income'*`deflator'
**************************
/* 5. Cost Calculations */
**************************

if "`include_kids'"=="no" {
	local total_cost = `program_cost' + `FE'
}

if "`include_kids'"=="yes" {
	local total_cost = `program_cost' + `FE' - `tax_rate'*`child_earn'*`perc_parents_w_birth'
}

*************************
/* 6. WTP Calculations */
*************************

if "`include_kids'"=="no" {
	local WTP = `program_cost'
	local WTP_kid = 0
}

if "`include_kids'"=="yes" {
	local WTP = `program_cost' + (1-`tax_rate')*`child_earn'*`perc_parents_w_birth'
	local WTP_kid = (1-`tax_rate')*`child_earn'*`perc_parents_w_birth'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'

* income globals
global inc_stat_`1' = `parent_income_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `parent_income_year'
global inc_age_stat_`1' = `mother_age_yrbirth'

if `WTP_kid'/`WTP'>0.5 {
	global age_benef_`1' = `age_kid'
	global inc_benef_`1' = `kid_income_2015'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `project_year' +`impact_age' - `project_age'
	global inc_age_benef_`1' = `impact_age'

	}
else {
	global age_benef_`1' = `age_stat'
	global inc_benef_`1' = `parent_income_2015'
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `parent_income_year'
	global inc_age_benef_`1' = `mother_age_yrbirth'

}


