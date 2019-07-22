********************************
/* 0. Program: NSW Youth  */
********************************

/*
Couch, Kenneth A.
"New evidence on the long-term effects of employment training programs."
Journal of Labor Economics 10, no. 4 (1992): 380-388.

Hollister, Robinson G., Peter Kemper, and Rebecca A. Maynard.
"The national supported work demonstration." (1984).
Chapter: Kemper P., David A. Long and Craig Thorton.
"A Benefit-Cost Analysis of the Supported Work Experiment."
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "${tax_rate_assumption}" //takes value paper internal, continuous
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_cont = $tax_rate_cont
}
local payroll_assumption = "$payroll_assumption" // "yes" or "no"


local proj_type = "${proj_type}" //takes value observed or growth forecast
local proj_length 	= "$proj_length" //"observed", "8yr", "21yr", or "age65"
local net_transfers = "$net_transfers" //takes value yes if adjustments for changes in net transfers
local wtp_valuation = "$wtp_valuation" //takes on value of "post tax", "cost" or "reduction private spending"

local nsw_estimates "$nsw_estimates" // "kemper" or "couch" or "both"


if "`proj_type'"=="growth_forecast" {
	cap assert "`nsw_estimates'" == "both"
	if _rc > 0 {
		di as err "In order to use projections one must set nsw_estimates to both"
		exit
	}
}

*********************************
/* 2. Causal Inputs from Paper */
*********************************



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

/*
local static_tax_fe = 301 // KLT Page 256, Table 8.5
*Participant short-term tax payment due to program participation.

local static_welfare_fe = -474 // KLT Page 256, Table 8.5
*Participant short-term change in welfare receipt due to program participation.

local initial_earnings = -3 // KLT Page 256, Table 8.5.
*Participant short-term earnings gain due to program partcipation.

T-stat for these is inferred from the year 1979 in Couch 1992. The t-statistic is
(9/175) so that is assumed here and the standard error is backed out.

*Couch Table 1; Average annual earnings difference between treatment and control groups, with SE's, from 1972-1986
*This examines the long-term impact of program participation.
*These are the results after training is administered.
local y_1979 = 9
local y_1979_se = 175
*Couch (1992) notes potential data problems for 1980 and 1981 earnings
local y_1980 = 157
local y_1980_se = 203
local y_1981 = 61
local y_1981_se = 169
local y_1982 = 72
local y_1982_se = 185
local y_1983 = 17
local y_1983_se = 195
local y_1984 = -7
local y_1984_se = 217
local y_1985 = 17
local y_1985_se = 242
local y_1986 = -34
local y_1986_se = 267

*/

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local usd_year = 1978 // Couch (1992) footnote 8
local deflate_76 = 1.086 // Couch (1992) footnote 8 inflation adjustment for Kemper, Long & Thornton (1984). Deflation from 1976 Q4 to 1978 Q1.

local alt_program_training = 4 * `deflate_76' // Kemper, Long, Thornton (1984) Page 256, Table 8.5. Reductions in payments to individuals from training programs foregone when individuals enroll in NSW.
local alt_program_admin = 83 * `deflate_76'  // Kemper, Long, Thornton (1984) Page 256, Table 8.5. Cost to the government of other training programs foregone when individuals enroll in NSW.

local age_1985 = 18 + 10 // Couch 1992, pg. 387.

local proj_start_age = `age_1985' + 2
local project_year = 1987

local program_year 1976

* This section should have EVERY causal effect that we draw upon from the paper, with references to the MVPF Spreadsheet.
local program_cost = 4193  * `deflate_76' // Kemper, Long, Thornton (1984) Page 256, Table 8.5. Figure for net cost to "non-participant." Augmented using the inflation adjustment from Couch 1992, found in footnote 8.

local program_pay = 2577 * `deflate_76' // Kemper, Long, Thornton (1984) Page 256, Table 8.5. Figure for net cost to "participant." Augmented using the inflation adjustment from Couch 1992, found in footnote 8.
local mean_age = 18 // Couch Table A1: Experimental mean age = 18.21; Control mean age = 18.35

* Inflation adjust bootstrapped estimates:
foreach local in static_tax_fe static_welfare_fe initial_earnings {
	local `local' = ``local''*`deflate_76'
}

