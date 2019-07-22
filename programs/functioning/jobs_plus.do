********************************
/*Program: Jobs Plus */
********************************
/* "Promoting Work in Public Housing The Effectiveness of Jobs-Plus Final report
Howard s Bloom, James A Riccio, Nandita Verma and Johanna Walter" March 2005

Jobs-Plus: A Promising Strategy for Increasing Employment and
Self-Sufficiency Among Public Housing Residents
Presented Before the Subcommittee on Federalism and the Census, House
Committee on Government Reform
James A. Riccio, Director
Low-Wage Workers and Communities, MDRC 
June 20, 2006 

* provide employment and training to working-age, nondisabled residents of public
* housing developments.

*/


********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local wtp_valuation = "$wtp_valuation"
local proj_type = "$proj_type" //takes values "observed", "fixed forecast", "growth forecast"
local proj_age = $proj_age //takes on age at end of projection
local correlation = $correlation
local wage_growth_rate = $wage_growth_rate
local sample = "$sample" // full or high

* globals for finding the tax rate.
* Note: 'paper internal' = CBO + the 5% marginal increase in rent payments.
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo" or "paper internal"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate  = $tax_rate_cont
}

********************************
/* 2. Causal Inputs from Paper */
*********************************
/*
local year_earn_impact_full = 498 // Bloom et al (2005) table 4.1
local year_earn_impact_full_p = runiform(0, 0.01) // statistically significant at 1%
local year_earn_impact_full_t = invnormal(1- `year_earn_impact_full_p'/2)
local year_earn_impact_full_se = abs(`year_earn_impact_full'/`year_earn_impact_full_t')

local year_earn_impact_high = 1141 // Bloom et al (2005) table 4.1
local year_earn_impact_high_p = runiform(0, 0.01) // statistically significant at 1%
local year_earn_impact_high_t = invnormal(1- `year_earn_impact_high_p'/2)
local year_earn_impact_high_se = abs(`year_earn_impact_high'/`year_earn_impact_high_t')

local year_earn_impact_baltimore = -189 // Bloom et al (2005) table 4.3
local year_earn_impact_baltimore_p = runiform(0.1, 0.9) // not statistically significant at 10%
local year_earn_impact_baltimore_t = invnormal(1- `year_earn_impact_baltimore_p'/2)
local year_earn_impact_baltimore_se = abs(`year_earn_impact_baltimore'/`year_earn_impact_baltimore_t')

local year_earn_impact_chatta = -224 // Bloom et al (2005) table 4.3
local year_earn_impact_chatta_p = runiform(0.1, 0.9) // not statistically significant at 10%
local year_earn_impact_chatta_t = invnormal(1- `year_earn_impact_chatta_p'/2)
local year_earn_impact_chatta_se = abs(`year_earn_impact_chatta'/`year_earn_impact_chatta_t')

local year_earn_impact_dayton = 895 // Bloom et al (2005) table 4.3
local year_earn_impact_dayton_p = runiform(0, 0.01) //  statistically significant at 1%
local year_earn_impact_dayton_t = invnormal(1- `year_earn_impact_dayton_p'/2)
local year_earn_impact_dayton_se = abs(`year_earn_impact_dayton'/`year_earn_impact_dayton_t')

local year_earn_impact_la = 1120 // Bloom et al (2005) table 4.3
local year_earn_impact_la_p = runiform(0, 0.01) //  statistically significant at 1%
local year_earn_impact_la_t = invnormal(1- `year_earn_impact_la_p'/2)
local year_earn_impact_la_se = abs(`year_earn_impact_la'/`year_earn_impact_la_t')

local year_earn_impact_stpaul = 1492 // Bloom et al (2005) table 4.3
local year_earn_impact_stpaul_p = runiform(0, 0.01) //  statistically significant at 1%
local year_earn_impact_stpaul_t = invnormal(1- `year_earn_impact_stpaul_p'/2)
local year_earn_impact_stpaul_se = abs(`year_earn_impact_stpaul'/`year_earn_impact_stpaul_t')

local year_earn_impact_seattle = 394 // Bloom et al (2005) table 4.3
local year_earn_impact_seattle_p = runiform(0.01, 0.05) //  statistically significant at 5%
local year_earn_impact_seattle_t = invnormal(1- `year_earn_impact_seattle_p'/2)
local year_earn_impact_seattle_se = abs(`year_earn_impact_seattle'/`year_earn_impact_seattle_t')

local year_earn_impact = `year_earn_impact_`sample''
local year_earn_impact_se = `year_earn_impact_`sample'_se'
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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local year_earn_impact = `year_earn_impact_`sample''

local marginal_rent = 0.05 
*4 out of 6 sites made rent indep of new income, and the remaining 2 lowered 
*contributions to 10-20% of earnings. From: 
*https://www.mdrc.org/sites/default/files/financial_incentive_designs_at_six_jobs_plus.pdf

local tot_program_cost = 2500 
/* "overall government expenditure per person on Jobs-Plus for the 1998 
research sample — the amount above the likely “normal” level of government 
expenditures made to encourage self sufficiency in the comparison developments — 
totaled roughly between $2,000-$3,000 over four years" congressional testimony p7 */

