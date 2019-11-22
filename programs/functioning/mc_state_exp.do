********************************
/* 0. Program: Medicaid State Expansions */
********************************

/*
Brown, David W., Amanda E. Kowalski, and Ithai Z. Lurie.
Long-Term Impacts of Childhood Medicaid Expansions on Outcomes in Adulthood
No. w20835. National Bureau of Economic Research, 2018.

Boudreaux, M. H., Golberstein, E., & McAlpine, D. D. (2016).
The long-term impacts of Medicaid exposure in early childhood: Evidence from the
program's origin.
Journal of Health Economics, 45, 161-175.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption"
local tax_rate = $tax_rate_cont
local proj_type = "$proj_type" //"observed" "fixed forecast" and "growth forecast"
local proj_age = $proj_age //takes on age at end of projection
local correlation = $correlation
local addmedcosts = "$addmedcosts" //Include reduction in medicaid spending in WTP
local vsl_assumption = "$vsl_assumption" // include vsl in MVPF, yes or no
local vsl2012 = ${VSL_2012_USD} // In Millions

local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
local medi_spend_0_18 = 0.593	// Impact on total medicaid spending 0-18 undiscounted;
								   0-18 BKL (2018) table 1
local tax_rev_19_28 = 0.533		// Undiscounted sum 19-28 (cumulative effect to 28)
								   from BKL 2018 table OA.7, column 10
local wage_inc_19_28 = 1.177	// Undiscounted sum 19-28 (cumulative effect to 28)
								   from BKL 2018 table OA.5, column 10
local mort_19_28 = -0.02		// Cumulative effect 19-28 from BKL 2018 table OA.4, column 10
local tax_rev_19 = 0.012		// BKL 2018 table OA.7
local tax_rev_20 = 0.016		// BKL 2018 table OA.7
local tax_rev_21 = 0.016		// BKL 2018 table OA.7
local tax_rev_22 = 0.026		// BKL 2018 table OA.7
local tax_rev_23 = 0.048		// BKL 2018 table OA.7
local tax_rev_24 = 0.07			// BKL 2018 table OA.7
local tax_rev_25 = 0.092		// BKL 2018 table OA.7
local tax_rev_26 = 0.094		// BKL 2018 table OA.7
local tax_rev_27 = 0.071		// BKL 2018 table OA.7
local tax_rev_28 = 0.088		// BKL 2018 table OA.7
local wage_inc_19 = 0.061		// BKL 2018 table OA.5
local wage_inc_20 = 0.035		// BKL 2018 table OA.5
local wage_inc_21 = -0.055		// BKL 2018 table OA.5
local wage_inc_22 = 0.015		// BKL 2018 table OA.5
local wage_inc_23 = 0.14		// BKL 2018 table OA.5
local wage_inc_24 = 0.217		// BKL 2018 table OA.5
local wage_inc_25 = 0.228		// BKL 2018 table OA.5
local wage_inc_26 = 0.136		// BKL 2018 table OA.5
local wage_inc_27 = 0.121		// BKL 2018 table OA.5
local wage_inc_28 = 0.28		// BKL 2018 table OA.5
local payroll_19 = 0.003		// BKL 2018 table OA.9
local payroll_20 = 0			// BKL 2018 table OA.9
local payroll_21 = -0.003		// BKL 2018 table OA.9
local payroll_22 = 0			// BKL 2018 table OA.9
local payroll_23 = 0.008		// BKL 2018 table OA.9
local payroll_24 = 0.015		// BKL 2018 table OA.9
local payroll_25 = 0.016		// BKL 2018 table OA.9
local payroll_26 = 0.013		// BKL 2018 table OA.9
local payroll_27 = -0.006		// BKL 2018 table OA.9
local payroll_28 = -0.006		// BKL 2018 table OA.9
local hosp_inc = 0.04			// Boudreaux et al. (2016) table 5 - Comes from 4% increase
								   in hospital visits on medicaid introduction.
local ever_coll_19_28 = 0.486	// BKL 2018 table OA.2
*/


/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates.
${folder_name}, being set externally, may vary in order to use pub bias corrected estimates. */
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

local USD_year = 2011 //Notes on BKL (2018), Table OA.5

local mean_earn_28 = 26.013*1000 // BKL (2018) table OA.5 column 10

local hosp_base = 0.06 //Boudreaux et al. (2016) table 5

*if "`tax_rate_assumption'" == "paper internal" local tax_rate = 20623/149245
*BKL (2018), Table OA.5, Table OA.7; observed in paper, not used for calculations

*Ages observed in sample (BKL page 2)
local old_age = 28
local young_age = 19

*Age at which income projections will start
local proj_start_age = `old_age'+ 1

*From BKL page 2: "We focus on children born from January 1981 to December 1984"
local old_birth = 1981
local young_birth = 1984

*Take average
local avg_birth = (`young_birth'+`old_birth')/2