*No direct income observed but aimed at AFDC eligible so use federal poverty line
local cfactual_income = 6612 // 1978 FPL for family of 4 with 2 children, from Census source in get_tax_rate.ado

*********************************
/* 4. Intermediate Calculations */
*********************************

*Aggregate Couch (1992) earnings estimates
local earnings_1979_1986 = 0
forvalues i = 1979/1986 {
	local earnings_1979_1986 = `earnings_1979_1986' + `y_`i''/((1+`discount_rate')^(`i'-`program_year'))
}

if "`nsw_estimates'" == "both" {
	local earn_impact_obs = `earnings_1979_1986' + `initial_earnings' + `program_pay'
}
else if "`nsw_estimates'" == "couch" {
	local earn_impact_obs =  `earnings_1979_1986' + `program_pay'
}
else if "`nsw_estimates'" == "kemper" {
	local earn_impact_obs = `initial_earnings' + `program_pay'
}

*Project earnings forewards
if "`proj_type'" == "observed" {
	local total_earn_impact = `earn_impact_obs'
}

if "`proj_length'" == "21yr"	local proj_end_age = `proj_start_age'+12
if "`proj_length'" == "age65"	local proj_end_age = 65

if "`proj_type'" == "growth forecast"{
	local earn_future = (`y_1986' + `y_1985' + `y_1984')/3 // Begin projection from the effect in later years

	est_life_impact `earn_future', ///
		impact_age(`age_1985') project_age(`proj_start_age') end_project_age(`proj_end_age') ///
		usd_year(`usd_year') project_year(`project_year') ///
		income_info(`cfactual_income') income_info_type(counterfactual_income) ///
		earn_method($earn_method) ///
		tax_method($tax_method) ///
		transfer_method($transfer_method) ///
		max_age_obs(`=`age_1985'+1')

	*Discount Earnings back to Initial year
	local earn_proj = ((1/(1+`discount_rate'))^(`project_year' - `program_year')) * r(tot_earn_impact_d)
	local total_earn_impact = `earn_impact_obs' + `earn_proj'
}


*Use assumptions to determine fiscal externality rate
if "`tax_rate_assumption'" == "paper internal" {
	local fe_rate = (`static_tax_fe')/(`initial_earnings'+ `program_pay')
}

if "`tax_rate_assumption'" == "continuous" {
	local fe_rate = `tax_rate_cont'
}

if "`tax_rate_assumption'" ==  "cbo" {
	local forecast_income no
	if regexm("`proj_type'","forecast") local forecast_income yes

	get_tax_rate `cfactual_income', ///
		include_transfers(no) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(`forecast_income') /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`project_year') /// year of income measurement
		program_age(`age_1985') ///
		earnings_type(household) // individual or household

	local fe_rate = r(tax_rate)
}


*Calculate Total Transfers if net transfers are included in WTP
local change_transfers = -`total_earn_impact' * `fe_rate'
if "`net_transfers'" == "yes" {
	local change_transfers = `change_transfers' + `static_welfare_fe' - `alt_program_training'
}

**************************
/* 5. Cost Calculations */
**************************

local fe = -`total_earn_impact'*`fe_rate' + `static_welfare_fe' - `alt_program_admin'

local total_cost = `program_cost' + `fe'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" {
	local WTP = `total_earn_impact' + `change_transfers'
}

if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost'
}

if "`wtp_valuation'" == "reduction private spending" {
	*This is something of a lower bound: participant values at value of alternate
	*programs, i.e. what they were willing to forego
	local WTP =  `alt_program_admin' +  `alt_program_training'
}

if "`wtp_valuation'" == "lower bound" {
	local WTP = 0.01*`program_cost'
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'
di `fe_rate'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'

global age_stat_`1' = `mean_age'
global age_benef_`1' = `mean_age'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_income' *r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `program_year' // 1-10 years after move average
global inc_age_stat_`1' = `mean_age'

global inc_benef_`1' = `cfactual_income'*r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `program_year'
global inc_age_benef_`1' = `mean_age'

