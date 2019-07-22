************************************************
/* 0. Program: Pell Grants for Adult Students */
************************************************

/*Seftor, Neil S. and Sarah E. Turner. 2002. "Back to School: Federal Student Aid
Policy and Adult College Enrollment." Journal of Human Resources 37 (2): 337-352.*/


********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local proj_type = "$proj_type" // only the growth forecast makes sense here
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation" // "post tax" or "cost"
local correlation = $correlation

* globals for finding the tax rate.
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}

*program specific globals
local val_given_marginal = $val_given_marginal // 0 or 0.5 or 1
local pell_fraction_baseline =  $pell_fraction_baseline // value between 0 and 1
local enrollment_time = $enrollment_time // number between 2 and 4 years

*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
/*Baseline enrollment for non-Pell-eligible individuals - Seftor and Turner 2002,
Table 2, Columns 1 and 3 ("Constant"):*/
local baseline_nonpell_m = 0.090
local baseline_nonpell_m_se = 0.002
local baseline_nonpell_f = 0.034
local baseline_nonpell_f_se = 0.001


/*Addiitonal baseline enrollment for Pell-eligible individuals - Seftor and Turner 2002,
Table 2, Columns 1 and 3 ("Pell Eligible"):*/
local baseline_add_pell_m = 0.006
local baseline_add_pell_m_se = 0.005
local baseline_add_pell_f = -0.002
local baseline_add_pell_f_se = 0.002


/*Increase in probability of enrollment for Pell-eligible individuals  - Seftor and Turner 2002,
Table 2, Columns 1 and 3 ("Post * Pell Eligible"):*/
local incr_coll_m = 0.015
local incr_coll_m_se = 0.007
local incr_coll_f = 0.014
local incr_coll_f_se = 0.004

*/
/*Import estimates from paper, giving option for corrected estimates.
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

local usd_year = 1973

/*Share male/female in sample - - Seftor and Turner 2002, Table 2, Notes:*/
local share_m = 47407/(47407 + 62405)
local share_f = 62405/(47407 + 62405)

/*Average age - Seftor/Turner's sample is ages 22-35, so taking midpoint*/
local avg_age = 28

/*Data for computing cost of college:*/
/*Total education and related expenditures for all institutions - NCES Financial 
Statistics of Institutions of Higher Education, 1975-1978, Table 1:*/
*NOTE: NCES figures are for fiscal years (so FY1975 corresponds to 1974-75). 
local total_eandr_1974 = 27250088*1000
local total_eandr_1975 = 30838948*1000
local total_eandr_1976 = 33416591*1000
local total_eandr_1977 = 36557657*1000

/*Total FTE enrollment for all institutions - NCES Digest of Education Statistics, Table 307.10
(https://nces.ed.gov/programs/digest/d18/tables/dt18_307.10.asp)*/
local fte_1974 = 7805452
local fte_1975 = 8479698 
local fte_1976 = 8312502
local fte_1977 = 8415339

/*Average Pell awards (https://www2.ed.gov/finaid/prof/resources/data/pell-historical/beog-eoy-1977-78.pdf,
Table 1):*/
local avg_pell_1974 = 622
local avg_pell_1975 = 763
local avg_pell_1976 = 758
local avg_pell_1977 = 852

