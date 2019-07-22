/*******************************************************************************
 0. Program: Disability Ins. -- Examiner Leniency 
*******************************************************************************/

/*
Maestas, Nicole, Kathleen J. Mullen, and Alexander Strand. 
"Does disability insurance receipt discourage work? Using examiner assignment 
to estimate causal effects of SSDI receipt." 
American economic review 103, no. 5 (2013): 1797-1829.

*/


********************************
/* 1. Pull Global Assumptions */
*********************************
local tax_rate_assumption = "$tax_rate_assumption" //takes value paper internal or cont, See Output_Wrapper.do for additional documentation
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local tax_rate_cont = $tax_rate_cont 
local correlation = $correlation

*Program Specific Global
if "$ui_di"!="yes" local health_cost = $health_cost

*If being run from within a UI program, use the Schmieder/von Wachter tax rate:
//Source: https://stats.oecd.org/Index.aspx?QueryId=55129.
if "$ui_di"=="yes" {
	local tax_rate_assumption = "continuous"
	local tax_rate_cont = 0.31437
	if "$DI_incl_med"== "yes"	local health_cost = 1
	else						local health_cost = 0
}
*********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
local avg_benefit = 1129*12 // Maestas et al. 2013 Page 1803

if `health_cost' == 1{
local avg_benefit = 1130*12 + 7200 // French and Song 2014, Pg. 295 and // Gelbach et al. 2017, Page 255
}
/*
NOTE: This alternate calculation uses the value of additional health insurance benefits 
provided. This is a number cited in French and Song 2014 and Gelber et al. 2017 
as a source of additional benefit provided by DI receipt. 
*/

*Earnings Change
local earning_2005_y2 = -3781 // Maestas et al. 2013 Table 4
local earning_2005_y2_se = (3781/3.05) // Maestas et al.2013 Table 4

*Change relative to SGA 
local sga_2005_y2 = -0.192 // Maestas et al. 2013 Table 4
local sga_2005_y2 = (-0.192/7.62) // Maestas et al. 2013 Table 4


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
		}
restore
	}

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local age_stat = 47.09 // Maestas et al. 2013, Table 1
local age_benef = `age_stat' // single beneficiary

local prior_earnings = 22697 //  Maestas et al. 2013, Table 1
local usd_year = 2008
local usd_year_benefits = 2010
local usd_year_health 2013
local inc_year 2001 // Maestas et al. 2013, Table 1 -- earnings 3-5 years prior to decision 

*Average benefits
deflate_to `usd_year', from(`usd_year_benefits')
local avg_benefit = 1129*12*r(deflator) // Maestas et al. 2013 Page 180

if `health_cost' == 1 {
	*Gelber et al. estimate is in USD2013 -> convert
	deflate_to `usd_year', from(`usd_year_health')
	local avg_benefit = `avg_benefit' + (7200*r(deflator)) 
	*French and Song 2014, Pg. 295 and Gelbach et al. 2017, Page 255
}
di `avg_benefit'

*********************************
/* 4. Intermediate Calculations */
*********************************


if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `prior_earnings' , ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`inc_year') /// year of income measurement 
		earnings_type(individual) /// individual or household

	local tax_rate_cont = r(tax_rate)
	di r(quintile)
	di r(pfpl)
}

local fe = -`earning_2005_y2'*`tax_rate_cont'
* get 2015 usd income
deflate_to 2015, from(`usd_year')
local earnings_2015 = `prior_earnings'*r(deflator)
**************************
/* 5. Cost Calculations */
**************************
local program_cost = `avg_benefit' + (`avg_benefit'*`sga_2005_y2')

local total_cost = `avg_benefit' + `fe'

di `total_cost'/`program_cost'

*************************
/* 6. WTP Calculations */
*************************
* we assume that people who changed their behavior to retain DI benefits (by keeping their earnings under the SGA
* threshold don't value the benefits (envelope theorem)

local WTP = `avg_benefit' + (`avg_benefit'*`sga_2005_y2')
di `WTP'
di " `avg_benefit' + (`avg_benefit'*`sga_2005_y2')"
di `avg_benefit'*`sga_2005_y2'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'
di `MVPF'
di `fe'
di "`WTP'/`total_cost'"

*****************
/* 8. Outputs */
*****************
global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'
* income globals
global inc_stat_`1' = `earnings_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `inc_year'
global inc_age_stat_`1' = round(`age_stat' -4) // since earnings 3-5 years prior to decision (Maestas et al 2013 table 1)

global inc_benef_`1' = `earnings_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `inc_year'
global inc_age_benef_`1' = round(`age_stat' -4) // since earnings 3-5 years prior to decision (Maestas et al 2013 table 1)

