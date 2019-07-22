/*******************************************************************************
 0. Program: Disability Ins. -- Judge Leniency 
*******************************************************************************/

/*
French, Eric, and Jae Song. "" 
American economic Journal: economic policy 6, no. 2 (2014): 291-337.

Gelber, Alexander, Timothy J. Moore, and Alexander Strand. 
"The Effect of Disability Ins. Payments on Beneficiaries' Earnings." 
American Economic Journal: Economic Policy 9, no. 3 (2017): 229-61.

Maestas, Nicole, Kathleen J. Mullen, and Alexander Strand. 
"Does disability insurance receipt discourage work? Using examiner assignment 
to estimate causal effects of SSDI receipt." 
American economic review 103, no. 5 (2013): 1797-1829.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************
local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"
local tax_rate_cont = $tax_rate_cont 

*Program Specific Globals
local health_cost = $health_cost

*********************************
/* 2. Estimates from Paper */
*********************************
/*
local earning_effect = -5787 // French and Song 2014, Table 6, Pg. 313
local earning_effect_se = 418 // French and Song 2014, Table 6, Pg. 313
Note: Calculations here focus on the results after 3 years of assignment. 
The authors also report results after five years, but note some recipients
have begun to retire to interpretation is less clear. 


*Change relative to SGA 
local sga_2005_y2 = -0.192 // Maestas et al. 2013 Table 4
local sga_2005_y2 = (-0.192/7.62) // Maestas et al. 2013 Table 4
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

local prior_earnings = 25763 // French and Song (2014), Table 6, Panel G
local income_year = 1988 //French and Song (2014) Data section 
local usd_year = 2006 //  French & Song (2014)

local avg_benefit = 1130*12 // French and Song 2014, Pg. 295

if `health_cost' == 1 {
	*Gelber et al. estimate is in USD2013 -> convert
	deflate_to `usd_year', from(2013)
	local avg_benefit = `avg_benefit' + (7200*r(deflator)) 
	*French and Song 2014, Pg. 295 and Gelber et al. 2017, Page 255
}

*Get ages
local p_35_45 = 0.364 //  French & Song (2014) table A2
local p_45_54 = 0.424 //  French & Song (2014) table A2
local p_55_59 = 0.138 //  French & Song (2014) table A2
local p_60_64 = 0.074 //  French & Song (2014) table A2

local avg_age = 	`p_35_45'*(35+45)/2 + ///
					`p_45_54'*(54+45)/2 + ///
					`p_55_59'*(55+59)/2 + ///
					`p_60_64'*(60+64)/2

*Single beneficiary
local age_stat = `avg_age'
local age_benef = `avg_age'

*********************************
/* 4. Intermediate Calculations */
*********************************

if "`tax_rate_assumption'" == "cbo"{
	get_tax_rate `prior_earnings', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`income_year') /// year of income measurement
		earnings_type(individual)
		
	local tax_rate_cont = r(tax_rate)	
	di r(quintile)
	di r(pfpl)
}
	
local fe = -`tax_rate_cont'*`earning_effect'

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
di "`avg_benefit' + (`avg_benefit'*`sga_2005_y2')"
di `avg_benefit' + (`avg_benefit'*`sga_2005_y2')
di `avg_benefit'*`sga_2005_y2'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'


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
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `prior_earnings' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `income_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `prior_earnings' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `income_year'
global inc_age_benef_`1' = `age_benef'