local earn_control = 8048 // congressional testimony table 1

local years_cost = 4
local years_earn = 7
local avg_age = 35 // Bloom et al (2005) table 2.1
local project_year = 2003

local usd_year = 2003

*********************************
/* 4. Intermediate Calculations */
*********************************

* Get marginal tax rate using counterfactual earnings, if using CBO tax rates.
if "`tax_rate_assumption'" == "cbo" | "`tax_rate_assumption'" == "paper internal" {
	get_tax_rate `earn_control', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
		usd_year(`usd_year') /// USD year of income
		inc_year(`project_year') /// year of income measurement
		earnings_type(individual) ///
		program_age(`avg_age') // age at which we observe income 
		
	local tax_rate = r(tax_rate)
}
if "`tax_rate_assumption'" == "paper internal" local tax_rate = `tax_rate' + `marginal_rent'
	
* discount program costs by year
local y_cost = `tot_program_cost'/`years_cost'
local program_cost = 0
forval i = 1/`years_cost' {
	local program_cost = `program_cost' + `y_cost' *(1/(1+`discount_rate')^(`i'-1))		
}

if "`proj_type'" == "observed" {
	local tot_earn = 0
	* sum earnings impacts over follow up period
	forval i = 1/`years_earn' {
		local tot_earn = `tot_earn' + `year_earn_impact'*(1/(1+`discount_rate')^(`i'-1))		
	}
}

if "`proj_type'" == "growth forecast" {
	est_life_impact `year_earn_impact', ///
		impact_age(`avg_age') project_age(`avg_age') project_year(`project_year') ///
		income_info(`earn_control') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age($proj_age) usd_year(`usd_year') income_info_type(counterfactual_income) ///
		max_age_obs(`=`avg_age'+`years_earn'-1')
	
	local tot_earn =  r(tot_earn_impact_d)
}

local after_tax_earn_impact = (1-`tax_rate')*`tot_earn'
local tax_impact = `tax_rate'*`tot_earn'

di `program_cost'
di `tot_earn'
di `tax_impact'
di `after_tax_earn_impact'
di `year_earn_impact'*`tax_rate'
di `year_earn_impact'*(1-`tax_rate')
di `tot_earn'*`tax_rate'
di `tot_earn'*(1-`tax_rate')
di `tax_rate'
**************************
/* 5. Cost Calculations */
**************************

local total_cost = `program_cost' - `tax_impact'


*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" local WTP = `after_tax_earn_impact'

if "`wtp_valuation'" == "cost" local WTP = `program_cost'

* no clear lower bound on valuation, choose valuation at 1% of program cost
if "`wtp_valuation'" == "lower bound" local WTP = 0.01*`program_cost'

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
di `tot_earn'
di `tax_rate'


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `avg_age'
global age_benef_`1' = `avg_age'

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `earn_control' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year'
global inc_age_stat_`1' = `avg_age'

global inc_benef_`1' = `earn_control' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_year'
global inc_age_benef_`1' = `avg_age'

