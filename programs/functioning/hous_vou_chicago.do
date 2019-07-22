***********************************************************
/* 0. Program: Jacob & Ludwig Housing Vouchers in Chicago */
***********************************************************

/*
*Labor market outcomes from:
Jacob, B. A., & Ludwig, J. (2012). The effects of housing assistance on labor 
supply: Evidence from a voucher lottery. American Economic Review, 102(1), 272-304.

Children's outcomes from:
Jacob, B. A., Kapustin, M., & Ludwig, J. (2014). The impact of housing assistance 
on child outcomes: Evidence from a randomized housing lottery. The Quarterly Journal 
of Economics, 130(1), 465-506.

* grant housing vouchers in a randomized lottery in Chicago 

*/

********************************
/* 1. Pull Global Assumptions */
********************************

local ev_correction = "$ev_correction" // "yes" or "no"
local value_transfer = "$value_transfer"

local tax_rate_assumption = "$tax_rate_assumption" // "continuous"
if "`tax_rate_assumption'" == "continuous" local tax_rate = $tax_rate_cont
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local correlation = $correlation
local wtp_valuation = "$wtp_valuation" // "cost" or "post tax"
local proj_type = "$proj_type" // "growth forecast" or "no kids", i.e. ignore kids
local discount_rate = $discount_rate 
local proj_age = $proj_age



******************************
/* 2. Causal Inputs from Paper */
******************************

/*

local earnings_impact = -328.95 // Jacob & Ludwig (2012) table 3
local earnings_impact_se = 74.56 // Jacob & Ludwig (2012) table 3
*Note: earnings are all reported quarterly in Jacob & Ludwig (2012)

*likelihood received public assistance
local pub_assist_impact = 0.067 // Jacob & Ludwig (2012) table 3
local pub_assist_impact_se = 0.009 // Jacob & Ludwig (2012) table 3

*likelihood received TANF
local tanf_impact = 0.017 // Jacob & Ludwig (2012) table 3
local tanf_impact_se = 0.004 // Jacob & Ludwig (2012) table 3

*likelihood received Medicaid
local medicaid_impact = 0.058 // Jacob & Ludwig (2012) table 3
local medicaid_impact_se = 0.009 // Jacob & Ludwig (2012) table 3

*likelihood received food stamps
local food_stamps_impact = 0.076 // Jacob & Ludwig (2012) table 3
local food_stamps_impact_se = 0.008 // Jacob & Ludwig (2012) table 3

*test score impact
local test_impact_m_0_6 = 0.0634 // Jacob, Kasputin & Ludwig (2015) table 3
local test_impact_m_0_6_se = 0.0325
local test_impact_f_0_6 = 0.0029 // Jacob, Kasputin & Ludwig (2015) table 3
local test_impact_f_0_6_se = 0.0316 
local test_impact_m_6_18 = 0.0126 // Jacob, Kasputin & Ludwig (2015) table 3
local test_impact_m_6_18_se = 0.0273
local test_impact_f_6_18 = 0.03 // Jacob, Kasputin & Ludwig (2015) table 3
local test_impact_f_6_18_se = 0.0273 
Test score effects are average effects over all post-treatment years.

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

local usd_year = 2007 // Jacob & Ludwig (2012)  table 3
*Jacob, Kasputin & Ludwig (2015) is in 2013 dollars, these are converted where necessary

local mean_voucher_start_year = (0.503*1540*1997 + 0.501*3085*1998 + 0.436*2631*2000 + ///
	0.445*5733*2001 + 0.497*4674*2002 + 0.427*446*2003) / (0.503*1540 + 0.501*3085 + 0.436*2631 + ///
	0.445*5733 + 0.497*4674 + 0.427*446)
local mean_voucher_start_year_int = round(`mean_voucher_start_year',1)
/*
The number of families offered vouchers per year (and the voucher use rate)
was 1,540 (50.3%) in 1997; 3,085 (50.1%) in 1998; 2,631 (43.6%) in 2000; 5,733
(44.5%) in 2001; 4,674 (49.7%) in 2002; 446 (42.7%) in 2003. -  Jacob, Kasputin & Ludwig (2015) footnote 16

Data run up to 2011 and test score impacts are averaged across all post-treatment
periods. Thus, the average number of years of vouchers over this period is 
2011 - `mean_voucher_start_year_int'

Thus we treat the policy as vouchers until 2011, as it is unclear where any test 
score impacts come from over the period.
*/

