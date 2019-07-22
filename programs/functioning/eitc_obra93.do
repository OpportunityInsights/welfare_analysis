********************************************************************************
*			1993 OBRA EITC Expansion
********************************************************************************

************************************************************************
/* 0. Program: Various policies from Meyer & Rosenbaum 2001 Estimates */
************************************************************************
/*
Hoynes, Hilary and Patel, Anku (2018). "Effective Policy for Reducing Poverty and Inequality? The Earned Income Tax Credit and the Distribution of Income." Journal of Human Resources

Meyer, Bruce and Rosenbaum, Dan (2001). "Welfare, the earned income tax credit and the
labor supply of single mothers." Quartlerly Journal of Economics

Eissa, Nada and Hoynes, Hilary (2004). "Taxes and the labor market participation of married couples: the earned income tax credit. Journal of Public Economics
https://gspp.berkeley.edu/assets/uploads/research/pdf/Eissa-Hoynes-JPUBE-2004.pdf

Chetty, Friedman and Rockoff (2011). "NEW EVIDENCE ON THE LONG-TERM IMPACTS OF TAX CREDITS." 104TH ANNUAL CONFERENCE ON TAXATION.
https://www.ntanet.org/wp-content/uploads/proceedings/2011/018-chetty-new-evidence-longterm-2011-nta-proceedings.pdf

Bastian and Michelmore. The Long-Term Impact of the Earned Income Tax Credit on Children’s Education and Employment Outcomes

Michelle Maxfield (2013). "The Effects of the Earned Income Tax Credit on Child
Achievement and Long-Term Educational Attainment."
Job market paper 2013

Manoli and Turner (2018) "Cash-on-Hand and College Enrollment: Evidence from
Population Tax Data and the Earned Income Tax Credit." American Economic Journal: Economic Policy (2018)

Michelmore, Katherine (2013). "The Effect of Income on Educational Attainment:
Evidence from State Earned Income Tax Credit Expansions."
Available at SSRN: https://ssrn.com/abstract=2356444 or http://dx.doi.org/10.2139/ssrn.2356444

Dahl, G and Lochner, L (2012). "The Impact of Family Income on Child Achievement: Evidence from the Earned Income Tax Credit." American Economic Review
*/


********************************
/* 1. Pull Global Assumptions */
*********************************
local kid_impact = "$kid_impact" // none, CFR, maxfield, DL, BM, BM_college, MT, michelmore
local paper = "$paper"
local wtp_valuation = "$wtp_valuation"
local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption"
if "`tax_rate_assumption'" == "continuous" local tax_rate_cont = $tax_rate_cont
local proj_age = $proj_age
local years_bach_deg = $years_bach_deg
local payroll_assumption = "$payroll_assumption"

local alt_transfer = "$alt_transfer"


