/*******************************************************************************
 0. Program: Unemployment Insurance Duration Extensions
*******************************************************************************/

/*
Schmieder, Johannes F. and Till M. von Wachter. 2016. “The Effects of Unemployment
Insurance Benefits: New Evidence and Interpretation.” Annual Review of Economics
8: 547-581.

Johnston, Andrew C. and Alexandre Mas. 2018. "Potential Unemployment Insurance
Duration and Labor Supply: The Individual and Market-Level Response to a Benefit
Cut." Journal of Political Economy 126 (6): 2480-2522.

Katz, Lawrence F. and Bruce D. Meyer. 1990. "The Impact of the Potential
Duration of Unemployment Benefits on the Duration of Unemployment." Journal of
Public Economics 41 (1): 45-72.

Ganong, Peter and Pascal J. Noel. 2019. "Consumer Spending During Unemployment:
Positive and Normative Implications." NBER Working Paper No. 25417.

Hendren, Nathaniel. 2017. “Knowledge of Future Job Loss and Implications for
Unemployment Insurance.” American Economic Review 107 (7): 1778-1823.

Mueller, Andreas I., Jesse Rothstein, and Till M. von Wachter. 2016. “Unemployment
Insurance and Disability Insurance in the Great Recession.” Journal of Labor
Economics 34 (S1): S445-S475.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************
global payroll_assumption = "no"
local cons_source = "$cons_source" //estimate used for consumption drop
local FE_source = "$FE_source" //estimate used for FE

local discount_rate = $discount_rate
local rra_coeff = $rra_coeff //coefficient of relative risk aversion
local FE_assumption = "$FE_assumption" //"pay" (payroll tax) or "full" (labor tax)
local scale_WTP = "$scale_WTP" //"yes" or "no" (scaling consumption drop by amount of info revealed)
local incl_DI = "$incl_DI" //"yes" or "no" (include spillovers to DI in FE calculation)
local DI_disp = $DI_disp //displacement factor for UI spillovers to DI
local DI_incl_med = "$DI_incl_med"  //"yes" or "no" (including Medicare benefits in cost of SSDI award)

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*

* Drops in consumption (WTP) - Schmieder and von Wachter 2016, Table 3:

	//Cochrane 1991:
	//NOTES: 	Schmieder and von Wachter use the midpoint of the two estimates in
	//			Table 2 (which reports estimates and t-stats). To get the corresponding
	//			SE, we assume (to be conservative) that the two estimates are
	//			perfectly correlated.
	local cons_cochrane = 0.255
	local cons_cochrane_se = 0.5*sqrt((0.2403/4.95)^2 + (0.2674/7.81)^2 + 2*(0.2403/4.95)*(0.2674/7.81))

	//Gruber 1997:
	//NOTES: 	Consumption drop is from Gruber 1994, Table 1. Treating the term in
	//			parentheses in that table as a SD and not SE and dividing by the
	//			square root of the sample size (n=1604) accordingly.
	local cons_gruber = 0.068
	local cons_gruber_se = 0.424/sqrt(1604)

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


*Fiscal externalities from duration extensions - Schmieder and von Wachter 2016, Table 1:
//NOTE: Schmieder and von Wachter have two FE estimates for each paper, one assuming
//		that lost labor income from employment is valued by the government at the
//		payroll tax rate (3%), one assuming that it is valued at the full labor
//		income tax rate. The latter matches what we use elsewhere and is conceptually
//		correct if we assume the government has a global, and not UI-only, budget
//		constraint, so we use this as our baseline.

	//Katz and Meyer 1990
	//NOTES:	Katz and Meyer estimate a proportional hazards model and then run
	//			policy simulations on their data. For both extensions and benefits,
	//			there is a single model parameter - and so, given that we don't
	//			have the underlying data, we assume that the t-stat for the elasticity
	//			underlying S/vW's FE estimate is the same as the t-stat for that
	//			parameter in their model. Source: Table 2, Column 2.
	local FE_katz_meyer_full = 1.89
	local FE_katz_meyer_full_se = `FE_katz_meyer_full'/(0.0247/0.0153)

	//Johnston and Mas 2016
	//NOTES:	Schmieder/von Wachter base their FE estimates on the 2015 working paper,
	//			while the published version of the paper has duration elasticity
	//			estimates that are slightly smaller. To account for this, we scale
	//			S/vW's FE estimates by the ratio of the underlying estimates in the
	//			two versions of the paper, and assume that the t-state for the FE is the
	//			same as in the published version. Source: Table 3.
	local FE_johnston_full = 0.69 * (7.19/8.697)
	local FE_johnston_full_se = `FE_johnston_full'/(7.19/0.818)

*Share of information revealed *prior* to the onset of unemployment - Hendren 2007, Appendix Table I:
local revealed_info_tm1 = 0.1968
local revealed_info_tm1_se = 0.0120

*Estimates for timepath of consumption during unemployment - using
*Ganong and Noel, Appendix Table 8 estimates for nondurables:
//Consumption drop at onset:
local gn_onset = -0.064
local gn_onset_se = 0.001
//Monthly change during receipt:
local gn_monthly_ch = -0.0081
local gn_monthly_ch_se = 0.0007

*Elasticity of SSDI applications with respect to final UI exhaustions - Mueller,
*Rothstein, and von Wachter 2016, Table 2, Column 1:
local mrvw_di_elas = -0.0025
local mrvw_di_elas_se = 0.0034

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
			use "${input_data}/causal_estimates/${folder_name}/draws/ui_e.dta", clear

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
		import delimited "${input_data}/causal_estimates/${folder_name}/ui_e.csv", clear

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

*Average UI weekly amount - Mueller, Rothstein, von Wachter (2016), p. 9 ("weekly
*UI payments average around $300"), confirmed in UI program data at dol.gov.
local avg_weekly_ui = 300

*Monthly job-finding rate of marginal SSDI applicant (MRvW, p.25):
local DI_job_finding = 0.10

*DI approval probability (MRvW, p.25):
local DI_approval_prob = 0.60

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

*Age of UI beneficiary:
if "`FE_source'"=="johnston"	local age_stat = (18+65)/2 	// no relevant age info so take working ages
if "`FE_source'"=="katz_meyer" 	local age_stat = 33 		// Mean age in PSID sample (Table 1)
local age_benef = `age_stat' // single beneficiary

*Relevant income:
if "`FE_source'"=="johnston"{
	local quarters_in_year = 4
	local quarter_wage = 7240 //Table 1
	local ind_income = `quarters_in_year' * `quarter_wage'
	local earn_year = 2011  //Table 1
	*Paper does not indicate year but 2011 would be sensible since that is the year in which earnings are measured
	local earn_USD_year = 2011
}
if "`FE_source'"=="katz_meyer"{
	**These measures are based on the PSID sample rather than the Moffit sample
	local weeks_work_per_year = 50 //assumption
	local hours_worked_per_wk = 40 //assumption
	local wage_per_hour = 7.95 //Table 1, UI = 1
	local ind_income = `weeks_work_per_year'* `hours_worked_per_wk'* `wage_per_hour'
	local earn_year = 1980 //pg. 51
	*Paper does not say explicitly that this measure is in 1980 USD, but this makes sense for 1980-1981 data
	local earn_USD_year = 1980
}
deflate_to 2015, from(`earn_USD_year')
local deflator = r(deflator)
local ind_income_2015 = `ind_income'*`deflator'


*********************************
/* 4. Intermediate Calculations */
*********************************

