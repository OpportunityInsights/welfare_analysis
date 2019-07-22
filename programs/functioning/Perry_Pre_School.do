**********************************
/* 0. Program: Perry Pre-School */
**********************************
/*
Standard errors not presented for any of the values used here. 
Instead use standard errors given on their final IRR and CBA calculations 
to bootstrap.

Heckman, J. J., Pinto, R., Shaikh, A. M., & Yavitz, A. (2011). 
Inference with imperfect randomization: The case of the Perry Preschool Program 
(No. w16935). National Bureau of Economic Research.

Heckman, J. J., Moon, S. H., Pinto, R., Savelyev, P. A., & Yavitz, A. (2010). 
The rate of return to the HighScope Perry Preschool Program. 
Journal of public Economics, 94(1-2), 114-128.
*/

local bootstrap = "`2'"

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" //takes value paper internal, continuous, or mixed
local tax_rate_cont = $tax_rate_cont
if "`tax_rate_assumption'"!="continuous" & "`tax_rate_assumption'"!="paper internal" & "`tax_rate_assumption'"!="cbo" {
	di in red "`tax_rate_assumption' is not a valid tax rate assumption for Perry Pre School"
	exit
}
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no" 

local proj_type= "$proj_type" //takes value observed or growth forecast
local proj_age = $proj_age //takes on age at end of projection
local wtp_valuation = "$wtp_valuation"

*Local assumptions / checks for this program that need to be initialized at top of do file
local welf_admin_cost = 0 
local include_other_costs = "$include_other_costs"
local inc_reduc_vic_wtp = "$inc_reduc_vic_wtp"

*********************************
/* 2. Causal Inputs from Paper */
*********************************

/*CBA
local CBA_draws_pe = 7.1 // Heckman et al. (2011) table 1 column 7, 3% discount rate
local CBA_draws_se = 2.3 // Heckman et al. (2011) table 1 column 7, 3% discount rate
*/

*Get (potentially) corrected CBA 
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

* Note: All these figures are treatment-control differences in the estimated costs. 
* In general, monetary values are in undiscounted 2006 USD.
local program_cost = 17759 // Heckman et al. (2011) p.14; No DWL of taxation.

