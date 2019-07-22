****************************************
/* 0. Program: Texas Pell  */
****************************************

*** Primary Estimates: Denning, Jeffrey T., Benjamin M. Marx, and Lesley J. Turner.
* ProPelled: The Effects of Grants on Graduation, Earnings, and Welfare. No. w23860.
* American Economic Journal: Applied Economics, July 2019.

********************************
/* 1. Pull Global Assumptions */
********************************

*Project Wide Globals
local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type"
local proj_age = $proj_age
local wtp_valuation = "$wtp_valuation"

local val_given_marginal = $val_given_marginal

*Program Specific Globals
local fica_tax_fraction = $fica_tax_fraction
local years_bach_deg = $years_bach_deg

*********************************
/* 2. Estimated Inputs from Paper */
*********************************

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

/*

local earning_y1 = -220 // Denning et al. 2019 Table 5
local earning_y1_se = 208

local earning_y2 = -8 // Denning et al. 2019 Table 5
local earning_y2_se = 255

local earning_y3 = 411 // Denning et al. 2019 Table 5
local earning_y3_se = 326

local earning_y4 = 1033 // Denning et al. 2019 Table 5
local earning_y4_se = 435

local earning_y5 = 1369 // Denning et al. 2019 Table 5
local earning_y5_se = 563

local earning_y6 = 1270 // Denning et al. 2019 Table 5
local earning_y6_se = 702

local earning_y7 = 2916 // Denning et al. 2019 Table 5
local earning_y7_se = 1514


local sum_earn = 3797 // Denning et al. 2019 Table 6
local sum_earn_se = 1676

local fed_tax = 540 // Denning et al. 2019 Table 6
local fed_tax_se = 201

local FICA_tax = 565 // Denning et al. 2019 Table 6
local FICA_tax_se = 249

local enrollment_y1 = 0.01 // Denning et al. 2019 Table 4A
local enrollment_y1_se = 0.014


local enrollment_y2 = 0.008 // Denning et al. 2019 Table 4A
local enrollment_y2_se = 0.016


local enrollment_y3 = 0.029 // Denning et al. 2019 Table 4A
local enrollment_y3_se = 0.017


local enrollment_y4 = 0.013 // Denning et al. 2019 Table 4A
local enrollment_y4_se = 0.017


local enrollment_y5 = -0.014 // Denning et al. 2019 Table 4A
local enrollment_y5_se = 0.016


local enrollment_y6 = -0.011 // Denning et al. 2019 Table 4A
local enrollment_y6_se = 0.017


local enrollment_y7 = 0.026 // Denning et al. 2019 Table 4A
local enrollment_y7_se = 0.031


Note: Denning et al. 2019 suggests in the text that enrollment after 7 years is
only 1 percentage point higher in the control group rather than the treatment group
(7 versus 8 percent). For our calculations we use the precise estimates from Table 4, rather than
those descriptions.

*/

*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************

local enrollment_y1_control = 0.74 // Denning et al. 2019 Table 4

local enrollment_y2_control = 0.61 // Denning et al. 2019 Table 4

local enrollment_y3_control = 0.55 // Denning et al. 2019 Table 4

local enrollment_y4_control = 0.38 // Denning et al. 2019 Table 4

local enrollment_y5_control = 0.20 // Denning et al. 2019 Table 4

local enrollment_y6_control = 0.10 // Denning et al. 2019 Table 4

local enrollment_y7_control = 0.07 // Denning et al. 2019 Table 4

local bach_7year = 0.062 //Denning et al. 2019 Table 4

local program_cost = 1000 // Denning et al. 2019 Table 5, cost normalized to $1000
local mean_earning_y7 = 23728  // Denning et al. 2019 Table 5

local year_8_age = 26 // Denning et al. 2019 Table 1 has mean age at application of 18.6. 8 years after application, age is ~26
local year_7_age = `year_8_age' - 1
local observed_start = 1
local observed_end = 7
local proj_start = 8
local end_earn = min(25, `proj_age') - 18
local years_effect = `proj_age' - `year_8_age'

local usd_year = 2013 // Denning et al. 2018, Page 6
local analysis_year = 2014 // Denning et al. 2019, Pages 6-7 notes 7 years of analysis are included for cohorts starting in 2008 and 2009.

