*****************************************
/* 0. Program: Oregon Health Insurance*/
********************************* *******

/*Finkelstein, A., Hendren, N., & Luttmer, E. (2015). 
"The Value of Medicaid: Interpreting Results from the Oregon Health Insurance 
Experiment"
(No. 21308). National Bureau of Economic Research, Inc.

Finkelstein, A., Taubman, S., Wright, B., Bernstein, M., Gruber, J., Newhouse, 
J. P., ... & Oregon Health Study Group. (2012). 
The Oregon health insurance experiment: evidence from the first year. 
The Quarterly journal of economics, 127(3), 1057-1106.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local uncomp_care_incidence = "$uncomp_care_incidence" //"government", "low-income indvs", "high-income indvs"
local calc_approach = "$calc_approach"
local correlation = $correlation

/*
Options for calc_approach are "complete-information", "consumption optimization 
proxy", and "consumption optimization CEX"  

"complete-information" -> "...requires a complete specification of a normative
utility function and estimates of the causal effect of Medicaid on the 
distribution of all arguments of the utility function."

"optimization" -> "We reduce the implementation requirements by parameterizing
the way in which Medicaid affects the individual’s budget set, and by assuming 
that individuals have the ability and information to make optimal choices
with respect to that budget set."
*/ 


*****************************
/* 2. Estimates from Paper */
******************************
/*
if "`calc_approach'" == "complete-information"{
	local calc_num = 1
	local WTP_recip = 1675 //Finkelstein et al. 2018, Table 3
	local WTP_recip_se = 60 //Finkelstein et al. 2018, Table 3
	
	local behavior_cost = 732 //Finkelstein et al. 2018 Table 3 (average in range 585-879)
	
	/*
	There is no direct SE for the behavior cost, so instead carry over the t
	stat from the impact on medical spending from appendix table 3:
	*/
	local medic_spend_est = 879
	local medic_spend_se = 365
	local medic_spend_t = `medic_spend_est' / `medic_spend_se'
	local behavior_cost_t = `medic_spend_t'
	local behavior_cost_se = `behavior_cost'/`behavior_cost_t'
}
if "`calc_approach'" == "consumption optimization proxy"{
	local calc_num = 2
	local WTP_recip = 1421 //Finkelstein et al. 2018, Table 3
	local WTP_recip_se = 180 //Finkelstein et al. 2018, Table 3
	
	local behavior_cost = 787 //Finkelstein et al. 2018 Table 3 
	
	/*
	There is no direct SE for the behavior cost, so instead carry over the t
	stat from the impact on medical spending from appendix table 3:
	*/
	local medic_spend_est = 879
	local medic_spend_se = 365
	local medic_spend_t = `medic_spend_est' / `medic_spend_se'
	local behavior_cost_t = `medic_spend_t'
	local behavior_cost_se = `behavior_cost'/`behavior_cost_t'
}
if "`calc_approach'" == "consumption optimization CEX"{
	local calc_num = 3
	local WTP_recip = 793 //Finkelstein et al. 2018, Table 3
	local WTP_recip_se = 417 //Finkelstein et al. 2018, Table 3
	
	local behavior_cost = 787 //Finkelstein et al. 2018 Table 3 
	
	/*
	There is no direct SE for the behavior cost, so instead carry over the t
	stat from the impact on medical spending from appendix table 3:
	*/
	local medic_spend_est = 879
	local medic_spend_se = 365
	local medic_spend_t = `medic_spend_est' / `medic_spend_se'
	local behavior_cost_t = `medic_spend_t'
	local behavior_cost_se = `behavior_cost'/`behavior_cost_t'
}
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

*Get back estimates for the correct calculation approach
if "`calc_approach'" == "complete-information" 				local calc_num = 1
if "`calc_approach'" == "consumption optimization proxy" 	local calc_num = 2
if "`calc_approach'" == "consumption optimization CEX" 		local calc_num = 3

foreach local in WTP_recip behavior_cost {
	local `local' = ``local'_`calc_num''
}

*********************************
/* 3. Assumptions from Paper */
********************************

local program_cost_w_behavior = 3600 //Finkelstein et al. 2018 pg. 5; note this is inclusive of the fiscal externality
local percent_transfer = .6 //Finkelstein et al. 2018 pg. 5
local tax_schedule_weight = .5 //Finkelstein et al. 2018 pg.27, originally in Hendren (2017)

*get average age
local p_19_49 = 0.66 //Finkelstein et al. 2018 table 2
local p_50_64 = 0.34 //Finkelstein et al. 2018 table 2

local avg_age = 	`p_19_49' * (19+49)/2 + ///
					`p_50_64' * (50+64)/2
					
local age_stat = `avg_age'
local age_benef = `avg_age'

*Get income levels
local avg_income = 13053 // control mean from Finkelstein et al. (2012) table 1
local usd_year = 2008 // Finkelstein et al. (2012) table 1

*********************************
/* 4. Intermediate Calculations */
*********************************

if "`uncomp_care_incidence'" == "government"{
	local program_cost = (`program_cost_w_behavior' - `behavior_cost')*(1-`percent_transfer')
}

if "`uncomp_care_incidence'" != "government"{
	local program_cost = `program_cost_w_behavior' - `behavior_cost'
}

**************************
/* 5. Cost Calculations */
**************************

*Cost estimates ignore admin costs and labor supply responses.

if "`uncomp_care_incidence'" == "government"{
	local FE = `program_cost_w_behavior'*`percent_transfer' // Gov't was already paying for this part here
	local total_cost = `program_cost_w_behavior' - `FE'
}

if "`uncomp_care_incidence'" != "government"{
	local total_cost = `program_cost_w_behavior'
}

*************************
/* 6. WTP Calculations */
*************************

if "`uncomp_care_incidence'" == "government"{
	local WTP = `WTP_recip'
}

if "`uncomp_care_incidence'" == "low-income indvs"{
	local WTP = `WTP_recip' + `program_cost_w_behavior'*`percent_transfer'
}

if "`uncomp_care_incidence'" == "high-income indvs"{
	local WTP = `WTP_recip' + (`program_cost_w_behavior'*`percent_transfer'*`tax_schedule_weight')
}

if "$wtp_valuation"=="lower bound" {
	*For lower bound set WTP to solely transfer component (no insurance value)
	if "`calc_approach'" == "complete-information" 	{
		local WTP = (863+569)/2 // Midpoint of range given in Finkelstein et al. (2018) for transfer component of WTP in table 9
	}
	else local WTP = 661 //Finkelstein et al. (2018) table 9, transfer component
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
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `avg_income' * r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `usd_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `avg_income' * r(deflator)
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `usd_year'
global inc_age_benef_`1' = `age_stat'