local years_vouchers = 2011 - `mean_voucher_start_year_int'

*2013-2007 deflator
deflate_to 2013, from(2007)
local cpi_13_07 = r(deflator)

*1998-2007 inflator
deflate_to 2007, from(1998)
local cpi_98_07 = r(deflator)

local voucher_cost = 8383 // Jacob & Ludwig (2012) Appendix pg. 22


local house_head_age = 30.624 // Jacob & Ludwig (2012) table 1

local num_adults = 1.4 // Jacob, Kasputin & Ludwig (2015) table 1
local num_kids = 3 // Jacob, Kasputin & Ludwig (2015) table 1

local pct_kids_0_6 = 8659/14348 // Jacob, Kasputin & Ludwig (2015) table 3

local mean_child_age = 8.2 // Jacob, Kasputin & Ludwig (2015) table 1

local prior_household_earnings = 18461 *`cpi_13_07' // 1996:III-1997:II, Jacob, Kasputin & Ludwig (2015) table 1

/*
No information is available on household pre-tax earnings and so this figure for household earnings is used instead.
*/

local benefit_ratio = 0.83
/*
"Reeder (1985) estimates the ratio of mean benefit to mean subsidy for housing 
vouchers to be around 0.83, so that the average equivalent variation of a housing 
voucher for our sample is $6,860 per year." - Jacob & Luidwig pg. 281
*/

if "`ev_correction'" == "yes" local ev_coeff = `benefit_ratio'
else local ev_coeff = 1


*SNAP value
local snap_value_month = 179.10 * `cpi_98_07'
local snap_value = 12*`snap_value_month'
/*
From USDA FNS: https://www.fns.usda.gov/pd/supplemental-nutrition-assistance-program-snap
1998 average per-family monthly SNAP value for Illinois
*/

*Medicaid costs
local medicaid_value = 4435 * `cpi_98_07'
/*
From: http://www.ppinys.org/reports/jtf/2001/Table%2042.htm
Medicaid cost per person served in 1998 for Illinois
*/

*TANF value
local tanf_per_family_per_month = 358 * `cpi_98_07'
local tanf_value = 12 * `tanf_per_family_per_month'
/*
1998 for entire US
https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/afdctanf-program-data
*/

**********************************
/* 4. Intermediate Calculations */
**********************************