*Average year in which earnings are observed for 28 year olds
local earn_year = round(`avg_birth'+`old_age')

**********************************
/* 4. Intermediate Calculations */
**********************************

*Expansions were mandatory up to 133% of FPL, optional up to 185%
*Assume parents earning at 133% of FPL
deflate_to `USD_year', from(1983)
local parent_earn = 1.33*10098*r(deflator) // FPL for 4 person HH with 2 children in 1983 (1983 USD)
*From  https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-poverty-thresholds.html

*Adjust VSL assumption to $2011
deflate_to `USD_year', from(2012)
local vsl = 1000000*`vsl2012'*r(deflator)

*Convert numbers in thousands
local tax_rev_19_28 = `tax_rev_19_28'*1000
local medi_spend_0_18 = `medi_spend_0_18'*1000
local wage_inc_19_28= `wage_inc_19_28'*1000

*Get moral hazard rate from  Boudreaux et al. (2016) utilization estimates.
*Take the increase in hospitalization relative to the base upon MC introduction,
*assume the increase is not valued
local moral_hazard_rate = `hosp_inc'/`hosp_base'

*Adjust mortality effect as it is in % units
local mort_19_28 = 0.01 * `mort_19_28'

*For taxes/wages/payroll get proportion of gain at each age
foreach var in wage_inc tax_rev payroll {
	*Get full sum
	local sum_`var' = 0
	forval i = 19/28 {
		local sum_`var' = `sum_`var'' + ``var'_`i''
	}
	*Allocate proportion
	forval i = 19/28 {
		local p_`var'_`i' = ``var'_`i''/`sum_`var''
	}
	local sum_`var' = `sum_`var''*1000
}

*Payroll cumulative impact not reported so derive from yearly impacts
local payroll_19_28 = `sum_payroll'

di `sum_payroll'
di `payroll_19_28' / `tax_rev_19_28'
di `tax_rev_19_28' - `payroll_19_28'

*Calculate discounted value of tax and earnings increases
foreach var in wage_inc tax_rev payroll {
	local sum_`var'_d = 0
	forval i = 19/28 {
		local sum_`var'_d = `sum_`var'_d' + `p_`var'_`i''*``var'_19_28'/((1+`discount_rate')^`i')
	}
}

