********************************************
/* 0. Program: Medicare */
********************************************

/*Finkelstein, Amy, and Robin McKnight. "What did Medicare do? The initial 
impact of Medicare on mortality and out of pocket medical spending." Journal of 
public economics 92, no. 7 (2008): 1644-1668. */

********************************
/* 1. Pull Global Assumptions */
********************************

local include_health = "$include_health" //options are "yes" or "no", not relevant if transfer only=="yes"
local transfer_only = "$transfer_only" //options are "yes" or "no"
local ge_costs = "$ge_costs" //options are "yes" or "no"
local correlation = $correlation

******************************
/* 2. Estimates from Paper */
******************************

/*
local reduction_oop_spend = 117.3 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local reduction_oop_spend_se = 106.5 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local reduction_priv_insure = 507.1 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local reduction_priv_insure_se = 97.0 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local increase_pub_priv_spend = 259.0 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local increase_pub_priv_spend_se = 150.2 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local total_spending = 142.3 //Finkelstein and McKnight (2008), Table 4 pg. 1655
local total_spending_se = 204.7 //Finkelstein and McKnight (2008), Table 4 pg. 1655

From Finkelstein and McKnight (2008) pg. 1666: "The coefficient of interest is
beta_3; it indicates the differential slope shift in 1966 experienced by hospitals
with more of an inpact of Medicare on insurance coverage relative to those with 
less of an impact...For the sample of individuals aged 65 and over, we estimate 
beta_3 to be -0.0004, with a standard error of 0.005. This implies that after 
five years (i.e. by 1970), Medicare was associated with a statistically 
insignificant decline in annual elderly deaths of -0.15% (~[exp(-.0004x0.75x5)-1])"

local beta_three = -.0004 //Finkelstein and McKnight (2008), Appendix A, pg. 1666
local beta_three_se = .005 //Finkelstein and McKnight (2008), Appendix A, pg. 1666
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

local moral_hazard_inc_ge = 974 // Finkelstein and McKnight (2008) table 6

local USD_year = 2000 //See footnotes of tables 

local insurance_value = 585 //Finkelstein and McKnight (2008), Table 6 pg. 1661

local VSLY = 100000 //Finkelstein and McKnight (2008) pg. 1661, citing  Cutler (2004)

local years_life_after_save = 4 //Finkelstein and McKnight (2008) pg. 1661

local avg_mort_over65_in65 = .06 //Finkelstein and McKnight (2008) pg. 1661

local avg_age = (65+90)/2 // elderly population 65+
local age_stat = `avg_age'
local age_benef = `avg_age'

*********************************
/* 4. Intermediate Calculations */
*********************************

*Get incomes
*Use US median income in 1965
deflate_to `USD_year', from(1965)
local median_inc = 6900*r(deflator) //Source: Census 1966 report: https://www2.census.gov/prod2/popscan/p60-049.pdf
// Using median as on title page of PDF (rounded from 6,882$ to 6,900$)

/*See Finkelstein & McKnight Appendix A for breakdown of this calculation*/
local percent_change_mortality = exp(`beta_three'*.75*5)-1

local increase_pub_spend = `increase_pub_priv_spend' + `reduction_priv_insure'

local life_years_value = -`percent_change_mortality'*`avg_mort_over65_in65'*`years_life_after_save'*`VSLY'

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `increase_pub_spend' - `total_spending' 
/* Note that program cost should not include the moral hazard component,
so we subtract the total spending increase */

if "`ge_costs'" == "no" {
	local total_cost = `increase_pub_spend'
}
if "`ge_costs'" == "yes" {
	local total_cost = `increase_pub_spend' + `moral_hazard_inc_ge' 
	/* Here include GE moral hazard component in total cost */
}

*************************
/* 6. WTP Calculations */
*************************

if "`transfer_only'" == "no"{
	if "`include_health'" == "no"{
		local WTP = `reduction_oop_spend' + `insurance_value' + `reduction_priv_insure'
	}

	if "`include_health'" == "yes"{
		local WTP = `reduction_oop_spend' + `insurance_value' + `reduction_priv_insure' + `life_years_value'
	}
} 

if "`transfer_only'" == "yes"{
	local WTP = `reduction_oop_spend' + `reduction_priv_insure'
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

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
deflate_to 2015, from(`USD_year')

global inc_stat_`1' = `median_inc' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = 1965
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `median_inc' * r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = 1965
global inc_age_benef_`1' = `age_stat'

*Bar chart globals
*WTP
global reduction_oop_spend_af = `reduction_oop_spend'
global insurance_value_af = `insurance_value'
global reduction_priv_insure_af = `reduction_priv_insure'
global life_years_value_af = `life_years_value'
global wtp_af = `WTP'
*Costs
global increase_pub_spend_af = `increase_pub_spend'
global total_spending_af = `total_spending'
global program_cost_af = `program_cost'
