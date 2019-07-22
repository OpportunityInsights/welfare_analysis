*************************************
/* 0. Program: JTPA Youth */
*************************************

/*Bloom, Howard S., Larry L. Orr, Stephen H. Bell, George Cave, Fred Doolittle,
 Winston Lin, and Johannes M. Bos. "The benefits and costs of JTPA Title II-A 
 programs: Key findings from the National Job Training Partnership Act study." 
 Journal of human resources (1997): 549-576.*/ 
 
* Provide job training for out-of school youths aged 14-21. 
 
********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" //takes value paper internal, mixed, or "cont". If "cont", also need to specify a number in tax_rate_cont
*Mixed tax rate: "Observed" values used for 2 years. Projected thereafter.
local tax_rate_cont = $tax_rate_cont
local payroll_assumption = "$payroll_assumption"
local afdc_assumption = "$afdc_assumption" // Yes = AFDC reductions continue in subsequent years, No = lump sum one-time reduction
local proj_type = "$proj_type" //"observed" or "growth forecast"
local proj_length = "$proj_length" // "observed" "8yr" "21yr" or "age65" 
local net_transfers = "$net_transfers" // yes/no to include effects of transfer changes on inviduals' WTP
local wtp_valuation = "$wtp_valuation" 
local correlation = $correlation

*********************************
/* 2. Estimates from the Paper */
**********************************
/*
When a range of p-values is given: assume a uniform distribution over it, draw a 
p-value, translate this into a std error for the estimate which can be used to simulate 
estimates as being normally distributed around the point estimate

local earn_impact_obs_m = -868 // Bloom Table 8 (sums earnings gain and wage subsidy; increase in earnings observed over 30m)
local earn_impact_obs_m_p = runiform(0.1,1) // "between .1 and 1" //Bloom Table 3
local earn_impact_obs_f = 210 // Bloom Table 8, JTPA Youth Row 19
local earn_impact_obs_f_p =  runiform(0.1,1) //"between .1 and 1" // Bloom Table 3

local static_welfare_fe_m = -119 // Bloom Table 8, JTPA Youth Row 13 (reduction in welfare payment from being in program during 30m)
local static_welfare_fe_m_p = runiform(0.1,1) //"p >.1" //no clear sample size for this estimate, but can assume over 30 and use z score
local static_welfare_fe_f = 379 // Bloom Table 8, JTPA Youth Row 13
local static_welfare_fe_f_p = runiform(0.1,1) //"p >.1" //no clear sample size for this estimate, but can assume over 30 and use z score
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
local samp_size_m = 1704 //Bloom Table 3
local samp_size_f = 2657 // Bloom Table 3

local year_jtpa = 1988 //random assignment lasted about 15 months in each SDA, on average, beginning in November 1987 and ending in September 1989

*Mean control group earnings (over 30-month period):
local control_group_mean_m = 16375 // Bloom Table 2
local control_group_mean_f = 10106 // Bloom Table 2

*Reduction in private spending:
local reduc_private_spending_m = 110 // Bloom Table 8
local reduc_private_spending_f = 76 // Bloom Table 8

/*tax effects calculated using earning impact and assumed marginal tax rate of 12.8%, 
see Bloom footnote 32*/  
local paper_tax_rate = 0.128 //Bloom footnote 32 p 571

local age_stat_m = ((16+19)/2)*0.639+ ((20+21)/2)*0.361 //From: https://www.upjohn.org/sites/default/files/2019-02/njtpareport_0.pdf exhibit 7.11
local age_stat_f = ((16+19)/2)*0.593+ ((20+21)/2)*0.407 //From: https://www.upjohn.org/sites/default/files/2019-02/njtpareport_0.pdf exhibit 7.10

local program_cost_m = 2165 // Bloom Table 8, JTPA Youth Row 2 (sums training costs and wage subsidy)
local program_cost_f = 1466 // Bloom Table 8, JTPA Youth Row 2