*********************************
/* 2. Causal Inputs from Paper */
*********************************
* This section contains all the causal effects drawn upon for the various specifications of the MVPF calculation.
/*
* Hoynes and Patel (2018)
local poverty_effect_1kid = 0.084 // Hoynes and Patel (2018) table 1 col 2
local poverty_effect_1kid_t = 0.070/0.01
local poverty_effect_1kid_se = abs(`poverty_effect_1kid'/`poverty_effect_1kid_t')
local poverty_effect_2kids = 0.054 //Hoynes and Patel (2018) table 1 col 5
local poverty_effect_2kids_t = 0.042/0.01
local poverty_effect_2kids_se = abs(`poverty_effect_2kids'/`poverty_effect_2kids_t')

local lfp_effect_Meyer = 0.0273 //Table IV
local lfp_effect_Meyer_se = 0.0034 // Table IV


* IMPACTS ON KIDS
* CFR (2011)
local impact_CFR = 0.062 // CFR (2011) table 2 panel A reading score (most conservative)
local impact_CFR_se = 0.002 // CFR (2011) table 2 panel A reading score (most conservative)
local test_to_earn_CFR = 0.09 // CFR (2011) p. 122 "We estimate that a 1 SD increase in test scores raises earnings by approximately 9 percentage points. Hence, a $1,000 tax credit would raise a child’s lifetime earnings by 0.09 x 0.06 = 0.54pp"

* Bastian and Michelmore (2018)
local impact_BM = 564.0 // Bastian and Michelmore (2018) Table 2
local impact_BM_se = 244.9 // Bastian and Michelmore (2018) Table 2

/* "an additional $1,000 in EITC exposure when a child is 13–18 years old
increases the likelihood of completing high school (1.3%), completing college
(4.2%), and being employed as a young adult (1.0%) and earnings by 2.2%." */
/*
local impact_BM_13_18 = 564.0
local impact_BM_13_18_se = 244.9
local impact_BM_6_12 = 42.4
local impact_BM_6_12_se = 415.1
local impact_BM_0_5 = 646.1
local impact_BM_0_5_se = 818.3
*/
local impact_BM_college_13_18 = 0.013
local impact_BM_college_13_18_se = 0.005
local impact_BM_college_6_12 = 0.009
local impact_BM_college_6_12_se = 0.006
local impact_BM_college_0_5 = -0.007
local impact_BM_college_0_5_se = 0.019

* Dahl and Lochner (2017) impact on test scores
local impact_DL = 0.0411 // Dahl and Lochner, 2017
local impact_DL_se = 0.0131 // Dahl and Lochner, 2017

* Maxfield 2013 - impact on test scores
local impact_maxfield = 0.0717 // table 6
local impact_maxfield_se = 0.0274 // table 6

* Manoli and Turner (2018)
/*" we estimate that an additional $1,000 in cash-on-hand from tax refunds in
the spring of the high school senior year increases college enrollment in the
next year by 1.3 percentage points" p243
*/
local impact_MT = 0.01323 //MT 2018 table 2
local impact_MT_se = 0.352

* Michelmore 2013
local impact_michelmore = 0.01 //Table 5, Panel B, Column 1;
local impact_michelmore_se = 0.003

*Alt Transfer
local alt_imp_welf = -592
local alt_imp_welf_se = 61

local alt_imp_snap = -178
local alt_imp_snap_se = 36

local alt_imp_otran = -63
local alt_imp_otran_se = 73

local alt_imp_tax = -790
local alt_imp_tax_se = 163

