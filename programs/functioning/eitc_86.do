********************************************
/* 0. Program: EITC Adults - TRA 1986 Eissa & Liebman Estimates */
********************************************
/*
Eissa, Nada, and Jeffrey B. Liebman. 
"Labor supply response to the earned income tax credit." 
The quarterly journal of economics 111, no. 2 (1996): 605-637.

https://academic.oup.com/qje/article/111/2/605/1938452 

Eissa, Nada and Hoynes, Hilary.
"Taxes and the labor market participation of married couples: the earned income 
tax credit."
Journal of Public Economics (2004)
https://gspp.berkeley.edu/assets/uploads/research/pdf/Eissa-Hoynes-JPUBE-2004.pdf

Meyer, B. D., & Rosenbaum, D. T. (2001). 
Welfare, the earned income tax credit, and the labor supply of single mothers. 
The quarterly journal of economics, 116(3), 1063-1114.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************

local paper = "$paper"

*********************************
/* 2. Estimates from Paper */
*********************************
/*
Estimating the effect of the EITC on labor force participation

Eissa and Liebman (1996) The lfp for single women, Table III
local lfp_effect_eissa	0.028 
local lfp_effect_eissa_se	0.009

Meyer & Rosenbaum (2001) The lfp for single working women of a decrease in taxes of 1000$  Table IV
local lfp_effect_meyer	0.0273
local lfp_effect_meyer_se 0.0034

Effect of EITC on labor force participation for men
Eissa and Hoynes (2004), Table IV
local lfp_effect_men_eissa	0.011	
local lfp_effect_men_eissa_se 0.01
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
			local `est'_pe = r(mean)
		}
	restore
}


*Using the lfp effect from the desired paper // eissa or meyer
local lfp_effect = `lfp_effect_`=lower("`paper'")''

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local usd_year = 1996 // Meyer & Rosenbaum (2001)

*Get average age
local pct_w_kids = 20810/(20810+46287) //Eissa and Liebman (1996), Table I
local age_kids = 31.17 //Eissa and Liebman (1996), Table I
local age_no_kids = 26.78 //Eissa and Liebman (1996), Table I
local age_stat = `pct_w_kids'*`age_kids' + (1-`pct_w_kids')*`age_no_kids'
local age_benef = `age_stat' // single beneficiary

* Percent of population in different EITC segments, from Eissa and Hoynes 2004 Table 8
local prop_phasein = 0.088
local prop_flat = 0.06
local prop_phaseout = 0.429
local prop_above = 0.423

* Post tax income changes 1984->1996 with no behavioural change in different EITC segments for families - from Eissa and Hoynes 2004 Table 8
local gross_phasein = 1144
local gross_flat = 2424
local gross_phaseout = 1591
local gross_above = 0

* Post tax income changes 1984->1996 including behavioural change in different EITC segments for families - from Eissa and Hoynes 2004 Table 8
local net_phasein = 1289
local net_flat = 2355
local net_phaseout = 1455
local net_above = -41

*Taxes/welfare if working
local taxes_if_work_1984 = 1521 //Meyer and Rosenbaum appendix 2 (all 1996 USD)
local taxes_if_work_1988 = 1030 //Meyer and Rosenbaum appendix 2
local welfare_if_work_1988 = 1478 //Meyer and Rosenbaum appendix 2

*LFPR single women
local frac_work = 0.729 // Eissa and Liebman 1996, Table 2
*Earnings:
local avg_eitc_earnings = 18013 //Meyer and Rosenbaum (2001), Appendix Table 2, 
*1988 women with children, earnings if worked (in 1996 USD)

local welfare_takeup = 0.684 // Blank and Ruggles (1996), Table 1

*1986 USD monthly AFDC average per family (1986)
*WELFARE INDICATORS AND RISK FACTORS: THIRTEENTH REPORT TO CONGRESS. AFDC/TANF PROGRAM DATA (2014)
*https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/afdctanf-program-data
local monthly_afdc = 339 
*convert to 1996 USD
deflate_to `usd_year', from(1986)
local monthly_afdc = `monthly_afdc'*r(deflator)

di r(deflator)
di `monthly_afdc'

*1986 USD monthly SNAP benefit PP (1986)
*WELFARE INDICATORS AND RISK FACTORS: THIRTEENTH REPORT TO CONGRESS. APPENDIX A. PROGRAM DATA (2014)
*https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/appendix-program-data
local monthly_snap_pp = 45.50
*convert to 1996 USD
deflate_to `usd_year', from(1986)
local monthly_snap_pp = `monthly_snap_pp'*r(deflator)
di `monthly_snap_pp'

local avg_fam_size = 2.681 //Meyer and Rosenbaum (2001) show that in 1984 the average single mother has 1.681 children

local frac_married = 0.523 // Liebman (2000) table 6

*This is the lowest bracket above 3K in 1987
local tax_rate_marr = 0.15  // 1996 from https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf

*1987 EITC rate in different EITC segments
*from https://www.taxpolicycenter.org/sites/default/files/legacy/taxfacts/content/pdf/historical_eitc_parameters.pdf
*note: take max children of 2
local eitc_rate_phasein = -0.14
local eitc_rate_flat = 0
local eitc_rate_phaseout = 0.10
local eitc_rate_above = 0

*********************************
/* 4. Intermediate Calculations */
*********************************