local wage_sub_expend_m = 100 // Bloom Table 8 (wage subsidy as part of training program for the 30m)
local wage_sub_expend_f = 74  // Bloom Table 8 (wage subsidy as part of training program for the 30m)

*Length of program (in months)
local program_length = 30


*********************************
/* 4. Intermediate Calculations */
*********************************
*Percent men/women in sample:
local p_f = `samp_size_f'/(`samp_size_f' + `samp_size_m') 
local p_m = `samp_size_m'/(`samp_size_f' + `samp_size_m')

*Average year of observation:
local avg_yr_obs = round((`year_jtpa' + `year_jtpa' + (`program_length'/12))/2) 
*USD year is not specified in the paper, so assuming same as average year of observation"
local usd_year = `avg_yr_obs'

*Because we have separate estimates for men and women, computing earnings/transfer
*impacts separately, then pooling at the end.
foreach s in f m {

	*Age last observed:
	local age_last_observed_`s' = round(`age_stat_`s'' + `program_length'/12)
	
	*Get annualized earnings/afdc impact and control group earnings (12/30 of the total earnings impact):
	local year_earn_impact_`s' = (`earn_impact_obs_`s'' - `wage_sub_expend_`s'')*(12/`program_length')
	local year_afdc_`s' = (`static_welfare_fe_`s'')*(12/`program_length')
	local control_group_mean_yr_`s' = `control_group_mean_`s''*(12/`program_length')

	*Calculate discounted sum of earnings and AFDC impacts (including projections, if applicable):
	local obs_earn_impact_`s' = 0
	local proj_earn_impact_`s' = 0
	local obs_afdc_impact_`s' = 0

	if "`proj_type'" == "observed"{
		forvalues i = 0/1 {
			local obs_earn_impact_`s' = `obs_earn_impact_`s'' + `year_earn_impact_`s''*(1/(1+`discount_rate'))^`i' 
			local obs_afdc_impact_`s' = `obs_afdc_impact_`s'' + `year_afdc_`s''*(1/(1+`discount_rate'))^`i'
		}
		* add the half-year at the end
		local obs_earn_impact_`s' = `obs_earn_impact_`s'' + `year_earn_impact_`s''*0.5/(1+`discount_rate')^1.5
		local obs_afdc_impact_`s' = `obs_afdc_impact_`s'' + `year_afdc_`s''*0.5/(1+`discount_rate')^1.5
		
		local proj_earn_impact_`s' = 0
	}

	if "`proj_type'" == "growth forecast"{
		*When we do a projection we end the observed period after a round number of years for convenience
		forvalues i = 0/1 {
			local obs_earn_impact_`s' = `obs_earn_impact_`s'' + `year_earn_impact_`s''*(1/(1+`discount_rate'))^`i' 
			local obs_afdc_impact_`s' = `obs_afdc_impact_`s'' + `year_afdc_`s''*(1/(1+`discount_rate'))^`i'
		}

		local proj_start_age = round(`age_stat_`s'' + `program_length'/12 + 1)
		local project_year = round(`year_jtpa' + `program_length'/12 + 1)
		
		if "`proj_length'" == "8yr"		local proj_end_age = `proj_start_age'+5
		if "`proj_length'" == "21yr"	local proj_end_age = `proj_start_age'+18
		if "`proj_length'" == "age65"	local proj_end_age = 65
		
		est_life_impact `year_earn_impact_`s'', ///
			impact_age(`age_last_observed_`s'') project_age(`proj_start_age') project_year(`project_year') ///
			income_info(`control_group_mean_yr_`s'') ///
			earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
			end_project_age(`proj_end_age') usd_year(`usd_year') income_info_type(counterfactual_income) ///
			max_age_obs(`age_last_observed_`s'')
			
		local proj_earn_impact_`s' = ((1/(1+`discount_rate'))^1) * r(tot_earn_impact_d)
	}

	*Generate tax rates based on program assumptions:
	if "`tax_rate_assumption'" == "paper internal"{
		local tax_rate_obs_`s' 	= `paper_tax_rate'
		local tax_rate_proj_`s' = `paper_tax_rate'
	}
	if "`tax_rate_assumption'" == "continuous"{
		local tax_rate_obs_`s' 	= `tax_rate_cont'
		local tax_rate_proj_`s' = `tax_rate_cont'
	}
	if "`tax_rate_assumption'" == "mixed"{

		get_tax_rate `control_group_mean_yr_`s'', ///
			include_transfers(yes) ///
			include_payroll(`payroll_assumption') /// "yes" or "no"
			forecast_income(yes) /// "yes" or "no"
			usd_year(`usd_year') /// USD year of income
			inc_year(`avg_yr_obs') /// year of income measurement 
			program_age(`age_last_observed_`s'') ///
			earnings_type(individual) // individual or household
		
		local tax_rate_obs_`s' 	= `paper_tax_rate'
		local tax_rate_proj_`s' = r(tax_rate)
	} 

	*Generate transfer/FE rates based on AFDC assumption (whether AFDC change is a
	*lump sum ["no"] or is part of the calculated fiscal externality rate ["yes"]):
	if "`afdc_assumption'" == "no"{
		local transfer_rate_`s' = 0
		local afdc_supp_`s' = `obs_afdc_impact_`s''
	}

	if "`afdc_assumption'" == "yes"{
		local transfer_rate_`s' = `static_welfare_fe_`s''/`earn_impact_obs_`s''
		local afdc_supp_`s' = 0
	}

	*Total FE rates:
	local fe_rate_obs_`s' = `tax_rate_obs_`s'' + `transfer_rate_`s''
	local fe_rate_proj_`s' = `tax_rate_proj_`s'' + `transfer_rate_`s''


	*Compute after-tax earnings and transfer impacts:
	local total_earn_impact_aftertax_`s' = (1-`tax_rate_obs_`s'') * (`obs_earn_impact_`s'' + `wage_sub_expend_`s'')  ///
									 + (1-`tax_rate_proj_`s'') * `proj_earn_impact_`s''
	local total_transfers_aftertax_`s' = - `afdc_supp_`s'' ///
									 -(`obs_earn_impact_`s''+`wage_sub_expend_`s''+`proj_earn_impact_`s'')*`transfer_rate_`s''
	
	local FE_`s' = (`obs_earn_impact_`s''+`wage_sub_expend_`s'')*`fe_rate_obs_`s'' + `proj_earn_impact_`s''*`fe_rate_proj_`s'' + `afdc_supp_`s''
}

*Pool cost and control group earnings:
foreach x in age_stat control_group_mean reduc_private_spending program_cost {
	local `x' = ``x'_f' *`p_f' + ``x'_m'*`p_m'
}
local control_group_mean_yr = `control_group_mean'*(12/`program_length')

**************************
/* 5. Cost Calculations */
**************************

local FE = (`FE_m' * `p_m') + (`FE_f' * `p_f')

local total_cost = `program_cost' - `FE' 

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax"{
	if "`net_transfers'" == "no"{
		local WTP = (`total_earn_impact_aftertax_m'*`p_m') + (`total_earn_impact_aftertax_f'*`p_f')
	}

	if "`net_transfers'" == "yes"{
		local WTP 	= (`total_earn_impact_aftertax_m' + `total_transfers_aftertax_m') * `p_m' ///
					+ (`total_earn_impact_aftertax_f' + `total_transfers_aftertax_f') * `p_f'
	}
}

if "`wtp_valuation'" == "cost"{
	local WTP = `program_cost'
}

if "`wtp_valuation'" == "reduction private spending" {
	local WTP = `reduc_private_spending'
}

if "`wtp_valuation'" == "lower bound"{
	// no clear lower bound on valuation, choose valuation at 1% of program cost
	local WTP = `program_cost'*.01
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'


global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_stat' 

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `control_group_mean_yr' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `avg_yr_obs'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `control_group_mean_yr' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `avg_yr_obs'
global inc_age_benef_`1' = `age_stat'
