*************************************
/* 0. Program: Job Start */
*************************************

/*

Cave, George, Hans Bos, Fred Doolittle, and Cyril Toussaint. 1993. "Jobstart:
Fina Report on a Program for School Dropouts." Manpower Demonstration Research Corporation.


* Provide education and job training/search support to high school dropouts aged 
* 17-21.

*/


********************************
/* 1. Pull Global Assumptions */
********************************
local discount_rate = $discount_rate
local proj_type = "$proj_type" //takes values "observed", "growth forecast"
local wtp_valuation = "$wtp_valuation" //takes on value of "post tax", "cost", or "lower bound"
local proj_length 	= "$proj_length" //"observed", "8yr", "21yr", or "age65"
local tax_rate_assumption = "$tax_rate_assumption" 
if "`tax_rate_assumption'" =="continuous" {
	local fe_rate_observed = $tax_rate_cont
	local fe_rate_proj = $tax_rate_cont
}
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local support_services = "$support_services" // "yes" or "no"
local correlation = $correlation

*********************************
/* 2. Estimates from the Paper */
*********************************

/*
*Earning effects, Cave et al (1993), Table 5.1
local earn_y1 = -499 
local earn_y2 = -121
local earn_y3 = 423 
local earn_y4 = 410 
local earn_y1_y4 = 214 

local earn_y1_p = .001 
local earn_y2_p = .563
local earn_y3_p =  .102
local earn_y4_p =  .125
local earn_y1_y4_p = .757


*Transfer effects
*Difference in Dollars from AFDC, Cave et al (1993), Table 6.1
local afdc_y1 = 63 
local afdc_y2 = 24
local afdc_y3 = -3
local afdc_y4 = -11
local afdc_y1_y4 = 74

local afdc_y1_p = .243
local afdc_y2_p = .703
local afdc_y3_p = .972
local afdc_y4_p = .897
local afdc_y1_y4_p = .750

*Difference in Dollars from Food Stamps, Cave et al (1993), Table 6.1
local fstamp_y1 = -45
local fstamp_y2 = -42
local fstamp_y3 = 31
local fstamp_y4 = 31
local fstamp_y1_y4 = -24 

local fstamp_y1_p = .207
local fstamp_y2_p = .228
local fstamp_y3_p = .449
local fstamp_y4_p = .493
local fstamp_y1_y4_p = .839

*Difference in Dollars General Assistance, Cave et al (1993), Table 6.1
local ga_y1 = 24
local ga_y2 = 7
local ga_y3 = -6
local ga_y4 = 3
local ga_y1_y4 = 29 

local ga_y1_p = .308
local ga_y2_p = .644
local ga_y3_p = .809
local ga_y4_p = .910
local ga_y1_y4_p = .653
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


*************************************
/* 3. Assumptions from the Paper */
*************************************

local usd_year = 1986 //Cave et al (1993), Table 7.2 footnotes
local program_year = 1986 //Cave et al (1993), pg.31 (range 1985-1987)
local avg_months_active = 6.6 //Cave et al (1993), pg. 75
local program_cost = 4548 //Cave et al (1993), pg. ES-23
local percent_support = .15 //Cave et al (1993), pg. ES-23

local ex_total_n = 988 //Cave et al (1993), Table 3
local co_total_n = 953 //Cave et al (1993), Table 3



*Participant age
local min_age = 17 //Cave et al (1993), pg. 30
local max_age = 21  //Cave et al (1993), pg. 30
local min_older_bucket = 20 //Cave et al (1993), Table 2.1
local percent_16_19 = .734 //Cave et al (1993), Table 2.1
local percent_20_21 = .266 //Cave et al (1993), Table 2.1


*Control group earnings, Cave et al (1993), Table 5.1
local contr_year3_earn = 4906 
local contr_year4_earn = 5182

*Treatment group earnings, Cave et al (1993), Table 5.1
local treat_year1_earn = 2097 
local treat_year2_earn = 3991
local treat_year3_earn = 5329
local treat_year4_earn = 5592 
local treat_y1_y4_earn = 17010 


local years_observed = 4

*********************************
/* 4. Intermediate Calculations */
*********************************

*Get y1 through y4 totals 
local earn_y1_y4 = `earn_y1' + `earn_y2' + `earn_y3' + `earn_y4'
local afdc_y1_y4 = `afdc_y1' + `afdc_y2' + `afdc_y3' + `afdc_y4'
local fstamp_y1_y4 = `fstamp_y1' + `fstamp_y2' + `fstamp_y3' + `fstamp_y4'
local ga_y1_y4 = `ga_y1' + `ga_y2' + `ga_y3' + `ga_y4'

