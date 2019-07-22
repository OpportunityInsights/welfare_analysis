/*******************************************************************************
 0. Program: Disability Ins. -- Judge Leniency 
*******************************************************************************/

/*
French, Eric, and Jae Song. "The effect of disability insurance receipt on labor supply." 
American economic Journal: economic policy 6, no. 2 (2014): 291-337.

Gelber, Alexander, Timothy J. Moore, and Alexander Strand. 
"The Effect of Disability Ins. Payments on Beneficiaries' Earnings." 
American Economic Journal: Economic Policy 9, no. 3 (2017): 229-61.

Deshpande, M. (2016)
"Does welfare inhibit success? The long-term effects of removing low-income youth 
from the disability rolls" 
American Economic Review, 106(11), 3300-3330.

United States Social Security Administration. (2014)
"SSI Annual Statistical Report, 2013"
SSA Publication No. 13-11827
*/


********************************
/* 1. Pull Global Assumptions */
*********************************

local tax_rate_assumption = "$tax_rate_assumption"
local payroll_assumption = "$payroll_assumption"
local transfer_assumption = "$transfer_assumption"
if "`tax_rate_assumption'" == "continuous" {
	local tax_rate_cont = $tax_rate_cont 
}
local correlation = $correlation
local wtp_valuation = "$wtp_valuation"
*Program Specific Globals
local health_cost = $health_cost
local insur_val = "$insur_val" // "yes" or "no" toggle for valuation of reduction in income volatility from SSI

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
local earning_effect = 3138 // French and Song 2014, Table 6, Pg. 313
local earning_effect_se = 168 // French and Song 2014, Table 6, Pg. 313
Note: Calculations here focus on the results after 3 years of assignment. 
The authors also report results after five years, but note some recipients
have begun to retire so interpretation is less clear. 
*/

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local prior_earnings = 8934 // French and Song (2014), Table 6, Panel G
local income_year = 1988 //French and Song (2014) Data section 
local usd_year = 2006 //  French & Song (2014)

*Only mechanical size of the transfer is valued. Therefore, we subtract the size 
*of the transfer that is increased due to reductions in earnings
local ssi_disregard = 0.5

*Gelber et al./US SSA estimates are in USD2013 -> convert
deflate_to 2006, from(2013)
local cpi_u_2013_2006 = r(deflator)

*US SSA: SSI Recipients by State and County, 2013:
*https://www.ssa.gov/policy/docs/statcomps/ssi_asr/2013/ssi_asr13.pdf
local avg_fed_benefit = 546.38*`cpi_u_2013_2006' // table 5, 18-64, monthly
local avg_state_supplement = 129.16*`cpi_u_2013_2006' // table 5, 18-64, monthly
local avg_benefit = (`avg_fed_benefit'+`avg_state_supplement')*12
/*
NOTE: This alternate calculation uses the value of additional health insurance benefits 
provided. 
*/
if `health_cost' == 1 {
	local avg_benefit = `avg_benefit' + (7200*`cpi_u_2013_2006') 
	*Gelber et al. 2017, Page 255
}

*Additional WTP from insurance value of SSI
if "`insur_val'" == "yes"	local insur_val_premium = 0.15 // Deshpande (2016) pg. 3327
if "`insur_val'" == "no"	local insur_val_premium = 0

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

**********************************
/* 4. Intermediate Calculations */
*********************************

if "`tax_rate_assumption'" ==  "cbo" {
	get_tax_rate `prior_earnings' , ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`income_year') /// year of income measurement 
		earnings_type(individual) // individual or household
	local tax_rate_cont = r(tax_rate)
	di r(quintile)
	di r(pfpl)
}

local fe = `earning_effect'*`tax_rate_cont'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `avg_benefit' - `ssi_disregard'*`earning_effect'

local total_cost = `avg_benefit' + `fe'


*************************
/* 6. WTP Calculations */
*************************

local WTP = (`avg_benefit' - (`ssi_disregard'*`earning_effect'))*(1+`insur_val_premium') 
di `WTP'
di "`avg_benefit'*(1+`insur_val_premium') - `ssi_disregard'*`earning_effect'"
di `total_cost'

if "`wtp_valuation'" == "lower bound" local WTP = `avg_benefit' - (`ssi_disregard'*`earning_effect')

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

di `MVPF'

*****************
/* 8. Outputs */
*****************

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = 	`age_stat' 

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `prior_earnings'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `income_year'
global inc_age_stat_`1' =`age_stat' 

global inc_benef_`1' = `prior_earnings'*r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `income_year' 
global inc_age_benef_`1' =`age_stat' 