*Assumptions of age for Initial Earnings Loss Projection
local proj_start_age = `avg_age'
local proj_short_end = `avg_age'+6
local impact_age = `avg_age'+3
local project_year = 1975
	
*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = `avg_age'+7
local impact_age_pos = `avg_age'+7
local project_year_pos = 1982

*Private contributions for college costs:
*NOTE: For this program, we are assuming to be conservative that individuals do 
*	   not contribute anything to college costs.
local priv_cost_impact = 0

*********************************
/* 4. Intermediate Calculations */
*********************************

*Get average inflation-adjusted cost of college per FTE and average Pell grant for 1974-1977:
local avg_pell = 0
local cost_of_college = 0 
forval y = 1974/1977 {
	deflate_to `usd_year', from(`y')
	local avg_pell = `avg_pell' + 0.25*`avg_pell_`y''*r(deflator)
	local cost_of_college = `cost_of_college' + 0.25*(`total_eandr_`y''/`fte_`y'')*r(deflator) //multiplies total expenditures per person with the deflator
}
*Baseline college enrollment for Pell-eligible individuals:
local baseline_coll = (`baseline_nonpell_m' + `baseline_add_pell_m') * `share_m' ///
					+ (`baseline_nonpell_f' + `baseline_add_pell_f') * `share_f'

*Pooled college enrollment effect of Pell:
local incr_coll = `incr_coll_m' * `share_m' ///
				+ `incr_coll_f' * `share_f'

*Fraction of enrolled students induced to change behavior via Pell:
local induced_fraction = `incr_coll'/(`incr_coll'+`pell_fraction_baseline'*`baseline_coll')

*Estimate earnings effect for those induced to enroll as a result of Pell:
int_outcome, outcome_type(attainment) impact_magnitude(`enrollment_time') usd_year(`usd_year')
local pct_earn_impact_neg = r(prog_earn_effect_neg)
local pct_earn_impact_pos = r(prog_earn_effect_pos)
	
*Now, forecast % earnings changes across lifecycle - these calculations are all 
*per additional enrollee. We'll scale these by the share induced to enroll below:
if "`proj_type'" == "growth forecast" {
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) earn_series(HS) /// no income info so using HS grad
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	/*NOTE: CBO calculator can only handle 1978-. Because the counterfactual earnings
			above are for 1975, we'll use the 1978 rates as a proxy for the MTR.*/
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// don't forecast short-run earnings, because it'll give them a high MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year_pos'+3') ///see note above
		earnings_type(individual) /// individual earnings
		program_age(`impact_age') // age of income measurement
	  local tax_rate_shortrun = r(tax_rate)
	}
		
	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = (1-`tax_rate_shortrun') * `total_earn_impact_neg'
		
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(.) income_info_type(none) earn_series(HS) ///no income info so using HS grad
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(`proj_start_age_pos'-`avg_age'))

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos'') /// year of income measurement
		earnings_type(individual) /// individual, because that's what's produced by int_outcome
		program_age(`impact_age_pos') // age of income measurement
	  local tax_rate_longrun = r(tax_rate)
	}
*Getting total earnings and tax effects
	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = (1-`tax_rate_longrun') * `total_earn_impact_pos'

	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
}
else {
	di as err "Only growth forecast allowed."
	exit
}


**************************
/* 5. Cost Calculations */
**************************
*Discounting for costs:
local enrollment_time_disc = 0
local end = ceil(`enrollment_time')
forval i=1/`end' {
	local enrollment_time_disc = `enrollment_time_disc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `enrollment_time_disc' - floor(`enrollment_time_disc')
if `partial_year' != 0 {
	local enrollment_time_disc = `enrollment_time_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}

*Program cost and total Pell expenditures:
local pell_cost = `avg_pell' * `enrollment_time_disc' * (`incr_coll'+`pell_fraction_baseline'*`baseline_coll')

local program_cost = `avg_pell' * `enrollment_time_disc' *`pell_fraction_baseline'*`baseline_coll'

*Calculate cost of additional enrollment above Pell grants per induced enrollee:
local enroll_cost = (`cost_of_college' - `priv_cost_impact' - `avg_pell')*`enrollment_time_disc'
/*
Note: This calculation is made to avoid double counting costs. The cost of providing 
the additional aid to new enrollees is implicitly included in the total government 
expenditures on their education.
*/

*Total cost: program cost plus additional taxes and enrollment costs for new enrollees
local total_cost = `pell_cost' + (`enroll_cost' - `increase_taxes')*`incr_coll'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	*Induced (to attend college) value at post tax earnings impact net of private costs incurred
	local wtp_induced = (`total_earn_impact_aftertax' - `priv_cost_impact')*`incr_coll'
	*Uninduced value at 100% of transfer
	local wtp_not_induced = `avg_pell'*`enrollment_time_disc'*`pell_fraction_baseline'*`baseline_coll'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}

if "`wtp_valuation'" == "cost" {
	*Induced value at fraction of transfer: `val_given_marginal'
	local wtp_induced = `avg_pell'*`enrollment_time_disc'*`val_given_marginal'*`incr_coll'
	*Uninduced value at 100% of transfer
	local wtp_not_induced =  `avg_pell'*`enrollment_time_disc'*`pell_fraction_baseline'*`baseline_coll'
	*Sum
	local WTP = `wtp_induced' + `wtp_not_induced'
}


**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

/*
Figures for Attainment Graphs 
*/
di `incr_coll'*`enrollment_time' //enrollment gain
di `pell_fraction_baseline'*`baseline_coll'*`enrollment_time' // baseline enrollment level receiving pell
di `avg_pell' * `enrollment_time' * `pell_fraction_baseline'*`baseline_coll' // Mechanical Cost 
di `avg_pell' * `enrollment_time' * `incr_coll' // Behavioral Cost Program
di 	`enroll_cost'*`incr_coll' // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual

*Locals for Appendix Write-Up 
di `tax_rate_longrun'
di `total_earn_impact_aftertax'*`incr_coll'
di `avg_pell'*`enrollment_time'*`pell_fraction_baseline'*`baseline_coll'
di `WTP'
di `program_cost'
di `baseline_coll'
di `incr_coll'
di `priv_cost_impact'
di `increase_taxes'*`incr_coll'
di `enroll_cost'*`incr_coll'
di `total_cost'
di `total_recipients'

****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'
di `increase_taxes_enrollment'
di `increase_taxes_attainment'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `avg_age' 
global age_benef_`1' = `avg_age'

* income globals
deflate_to 2015, from(`usd_year')

global inc_stat_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos''
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos''
global inc_age_benef_`1' = `impact_age_pos'