local year_return = 0.1126 // Zimmerman 2014

*********************************
/* 4. Intermediate Calculations */
*********************************

*Calculate Observed Tax Rate
local tax_rate_prog = `fed_tax'/(`sum_earn'+`fed_tax')
/*This calculation assumes Denning et al. 2019 Table 6 reports earnings post tax.
At the discontinuity, aid for first time entrants jumps by $658. The estimates of yearly earnings gains in Table 5 correspond to increase earnings due to a $1000 increase in aid. Consequently, we would expect this table to report the earnings gains for a treated individual scaled by a factor of 1000/658. Table 6 provides the cumulative earnings gains amongst treated individuals. In this case, earnings gains are not scaled by a factor of 1000/658. Since the notes on Table 6 say that the reporting earning impact comes from summing the earnings effects in years 4 through 7, we can compare the numbers in the respective tables. We should expect the earnings gains in Table 5 to be greater than the earnings impact in Table 6 by a factor of 1000/658. In truth, they are greater by a factor
of 1000/576. We only recover the 1000/658 ratio when we add the Federal Income Tax estimates in Table 6 to our earnings estimates. Consequently, we assume the earnings gains reported in Table 6 are post-tax earnings.*/

*Calcualte Observed Rate of FICA Contributions
local fica_rate_prog = `FICA_tax'/(`sum_earn'+`fed_tax')

*Calculate Earnings Gain as a Fraction of Control Group Earnings in Last Observed Year
local earn_rate = `earning_y7'/`mean_earning_y7'

*Choose Tax Rate for Use in Calculation
local tax_rate = 0
if "`tax_rate_assumption'" == "paper internal" {
	local tax_rate = `tax_rate_prog'+ (`fica_rate_prog'*`fica_tax_fraction')
	local tax_rate_short = `tax_rate'
	local tax_rate_long = `tax_rate'
}

if "`tax_rate_assumption'" == "continuous"{
	local tax_rate_short = `tax_rate_cont'
	local tax_rate_long = `tax_rate_cont'
}

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `mean_earning_y7' , /// annual control mean earnings
		inc_year(`analysis_year') /// year of income measurement
		include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
		include_transfers(yes) /// transfers not otherwise accounted for
		usd_year(`usd_year') /// usd year of income
		forecast_income(yes) /// if childhood program where need lifecycle earnings, yes
		earnings_type(individual) ///
		program_age(25) // this corresponds to year 7

	local tax_rate = r(tax_rate)
	local tax_rate_short = `tax_rate'
	local tax_rate_long = `tax_rate'
}

if "`tax_rate_assumption'" == "mixed" {
	local tax_rate_short = `tax_rate_prog'+ (`fica_rate_prog'*`fica_tax_fraction')

	get_tax_rate `mean_earning_y7' , /// annual control mean earnings
		inc_year(`analysis_year') /// year of income measurement
		include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
		include_transfers(yes) /// transfers not otherwise accounted for
		usd_year(`usd_year') /// usd year of income
		forecast_income(yes) /// if childhood program where need lifecycle earnings, yes
		earnings_type(individual) ///
		program_age(25) // this corresponds to year 7

	local tax_rate_long = r(tax_rate)
}

*Created Discounted Sum of Total Observed Earnings
local total_earn = 0
forvalues i = `observed_start'/`observed_end'{
	local total_earn = `total_earn' +  `earning_y`i''*(1/(1+`discount_rate')^(`i'-1))
}


