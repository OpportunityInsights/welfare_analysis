*************************************************
/* 0. Program: Head Start (Ludwig and Miller) */
*************************************************
/*
Ludwig, J., & Miller, D. L. (2007). 
"Does Head Start improve children's life chances? Evidence from a regression 
discontinuity design." 
The Quarterly journal of economics, 122(1), 159-208.
*/

********************************
/* 1. Pull Global Assumptions */
*********************************

local discount_rate = $discount_rate
local VSL_2012_USD = $VSL_2012_USD
local tax_rate_assumption = "$tax_rate_assumption" //"continuous" or "cbo"
if "`tax_rate_assumption'"=="continuous" local tax_rate = $tax_rate_cont
local proj_type = "$proj_type" //"growth forecast" only
local wtp_valuation = "$wtp_valuation" // "post tax" or "lower bound"
local payroll_assumption = "$payroll_assumption"
local proj_age = $proj_age

local years_enroll = $years_enroll //years of additional attainment associated with college enrollment
local include_vsl = "$include_vsl" // include mortality impacts (y/n)

*********************************
/* 2. Estimates from Paper */
*********************************

/*
*College enrollment effect - Ludwig & Miller (2007) table IV:
local coll_effect = 0.037
local coll_effect_se = 0.02

*Mortality effect - Ludwig & Miller (2007) table III, rate per 100,000:
local mort_effect = -1.895
local mort_effect_se = 0.98

*1968 Head Start spending per child - Ludwig & Miller (2007) table II:
local cost_1968 = 137.251
local cost_1968_se = 128.968

*1972 Head Start spending per child - Ludwig & Miller (2007) table II:
local cost_1972 = 182.119
local cost_197_se = 148.321
*/

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
			local `est'_pe = r(mean)
		}
	restore
}

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local reform_year = (1968+1972)/2 // we take costs from 1968/72
local reform_year_int = round(`reform_year')
local reform_age = (3+5)/2

local usd_year = 1972 // set base to 1972, as it appears Ludwig & Miller report impacts in nominal terms
deflate_to `usd_year', from(1968)
local cost_1968 = `cost_1968' * r(deflator)

*Estimate parent income:
*Discontinuity is at the 300th poorest county: assume parents earn at 50% of the 
*FPL for a family with two kids
local fpl_h4_c2_1978 = 6612 //source: https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-poverty-thresholds.html
*1978 is earliest year in the data so take that
deflate_to `usd_year', from(1978)
local avg_par_inc = `fpl_h4_c2_1978' * r(deflator)
local par_inc_year = 1978
get_mother_age `par_inc_year', yob(`=round(`reform_year'-`reform_age')')
local par_age = r(mother_age)

*********************************
/* 4. Intermediate Calculations */
*********************************

*VSL impact from reductions in mortality
di `mort_effect'
local mort_effect = `mort_effect'/100000 // estimate is per 100,000
deflate_to `usd_year', from(2012)
local VSL = 1000000*`VSL_2012_USD'*r(deflator)
local tot_mort_val_d = 0
forval a = 5/9 { // yearly mortality effect over ages 5-9
	local tot_mort_val_d = `tot_mort_val_d' - `mort_effect'*`VSL'/((1+`discount_rate')^(`a'-`reform_age'))
}

*Get earnings impact corresponding to college impact
local years_impact = `coll_effect'*`years_enroll'
int_outcome , outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year') 
local pct_earn_impact_neg = r(prog_earn_effect_neg)
local pct_earn_impact_pos = r(prog_earn_effect_pos)