*/


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
	local estimates_list ${estimates_${name}}
	foreach var in `estimates_list' {
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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local usd_year = 1996 // Meyer & Rosenbaum (2001)
local program_year = 1993
local parent_income_year = 1992

local lfp_effect_men_eissa_se = 0.01 // Eissa & Hoynes (2004) table IV
local mean_lfp_sing = 0.692 // Hoynes and Patel 2018, Table 1
*Calculate ages
local pct_with_kids = 10333/(19311+10333) // Meyer & Rosenbaum (2001) table 1, 1992
local age_with_kids = 31.96 // Meyer & Rosenbaum (2001) appendix table 2, 1992
local age_no_kids = 28.83 // Meyer & Rosenbaum (2001) appendix table 2, 1992
local age_stat = `pct_with_kids'*`age_with_kids' + (1-`pct_with_kids')*`age_no_kids'
if ("`kid_impact'" == "none" | "`kid_impact'" == "") local age_stat = `age_no_kids'

local age_kid_none 0 // not used in this case
local age_kid_CFR = 11.6 //CFR p117
local age_kid_MT = 18 // effects only for exposure at 18
local age_kid_michelmore = 18 // effects only for exposure at 18
local age_kid_BM = (0+18)/2 // effects for 0-18 yo exposure
local age_kid_BM_college = (0+18)/2 // effects for 0-18 yo exposure
local age_kid_maxfield = 7.65 // maxfield table 3
local age_kid_DL = 11.23 // Dahl and Lochner appx table A1
local age_kid = `age_kid_`kid_impact''

* earnings levels
local earnings_level_BM = 25391
local faminc_BM = 62430 // table 1
local avg_eitc_earnings = 17930 //Meyer and Rosenbaum (2001), Appendix Table 2, 1992 women with children, earnings if worked (in 1996 USD)

* taxes & transfers
local taxes_if_work_1996 = 79 //Meyer and Rosenbaum appendix 2
local welfare_if_work_1996 = 1488 //Meyer and Rosenbaum appendix 2

local welfare_takeup = 0.684 // Blank and Ruggles (1996), Table 1
local monthly_afdc = 373 // https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/afdctanf-program-data
local monthly_snap_pp = 67.95 // https://www.fns.usda.gov/sites/default/files/SNAPsummary.xls
local avg_fam_size = 2.681 //Meyer and Rosenbaum 2001 show that in 1984 the average single mother has 1.681 children

local number_kids = 2 // we assume families have two kids for all specs that include kid effects

* USD years for the various kids impacts
local year_CFR = 2010
local year_BM = 2013
local year_BM_college = 2013
local year_DL = 2000
local year_maxfield = 2008
local year_MT = 2015
local year_michelmore = 2011

* For calculating the FE for married couples:

local frac_married = 0.523 // Liebman 2000 table 6
* Percent of population in different EITC segments, from Eissa and Hoynes 2002 Table 8
local prop_phasein = 0.088
local prop_flat = 0.06
local prop_phaseout = 0.429
local prop_above = 0.423

* change in after tax income in different EITC segments holding behavior constant
*(i.e. change in EITC receipts holding labor supply constant) - from Eissa and Hoynes 2002 Table 8
local gross_phasein = 1144
local gross_flat = 2424
local gross_phaseout = 1591
local gross_above = 0

* total change in after tax income (inclusive of labor supply changes)
* in different EITC segments - from Eissa and Hoynes 2002 Table 8
local net_phasein = 1289
local net_flat = 2355
local net_phaseout = 1455
local net_above = -41


local tax_rate_marr = 0.15  // Marginal Tax rate in 1996, from https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf
* 1996 EITC rate in different EITC segments - from https://www.taxpolicycenter.org/sites/default/files/legacy/taxfacts/content/pdf/historical_eitc_parameters.pdf
*note: take max children of 2
local eitc_rate_phasein = -0.4
local eitc_rate_flat = 0
local eitc_rate_phaseout = 0.2106
local eitc_rate_above = 0

*********************************
/* 4. Intermediate Calculations */
*********************************
local poverty_effect = 0.5*(`poverty_effect_1kid' + `poverty_effect_2kids') // The paper does not report sample sizes for these two groups, so we assume a50/50 split


