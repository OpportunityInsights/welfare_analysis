
********************************
/*0. Program: Work Advance */
********************************

/*
Hendra, Richard, et al. "Encouraging Evidence on a Sector-Focused Advancement 
Strategy: Two-Year Impacts from the WorkAdvance Demonstration." (2016).

*Provide skills-focused job training. 

*/


********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" //takes value paper internal, continuous, or cbo
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local proj_type = "$proj_type" //takes value observed, growth forecast 
local proj_length 	= "$proj_length" //"observed", "8yr", "21yr", or "age65"
local correlation = $correlation
local wtp_valuation = "$wtp_valuation"


*********************************
/* 2. Estimates from the Paper */
*********************************

/*

When a range of p-values is given: assume a uniform distribution over it, draw a 
p-value, translate this into a std error for the estimate which can be used to simulate 
estimates as being normally distributed around the point estimate

local year_2_earnings = 1945 // Hendra et al. (2016), ES-16
local year_2_earnings_p = runiform(0, 0.01) //"between 0 and .01"
local t_year_2_earnings = invnormal(1 - `year_2_earnings_p'/2) //based on p value of 0.01
local year_2_earnings_se = `year_2_earnings'/`t_year_2_earnings'

local year_3_earnings = 1865 // Schaberg (2017), pg.11-12
local year_3_earnings_p = runiform(0, 0.01) // "between 0 and .01" 
local t_year_3_earnings = invnormal(1 - `year_3_earnings_p'/2) //based on p value of 0.01
local year_3_earnings_se = `year_3_earnings'/`t_year_3_earnings'
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
/* 3. Assumptions from the Paper */
****************************************************

local net_cost_red_perscholas = 2278 // Hendra et al. (2016), Table 4.2, Combines net out of program costs  
local net_cost_red_st_nicks = 798 // Hendra et al. (2016), Table 4.2 
local net_cost_red_madison = 244 // Hendra et al. (2016), Table 4.2
local net_cost_red_towards = 408 // Hendra et al. (2016), Table 4.2 
*No SEs for these...

local program_cost_perscholas = 5754 // Hendra et al. (2016), Table 4.2
local program_cost_st_nicks = 6666 // Hendra et al. (2016), Table 4.2
local program_cost_madison = 5203 // Hendra et al. (2016), Table 4.2
local program_cost_towards = 5262 // Hendra et al. (2016), Table 4.2

local share_perscholas = (690/2564) // Hendra et al. (2016), Figure 1.2
local share_st_nicks = (479/2564) // Hendra et al. (2016), Figure 1.2
local share_madison = (697/2564) // Hendra et al. (2016), Figure 1.2
local share_towards = (698/2564) // Hendra et al. (2016), Figure 1.2

local mean_age = 34 // Schaberg Table 1: average program ages of 31, 35, 35, and 35. 
	//Sample sizes similar, weighted average rounds to age 34.
local observed_length = 2 //Have data on three years of the program
local prog_year = 2011 //Hendra et al 2016 p 27
local control_group_mean = 686*12 // Hendra et al table 1.4


*********************************
/* 4. Intermediate Calculations */
*********************************

*Discounted observed earnings impact:
local obs_earn_impact = (`year_2_earnings'/((1+`discount_rate')^1)) + (`year_3_earnings'/((1+`discount_rate')^2))

*Projected earnings impact:
local age_last_observed = `mean_age' + `observed_length'
local project_start_year = `prog_year' + `observed_length' + 1
local proj_start_age = `age_last_observed'+1
if "`proj_length'" == "8yr"		local proj_end_age = `proj_start_age'+4
if "`proj_length'" == "21yr"	local proj_end_age = `proj_start_age'+17
if "`proj_length'" == "age65"	local proj_end_age = 65

if "`proj_type'" == "observed" {
	local proj_earn_impact = 0
}

if  "`proj_type'" == "growth forecast"  {

	est_life_impact `year_3_earnings', ///
		impact_age(`age_last_observed') project_age(`proj_start_age') project_year(`project_start_year') ///
		income_info(`control_group_mean') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		end_project_age(`proj_end_age') usd_year(`prog_year') income_info_type(counterfactual_income)

	
	local proj_earn_impact = ((1/(1+`discount_rate'))^3) * r(tot_earn_impact_d) //discount to year of spending
}

*Total earnings impact:
local total_earn_impact = `proj_earn_impact' + `obs_earn_impact'

*Use assumptions to determine tax rate
if "`tax_rate_assumption'" == "paper internal"{
	local fe_rate = 0.20
}

if "`tax_rate_assumption'" == "continuous"{
	local fe_rate= $tax_rate_cont
}

if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `control_group_mean' , /// annual control mean earnings 
			inc_year(`project_start_year') /// year of income measurement 
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) /// include in assumptions file (y/n)
			usd_year(`project_start_year') /// usd year of income 
			forecast_income(no) /// if childhood program where lifecycle earnings needed, yes
			earnings_type(household) /// optional option, only if info provided. default is 4 
			
		local tax_rate = r(tax_rate)
		local tax_rate_cont = r(tax_rate)
		local fe_rate = r(tax_rate)
}	

*Total change in taxes/transfers:
local total_transfers = `total_earn_impact'*`fe_rate' 


**************************
/* 5. Cost Calculations */
**************************

local program_cost 	= `program_cost_perscholas'*`share_perscholas' ///
					+ `program_cost_st_nicks'*`share_st_nicks'  ///
					+ `program_cost_madison'*`share_madison' 	///
					+ `program_cost_towards'*`share_towards'
					
local cost_red_other_pro 	= `net_cost_red_perscholas'*`share_perscholas' ///
							+ `net_cost_red_st_nicks'*`share_st_nicks' ///
							+ `net_cost_red_madison'*`share_madison' ///
							+ `net_cost_red_towards'*`share_towards'
							
local FE = `total_earn_impact'*`fe_rate' + `cost_red_other_pro'
local total_cost = `program_cost' - `FE' 

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" local WTP = `total_earn_impact' - `total_transfers'
if "`wtp_valuation'" == "cost" local WTP = `program_cost'
if "`wtp_valuation'" == "lower_bound" local WTP = `program_cost'*.01
	// no clear lower bound on valuation, choose valuation at 1% of program cost

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
deflate_to 2015, from(`prog_year')

global inc_stat_`1' = `control_group_mean'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_start_year'-1
global inc_age_stat_`1' = `age_last_observed'

global inc_benef_`1' = `control_group_mean'*r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_start_year'-1
global inc_age_benef_`1' = `age_last_observed'