*Project earnings impact over the lifecycle
if "`proj_type'" == "growth forecast" {
	*Initial earnings decline
	local proj_start_age = 18
	local proj_short_end = 24
	local impact_age = 34 // as we use mobility estimate to get kid inocme at 34 from parent income
	local project_year = `reform_year'+`proj_start_age'-`reform_age'
	
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`avg_par_inc') income_info_type(parent_income) ///
		parent_income_year(`par_inc_year') parent_age(`par_age') ///
		earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
		percentage(yes)
		
	local total_earn_impact_neg = r(tot_earn_impact_d)/((1+`discount_rate')^(`proj_start_age'-`reform_age'))
	local cfactual_inc_neg = r(cfactual_income)
		
	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `cfactual_inc_neg' , /// annual control mean earnings 
			inc_year(`=round(`project_year'-`proj_start_age'+`impact_age')') /// year of income measurement 
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) /// include transfers (y/n)
			usd_year(`usd_year') /// usd year of income 
			forecast_income(no) /// if childhood program where need lifecycle earnings, yes
			earnings_type(individual) // optional option, only if info provided. default is 4 
		
		local tax_rate = r(tax_rate)
	}	
	
	local increase_taxes_neg = `tax_rate' * `total_earn_impact_neg'
	
	*Later earnings increase
	local proj_start_age = 25
	local impact_age = 34
	local project_year = `reform_year'+`proj_start_age'-`reform_age'
		
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`avg_par_inc') income_info_type(parent_income) ///
		parent_income_year(`par_inc_year') parent_age(`par_age') ///
		earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
		percentage(yes)
		
	local total_earn_impact_pos = r(tot_earn_impact_d)/((1+`discount_rate')^(`proj_start_age'-`reform_age'))
	local cfactual_inc_pos = r(cfactual_income)

	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `cfactual_inc_pos' , /// annual control mean earnings 
			inc_year(`=round(`project_year'-`proj_start_age'+`impact_age')') /// year of income measurement 
			include_payroll("`payroll_assumption'") /// include in assumptions file (y/n)
			include_transfers(yes) /// include transfers (y/n)
			usd_year(`usd_year') /// usd year of income 
			program_age(`impact_age') /// age of program beneficiaries when income is measured 
			forecast_income(yes) /// 
			earnings_type(individual)
			
		local tax_rate = r(tax_rate)
	}	
		
	local increase_taxes_pos = `tax_rate' * `total_earn_impact_pos'

	*Combine Estimates
	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact' - `increase_taxes'
}
else {
	di as err "Only growth forecast allowed"
	exit
}

*Get implied cost increases from college attendance
if "$got_ludwig_cost"!="yes" {
	cost_of_college , year(`=round(`reform_year'+18-`reform_age')')
	global ludwig_college_cost = r(cost_of_college)
	global ludwig_tuition_cost = r(tuition)
	global got_ludwig_cost = "yes"
}
deflate_to `usd_year', from(`=round(`reform_year'+18-`reform_age')')
local govt_college_cost = 0
local priv_college_cost = 0
forval i = 1/`years_enroll'{
	local govt_college_cost = `govt_college_cost' + (${ludwig_college_cost} - ${ludwig_tuition_cost})*(`coll_effect')* ///
													r(deflator)*(1/(1+`discount_rate')^(18-`reform_age'+`i'-1))
	local priv_college_cost = `priv_college_cost' + (${ludwig_tuition_cost})*(`coll_effect')* ///
													r(deflator)*(1/(1+`discount_rate')^(18-`reform_age'+`i'-1))
}
	
**************************
/* 5. Cost Calculations */
**************************

local avg_cost = (`cost_1968' + `cost_1972')/2

local program_cost = 0
forval i = 1/3 {  // three years of enrollment in head start
	local program_cost = `program_cost' + (`avg_cost')/((1+`discount_rate')^(`i'-1))
}

local total_cost = `program_cost' - `increase_taxes' + `govt_college_cost'

*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" { 
	local WTP = `total_earn_impact_aftertax' -`priv_college_cost'
	if "`include_vsl'"=="yes" local WTP = `WTP' + `tot_mort_val_d'
}

if "`wtp_valuation'" == "cost" local WTP = `program_cost'

if "`wtp_valuation'" == "lower bound" local WTP = `program_cost'*0.01


**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*****************
/* 8. Outputs */
*****************

di `total_earn_impact'
di `total_earn_impact_aftertax'
di `increase_taxes'
di `tot_mort_val_d'
di `priv_college_cost'
di `govt_college_cost'
di `program_cost'
di `total_cost'
di `WTP'
di `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `reform_age'
global age_benef_`1' = `reform_age'

*income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_inc_pos'* r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = round(`project_year'-`proj_start_age'+`impact_age')
global inc_age_stat_`1' = `impact_age'

global inc_benef_`1' = `cfactual_inc_pos'* r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = round(`project_year'-`proj_start_age'+`impact_age')
global inc_age_benef_`1' = `impact_age'