* Labor Supply Effect: We set the effect of EITC on LFP based on either Hoynes and Patel (2018) or Meyer and Rosenbaum (2001).
if "`paper'" == "Hoynes" {
	local lfp_effect = `poverty_effect'
}

if "`paper'" == "Meyer" {
	local lfp_effect = `lfp_effect_Meyer'
}

* T(0) = taxes - transfers of people with zero earnings. Based on the welfare take-up rate from Blank and Ruggles (1996) multiplied by yearly average AFDC and SNAP benefits, adjusted for inflation.
local T_0_1993 = -`welfare_takeup'*12*(`monthly_afdc' + `avg_fam_size'*`monthly_snap_pp')
deflate_to `usd_year', from(`program_year')
local deflator = r(deflator)
local T_0 = `T_0_1993'*`deflator'

* T(y) = taxes - transfers for employed people
local T_y = `taxes_if_work_1996' - `welfare_if_work_1996'

* FE for singles is entirely on the extensive margin - probability they enter the labor force
* Captures impact on government budget of labor force entry
local FE_single = -(`T_y' - `T_0')*`lfp_effect'

local control_mean_sing = `mean_lfp_sing' - (`lfp_effect'/2)
local induced_prog_cost_frac = `lfp_effect'/`control_mean_sing'

if "`alt_transfer'" == "yes" {

	*Scale Effects Per $1,000 in EITC
	local impact_ratio = 1.20 // Hoynes and Patel 2018, Table 4, ratio of results to results by $1,000
	local alt_imp_welf = `alt_imp_welf'*`impact_ratio'
	local alt_imp_snap = `alt_imp_snap'*`impact_ratio'
	local alt_imp_otran = `alt_imp_otran'*`impact_ratio'
	local alt_imp_tax = `alt_imp_tax'*`impact_ratio'

	local FE_single = (`alt_imp_tax' + 1000) + `alt_imp_snap' + `alt_imp_welf' + `alt_imp_otran'
	di `FE_single'
}

* For marrieds look at intensive margin. Net - gross gives change in after tax earnings due to change in labor supply. We translate this into tax revenue and take a weighted average (by population) over different segments of the EITC schedule.
local total_gross = 0
local total_rev_impact = 0
foreach seg in phasein flat phaseout above {
	local tax_`seg' = `tax_rate_marr' + `eitc_rate_`seg''
	local rev_impact_`seg' = (`net_`seg'' - `gross_`seg'')*`tax_`seg''/(1-`tax_`seg'')
	local total_gross = `total_gross' + `gross_`seg''*`prop_`seg''
	local total_rev_impact = `total_rev_impact' + `rev_impact_`seg''*`prop_`seg''
}

local FE_married = -`total_rev_impact'/`total_gross'
di 	`FE_married'


* Get SE for FE_married via assuming common t-stat with the lfp_effect for men
*estimated by Eissa & Hoynes. Get SE from uncorrected estimates.
local lfp_effect_men_eissa_uc = 0.011 // Eissa & Hoynes (2004) table IV
local lfp_effect_men_eissa_se = 0.01 // Eissa & Hoynes (2004) table IV
local lfp_effect_men_eissa_t = `lfp_effect_men_eissa_uc' / `lfp_effect_men_eissa_se'
local FE_married_t = `lfp_effect_men_eissa_t'

local FE_married_t = `lfp_effect_men_eissa' / `lfp_effect_men_eissa_se'
local FE_married_se = `FE_married'/`FE_married_t'

*Now apply correction applied to lfp effect for men to get corrected estimate
*of FE_married
local lfp_effect_men_t_corrected = `lfp_effect_men_eissa_pe'/`lfp_effect_men_eissa_se'
local FE_married_t_corrected = `lfp_effect_men_t_corrected'
local FE_married = `FE_married_t_corrected'*`FE_married_se'
di `FE_married'

* multiply by increase in EITC benefit, normalized to 1000 (as things are calculated we get FE per $1 )
local FE_married = `FE_married' * 1000*(1-`induced_prog_cost_frac')

if "`kid_impact'" == "CFR" local impact_CFR = `impact_CFR'*`test_to_earn_CFR' //multiply by their assumed effect of test score on earnings
* Make inflation adjustments for kid impacts - want every effect to be for a 1000 1996 USD incr in EITC. Because BM gives effects by age group, we adjust for each one.
if "`kid_impact'" != "none" {
		deflate_to `usd_year', from(`year_`kid_impact'')
		local adj = r(deflator)
		if !strpos("`kid_impact'", "BM") local impact = `impact_`kid_impact''/`adj'
		else {
			foreach age in 0_5 6_12 13_18 {
				local impact_`kid_impact'_`age' = `impact_`kid_impact'_`age''/`adj'
			}
		}
	}

deflate_to `usd_year', from(`year_BM')
local earnings_level_BM = `earnings_level_BM'*r(deflator)
local faminc_BM = `faminc_BM'*r(deflator) // Family income for BM estimates on kid's outcomes.

***EITC Kids Impacts***
local kid_earn = 0
local kid_earn_post = 0
local kid_tax = 0
local parent_age = round(`age_with_kids')


if "`kid_impact'" == "DL" | "`kid_impact'" == "maxfield"  {
	/// Forecast the impact on children's earnings when we use an estimate of improved
	int_outcome, outcome_type("test score") impact_magnitude(`impact') usd_year(`usd_year') //usd year irrelevant for test_score
	local test_effect = r(prog_earn_effect)

	local project_year = `program_year' + 18 - round(`age_kid') // increase in EITC happens in 1993, kids affect must be 0-18 then, so turn 18 (when projection starts) in 2002

	est_life_impact `test_effect', ///
		impact_age(34) project_age(18) project_year(`project_year') ///
		income_info(`avg_eitc_earnings') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age(`proj_age') usd_year(`usd_year') income_info_type(parent_income) ///
		parent_income_year(`parent_income_year') parent_age(`parent_age') percentage(yes)

		local one_kid_earn = r(tot_earn_impact_d)
		local cfactual_income = r(cfactual_income)
		local inc_year = round(`project_year' + 34 - 18)
		local program_age = 34
		local kid_earn = `number_kids'*`one_kid_earn' * (1/(1+`discount_rate'))^(`project_year' - `parent_income_year')
		if "`tax_rate_assumption'" == "cbo" {
			get_tax_rate `cfactual_income', ///
				inc_year(`inc_year') ///
				earnings_type(individual) ///
				usd_year(`usd_year') ///
				include_transfers(yes) forecast_income(yes) ///
				include_payroll("`payroll_assumption'")  program_age(`program_age')


	local tax_rate_cont = r(tax_rate)
	}
		local kid_tax = `kid_earn'*`tax_rate_cont'
		local kid_earn_post = `kid_earn' -  `kid_tax'
}

if "`kid_impact'" == "CFR"  {
	local project_year = `program_year' +18 - round(`age_kid') // increase in EITC happens in 1993, kids affect must be 0-18 then, so turn 18 (when projection starts) in 2002
	est_life_impact `impact', ///
		impact_age(34) project_age(18) project_year(`project_year') ///
		income_info(`avg_eitc_earnings') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age(`proj_age') usd_year(`usd_year') income_info_type(parent_income) ///
		parent_income_year(`parent_income_year') parent_age(`parent_age') percentage(yes)

		local one_kid_earn = r(tot_earn_impact_d)
		local cfactual_income = r(cfactual_income)

		local inc_year = round(`project_year' + 34 - 18)

		local program_age = 34
		local kid_earn = `number_kids'*`one_kid_earn' * (1/(1+`discount_rate'))^(`project_year' - `parent_income_year')

		if "`tax_rate_assumption'" == "cbo" {
			get_tax_rate `cfactual_income', ///
				inc_year(`inc_year') ///
				earnings_type(individual) ///
				usd_year(`usd_year') ///
				include_transfers(yes) forecast_income(yes) ///
				include_payroll("`payroll_assumption'")  program_age(`program_age')

	local tax_rate_cont = r(tax_rate)
	}


		local kid_tax = `kid_earn'*`tax_rate_cont'
		local kid_earn_post = `kid_earn' -  `kid_tax'

}


if "`kid_impact'" == "BM"{
	* Take the midpoint of each age bin as the average age of the category.
	local discount_age_0_5 = (0+5)/2
	local discount_age_6_12 = (6+12)/2
	local discount_age_13_18 = (13+18)/2
	local impact_age = round(0.5*(22+27)) // notes to table 2

* translate the impacts into % using the fact that the 13-18 one is a 2.2% effect
	foreach age in 0_5 6_12 13_18 {
		local pct_impact = `impact_BM_`age''/`earnings_level_BM'
		est_life_impact `pct_impact', ///
		impact_age(`impact_age') project_age(18) project_year(`=`program_year' + 18 - `discount_age_`age'''  ) ///
		income_info(`earnings_level_BM') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age(`proj_age') usd_year(`usd_year') income_info_type(counterfactual_income) percentage(yes)
	local one_kid_earn_`age' = r(tot_earn_impact_d) *(1/(1+`discount_rate'))^(18 - `discount_age_`age'')

	}
	* we assume a uniform distribution of kids over ages
	local kid_earn = `number_kids'*(`one_kid_earn_0_5'*(5 - 0 + 1)/(18-0 +1) + ///
	`one_kid_earn_6_12'*(12-6 + 1)/(18- 0 +1) + `one_kid_earn_6_12'*(18-13+1)/(18 - 0 +1))

	local inc_year = round(`program_year' - `discount_age_`age'' + `impact_age' )
	local program_age = `impact_age'
	if "`tax_rate_assumption'" == "cbo" {
		get_tax_rate `earnings_level_BM', ///
			inc_year(`inc_year') ///
			earnings_type(individual) ///
			usd_year(`usd_year') ///
			include_transfers(yes) forecast_income(yes) ///
			include_payroll("`payroll_assumption'") program_age(`program_age')

	local tax_rate_cont = r(tax_rate)
	}
	local cfactual_income = `earnings_level_BM'

	local kid_tax = `kid_earn'*`tax_rate_cont'
	local kid_earn_post = `kid_earn' -  `kid_tax'

	}

if "`kid_impact'" == "BM_college" {
	local discount_age_0_5 = (0+5)/2
	local discount_age_6_12 = (6+12)/2
	local discount_age_13_18 = (13+18)/2
	local impact_age = 0.5*(22+27) // notes to table 2

	local proj_start_age = 25

	foreach age in 0_5 6_12 13_18 {
		local years_impact = `impact_BM_college_`age''*`years_bach_deg'
		int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
		local pct_earn_impact = r(prog_earn_effect_pos)
		local priv_cost_impact = r(private_cost)
		local project_year = `program_year' + (`proj_start_age' - `discount_age_`age'')
		est_life_impact `pct_earn_impact', ///
			impact_age(34) project_age(`proj_start_age') project_year(`project_year') ///
			income_info(`faminc_BM') ///
			earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
			end_project_age(`proj_age') usd_year(`usd_year') income_info_type(parent_income) ///
			parent_age(`parent_age') parent_income_year(`parent_income_year') percentage(yes) // project from age 25 to be consistent with other college effects (but this is inconsistent with what we do for the test score effects above)

		local one_kid_earn_`age' = r(tot_earn_impact_d)*(1/(1+`discount_rate'))^(`proj_start_age' - `discount_age_`age'')
		local priv_cost_impact_`age' = `priv_cost_impact'*(1/(1+`discount_rate'))^(18 - `discount_age_`age'')
		}
	local cfactual_income = r(cfactual_income) // all the kids should have the same counterfactual income since comes from parent income
	local inc_year = round(`project_year' + 34 - `proj_start_age')
	local kid_earn = `number_kids'*(`one_kid_earn_0_5'*(5 - 0 + 1)/(18-0 +1) + ///
	`one_kid_earn_6_12'*(12-6 + 1)/(18- 0 +1) + `one_kid_earn_13_18'*(18-13+1)/(18 - 0 +1))
	local priv_cost_impact = `number_kids'*(`priv_cost_impact_0_5'*(5 - 0 + 1)/(18-0 +1) + ///
	`priv_cost_impact_6_12'*(12-6 + 1)/(18- 0 +1) + `priv_cost_impact_13_18'*(18-13+1)/(18 - 0 +1))
	local program_age = 34
	if "`tax_rate_assumption'" == "cbo" {
		get_tax_rate `cfactual_income', ///
				inc_year(`inc_year') ///
				earnings_type(individual) ///
				usd_year(`usd_year') ///
				include_transfers(yes) forecast_income(yes) ///
				include_payroll("`payroll_assumption'") program_age(`program_age')

	local tax_rate_cont = r(tax_rate)
	}

		local kid_tax = `kid_earn'*`tax_rate_cont'
		local kid_earn_post = `kid_earn' -  `kid_tax' - `priv_cost_impact'
}


if "`kid_impact'" == "MT" | "`kid_impact'" == "michelmore" {
	// Output measured by enrollment effects.
	int_outcome, outcome_type(enrollment) impact_magnitude(`impact') usd_year(`usd_year')

	local pct_earn_impact = r(prog_earn_effect_pos)
	local priv_cost_impact = r(private_cost)
	local tot_cost_impact = r(total_cost)
	local proj_start_age = 25
	local project_year = 1993 + (`proj_start_age' - `age_kid') // affected kids are 18 when their parents get the EITC bump in 1993

	est_life_impact `pct_earn_impact', ///
		impact_age(34) project_age(`proj_start_age') project_year(`project_year') ///
		income_info(`avg_eitc_earnings') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age(`proj_age') usd_year(`usd_year') income_info_type(parent_income) ///
		percentage(yes) parent_income_year(`parent_income_year') parent_age(`parent_age')

		local one_kid_earn = r(tot_earn_impact_d)
		local cfactual_income = r(cfactual_income)

		local inc_year = round(`project_year' + 34- `proj_start_age')
		local kid_earn = (`number_kids'/18)*`one_kid_earn' * (1/(1+`discount_rate'))^(`project_year' - `parent_income_year' ) /* we divide number of kids by 18 because effects are for kids whose parents receive a credit when they are 18 - assume uniform distrib of kids over ages*/

		local program_age = 34
		if "`tax_rate_assumption'" == "cbo" {
			get_tax_rate `cfactual_income', ///
				inc_year(`inc_year') ///
				earnings_type(individual) ///
				usd_year(`usd_year') ///
				include_transfers(yes) forecast_income(yes) ///
				include_payroll("`payroll_assumption'") program_age(`program_age')

	local tax_rate_cont = r(tax_rate)
	}


		local kid_tax = `kid_earn'*`tax_rate_cont'
		local kid_earn_post = `kid_earn' -  `kid_tax' ///
		- `priv_cost_impact'*`number_kids'* (1/(1+`discount_rate'))^(`project_year' - `parent_income_year' )

		}

**************************
/* 5. Cost Calculations */
**************************
local program_cost = 1000*(1-`induced_prog_cost_frac')  

// Normalization of EITC benefits.
// The total cost is a composition of the direct program costs, the fiscal extenalities due to changes in the labor supply, and the tax revenue from improvements in children's outcomes.
local total_cost = `program_cost' + `FE_single'*(1 - `frac_married') ///
	+ `frac_married'*`FE_married' - `kid_tax'

di `program_cost'
di `FE_single'
di `FE_married'

* get incomes in 2015 usd
deflate_to 2015, from(`usd_year')
local deflator = r(deflator)
local avg_eitc_earnings_2015 = `avg_eitc_earnings'*`deflator'
if "`kid_impact'"!="none" local cfactual_income_2015 = `cfactual_income'*`deflator'
*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "cost" local WTP = `program_cost'
if "`wtp_valuation'" == "post tax" local WTP = `program_cost' + `kid_earn_post'
local WTP_kid = `kid_earn_post' //

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

di `FE_single'
di `program_cost'


di `program_cost'
di `total_cost'
di `WTP'
di `kid_earn_post'
di - `kid_tax'
di `MVPF'
di `WTP_kid'
di -`kid_tax'
di ((`impact_BM_college_0_5'+`impact_BM_college_6_12'+`impact_BM_college_13_18')/3)
di `impact'


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
* income globals
global inc_stat_`1' = `avg_eitc_earnings_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `parent_income_year'
global inc_age_stat_`1' = `age_stat'


if `WTP_kid'>`=`WTP'*0.5'{
	global age_benef_`1' = `age_kid'
	global inc_benef_`1' = `cfactual_income_2015'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `inc_year'
	global inc_age_benef_`1' = `program_age'

	}
else {
	global age_benef_`1' = `age_stat'
	global inc_benef_`1' = `avg_eitc_earnings_2015'
	global inc_type_benef_`1' ="individual"
	global inc_year_benef_`1' = `parent_income_year'
	global inc_age_benef_`1' = `age_stat'

}