*Average participant age
local avg_part_age = round(((`min_age' + `min_older_bucket' - 1 )/2)*`percent_16_19' + ((`min_older_bucket' + `max_age' )/2)*`percent_20_21')
local proj_start_age = `avg_part_age' + `years_observed'
local impact_age = round((`avg_part_age' + (`avg_part_age' + `years_observed'))/2)

*Average yearly observed earnings
local avg_yr_earn_obs = (`treat_y1_y4_earn'/`years_observed')

*Average year of observed earnings 
local avg_yr_obs = (`program_year' +  (`program_year' + `years_observed'))/2
local project_year = `program_year' + `years_observed'

*Discount observed earnings impacts
local earn_impact_obs = 0
forvalues i = 1/`years_observed'{
	local earn_impact_obs = `earn_impact_obs' + `earn_y`i''*(1/(1+`discount_rate'))^(`i'-1) 
}

*Total and discount observed transfers 
local afdc_obs = 0
local fstamp_obs = 0
local ga_obs = 0 

forvalues i = 1/`years_observed'{
	local afdc_obs = `afdc_obs' + `afdc_y`i''*(1/(1+`discount_rate'))^(`i'-1) 
	local fstamp_obs = `fstamp_obs' + `fstamp_y`i''*(1/(1+`discount_rate'))^(`i'-1) 
	local ga_obs = `ga_obs' + `ga_y`i''*(1/(1+`discount_rate'))^(`i'-1) 
}
local transfers_obs = `afdc_obs' + `fstamp_obs' + `ga_obs'


*Get tax rate for observed years
if "`tax_rate_assumption'" ==  "cbo" {

	get_tax_rate `avg_yr_earn_obs', ///
		include_transfers(no) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(no) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`avg_yr_obs') /// year of income measurement 
		program_age(`impact_age') ///
		earnings_type(individual) // individual or household

	local fe_rate_observed = r(tax_rate)
}	

*Get tax rate for projection
if "`tax_rate_assumption'" ==  "cbo" & "`proj_type'" != "observed"{

	get_tax_rate `avg_yr_earn_obs', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`usd_year') /// USD year of income
		inc_year(`avg_yr_obs') /// year of income measurement 
		program_age(`impact_age') ///
		earnings_type(individual) // individual or household

	local fe_rate_proj = r(tax_rate)
}

 
*Projections
if "`proj_length'" == "8yr"		local proj_end_age = `proj_start_age'+3
if "`proj_length'" == "21yr"	local proj_end_age = `proj_start_age'+16
if "`proj_length'" == "age65"	local proj_end_age = 65

if "`proj_type'" == "observed" {
	local total_earn_post_tax = `earn_impact_obs'*(1-`fe_rate_observed')
	local total_taxes = `earn_impact_obs'*`fe_rate_observed'
}

*Average to get counterfactual income
local cfactual_income = (`contr_year3_earn' + `contr_year4_earn')/2

if "`proj_type'" == "growth forecast"{
	*Calculate average of last 2 years of earnings 
	local earn_future = (`earn_y3' + `earn_y4')/2
	
	est_life_impact `earn_future', ///
		impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_end_age') ///
		usd_year(`usd_year') project_year(`project_year') ///
		income_info(`cfactual_income') income_info_type(counterfactual_income) ///
		earn_method($earn_method) ///
		tax_method($tax_method) ///
		transfer_method($transfer_method) max_age_obs(`=`avg_part_age' + `years_observed'-1')
			
	*Discount Earnings back to Initial year 
	local earn_proj = ((1/(1+`discount_rate'))^(`project_year' - `program_year')) * r(tot_earn_impact_d)
	local total_earn_post_tax = `earn_impact_obs'*(1-`fe_rate_observed') + `earn_proj'*(1-`fe_rate_proj')
	local total_taxes = `earn_impact_obs'*`fe_rate_observed' + `earn_proj'*`fe_rate_proj'

}


**************************
/* 5. Cost Calculations */
**************************

local FE = `total_taxes' - `transfers_obs'

local total_cost = `program_cost' - `FE' 

*************************
/* 6. WTP Calculations */
*************************


if "`wtp_valuation'" == "cost"{
	local WTP = `program_cost'
}

if "`wtp_valuation'" == "lower bound"{
	// no clear lower bound on valuation, choose valuation at 1% of program cost
	local WTP = `program_cost'*.01
}

if "`wtp_valuation'" == "post tax"{
	if "`support_services'" == "no"{
		local WTP = `total_earn_post_tax' + `transfers_obs' 
	}
	
	if "`support_services'" == "yes"{
		local WTP = `total_earn_post_tax' + `transfers_obs' + (`program_cost'*`percent_support')
	}	
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
global age_stat_`1' = `avg_part_age'
global age_benef_`1' = `avg_part_age' 

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `cfactual_income' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year'-1
global inc_age_stat_`1' = `impact_age'

global inc_benef_`1' = `cfactual_income' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_year'-1
global inc_age_benef_`1' = `impact_age'