* Get effect for singles

local eitc_increase = `taxes_if_work_1984'-`taxes_if_work_1988' //The change in taxes in 1996 USD$
if "`paper'" == "Meyer" {
	local lfp_effect = `lfp_effect'*`eitc_increase'/1000 // the meyer effect is per $1000 increase so we adjust to be the size of the 1986 program
}

* T(0) Government revenue if not working 
local T_0 = -`welfare_takeup'*12*(`monthly_afdc' + `avg_fam_size'*`monthly_snap_pp')
di `T_0'

* T(y) Government revenue if working
local T_y = `taxes_if_work_1988' - `welfare_if_work_1988'
di `T_y'

* The FE for single people is (T(y) - T(0)) * (change in LFP)
local FE_single = -(`T_y' - `T_0')*`lfp_effect'
di `FE_single'/`eitc_increase'

*Scale EITC increase by LFPR to get cost per person
local eitc_increase_scaled = `eitc_increase'*`frac_work'
/*
Note: Costs are scaled by the fraction of single mothers
in the labor force. 
*/


*Get effect for married
local total_gross = 0 
local total_rev_impact = 0
foreach seg in phasein flat phaseout above {
	*get effective tax rate in each segment
	local tax_`seg' = `tax_rate_marr' + `eitc_rate_`seg'' 
	*Get behavioural change in post tax income, then find implied revenue effect
	local rev_impact_`seg' = (`net_`seg'' - `gross_`seg'')*`tax_`seg''/(1-`tax_`seg'')
	di `tax_`seg''
	di `rev_impact_`seg''
	
	local total_gross = `total_gross' + `gross_`seg''*`prop_`seg''
	local total_rev_impact = `total_rev_impact' + `rev_impact_`seg''*`prop_`seg''
}

local FE_married = -`total_rev_impact'/`total_gross'
di `FE_married'


*Get SE for FE_married via assuming common t-stat with the lfp_effect for men
*estimated by Eissa & Hoynes. Get SE from uncorrected estimates.
local lfp_effect_men_eissa_uc = 0.011 // Eissa & Hoynes (2004) table IV
local lfp_effect_men_eissa_se = 0.01 // Eissa & Hoynes (2004) table IV
local lfp_effect_men_eissa_t = `lfp_effect_men_eissa_uc' / `lfp_effect_men_eissa_se'
local FE_married_t = `lfp_effect_men_eissa_t'
local FE_married_se = `FE_married'/`FE_married_t'

*Now apply correction applied to lfp effect for men to get corrected estimate
*of FE_married
local lfp_effect_men_t_corrected = `lfp_effect_men_eissa_pe'/`lfp_effect_men_eissa_se'
local FE_married_t_corrected = `lfp_effect_men_t_corrected'
local FE_married = `FE_married_t_corrected'*`FE_married_se'

* multiply by the mechanical increase in EITC (as things are calculated we get FE per $1)
local FE_married = `FE_married' * `eitc_increase_scaled'


di `FE_married'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `eitc_increase_scaled'

local total_cost = `program_cost' + `FE_single'*(1 - `frac_married') ///
	+ `frac_married'*`FE_married' 
	
*************************
/* 6. WTP Calculations */
*************************

local WTP = `eitc_increase_scaled'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

di `program_cost'
di `FE_single'
di `lfp_effect'
di 	`T_y' - `T_0'
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
global inc_stat_`1' = `avg_eitc_earnings' * r(deflator)
global inc_type_stat_`1' = "individual" //just mother earnings
global inc_year_stat_`1' = 1988
global inc_age_stat_`1' = 32 // Meyer & Rosenbaum (2001) table A2, 1988 single mothers

global inc_benef_`1' = `avg_eitc_earnings' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = 1988
global inc_age_benef_`1' = 32 // Meyer & Rosenbaum (2001) table A2, 1988 single mothers