*Estimate Long-Run Earnings Effect Using Growth Forecast Method
local earn_proj = 0
if "`proj_type'" == "growth forecast"{
	est_life_impact `earn_rate', ///
		impact_age(`year_7_age') project_age(`year_8_age') end_project_age(`proj_age') ///
		project_year(`analysis_year') usd_year(`usd_year') ///
		income_info(`mean_earning_y7') income_info_type(counterfactual_income) ///
		percentage("yes") ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		max_age_obs(`year_7_age')


	local earn_proj = r(tot_earn_impact_d)*(1/(1+`discount_rate')^(`year_8_age'-18))
}

*Incorporate taxes into earnings effects
local combined_earn = `earn_proj' + `total_earn'
local increase_taxes = `tax_rate_short' * `total_earn' + `earn_proj'*`tax_rate_long'
local total_earn_impact_aftertax = `combined_earn' - `increase_taxes'

*Estimate Induced Fraction
local induced_fraction = `earn_rate'/(`year_return'*`years_bach_deg')
/*
Note: This is an attempt to determine the fraction of treated individuals
induced to change their behavior as the result of the Pell aid. The 6.2%
of individuals confirmed to have graduated could not produce an effect of
sufficient magnitude. We assume that all individuls who change their earnings
in response to the $1000 in grant aid change their earnings by an amount equivalent
to two years of additional schooling. From there, we can find the fraction of grant
recipients who must be induced into changing their behavior to explain the full
earnings effect.
*/

**************************
/* 5. Cost Calculations */
**************************
*Calculate Discounted Years of Additional Enrollment Induced by the Grant
local total_enroll = 0
local total_enroll_disc = 0
forvalues i = 1/`end_earn'{
local total_enroll = `total_enroll' + `enrollment_y`i''
local total_enroll_disc = `total_enroll_disc' + (`enrollment_y`i'')/((1+`discount_rate')^(`i'-1))
}

*Calculate Government Costs of Additional Enrollment
cost_of_college, year(`analysis_year') state("TX") type_of_uni("rmb")
local cost_of_college = `r(cost_of_college)'
local year_cost = `cost_of_college'
local add_year_costs = `total_enroll_disc'*`year_cost'
/*
Note: We assume here that 100% of schooling expenditures are covered by the government. This approximation is used because total grant aid for ineligible students is reported
as $9,250, a figure higher than yearly tuition costs. Total loans are only $2,835. This approached is used to measure that added costs of persistent enrollment rather than the estimates of crowded in grant funds from Table 6 of the paper. This is because the fiscal costs of increased persistence extend beyond grant funds and the paper makes clear that increased persistence in enrollment is the primary channel through which additional grant costs accumulate. The paper explains that receiving Pell Aid in the first year does not
have a mechanical effect on receipt in future years so no adjustment for double counting is necessary.
*/


*Calculate total costs adjusting for tax revenue
local total_cost = `program_cost' - `increase_taxes' + `add_year_costs'
global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'

*************************
/* 6. WTP Calculations */
*************************

*Calculate WTP based on valuation assumption
if "`wtp_valuation'" == "post tax"{
	local WTP_induced = `total_earn_impact_aftertax'
	local WTP_non_induced = (1-`induced_fraction')*`program_cost'
	local WTP = `WTP_non_induced' + `WTP_induced'
}

if "`wtp_valuation'" == "cost"{
	local WTP_non_induced = (1-`induced_fraction')*`program_cost'
	local WTP_induced = (`induced_fraction')*`program_cost'*`val_given_marginal'
	local WTP = `WTP_non_induced' + `WTP_induced'
}
/*
Note: We assume that all students value the transfer at cost and that there are
no marginal enrollees. This is because Denning et al. 2019 make clear that there
are no initial enrollment effects.
*/
display `WTP'
global WTP_`1' = `WTP'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

/*
Figures for Attainment Graph
*/
di  `bach_7year'*`years_bach_deg' //attainment gain
di `total_enroll' // alternate attainment gain
di  1 // baseline enrollment
di  `program_cost'*(1-`bach_7year') // Mechanical Cost
di  `program_cost'*(`bach_7year') // Behavioral Cost Program
di 	`add_year_costs' // Behavioral Cost Crowd-In
di `WTP_induced' //WTP induced
di `WTP_non_induced' //WTP Non-Induced
di 	`mean_earning_y7' // Income Counter-Factual


*Appendix Values
di `total_earn'
di `combined_earn'
di `WTP'
di `add_year_costs'
di `increase_taxes'
di `total_cost'
di `MVPF'


display `MVPF'
display `WTP'
di `total_cost'
global MVPF_`1' = `MVPF'
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption

* income globals
global inc_stat_`1' = `mean_earning_y7'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `analysis_year'
global inc_age_stat_`1' = 25

global inc_benef_`1' = `mean_earning_y7'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `analysis_year'
global inc_age_benef_`1' = 25