*For Stephens (2001) WTP, calculate corresponding consumption drop:
if "`cons_source'"=="stephens" {
	local `cons_est' = 1-exp(``cons_est'')
}

*Calculate implied Ganong/Noel consumption decrease at time of exhaustion relative
*to drop at onset of unemployment - assuming that UI lasts 26 weeks. Using
*this additively below to be conservative.
local cons_exhaust_scale = -`gn_monthly_ch'*(26/4)


*PDV of SSDI benefits and lost earnings:
//NOTES:	MRvW's estimates are for the increase in DI applications from
//			UI exhaustions, not for an increase in the lifetime probability
//			of EVER applying for DI. To allow for the possibility that
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
//			e.	Inflation-adjust (since MRvW's estimates are for 2004-2012 [so
//				assuming 2008$] but vWSM's are in 1997$).
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
	deflate_to 2008, from(1997)
	local deflator = r(deflator)
	local `x'_pdv =  ``x'_pdv_1997' * `deflator'

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
//NOTES:	The MRvW (2016) estimate above is the elasticity of monthly SSDI applications
//			to monthly UI exhaustions. Thus, we consider a hypothetical experiment
//			where UI benefits are extended by one month. We assume that this extension
//			*prevents* `DI_job_finding' percent of UI-exhaustee-to-DI individuals
//			from *exhausting* their benefits (since they are able to find a job
//			during the four-week extension). Per MRvW, "there are about
//			one-fifth as many SSDI applications as UI exhaustions in a typical month" (p.25),
//			so using this to get the change in the probability of SSDI application.
if  "`DI_incl_med'" == "yes" {
	local DI_spillover = -(`mrvw_di_elas'*0.2)*`DI_job_finding'*`DI_approval_prob'*`di_total_med_pdv'/(4*`avg_weekly_ui')
}
if  "`DI_incl_med'" == "no" {
	local DI_spillover = -(`mrvw_di_elas'*0.2)*`DI_job_finding'*`DI_approval_prob'*`di_total_nomed_pdv'/(4*`avg_weekly_ui')
}

local program_cost = 1

if "`incl_DI'" == "yes" {
	local total_cost = `program_cost' + ``FE_est'' + `DI_spillover'
}
if "`incl_DI'" == "no" {
	local total_cost = `program_cost' + ``FE_est''
}
*************************
/* 6. WTP Calculations */
*************************

if "`cons_source'" == "no markup" local WTP = 1
else {
	if "`scale_WTP'" == "yes"	local WTP = 1 + `rra_coeff'* (``cons_est'' + `cons_exhaust_scale' ) / (1-`revealed_info_tm1')
	if "`scale_WTP'" == "no" 	local WTP = 1 + `rra_coeff'* (``cons_est'' + `cons_exhaust_scale' )
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

global inc_stat_`1' = `ind_income_2015'
global inc_type_stat_`1' = "individual"
global inc_benef_`1' = `ind_income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_stat_`1' = `earn_year'
global inc_year_benef_`1' = `earn_year'
global inc_age_benef_`1' = `age_benef'
global inc_age_stat_`1' = `age_stat'

macro drop payroll_assumption