*K-12 Inputs (Grades K-12) //Heckman et al. (2011), Table 3
*Note: Based on an annual cost per pupil in Michigan of 6645 in 2006 USD,  under
*the assumption that all subjects attended public schools afterwards. Includes 
*cost of obtaining GED (from Heckman and LaFontaine (2008) and additional cost 
*for subjects that received special education (2x regular per pupil expenditure, 
*see Chambers, Parish and Harr (2004)).
local m_k12_cost = (107575-98855)
local f_k12_cost = (98678-98349)

* College & Vocational Training Inputs (Ages 19-28) //Heckman et al. (2011), Table 3
//College: Cost of college calculated as number of subject's credit hours attempted 
*multiplied by cost per credit hour (student tuition + publc insitutional expenditures). 
*For 2-year colleges, use $590 per credit hour. For 4-year college, use $1765 per 
*credit hour. See footnote 23, p.16 for details.
local m_c_cost = (6705-19735)
local f_c_cost = (21816-16929)

//Vocational: Assumed cost of 1.8x high school annual per pupil cost based on 
*Tsang (1997) and number of months each subject attended vocational training.
local m_v_cost = (7223-12202)
local f_v_cost = (3120-674)

//After 27: If attended college after age 27, costs are assumed the same. "Some college" 
*is interpreted as one-year in a 2-year college. Masters degrees are given the same 
*credit hour cost of 4-year colleges.
local m_cv_aft27_cost = (2409-3396)
local f_cv_aft27_cost = (7770-1021)

* Earnings & Tax Inputs (Age <=27, Ages 28-40, Ages 41-65) //Heckman et al. (2011), Table 3
//Note: All these figures are treatment-control differences in the estimated costs 
*and benefits. Further, all earnings are pre-tax, but include fringe benefits that
*the authors assume tax exempt. 
//Note: Follow authors' preferred methods in all cases. For the imputation, they 
*use a kernel-based matching algorithm to match Perry subjects to similar respondents
*in the NLSY79. Further, all earnings incorporate fringe-benefits, which are assumed 
*tax-free and to be constant at the economy-wide mean of the share of fringe benefits 
*in total employee compensation.
//Ages 19-27
local m_less27_earn = (186923-185239)
local f_less27_earn = (189633-165059)
//Ages 28-40
local m_28_40_earn = (370772-287920)
local f_28_40_earn = (356159-290948)
* age 40 earning difference (for growth forecast)
local m_40_earn = 32023 - 24730
local f_40_earn = 24434 - 20345
local m_control_40 = 24730 // control group mean
local f_control_40 = 20345 // control group mean

//Ages 41-65: For the extrapolation method, they extract a "low ability" sample 
*of the PSID, estimate a model of earnings dynamics, and use fitted model to 
*extrapolate in their Perry sample. For this extrapolation, they account for 
*survival rates by gender, age, and educational attainment.
local m_41_65_earn = (563995-503699)
local f_41_65_earn = (524181-402315)

* Social Costs of Crime Inputs // Heckman et al. (2011), Table 3
//Police/Court Costs: Calculated as Michigan-specific cost of arrest calculated 
*from the UCR and the CJEE, assuming each arrest in the Perry data incurred an 
*average level of all possible police and court costs.
local m_police = (106-153)*1000
local f_police = (25-54)*1000

//Correctional Costs: Given full record of incarcerations/parole/probation in the 
*Perry data, the authors use expenditures on correctional institutions by state 
*and local governments in Michigan divided by the total institutional population 
*to get to a unit cost of correction. 
local m_corr = (41-67)*1000
local f_corr = (0-5)*1000

//Victimization Costs: Estimates use the "Separate/High" row in Table 3. "Separate" 
*indicates the authors compile incidence/arrests ratios for each kind of crime for 
*which a Perry subject was arrested for from external sources (UCR and NCVS), and 
*construct a proxy for the number of incidences for each offense. Each crime also 
*has a different cost to the victim, which the authors take from Cohen (2005). 
*"High" indicates that the social cost of a murder is assumed to be $4.1 million, 
*which does not change results much.
local m_victimiz = (370-730)*1000
local f_victimiz = (3-321)*1000

* Welfare // Heckman et al. (2011), Appendix Table J.1; // The Perry sample contains 
*data on the incidence of welfare dependence and actual welfare payments, but not 
*much information on in-kind transfer programs and cash assistance programs. 
//Ages 19-27: Only the number of months in welfare are known, so values are imputed 
*using the matched NLSY "low ability" subsample. This is done for cash assistance 
*programs only. For in-kind benefits, the authours use the SIPP to estimate linear
* probability models for each kind of in-kind transfers (e.g. Medicare) and use 
*estimates of Moffitt (2003) of the monetary values of in-kind transfers to form 
*an expected cash assistance value of in-kind transfers.
local m_less27_welf = (235-303)*(1+`welf_admin_cost')
local f_less27_welf = (18590-36085)*(1+`welf_admin_cost')

//Ages 28-40: No imputations needed in this age range.
local m_28_40_welf = (2186-7108)*(1+`welf_admin_cost')
local f_28_40_welf = (30398-15556)*(1+`welf_admin_cost')

//Ages 41-65: Authors use the PSID "low ability" sample to extrapolate welfare 
*benefits, much in line with what is done for earnings.
local m_41_65_welf = (4034-6965)*(1+`welf_admin_cost')
local f_41_65_welf = (17178-19377)*(1+`welf_admin_cost')

local perc_m = 72/123 // Table D.2
local perc_f = 51/123 // Table D.2
local project_year = 1965 + 41 - 4 // Perry Pre school happened between 1962 and 1965 
*when kids were 3-4 and projection starts when they are 41
local usd_year = 2006 // Heckman et al (2011)
local impact_age = 40 // last observed impact

*  Appendix table D1
local m_2_yr_col_credits = 11.7 - 9.5
local f_2_yr_col_credits = 4.7 - 7.2

local m_4_yr_col_credits = 0.3 - 8.7
local f_4_yr_col_credits = 11.4 - 7.8

**********************************
/* 4. Intermediate Calculations */
**********************************

*PDV of Fiscal Externalities and Later Life Benefits
*Get ages
local age_benef = (3+5)/2 // preschool ages
local age_stat = (3+5)/2 // preschool ages

*Set age to discount to
local discount_to = `age_benef'

*Get corrected t-stat for CBA
local CBA_se = 2.3 // Heckman et al. (2011) table 1 column 7, 3% discount rate
if "`bootstrap'"=="yes" local CBA_pe = `CBA_draws_pe' // pe used for draws of CBA - may be corrected
else local CBA_pe = `CBA_draws' // pe used for draws of CBA - may be corrected
local CBA_new_t = `CBA_pe'/`CBA_se'
*This will be used to bootstrap the FE and WTP in section 7


* Determine fiscal externality rate
local 40_earn = `m_40_earn'*`perc_m'+`f_40_earn'*`perc_f'	
local 40_control = `m_control_40'*`perc_m'+`f_control_40'*`perc_f'	

if "`tax_rate_assumption'" == "paper internal"  {
	local tax_rate = 0.225 // Heckman et al. (2010) page 121
}
if "`tax_rate_assumption'" == "continuous"  {
	local tax_rate = `tax_rate_cont'
}
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `40_control', /// earnings at 40 for control
		include_transfers(no) /// welfare impacts observed (or partially observed) directly
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year'-1') /// year of income measurement 
		program_age(40) ///
		earnings_type(individual) // individual or household
	local tax_rate = r(tax_rate)
	di r(pfpl)
	di `40_control'
}
	
* Transfer rates:
foreach age_group in less27 28_40 41_65 {
	foreach gender in m f {
		local transfer_rate_`age_group'_`gender' = -``gender'_`age_group'_welf'/``gender'_`age_group'_earn'
	
	}
}
local k12_years = 13 

*************************
*****Education Costs*****
*************************

* K-12 Costs (Grades K-12)
local k12_cost = `m_k12_cost'*`perc_m' + `f_k12_cost'*`perc_f'
local k12_yr_cost = `k12_cost'/`k12_years'

local disc_k12_cost = 0
local age = 5 // Starting age of K-12
forvalues i = 1/`k12_years'{
	local disc_k12_cost = `disc_k12_cost' + `k12_yr_cost'/((1+`discount_rate')^(`age'-`discount_to'))
	local age = `age'+1
}
local total_k12_cost = `disc_k12_cost'

* College & Vocational Training (Ages 19-27, All later schooling at Age 28)
local end_cv = min(27, `proj_age')
local cv_years = max(0,`end_cv' - 19 + 1) 
local aft_27 = (`proj_age'>27) //we don't know how the after 27 costs accrue over time so assume they accrue starting at age 28

local cv_cost = (`m_c_cost'+`m_v_cost')*`perc_m'+(`f_c_cost'+`f_v_cost')*`perc_f'
local cv_aft27_cost = `aft_27'*(`m_cv_aft27_cost'*`perc_m'+`f_cv_aft27_cost'*`perc_f')
local cv_yr_cost = `cv_cost'/(27-19+1)
local disc_cv_cost = 0
local age = 19
forvalues i = 1/`cv_years'{
	local disc_cv_cost = `disc_cv_cost' + `cv_yr_cost'/((1+`discount_rate')^(`age'-`discount_to'))
	local age = `age'+1
}

local disc_cv_cost = `disc_cv_cost' + `cv_aft27_cost'/((1+`discount_rate')^(`age'-`discount_to'))
local total_cv_cost = `disc_cv_cost'

* Total Education Costs
local total_educ_costs = `total_k12_cost' + `total_cv_cost'

* Get proportion of college costs paid by government
/* Take an average, weighted by the proportion in sample achieving 2yr vs 4yr 
degrees, of the private cost shares at 2 and 4 year institutions when these
individuals are 22 */
if "${got_perry_coll_costs}"!="yes" {
	foreach type in community rmb {
		cost_of_college, year(`=1965+22') type_of_uni(`type')
		local perry_`type'_cost_share = r(tuition)/r(cost_of_college)
		di r(tuition)/r(cost_of_college)
	}
	local perry_cc_pct = 15/(15+3) // share earning 2 yr degrees of all earnings degrees
	local perry_rmb_pct = 3/(15+3) // share earning 4 yr degrees of all earnings degrees
	global perry_priv_cost_share = `perry_cc_pct'*`perry_community_cost_share' + ///
								`perry_rmb_pct'*`perry_rmb_cost_share'
	global got_perry_coll_costs yes
}
local priv_cost_prop = ${perry_priv_cost_share}
di `priv_cost_prop'

******************
*****Earnings*****
******************

* Ages and lengths of earnings projections:
local less27_years = 27-19+1
local less27_years_loop = 27-19+1
if `proj_age' <19 local less27_years_loop = 0
if `proj_age'>=19 & `proj_age' <=27 local less27_years_loop = `proj_age'-19 + 1

local 28_40_years = 40-28+1
local 28_40_years_loop = 40-28+1
if `proj_age' <28 local 28_40_years_loop = 0
if `proj_age'>=28 & `proj_age' <=40 local 28_40_years_loop = `proj_age'-28 + 1

local 41_65_years = 65-41+1
local 41_65_years_loop = `proj_age'-41+1
if `proj_age' <41 local 41_65_years_loop = 0


local disc_41_65_tax = 0
local disc_41_65_earn = 0
* Earnings (Ages 19-65)
local age = 19 // Go back to 19 years old to capture work during ages 19-27.
local age_groups less27 28_40 41_65
foreach group in `age_groups' {
	local earn_`group' = `m_`group'_earn'*`perc_m'+`f_`group'_earn'*`perc_f'
	local earn_yr_`group' = `earn_`group''/``group'_years'
	local disc_earn_`group' = 0
	forvalues i = 1/``group'_years_loop'{
		local disc_earn_`group' = `disc_earn_`group'' + `earn_yr_`group''/((1+`discount_rate')^(`age'-`discount_to'))
		local age = `age'+1
	}
}

* Tax Revenue &  post tax earnings (Ages 19-65)
foreach group in `age_groups' {
	local disc_tax_`group' = `tax_rate' * `disc_earn_`group''
	local disc_welf_`group' = `transfer_rate_`group'_f' * `disc_earn_`group'' * (`f_`group'_earn'*`perc_f'/`earn_`group'') ///
		+`transfer_rate_`group'_m' * `disc_earn_`group'' * (`m_`group'_earn'*`perc_m'/`earn_`group'')
	
	local disc_earn_post_tax_`group' =  `disc_earn_`group'' -`disc_tax_`group'' - `disc_welf_`group''
}

* Potentially use growth forecast post 40
if "`proj_type'" == "growth forecast" {
	est_life_impact `40_earn', ///
		impact_age(`impact_age') project_age(`=`impact_age'+1') project_year(`project_year') ///
		income_info(`40_control') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age(`proj_age') usd_year(`usd_year') income_info_type(counterfactual_income) ///
		max_age_obs(40)

	local disc_earn_41_65 = r(tot_earn_impact_d)/(1+`discount_rate')^(`impact_age'+1 - `discount_to')
	local disc_tax_41_65 = `tax_rate' * `disc_earn_41_65'
	*Use implicit transfer rate from Heckman et al.'s projections:
	local disc_welf_41_65 = `transfer_rate_41_65_f' * `disc_earn_41_65' * (`f_41_65_earn'*`perc_f'/`earn_41_65') ///
		+ `transfer_rate_41_65_m' * `disc_earn_41_65' * (`m_41_65_earn'*`perc_m'/`earn_41_65')
	
	local disc_earn_post_tax_41_65 =  `disc_earn_41_65' -`disc_tax_41_65' - `disc_welf_41_65'
}
di `40_earn' /`40_control'

local total_aft_tax_earnings = 0
local tax_revenue = 0
local total_welfare = 0
local age_groups less27 28_40 41_65
if "`proj_type'" == "observed" local age_groups less27 28_40 //participants observed until 40
foreach group in `age_groups' {
	local total_aft_tax_earnings = `total_aft_tax_earnings' + `disc_earn_post_tax_`group''
	local tax_revenue = `tax_revenue' + `disc_tax_`group''
	local total_welfare = `total_welfare' + `disc_welf_`group''
}

*******************************
*****Social Costs of Crime*****
*******************************

*Ages and lengths of projections)
local end = min(40, `proj_age')
local police_age = 16
local police_years = max(0,`end'-16+1)
local corr_age = 19
local corr_years = max(0, `end'-19+1)
local victimiz_years = max(0, `end'-16+1)
local victimiz_age = 16

* Police/Courts (Ages 16-40), Incarceration/Correctional (Ages 19-40), Victimization (Ages 16-40)
local social_costs police corr victimiz
foreach type in `social_costs' {
	local age = ``type'_age'
	local `type'_cost = `m_`type''*`perc_m'+`f_`type''*`perc_f'
	local `type'_yr_cost = ``type'_cost'/``type'_years'
	local disc_`type'_cost = 0
	forvalues i = 1/``type'_years'{
		local disc_`type'_cost = `disc_`type'_cost' + ``type'_yr_cost'/(1 + `discount_rate')^(`age'-`discount_to')
		local age = `age'+1
	}
	local total_`type'_cost = `disc_`type'_cost'
}

local total_crime_cost = `disc_police_cost' + `disc_corr_cost' + `disc_victimiz_cost'


**************************
/* 5. Cost Calculations */
**************************

local FE = -`tax_revenue' - `total_welfare' +`total_cv_cost'*(1 - `priv_cost_prop')
if "`include_other_costs'" == "yes" local FE = `FE' +`total_k12_cost' + `total_police_cost'+`total_corr_cost'

************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	local WTP = `total_aft_tax_earnings' - `total_cv_cost'* `priv_cost_prop'
	if "`inc_reduc_vic_wtp'"=="yes" {
		local WTP = `WTP' - `disc_victimiz_cost'
	}
}
if "`wtp_valuation'" == "cost" 			local WTP = `program_cost'
if "`wtp_valuation'" == "lower bound" 	local WTP = 0.01*`program_cost'


**************************
/* 7. MVPF Calculations */
**************************

*Bootstrap FE/WTP using t-stat from CBA (FE as defined here should negatively correlate with WTP)
*t-stat for CBA corresponds to t-stat for these in model where there is a single
*outcome of whether it 'works', which all benefits/costs are just scalar transforms of.
*This makes sense given that Heckman et al.'s benefits/costs are in education, 
*earnings, crime, and welfare
if "`bootstrap'" == "yes" {
	*Check for draws
	cap confirm matrix perry_pre_school_draws_${replications}
	if _rc>0 {
		preserve
			cap confirm file "${welfare_files}/data/inputs/effect_draws/perry_pre_school_draws_${replications}_draws.dta"
			if (_rc>0 | "${redraw_perry_pre_school}" == "yes") {
				noi di in red "Redrawing perry pre school effects"
				pause on
				pause
				pause off

				clear
				set obs $replications
				g draw = _n
				g uni_rand = runiform()
				save "${welfare_files}/data/inputs/effect_draws/perry_pre_school_draws_${replications}_draws.dta", replace
			}
			else {
				use "${welfare_files}/data/inputs/effect_draws/perry_pre_school_draws_${replications}_draws.dta", clear
			}
			mkmat uni_rand, ///
				matrix(perry_pre_school_draws_${replications}) rownames(draw)
		restore
	}
	confirm matrix perry_pre_school_draws_${replications}
	
	*Get SEs for FE/WTP
	local FE_se = abs(`FE'/`CBA_new_t')
	if "`wtp_valuation'" == "cost" local WTP_se = 0
	else local WTP_se = abs(`WTP'/`CBA_new_t')
	
	*Redraw FE and WTP
	matrix temp = perry_pre_school_draws_${replications}["${draw_number}", "uni_rand"]
	local FE = `FE' + `FE_se'*invnormal(temp[1,1])
	local WTP = `WTP' - `WTP_se'*invnormal(temp[1,1]) // induce negative correlation to maximise width of CI
}

local total_cost = `program_cost' + `FE'
local total_cost_w_vict = `total_cost' + `total_victimiz_cost'

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `program_cost'-`total_cost'
di (`program_cost'-`total_cost')/`program_cost'
di `WTP'
di `MVPF'
di "`total_aft_tax_earnings' + `total_welfare'"

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')

global inc_stat_`1' = `40_earn' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year'-1
global inc_age_stat_`1' = 40

global inc_benef_`1' = `40_earn' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_year'-1
global inc_age_benef_`1' = 40