*Get tax rate 
if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `prior_household_earnings' , /// annual control mean earnings 
		inc_year(1996) /// year of income measurement 
		include_payroll("`payroll_assumption'") /// (y/n)
		include_transfers(no) /// 
		usd_year(`usd_year') /// usd year of income 
		program_age(`=round(`house_head_age')') /// age of program beneficiaries when income is measured 
		forecast_income(no) /// if childhood program where lifecycle earnings needed, yes
		earnings_type(household) /// optional option, only if info provided. default is 4 
		kids(`=round(`num_kids')')
		
	local tax_rate = r(tax_rate) + 0.3 // add 30% as voucher recipient
	local tax_rate_cont = r(tax_rate) + 0.3 // add 30% as voucher recipient
}

*Average young and old children's test score impacts
foreach sex in m f {
	local test_impact_`sex' = `test_impact_`sex'_0_6' * `pct_kids_0_6' + ///
								`test_impact_`sex'_6_18' * (1-`pct_kids_0_6')
}

*Average male and female test score impacts
local test_impact = (`test_impact_m' + `test_impact_f')/2

*Multiply quarterly earnings by 4 to get adult yearly impact
local year_earn_impact = `earnings_impact'*4

local tax_impact = `tax_rate' * `year_earn_impact'

*Forecast impact on kids
if "`proj_type'" == "growth forecast" {
	*Forecast impact on average child
	int_outcome, outcome_type(test score) impact_magnitude(`test_impact') usd_year(`usd_year')
	
	local pct_earn_impact = r(prog_earn_effect)
		
	local proj_start_age = 18
	local mean_child_age_int = round(`mean_child_age',1)
	local project_year = `mean_voucher_start_year_int' + `proj_start_age' - `mean_child_age_int'
	
	est_life_impact `pct_earn_impact', ///
		impact_age(`proj_start_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`prior_household_earnings') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		parent_age(`=round(`house_head_age',1)') ///
		parent_income_year(1996) percentage(yes)
		
	local total_earn_impact = ((1/(1+`discount_rate'))^(`proj_start_age' - `mean_child_age_int')) * r(tot_earn_impact_d)
	local cfactual_income = r(cfactual_income)
	
	*Get tax rate for kids
	get_tax_rate `cfactual_income' , /// annual control mean earnings 
		inc_year(`project_year') /// year of income measurement 
		include_payroll("`payroll_assumption'") ///
		include_transfers(yes) ///
		usd_year(`usd_year') /// usd year of income 
		program_age(`proj_start_age') /// age of program beneficiaries when income is measured 
		forecast_income(yes) /// if childhood program where need lifecycle earnings, yes
		earnings_type(individual) 
	
	local tax_rate_kid = r(tax_rate)
	
	local increase_taxes = `tax_rate_kid' * `total_earn_impact'
	
	*Make earning impact and tax increase at the household level
	local total_earn_impact = `total_earn_impact' * `num_kids'
	local increase_taxes = `increase_taxes' * `num_kids'
}
	
else if "`proj_type'" == "no kids" {
	local total_earn_impact = 0
	local increase_taxes = 0
	local tax_rate_kid = 0
}

**************************
/* 5. Cost Calculations */
**************************

*Yearly costs - voucher impacts on adults viewed as static
local year_cost = `voucher_cost' // no admin costs etc.

*we assume that if the head of household moves onto medicaid the entire family does too.
local year_FE = `tax_impact' - `snap_value'*`food_stamps_impact' - ///
	(`medicaid_value' * (`num_adults' + `num_kids') * `medicaid_impact') - ///
	(`tanf_value' * `tanf_impact'*(0.7)) 
/*
TANF impact is multiplied by 0.7 because Jacob and Ludwig 2012 Appendix pg. 2 
indicates that increases in TANF benefits are offset by 30% due to a decline in 
housing voucher benefits.

We also assume that if the head of household moves onto medicaid the entire family
does as well.
*/
	
di `year_FE'
di -`year_FE' + `year_cost'
di `year_FE' - `tax_impact'

*Scale up to voucher_years assumption
local program_cost = 0
local FE = 0
forval i = 1/`years_vouchers' {
	local program_cost = `program_cost' + `year_cost' * (1/(1+`discount_rate')^(`i'-1))
	local FE = `FE' + `year_FE' * (1/(1+`discount_rate')^(`i'-1))
}

*Incorporate effects on children
local total_cost = `program_cost' - `FE' - `increase_taxes'


*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "cost" {
	forval i = 1/`years_vouchers'{
		local WTP = `WTP' + `ev_coeff'*`year_cost' * (1/(1+`discount_rate')^(`i'-1))
	}
	local WTP_kid = 0
	if "`value_transfer'" == "yes"{
	
		forval i = 1/`years_vouchers'{
			local WTP = `WTP' + ((`snap_value'*`food_stamps_impact') + ///
			(`medicaid_value' * (`num_adults' + `num_kids') * `medicaid_impact') + ///
			(`tanf_value' * `tanf_impact'))*(1/(1+`discount_rate')^(`i'-1))
	}
	
	}
}

if "`wtp_valuation'" == "post tax" {
	forval i = 1/`years_vouchers' {
		local WTP = `WTP' + `ev_coeff'*`year_cost' * (1/(1+`discount_rate')^(`i'-1))
	}
	
	local WTP_kid = (1-`tax_rate_kid')*`total_earn_impact'
	
	if "`value_transfer'" == "yes"{
	forval i = 1/`years_vouchers' {
	local WTP = `WTP' + ((`snap_value'*`food_stamps_impact') + ///
	(`medicaid_value' * (`num_adults' + `num_kids') * `medicaid_impact') + (`tanf_value' * `tanf_impact'))* ///
	(1/(1+`discount_rate')^(`i'-1))
	}
	}
}
else{
	local WTP_kid = 0
}

local WTP = `WTP' + `WTP_kid'

local age_stat = `house_head_age'
if `WTP_kid'>`=`WTP'/2' local age_benef = `mean_child_age'
else local age_benef = `house_head_age'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `tax_rate' * `year_earn_impact'
di `tax_rate'
di `year_earn_impact'
di `year_FE'
di `year_FE' - `tax_impact'
di `year_cost' - `year_FE'
di `year_cost' - `year_FE' - (`increase_taxes'/11)
di `ev_coeff'*`year_cost'

di `WTP'

di `total_earn_impact' 
di `increase_taxes'

di 	`medicaid_value'
di `MVPF'
di `total_earn_impact'
di `tax_rate_kid'*`total_earn_impact'
di `total_earn_impact' / `years_vouchers'
di `tax_rate_kid'*`total_earn_impact' / `years_vouchers'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `prior_household_earnings' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = 1997
global inc_age_stat_`1' = `=round(`house_head_age',1)'

if `age_benef'==`age_stat' {
	global inc_benef_`1' = `prior_household_earnings' * r(deflator)
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = 1997
	global inc_age_benef_`1' = `=round(`house_head_age',1)'
}
else {
	global inc_benef_`1' = `cfactual_income'*r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `project_year'+34-`proj_start_age'
	global inc_age_benef_`1' = 34 // child income is predicted from parent income
}



