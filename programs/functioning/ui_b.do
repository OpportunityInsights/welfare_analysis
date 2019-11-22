/*******************************************************************************
 0. Program: Unemployment Insurance Benefit Expansions
*******************************************************************************/

/*
Schmieder, Johannes F. and Till M. von Wachter. 2016. “The Effects of Unemployment
Insurance Benefits: New Evidence and Interpretation.” Annual Review of Economics
8: 547-581.

Gruber, Jonathan. 1997. "The Consumption Smoothing Benefits of Unemployment
Insurance." American Economic Review 87(1): 192-205.

David Card, Andrew Johnston, Pauline Leung, Alexandre Mas, and Zhuan Pei. 2015.
"The Effect of Unemployment Benefits on the Duration of Unemployment Insurance
Receipt: New Evidence from a Regression Kink Design in Missouri, 2003-2013."
NBER Working Paper No. 20869.

Chetty, Raj. 2008. "Moral hazard versus liquidity and optimal unemployment
insurance." Journal of Political Economy 116(2): 173-234.

Katz, Lawrence F. and Bruce D. Meyer. 1990. "The Impact of the Potential
Duration of Unemployment Benefits on the Duration of Unemployment." Journal of
Public Economics 41 (1): 45-72.

Kroft, Kory and Matthew J. Notowidigdo. 2016. "Should Unemployment Insurance
Vary with the Unemployment Rate? Theory and Evidence." Review of Economic
Studies 83 (3): 1092-1124.

Landais, Camille. 2015. "Assessing the Welfare Effects of Unemployment Benefits
Using the Regression Kink Design." American Economic Journal: Economic Policy 7
(4): 243-278.

Meyer, Bruce D. and Wallace K. C. Mok. "Quasi-Experimental Evidence on the Effects
of Unemployment Insurance from New York State." NBER Working Paper No. 12865.

Solon, Gary. 1985. "Work Incentive Effects of Taxing Unemployment Benefits."
Econometrica 53 (2): 295-306.

Hendren, Nathaniel. 2017. “Knowledge of Future Job Loss and Implications for
Unemployment Insurance.” American Economic Review 107 (7): 1778-1823.

Lindner, Stephan. 2016. "How Do Unemployment Insurance Benefits Affect the
Decision to Apply for Social Security Disability Insurance?" Journal of Human
Resources 51 (1): 62-94.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************
global payroll_assumption = "no"
local cons_source = "$cons_source" //estimate used for consumption drop
local FE_source = "$FE_source" //estimate used for FE

cap local discount_rate = $discount_rate
local rra_coeff = $rra_coeff //coefficient of relative risk aversion
local FE_assumption = "$FE_assumption" // "full" (labor tax)
local scale_WTP = "$scale_WTP" //"yes" or "no" (scaling consumption drop by amount of info revealed)
local incl_DI = "$incl_DI" //"yes" or "no" (include spillovers to DI in FE calculation)
local DI_disp = $DI_disp //displacement factor for UI spillovers to DI
local DI_incl_med = "$DI_incl_med"  //"yes" or "no" (including Medicare benefits in cost of SSDI award)

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
* Drops in consumption (WTP) - Schmieder and von Wachter 2016, Table 3:

	//Gruber 1997:
	//NOTES: 	Consumption drop is from Gruber 1994, Table 1. Treating the term in
	//			parentheses in that table as a SD and not SE and dividing by the
	//			square root of the sample size (n=1604) accordingly.
	local cons_gruber = 0.068
	local cons_gruber_se = 0.424/sqrt(1604)

	//Cochrane 1991:
	//NOTES: 	Schmieder and von Wachter use the midpoint of the two estimates in
	//			Table 2 (which reports estimates and t-stats). To get the corresponding
	//			SE, we assume (to be conservative) that the two estimates are
	//			perfectly correlated.
	local cons_cochrane = 0.255
	local cons_cochrane_se = 0.5*sqrt((0.2403/4.95)^2 + (0.2674/7.81)^2 + 2*(0.2403/4.95)*(0.2674/7.81))


	//Stephens 2001
	//NOTES:	The 9% consumption figure used by Schmieder and von Wachter is based
	//			on Table 2 - it's EXP("average of postshock effects") - 1. To account
	//			for this, will input the coefficients from the table here and will
	//			calculate the corresponding consumption drop post-bootstrap.
	local cons_stephens = -0.0975
	local cons_stephens_se = 0.0172

	//Chetty and Szeidl 2006:
	//NOTES:	This is mislabeled in the Schmieder/von Wachter table as "Chetty and
	//			Looney 2006." Source: Appendix Table II, Row 2
	local cons_chetty_szeidl = 0.106
	local cons_chetty_szeidl_se = 0.024

	//Rothstein and Valletta 2014
	//NOTES:	Schmieder/von Wachter's consumption drop estimates are based on
	//			income drops for the full 2001/2008 panels in the working paper
	//			version (cited in text, shown in Figure 5, but no corresponding
	//	 		table). We don't have t-stats for those, but we do have the SEs
	//			for the income drops for the UI exhaustee subsamples of each panel
	//			in Table 2. Using these for now.
	local cons_roth_vall_2001 = 0.1
	local cons_roth_vall_2001_se = `cons_roth_vall_2001'/(1554/157)

	local cons_roth_vall_2008 = 0.2
	local cons_roth_vall_2008_se = `cons_roth_vall_2008'/(1426/5306)

	//Kroft and Notowidigdo 2016
	//NOTES:	Source: Table 6
	local cons_kroft_noto = 0.069
	local cons_kroft_noto_se = 0.003

	//Ganong and Noel 2015 (working paper version)
	//NOTES:	Source: Table 4
	local cons_ganong_noel = 0.061
	local cons_ganong_noel_se = 0.001

*Fiscal externalities from benefit increases - Schmieder and von Wachter 2016, Table 2:
//NOTE: Schmieder and von Wachter have two FE estimates for each paper, one assuming
//		that lost labor income from employment is valued by the government at the
//		payroll tax rate (3%), one assuming that it is valued at the full labor
//		income tax rate. The latter matches what we use elsewhere and is conceptually
//		correct if we assume the government has a global, and not UI-only, budget
//		constraint, so we use this as our baseline.

	//Solon 1985
	//NOTES:	Solon estimates a structural model of unemployment duration. The implied
	//			semi-elasticity of duration wrt benefit amount is given as the ratio
	//			of two model parameters (see his equation (3)). To get a t-stat for the
	//			elasticity underlying the FE estimates, We make the following
	//			assumptions: (a) the denominator of this ratio (alpha) is not stochastic
	//			and is not mean-zero (to avoid issues related to the Cauchy distribution's
	//			lack of moments - estimate: 0.799, SE: 0.010); (b) the t-stat for the
	//			elasticity is the same as the t-stat for the semi-elasticity (so
	//			the same as the t-stat for the numerator of the ratio given assumption
	//			(a). Source; Table 1, Column 1.
	local FE_solon_full = 0.14
	local FE_solon_full_se = `FE_solon_full'/(0.0071/0.0012)

	//Katz and Meyer 1990
	//NOTES:	Katz and Meyer estimate a proportional hazards model and then run
	//			policy simulations on their data. For both extensions and benefits,
	//			there is a single model parameter - and so, given that we don't
	//			have the underlying data, we assume that the t-stat for the elasticity
	//			underlying S/vW's FE estimate is the same as the t-stat for that
	//			parameter in their model. Source: Table 2, Column 2.

	local FE_katz_meyer_full = 1.74
	local FE_katz_meyer_full_se = `FE_katz_meyer_full'/(0.004/0.0015)

	//Meyer and Mok 2007
	//NOTES:	Schmieder/von Wachter use three different elasticity estimates for
	//			Meyer and Mok: the first uses their constant-hazard approximation,
	//			the second two are the high/low values from	their duration model.
	//			As with Katz and Meyer, for the duration model
	//			(which comes from simulations involving their data) we assume that
	//			the the t-stat for S/vW's FE estimate is the same as the t-stat for that
	//			parameter in their model. Source: Table 6, Column 5 (Tobit); Table 8,
	//			Column 8 (low duration model estimate); Table 8, Column 2 (high
	//			duration model estimate).
	//			Since these all correspond to the same sample/policy change, we
	//			use the middle of the three estimates ("meyer_hi").
	local FE_meyer_ch_full = 0.81
	local FE_meyer_ch_full_se = `FE_meyer_tob_full'/(0.6085/0.1445)

	local FE_meyer_lo_full = 0.16
	local FE_meyer_lo_full_se = `FE_meyer_lo_full'/(0.1794/0.0848)

	local FE_meyer_hi_full = 0.31
	local FE_meyer_hi_full_se = `FE_meyer_hi_full'/(0.3468/0.0599)

	//Chetty 2008
	//NOTES:	Source: Table 2, Column 1.
	local FE_chetty_full = 0.71
	local FE_chetty_full_se = `FE_chetty_full'/(0.527/0.267)

	//Landais 2015
	//NOTES:	Source: Table 4, Column 1.
	local FE_landais_full = 0.4
	local FE_landais_full_se = `FE_landais_full'/(0.73/0.11)

	//Kroft and Notowidigdo 2016
	//NOTES:	Source: Table 1, Column 1.
	local FE_kroft_noto_full = 1.43
	local FE_kroft_noto_full_se = `FE_kroft_noto_full'/(0.632/0.332)

	//Card et al. 2015
	//NOTES:	These are from the NBER working paper version, NOT the AER cited by
	//			Schmieder and von Wachter. Unable to find exact S/vW estimates in
	//			Card et al.'s tables, so using the estimates that are closest (shouldn't
	//			matter much given that everything is highly significant). Source: Table 1,
	//			Column 4. First estimates are for post-period (recession), second
	//			are for pre-period (expansion).
	local FE_card_rec_full = 1.68
	local FE_card_rec_full_se = `FE_card_rec_full'/(0.684/0.067)

	local FE_card_exp_full = 0.59
	local FE_card_exp_full_se = `FE_card_exp_full'/(0.356/0.041)


*Information revealed at onset of unemployment - Hendren 2007, Appendix Table I:
local revealed_info_tm1 = 0.1968
local revealed_info_tm1_se = 0.0120

*Reduction in SSDI applications from additional UI benefits - Lindner 2016,
*Table 6, Column 4
//NOTES:	Lindner's logit-model estimates are semielasticities of the log
//			odds ratio of DI application with respect to the UI monthly benefit
//			amount (in hundreds of dollars). However, as he points out
//			footnote (20) for small probabilities these can be interpreted as
//			semielasticities of the conditional probability of application. He
//			himself uses this approximation in his cost-benefit analysis, so
//			following that here. Using the full logit model (Column 4).
local lindner_di_reduc = -6.19
local lindner_di_reduc_se = 4.73

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
			use "${input_data}/causal_estimates/${folder_name}/draws/ui_b.dta", clear

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
		import delimited "${input_data}/causal_estimates/${folder_name}/ui_b.csv", clear

		levelsof estimate, local(estimates)
		foreach est in `estimates' {
			qui su pe if estimate == "`est'"
			local `est' = r(mean)
		}
	restore
}

local cons_est "cons_`cons_source'"
local FE_est "FE_`FE_source'_`FE_assumption'"

*********************************
/* 3. Exact Inputs from Paper  */
*********************************
*Baseline probability of DI application for UI beneficaries - Lindner 2016,
*p. 86 ("...application probability of 1.68 percent as found in the individual-
*level sample...")
local DI_app_baseline 0.0168

*DI approval probability - Lindner 2016, p. 86 ("The application success
*probability for DI applicants is about 60 percent in the sample.")
local DI_approval_prob = 0.60

* Average UI length in months - for now, assuming 16 weeks to approx. match national average
* for regular UI programs in 1997
* (Souce: Department of Labor: https://oui.doleta.gov/unemploy/claimssum.asp, 1997 U.S. Total)
* (we need this to scale the DI spillovers, since otherwise we'd be estimating
* the FE per dollar of monthly benefits instead of dollar of total UI benefits).
local UI_claim_len = 4

*Figures from von Wachter, Song, and Manchester (2011), Web Appendix G used in
*calculating spillovers from reduced DI applications (all figures for men from
*Appendix Table G3, for women from Appendix Table G4):
//NOTES:	For now, we are using vWSM's average values for all 1997 male/female
//			new DI applicants and will combine these values below using the gender
//			shares in their data. We thus assume that UI recipients who are induced
//			not to apply to DI by additional benefits have the same characteristics
//			as the pool of all 1997 SSDI applicants.
//Average time on SSDI (tenths of years [see below for explanation]):
local di_dur_m = 100
local di_dur_f = 117
//PDV of SSDI benefits (not including Medicare, 1997$):
local di_ben_nomed_pdv_m = 133700
local di_ben_nomed_pdv_f = 115720
//PDV of SSDI benefits (including Medicare, 1997$):
local di_ben_med_pdv_m = 178570
local di_ben_med_pdv_f = 168242
//Share of 1997 new beneficaries who are male:
local di_share_m = 199772/(199772+194314)

*Year of UI program implementation:
if "`FE_source'"=="card_exp"	local year_implementation 2005
if "`FE_source'"=="card_rec" 	local year_implementation 2010
if "`FE_source'"=="chetty" 		local year_implementation 1992
if "`FE_source'"=="katz_meyer" 	local year_implementation 1980
if "`FE_source'"=="kroft_noto" 	local year_implementation 1992
if "`FE_source'"=="landais" 	local year_implementation 1980
if "`FE_source'"=="meyer_hi" 	local year_implementation 1989
if "`FE_source'"=="meyer_lo" 	local year_implementation 1989
if "`FE_source'"=="meyer_tob" 	local year_implementation 1989
if "`FE_source'"=="solon" 		local year_implementation 1979

*Age of UI beneficiary:
if "`FE_source'"=="card_exp"	local age_stat = (18+65)/2 	// no relevant age info so take working ages
if "`FE_source'"=="card_rec" 	local age_stat = (18+65)/2 	// no relevant age info so take working ages
if "`FE_source'"=="chetty" 		local age_stat = 37 		// Mean age in SIPP sample (Table 1)
if "`FE_source'"=="katz_meyer" 	local age_stat = 33 		// Mean age in PSID sample (Table 1)
if "`FE_source'"=="kroft_noto" 	local age_stat = 37 		// Mean age in SIPP sample (Table 1)
if "`FE_source'"=="landais" 	local age_stat = 34 		// Mean age in Washington state sample (Table 1).
if "`FE_source'"=="meyer_hi" 	local age_stat = (18+65)/2 	// no relevant age info so take working ages
if "`FE_source'"=="meyer_lo" 	local age_stat = (18+65)/2 	// no relevant age info so take working ages
if "`FE_source'"=="meyer_tob" 	local age_stat = (18+65)/2 	// no relevant age info so take working ages
if "`FE_source'"=="solon" 		local age_stat = (18+65)/2 	// no relevant age info so take working ages
local age_benef = `age_stat' // single beneficiary

*Income of beneficiaries:
**NOTE: We unfortunately were not able to identify an income level for the beneficiaries
* of the policy evaluated in Solon (1985).
if "`FE_source'"=="card_exp"{
	local benefit_03 = 250 //max benefit 2003 (footnote 10 in NBER version)
	local benefit_04 = 250 //max benefit 2004 (footnote 10 in NBER version)
	local benefit_05 = 250 //max benefit 2005 (footnote 10 in NBER version)
	local benefit_06 = 270 //max benefit 2006 (footnote 10 in NBER version)
	local benefit_07 = 280  //max benefit 2007 (footnote 10 in NBER version)
	local num_yrs_averaged = 5
	local percent_of_q_earn = .04 // pg. 2 of NBER WP
	local quarters_in_yr = 4

	forvalues i = 3/7{
		local earn_0`i' = (`benefit_0`i''/`percent_of_q_earn')*`quarters_in_yr'
		deflate_to 2015, from(200`i')
		local deflator = r(deflator)
		local earn_0`i'_15 = `earn_0`i''*`deflator'
	}

	local earn_avg_15 = (`earn_03_15'+ `earn_04_15' + `earn_05_15' + `earn_06_15' + `earn_07_15')/ `num_yrs_averaged'
	local year_earn = (2003 + 2004 +2005+ 2006 +2007)/ `num_yrs_averaged'
}
if "`FE_source'"=="card_rec"{
	local benefit = 320 //max benefit 2008 onwards (footnote 10 in NBER version)
	local num_yrs_averaged = 6
	local percent_of_q_earn = .04  //pg. 2 of NBER WP
	local quarters_in_yr = 4
	local earn_each_yr = (`benefit'/`percent_of_q_earn')*`quarters_in_yr'

	forvalues i = 8/13{
		local year = 2000+ `i'

		deflate_to 2015, from(`year')
		local deflator = r(deflator)
		local earn_`i'_15 = `earn_each_yr'*`deflator'
	}

	local earn_avg_15 = (`earn_8_15'+ `earn_9_15 '+ `earn_10_15' + `earn_11_15' + `earn_12_15' + `earn_13_15' )/ `num_yrs_averaged'
	local year_earn = (2008 + 2009 + 2010 + 2011 + 2012 + 2013)/ `num_yrs_averaged'
}
if "`FE_source'"=="chetty"{
	local mean_wage = 20711 //Table 1
	local earn_USD_year = 1990 //Table 1 footnotes

	deflate_to 2015, from(`earn_USD_year')
	local deflator = r(deflator)
	local earn_avg_15 = `mean_wage'*`deflator'

	local num_yrs_averaged = 8 //years in Table 1 footnotes
	local year_earn = (1985 + 1986 + 1987 + 1990 + 1991 + 1992 + 1993 + 1996)/`num_yrs_averaged'
}

if "`FE_source'"=="katz_meyer"{
	**These measures are based on the PSID sample rather than the Moffit sample
	local weeks_work_per_year = 50 //assumption
	local hours_worked_per_wk = 40 //assumption
	local wage_per_hour = 7.95 //Table 1, UI = 1
	local ind_income = `weeks_work_per_year'* `hours_worked_per_wk'* `wage_per_hour'
	local year_earn = 1980 //pg. 51

	*Paper does not say explicitly that this measure is in 1980 USD, but this makes sense for 1980-1981 data
	local earn_USD_year = 1980
	deflate_to 2015, from(`earn_USD_year')
	local deflator = r(deflator)
	local earn_avg_15 = `ind_income'*`deflator'
}
if "`FE_source'"=="kroft_noto"{
	local earnings = 20920 //Table 1
	local earn_USD_year = 2000 //Table 1 footnotes
	local first_year_earn = 1985 //Table 1 footnotes
	local last_year_earn = 2000 //Table 1 footnotes

	deflate_to 2015, from(`earn_USD_year')
	local deflator = r(deflator)
	local earn_avg_15 = `earnings'*`deflator'

	local year_earn = round((`first_year_earn' + `last_year_earn')/2)
}

if "`FE_source'"=="landais"{

local quarters_in_yr = 4

*Values for each state in Table 1 (except start years on pg. 27)
	local idaho_hqw = 9835
	local idaho_kink_over_hqw = 1.44
	local idaho_n = 33125
	local idaho_start = 1976

	local louis_hqw = 9538
	local louis_kink_over_hqw = 1.65
	local louis_n = 44702
	local louis_start = 1979

	local miss_hqw = 8218
	local miss_kink_over_hqw = .98
	local miss_n = 28599
	local miss_start = 1978

	local nmex_hqw = 8252
	local nmex_kink_over_hqw = 1.3
	local nmex_n = 27004
	local nmex_start = 1980

	local wash_hqw = 8982
	local wash_kink_over_hqw = 1.49
	local wash_n = 41992
	local wash_start = 1979

	local earn_USD_year = 2010

	local last_year_earn = 1984 //pg. 27

	foreach state in "idaho" "louis" "miss" "nmex" "wash"{
		local `state'_kink = ``state'_kink_over_hqw' * ``state'_hqw'
		local `state'_earn = ``state'_kink' * `quarters_in_yr'
		local `state'_year = (``state'_start' + `last_year_earn')/2
	}

	local total_n = `idaho_n' + `louis_n' + `miss_n' + `nmex_n' + `wash_n'
	local year_earn = round((`idaho_n'/`total_n')*`idaho_year' + (`louis_n'/`total_n')*`louis_year' + (`miss_n'/`total_n')*`miss_year' + (`nmex_n'/`total_n')*`nmex_year' + (`wash_n'/`total_n')*`wash_year')
	local earn_avg_10 = (`idaho_n'/`total_n')*`idaho_earn' + (`louis_n'/`total_n')*`louis_earn' + (`miss_n'/`total_n')*`miss_earn' + (`nmex_n'/`total_n')*`nmex_earn' + (`wash_n'/`total_n')*`wash_earn'

	deflate_to 2015, from(`earn_USD_year')
	local deflator = r(deflator)
	local earn_avg_15 = `earn_avg_10'*`deflator'
}
if inlist("`FE_source'","meyer_hi", "meyer_lo", "meyer_ch") {
* Meyer and Mok (2007) appx table 2: weekly earnings * weeks worked for each of the earnings groups, weighted by sample size
	local avg_earnings = (17878*696.470*44.203 + 12884*407.263*42.639 + 52699*228.199*38.857)/(17878 +12884+52699)
	local year_earn = 1988

	deflate_to 2015, from(1988)
	local earn_avg_15 = `avg_earnings'*r(deflator)
}

*********************************
/* 4. Intermediate Calculations */
*********************************

*If using Stephens (2001) WTP, calculate corresponding consumption drop:
if "`cons_source'"=="stephens" {
	local `cons_est' = 1-exp(``cons_est'')
}

*PDV of SSDI benefits and lost earnings:
//NOTES:	Lindner's estimates are for the reduction in DI application likelihood
//			conditional on unemployment, not for a reduction in the lifetime
//			probability of EVER applying for DI. To allow for the possibility that
//			UI delays, but does not fully prevent, DI application, we use the
//			parameter $DI_disp to scale the amount of time additional UI benefits
//			displace DI applications (where 1 = full displacement and 0 = no
//			displacement). Our procedure for the PDV calculations is as follows:
//			a.	For each of men and women, back out the implied per-period flow
//				(assuming it's constant) from the vSWM PDVs (which use a 3% annual
//				discount rate). Since they experess average time on DI to the 0.1
//				place, we use tenths of a year.
//			b. 	Scale the average length of time on DI for each of men and women
//				by $DI_disp.
//			c.	Recompute the PDV for each of men and women using the per-period
//				flow computed in (a) and the length of time in (b) and our global
//				discount rate assumption.
//			d.	Compute an average PDV using the gender shares from wWSM's sample.
//			e.	Inflation-adjust (since Lindner's estimates are in 2000$ but vWSM's
//				are in 1997$).
foreach x in di_ben_nomed di_ben_med {
	foreach s in m f {
		//Cumulative discount factor assuming 3% annual discounting:
		local cumul_disc = 0
		local endpd = `di_dur_`s''-1
		forval i = 0/`endpd' {
			local cumul_disc = `cumul_disc' + (1/(1.03^0.1))^(`i')
		}

		//Implied per-period flow:
		local `x'_flow_`s' = ``x'_pdv_`s''/`cumul_disc'

		//Rescale time:
		local di_dur_rescale_`s' = `DI_disp'*`di_dur_`s''
		local endpd_rescale = `di_dur_rescale_`s''-1

		//Recompute PDV:
		local `x'_pdv_rescale_`s'= 0
		forval i = 0/`endpd_rescale' {
			local `x'_pdv_rescale_`s' = ``x'_pdv_rescale_`s'' + ``x'_flow_`s''*(1/((1+`discount_rate')^0.1))^(`i')
		}
	}
	//Compute average PDV:
	local `x'_pdv_1997 = `di_share_m' * ``x'_pdv_rescale_m' + (1-`di_share_m') * ``x'_pdv_rescale_f'

	//Inflation-adjust:
	deflate_to 1997, from(2000)
	local `x'_pdv =  ``x'_pdv_1997' * r(deflator)
}

*Compute per-dollar total cost of DI (inclusive of behavioral responses) using
*DI_examiner.do:
//For now, using average tax wedge for U.S. in 2015 to match Schmieder/von Wachter's
//FE estimates for UI. (Source: https://stats.oecd.org/Index.aspx?QueryId=55129).
global ui_di yes
do "${program_folder}/DI_Examiner.do" DI_examiner `2' `3'
local DI_cost_per_dollar = ${cost_DI_examiner}/${program_cost_DI_examiner}
di `DI_cost_per_dollar'
global ui_di no

*Total present-discounted cost of a DI award (inclusive of earnings responses):
foreach x in nomed med {
	local di_total_`x'_pdv = `di_ben_`x'_pdv' * `DI_cost_per_dollar'
}

**************************
/* 5. Cost Calculations */
**************************

*FEs from reduced DI applications:
//NOTES:	The Lindner (2016) estimate above is (approximately) the percent reduction
//			in DI application probabilities per $100 of benefits, so we must divide
//			by $100 to get the per-monthly-dollar effect in percent terms. Then
//			dividing by UI claiming duration to get per-dollar effect.
if  "`DI_incl_med'" == "yes" {
	local DI_ben_reduc = ((`lindner_di_reduc'/100)/100)*`DI_app_baseline'*`DI_approval_prob'*`di_total_med_pdv'/`UI_claim_len'
}
if  "`DI_incl_med'" == "no" {
	local DI_ben_reduc = ((`lindner_di_reduc'/100)/100)*`DI_app_baseline'*`DI_approval_prob'*`di_total_nomed_pdv'/`UI_claim_len'
}

local program_cost = 1

if "`incl_DI'" == "yes" {
	local total_cost = `program_cost' + ``FE_est'' + `DI_ben_reduc'
}

if "`incl_DI'" == "no" {
	local total_cost = `program_cost' + ``FE_est''
}

*************************
/* 6. WTP Calculations */
*************************

if "`cons_source'" == "no markup" local WTP = 1
else {
	if "`scale_WTP'" == "yes"	local WTP = 1 + `rra_coeff'* ``cons_est'' / (1-`revealed_info_tm1')
	if "`scale_WTP'" == "no" 	local WTP = 1 + `rra_coeff'* ``cons_est''
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

*display outputs
di `MVPF'
di `WTP'
di `total_cost'
di `program_cost'

*store outputs in local for wrapper
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global WTP_`1' = `WTP'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

if "`FE_source'"!="solon"{
	global inc_stat_`1' = `earn_avg_15'
	global inc_type_stat_`1' = "individual"
	global inc_benef_`1' = `earn_avg_15'
	global inc_type_benef_`1' = "individual"
	global inc_year_stat_`1' = `year_earn'
	global inc_year_benef_`1' = `year_earn'
	global inc_age_benef_`1' = `age_benef'
	global inc_age_stat_`1' = `age_stat'
}

macro drop payroll_assumption