*Calculate discounted average real spending in each year (no data on time structure here)
local year_spend = `medi_spend_0_18'/18
local sum_medi_spend_d = 0
forvalues i = 1/18 {
	local sum_medi_spend_d = `sum_medi_spend_d' + `year_spend'/((1+`discount_rate')^`i')
}

*Get implied cost increase to govt from college attendance
if "${got_bkl_cost}"!="yes" {
	cost_of_college , year(`=round(`avg_birth'+18)')
	global bkl_year_college_cost  = r(cost_of_college)
	global bkl_tuition_cost = r(tuition)
	global got_bkl_cost = "yes"
}

*Assume 2 years on average for those induced to attend some college. Divide ever_coll_19_28
*by 100 because it is in %.
deflate_to `USD_year', from(`=`avg_birth'+18')
local govt_college_cost = (${bkl_year_college_cost}-${bkl_tuition_cost})*2*(`ever_coll_19_28'/100)* ///
	r(deflator)*(1/(1+`discount_rate')^18)
local priv_college_cost = (${bkl_tuition_cost})*2*(`ever_coll_19_28'/100)* ///
	r(deflator)*(1/(1+`discount_rate')^18)


*************************************
* Forecast effects to later ages
*************************************

*Calculate the earnings and tax impact at age 28, the last year observed
local earn_impact_28 = `p_wage_inc_28'*`sum_wage_inc'
local tax_impact_28 = `p_tax_rev_28'*`sum_tax_rev'

*Project
if "`proj_type'" == "growth forecast"{
	est_life_impact `earn_impact_28', ///
		impact_age(`old_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`=`earn_year'+1') usd_year(`USD_year') ///
		income_info(`=`mean_earn_28'-0.5*`earn_impact_28'') income_info_type(counterfactual_income) ///
		earn_method(multiplicative) tax_method(off) transfer_method(off) ///
		max_age_obs(28)

	local cfactual_income = r(cfactual_income)
	local earn_proj_d = ((1/(1+`discount_rate'))^`proj_start_age') * r(tot_earn_impact_d)
}
if "`proj_type'" == "observed" local earn_proj_d = 0

*Get tax rate to apply to projected earnings
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `cfactual_income', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`USD_year') /// USD year of income
		inc_year(`earn_year') /// year of income measurement
		program_age(`proj_start_age') ///
		earnings_type(individual) // individual or household

	local tax_rate = r(tax_rate)
}

if "`tax_rate_assumption'" ==  "paper internal" {
	if "`payroll_assumption'"=="no" {
		local tax_rate = (`tax_rev_28'-`payroll_28')/`wage_inc_28'
		di `tax_rate'

	}
	if "`payroll_assumption'"=="yes" {
		local tax_rate = `tax_rev_28'/`wage_inc_28'
	}
}
di `tax_rate'

local increase_taxes_proj = `tax_rate' * `earn_proj_d'
di `increase_taxes_proj'


*Get ages
local age_kid = (0+18)/2 // cohort exposed to expansions throughout childhood

*Get mother age at birth
get_mother_age `avg_birth', yob(`avg_birth')
local mother_age_at_birth = r(mother_age)

*Adjust to align with child age
local age_mother = `mother_age_at_birth'+`age_kid'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `sum_medi_spend_d'

di `sum_medi_spend_d'
di `year_spend'

*Observed tax FE (+ college cost)
local total_cost = `program_cost' - `sum_tax_rev_d' + `govt_college_cost'

*Net out payroll taxes if needed
if "`payroll_assumption'"=="no" {
	local total_cost = `total_cost' + `sum_payroll_d'
}

*Projected tax FE
if "`proj_type'" == "growth forecast" {
	local total_cost = `total_cost' - `increase_taxes_proj'
}

di `increase_taxes_proj' +  `sum_tax_rev_d'
di  `sum_wage_inc_d' - `sum_tax_rev_d'
di  `wage_inc_19_28' - `tax_rev_19_28'
di  `sum_wage_inc_d'
di  `sum_tax_rev_d'

**********************************
/* 5b. Cost Calculations by Age*/
**********************************

*Create Cost Variables for Each Year
local year_0_cost = 0
forval i = 1/`proj_age' {
	*Just medical costs 1-18
	if inrange(`i', 1, 18) {
		local year_`i'_cost = `year_`=`i'-1'_cost' + `year_spend'/(1+`discount_rate')^`i'
	}
	*Observed tax impacts 19-28
	if inrange(`i',19, 28) {
		local year_`i'_cost = `year_`=`i'-1'_cost'  - `p_tax_rev_`i''*`tax_rev_19_28'/((1+`discount_rate')^`i')
	}
	if inrange(`i', 29, `proj_age') {
		if "`proj_type'" == "observed" local year_`i'_cost = `year_`=`i'-1'_cost'
		if "`proj_type'" == "growth forecast" {
			local year_`i'_cost = `year_28_cost' - `tax_rate'*${aggt_earn_impact_a`i'}/(1+`discount_rate')^29
		}
	}
}


*************************
/* 6. WTP Calculations */
*************************

*WTP for future earnings increases
local after_tax_income_obs = `sum_wage_inc_d' - `sum_tax_rev_d'

*WTP for increased medical spending?
if "`addmedcosts'" == "yes" {
	local valmedcosts = `sum_medi_spend_d' *(1-`moral_hazard_rate')
}
else local valmedcosts = 0
di `sum_medi_spend_d' *(1-`moral_hazard_rate')
di `valmedcosts'
di `after_tax_income_obs'
di (1-`tax_rate')*`earn_proj_d'+`after_tax_income_obs'
di (1-`tax_rate')*`earn_proj_d'


*Lives saved?
if "`vsl_assumption'" == "yes"{
	local bene_life_saved = -`mort_19_28'*`vsl'/((1+`discount_rate')^(`=0.5*(`old_age'+`young_age')'))
}
else local bene_life_saved = 0
di `bene_life_saved'
di 0.5*(`old_age'+`young_age')

*Total WTP
local WTP = `after_tax_income_obs' + (1-`tax_rate')*`earn_proj_d' + ///
			`bene_life_saved' + `valmedcosts' - `priv_college_cost'

*WTP from kid
local WTP_kid = `after_tax_income_obs' + (1-`tax_rate')*`earn_proj_d' + ///
			`bene_life_saved'  - `priv_college_cost'

if "$wtp_assumption"=="lower bound" {
	local WTP = 0.01*`program_cost' // conservative lower bound as we don't observe
	*any crowd out of private expenditure, which would be the ideal estimator here
}

*Determine chief economic beneficiary
local age_stat = `age_mother'
if `WTP_kid'>`=`WTP'*0.5' local age_benef = `age_kid'
else local age_benef = `age_mother'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

di `MVPF'
di `WTP'
di `total_cost'
di `program_cost'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'


* income globals
deflate_to 2015, from(`USD_year')

global inc_stat_`1' = `parent_earn' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = 1983
global inc_age_stat_`1' = `age_stat'

if `WTP_kid'>`=`WTP'*0.5' {
	global inc_benef_`1' = `mean_earn_28' * r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `earn_year'
	global inc_age_benef_`1' = (`young_age'+`old_age')/2
}

else {
	global inc_benef_`1' = `parent_earn' * r(deflator)
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = 1983
	global inc_age_benef_`1' = `age_stat'
}

forvalues k = 0/`proj_age'{
	global y_`k'_cost_`1' = `year_`k'_cost'
}
