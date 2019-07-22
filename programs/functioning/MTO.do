***********************************************************
/* 0. Program: MTO (Chetty, Hendren, and Katz, 2016)*/
***********************************************************

/*
Chetty, R., Hendren, N., & Katz, L. F. (2016). 
"The effects of exposure to better neighborhoods on children: New evidence from 
the Moving to Opportunity experiment."
American Economic Review, 106(4), 855-902.

Goering, J., Kraft, J., Feins, J., McInnis, D., Holin, M. J., & Elhassan, H. (1999). 
"Moving to Opportunity for fair housing demonstration program: Current status and 
initial findings."
Washington, DC: US Department of Housing and Urban Development.

HUD Final impact report
https://www.huduser.gov/publications/pdf/mtofhd_fullreport_v2.pdf
*/

********************************
/* 1. Pull Global Assumptions */
********************************

*Program specific globals
local kids_age = "$kids_age" // "young", "old" or "observed"
local include_parents = "$include_parents" // "yes" or "no" to include parent impacts
local include_kids = "$include_kids" // "yes" or "no" to include kid impacts

local parent_earn_years = $parent_earn_years // either 2 or 10
local extend_parent_earn = "$extend_parent_earn" // "yes" or "no"
local years_enroll = $years_enroll

*'global' globals
local discount_rate = $discount_rate
local wage_growth_rate = $wage_growth_rate
local proj_age = $proj_age
local proj_type = "$proj_type" //"growth forecast"
local correlation = $correlation
local wtp_valuation = "$wtp_valuation"

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption" 
local payroll_assumption = "$payroll_assumption" 

******************************
/* 2. Estimates from Paper */
******************************
/*
*Young
local earn_effect_young = 3476.8 //Chetty et al (2016) Table 3, Col. 4
local earn_effect_young_se = 1418.2 //Chetty et al (2016) Table 3, Col. 4
local tax_change_young = 393.6 //Chetty et al (2016) Table 12, Col. 3
local tax_change_young_se = 134.1 //Chetty et al (2016) Table 12, Col. 3
local college_effect_young = 5.233 // Chetty et al (2016) Appendix Table 4b, Col. 1
local college_effect_young_se = 2.382 // Chetty et al (2016) Appendix Table 4b, Col. 1

*Old
local earn_effect_old = -2426.7 //Chetty et al (2016) Table 3, Col. 4
local earn_effect_old_se = 2154.4 //Chetty et al (2016) Table 3, Col. 4
local tax_change_old = -441.6 //Chetty et al (2016) Table 12, Col. 3
local tax_change_old_se = 230.8 //Chetty et al (2016) Table 12, Col. 3
local college_effect_old = -10.32 // Chetty et al (2016) Appendix Table 4b, Col. 1
local college_effect_old_se = 4.221 // Chetty et al (2016) Appendix Table 4b, Col. 1


*Parent impacts
*Earnings
local earn_impact_1_2 = -786.86 // HUD MTO Final impact report exhibit 5.5, TOT impact experimental vs control
local earn_impact_1_2_se = 462.10  // HUD report exhibit 5.5, TOT impact experimental vs control
local earn_impact_1_10 = -672.54 // HUD report exhibit 5.5, TOT impact experimental vs control
local earn_impact_1_10_se = 716.54 // HUD report exhibit 5.5, TOT impact experimental vs control
*SNAP/TANF (these are 2 year impacts July 2007-June 2009)
local tanf_impact = 120.29 // HUD report exhibit 5.13, TOT impact experimental vs control
local tanf_impact_se = 245.44 // HUD report exhibit 5.13, TOT impact experimental vs control
local snap_impact = 664.54 // HUD report exhibit 5.13, TOT impact experimental vs control
local snap_impact_se = 335.54 // HUD report exhibit 5.13, TOT impact experimental vs control
*/

/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates.
${folder_name}, being set externally, may vary in order to use pub bias corrected estimates. */

if "`1'" != "" global name = "mto"
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

local earn_control_1_2 = 5781.17 // HUD report exhibit 5.5 
local earn_control_1_10 = 9092.08 // HUD report exhibit 5.5

local frac_kids_young = 1969/(1969+959) //Chetty et al (2016) Table 1, bottom row

if  "`kids_age'" == "young" {
	local age_kid = 8.2 //Chetty et al (2016) table 1
	local age_stat = 44.8 // Chetty et al (2016) appendix table 1A
}
if  "`kids_age'" == "old" {
	local age_kid = 15.1 //Chetty et al (2016) table 1
	local age_stat = 50.9 // Chetty et al (2016) appendix table 1A
}
if  "`kids_age'" == "observed" {
	local age_kid = `frac_kids_young'*8.2+ (1-`frac_kids_young')*15.1 //Chetty et al (2016) table 1
	local age_stat = `frac_kids_young'*44.8 + (1-`frac_kids_young')*50.9 // Chetty et al 2016 appendix table 1A
}

local usd_year = 2012 //Chetty et al (2016) pg. 8

/*
"The MTO randomized housing mobility
demonstration, conducted by the U.S. Department of Housing and Urban Development (HUD),
enrolled 4,604 low-income families living in five U.S. cities { Baltimore, Boston, Chicago, Los
Angeles, and New York from 1994 to 1998."
*/
local year_move = 1996 // Chetty et al (2016) pg. 6

/*
Olsen (2009) estimates that the direct fiscal costs of housing voucher programs are similar to
or slightly lower than the costs of project-based public housing. Olsen's estimates imply that
the main incremental cost of moving families out of public housing using an MTO-type voucher
program would be the funding of counselors to help low-income families relocate. - Chetty et al. (2016) pg. 37
*/
local cost_per_family = 3783 //Chetty et al (2016) pg. 37


*Young kids
local avg_age_move_young = 8.2 //Chetty et al (2016) pg. 16 

local MTO_control_earn_08_12_young = 11270.3 //Chetty et al (2016) Table 3
local MTO_control_earn_26_young = 11398.3 //Chetty et al (2016) Table 3

*Old kids 
local avg_age_move_old = 15.1 //Chetty et al (2016) pg. 16

local MTO_control_earn_08_12_old = 15881.5 //Chetty et al (2016) Table 3
local MTO_control_earn_26_old = 13968.9 //Chetty et al (2016) Table 3

local kids_per_family = 2.5 // Goering et al. (1999) pg. 32

**********************************
/* 4. Intermediate Calculations */
**********************************

*Deflate parent impacts from HUD report
deflate_to 2012, from(2009) // HUD report is in 2009 dollars, Chetty et al. (2012)
local deflate_09_12 = r(deflator)
foreach local in earn_impact_1_2 earn_control_1_2 earn_impact_1_10 earn_control_1_10 tanf_impact snap_impact {
	local `local' = ``local''*`deflate_09_12'
}

*Estimating tax rates 
if "`tax_rate_assumption'" == "paper internal"{
	local tax_rate_young_short = `tax_change_young'/`earn_effect_young'
	local tax_rate_old_short = `tax_change_old'/`earn_effect_old'
	local tax_rate_young_long = `tax_change_young'/`earn_effect_young'
	local tax_rate_old_long = `tax_change_old'/`earn_effect_old'
	local tax_rate_parent = $tax_rate_cont
}

if "`tax_rate_assumption'" == "continuous"{
	local tax_rate_young_short = $tax_rate_cont
	local tax_rate_old_short = $tax_rate_cont
	local tax_rate_young_long = $tax_rate_cont
	local tax_rate_old_long = $tax_rate_cont
	local tax_rate_parent = $tax_rate_cont
}

if "`tax_rate_assumption'" == "mixed"{
	local tax_rate_young_short = `tax_change_young'/`earn_effect_young'
	local tax_rate_old_short = `tax_change_old'/`earn_effect_old'
	
	*Kid tax rates
	foreach age in young old {		
		get_tax_rate `MTO_control_earn_26_`age'', ///
			 include_transfers(yes) ///
			 include_payroll(`payroll_assumption') /// "yes" or "no"
			 forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
			 usd_year(`usd_year') /// USD year of income
			 inc_year(`=round(`year_move'+26-`avg_age_move_`age'',1)') /// year of income measurement
			 earnings_type(individual) ///
			 program_age(26) // age we're projecting from
			 
		local tax_rate_`age'_long = r(tax_rate)
	}
	
	*Parent tax rate
	get_tax_rate `earn_control_1_`parent_earn_years'', ///
			 include_transfers(no) /// we have SNAP/TANF impacts separately for parents
			 include_payroll(`payroll_assumption') /// "yes" or "no"
			 forecast_income(no) /// forecast long-run earnings, so we get a realistic lifetime MTR.
			 usd_year(`usd_year') /// USD year of income
			 inc_year(`=`year_move'+(`parent_earn_years'/2)') /// year of income measurement
			 earnings_type(individual) ///
			 program_age(`=round(`age_stat',1)') // age we're projecting from
			 
	local tax_rate_parent = r(tax_rate) + 0.3 // Add 30% is the implicit marginal tax rate on housing voucher 
	
}

if "`tax_rate_assumption'" == "cbo"{
	*Kid tax rates
	foreach age in young old {		
		get_tax_rate `MTO_control_earn_26_`age'', ///
			 include_transfers(yes) ///
			 include_payroll(`payroll_assumption') /// "yes" or "no"
			 forecast_income(yes) /// forecast long-run earnings, so we get a realistic lifetime MTR.
			 usd_year(`usd_year') /// USD year of income
			 inc_year(`=round(`year_move'+26-`avg_age_move_`age'',1)') /// year of income measurement
			 earnings_type(individual) ///
			 program_age(26) // age we're projecting from
			 
		local tax_rate_`age'_short = r(tax_rate)
		local tax_rate_`age'_long = r(tax_rate)
	}
	
	*Parent tax rate
	get_tax_rate `earn_control_1_`parent_earn_years'', ///
			 include_transfers(no) /// we have SNAP/TANF impacts separately for parents
			 include_payroll(`payroll_assumption') /// "yes" or "no"
			 forecast_income(no) /// forecast long-run earnings, so we get a realistic lifetime MTR.
			 usd_year(`usd_year') /// USD year of income
			 inc_year(`=`year_move'+(`parent_earn_years'/2)') /// year of income measurement
			 earnings_type(individual) ///
			 program_age(`=round(`age_stat',1)') // age we're projecting from
			 
	local tax_rate_parent = r(tax_rate) + 0.3 // Add 30% as receiving housing vouchers
}

local avg_age_move_young_int = round(`avg_age_move_young',1)
local avg_age_move_old_int = round(`avg_age_move_old',1)

*Project earnings impact for kids
if "`proj_type'" == "growth forecast" {
	
	est_life_impact `earn_effect_young', ///
		impact_age(26) project_age(18) end_project_age(26) ///
		project_year(`=`year_move'+18-`avg_age_move_young_int'') usd_year(`usd_year') ///
		income_info(`MTO_control_earn_26_young') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method(off) transfer_method(off) ///
		max_age_obs(26)
	
	local tot_earn_impact_y = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(18-`avg_age_move_young_int'))
	local tax_impact_y = `tax_rate_young_short' * `tot_earn_impact_y'
	local tot_earn_impact_aftertax_y =  `tot_earn_impact_y' - `tax_impact_y'
	
	est_life_impact `earn_effect_young', ///
		impact_age(26) project_age(27) end_project_age(`proj_age') ///
		project_year(`=`year_move'+18-`avg_age_move_young_int' + 9') usd_year(`usd_year') ///
		income_info(`MTO_control_earn_26_young') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method(off) transfer_method(off) ///
		max_age_obs(26)
	
	local tot_earn_impact_y = `tot_earn_impact_y' + r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(27-`avg_age_move_young_int'))
	local tax_impact_y = `tax_impact_y' + (`tax_rate_young_long' * `tot_earn_impact_y')
	local tot_earn_impact_aftertax_y =  `tot_earn_impact_aftertax_y' + r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(27-`avg_age_move_young_int')) - (`tax_rate_young_long' * `tot_earn_impact_y')
	
	if "`kids_age'" == "old" {
	local tot_earn_impact_y = 0 
	local tax_impact_y = 0
	local tot_earn_impact_aftertax_y = 0
	}
	
	if "`kids_age'" == "observed" | "`kids_age'" == "old"  {
	est_life_impact `earn_effect_old', ///
		impact_age(26) project_age(18) end_project_age(26) ///
		project_year(`=`year_move'+18-`avg_age_move_old_int'') usd_year(`usd_year') ///
		income_info(`MTO_control_earn_26_old') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method(off) transfer_method(off) ///
		max_age_obs(26)
	
	local tot_earn_impact_o = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(18-`avg_age_move_old_int'))
	local tax_impact_o = (`tax_rate_old_short'*`tot_earn_impact_o')
	local tot_earn_impact_aftertax_o = r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(18-`avg_age_move_old_int')) - (`tax_rate_old_short' * `tot_earn_impact_o')
		
	est_life_impact `earn_effect_old', ///
		impact_age(26) project_age(27) end_project_age(`proj_age') ///
		project_year(`=`year_move'+18-`avg_age_move_old_int' + 9') usd_year(`usd_year') ///
		income_info(`MTO_control_earn_26_old') income_info_type(counterfactual_income) ///
		earn_method($earn_method) tax_method(off) transfer_method(off) ///
		max_age_obs(26)
	
	local tot_earn_impact_o = `tot_earn_impact_o' + r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(27-`avg_age_move_old_int'))
	local tax_impact_o = `tax_impact_o' + `tax_rate_old_long' * `tot_earn_impact_o'
	local tot_earn_impact_aftertax_o = `tot_earn_impact_aftertax_o' + (r(tot_earn_impact_d)*((1/(1+`discount_rate'))^(27-`avg_age_move_old_int'))) - (`tax_rate_old_long' * `tot_earn_impact_o')
		
	}
	
}
di `=2012-`year_move'+`avg_age_move_young_int''

*Scale Effects
if "`proj_type'" != "no kids" {
	if "`kids_age'" == "young"{
		local tot_earn_impact = `tot_earn_impact_y'
		local tax_impact = `tax_impact_y'
		local tot_earn_impact_aftertax = `tot_earn_impact_aftertax_y'
	}

	if "`kids_age'" == "old"{
		local tot_earn_impact = `tot_earn_impact_o'
		local tax_impact = `tax_impact_o'
		local tot_earn_impact_aftertax = `tot_earn_impact_aftertax_o'
	}

	if "`kids_age'" == "observed" {
		local tot_earn_impact = (`tot_earn_impact_o'*(1 - `frac_kids_young')) + (`tot_earn_impact_y'*`frac_kids_young')
		local tax_impact = (`tax_impact_o'*(1 - `frac_kids_young')) + (`tax_impact_y'*`frac_kids_young')
		local tot_earn_impact_aftertax = (`tot_earn_impact_aftertax_o'*(1 - `frac_kids_young')) + (`tot_earn_impact_aftertax_y'*`frac_kids_young') 
	}
}
else if "`proj_type'" == "no kids" {
	local tot_earn_impact = 0
	local tax_impact = 0
	local tot_earn_impact_aftertax = 0
}

*Get parent impact
if "`include_parents'"=="yes" {
	*Get average yearly parent welfare impact
	local welfare_impact = 0.5*((`tanf_impact'*0.7)+`snap_impact') // halve because impacts are over two years
	/*
	Note: We adjust the TANF impact by 0.7 because the calculation of adjusted monthly income for housing 
	benefits includes TANF benefits. As a result, only 70% of the observed TANF increases translate into
	fiscal externalities if we assume, as we do above, that the marginal tax rate on all earnings changes is 30%. 
	*/
	local par_tot_earn_impact = 0
	local par_tot_welfare_impact = 0
	
	if "`extend_parent_earn'"=="yes" local years = 65-round(`age_stat',1)
	else if "`extend_parent_earn'"=="no" local years = `parent_earn_years'
	
	forval i =1/`years' {
		local par_tot_earn_impact = `par_tot_earn_impact' + (`earn_impact_1_`parent_earn_years''/((1+`discount_rate')^(`i'-1)))
		local par_tot_welfare_impact = `par_tot_welfare_impact' + (`welfare_impact'/((1+`discount_rate')^(`i'-1)))
	}
	local FE_parent = `par_tot_welfare_impact'-`tax_rate_parent'*`par_tot_earn_impact'
}
else if "`include_parents'"=="no" local FE_parent = 0


*Get implied cost increase to govt from college attendance
if "$got_mto_cost"!="yes" {
	cost_of_college , year(`=`year_move'+18-`avg_age_move_young_int'')
	global mto_college_cost_young = r(cost_of_college)
	global mto_tuition_cost_young = r(tuition)
	
	cost_of_college , year(`=`year_move'+18-`avg_age_move_old_int'')
	global mto_college_cost_old = r(cost_of_college)
	global mto_tuition_cost_old = r(tuition)
	global got_mto_cost = "yes"
}

deflate_to `usd_year', from(`=`year_move'+18-`avg_age_move_young_int'')
local govt_college_cost_young = (${mto_college_cost_young} - ${mto_tuition_cost_young})*`years_enroll'*(`college_effect_young'/100)* ///
	r(deflator)*(1/(1+`discount_rate')^(18-`avg_age_move_young_int'))

local priv_college_cost_young = (${mto_tuition_cost_young})*`years_enroll'*(`college_effect_young'/100)* ///
	r(deflator)*(1/(1+`discount_rate')^(18-`avg_age_move_young_int'))
	
deflate_to `usd_year', from(`=`year_move'+18-`avg_age_move_old_int'')
local govt_college_cost_old = (${mto_college_cost_old} - ${mto_tuition_cost_old})*`years_enroll'*(`college_effect_old'/100)* ///
	r(deflator)*(1/(1+`discount_rate')^(18-`avg_age_move_old_int'))
local priv_college_cost_old = (${mto_tuition_cost_old})*`years_enroll'*(`college_effect_old'/100)* ///
	r(deflator)*(1/(1+`discount_rate')^(18-`avg_age_move_old_int'))

	
if "`kids_age'" == "old" {
	local govt_college_cost = `govt_college_cost_old' 
	local priv_college_cost = `priv_college_cost_old'
}

if "`kids_age'" == "young" {
	local govt_college_cost = `govt_college_cost_young' 
	local priv_college_cost = `priv_college_cost_young'
}

if "`kids_age'" == "observed" {
	local govt_college_cost = (`govt_college_cost_young'*`frac_kids_young') +  (`govt_college_cost_old'*(1 - `frac_kids_young'))
	local priv_college_cost = (`priv_college_cost_young'*`frac_kids_young') +  (`priv_college_cost_old'*(1 - `frac_kids_young'))
}

**************************
/* 5. Cost Calculations */
**************************

local program_cost = `cost_per_family'

if "`include_kids'" == "yes" local FE = `FE_parent' - `tax_impact'*`kids_per_family' + `govt_college_cost'*`kids_per_family'
if "`include_kids'" == "no" local FE = `FE_parent'
di `FE_parent'+`program_cost'
di "`include_kids'"
local total_cost = `program_cost' + `FE' 


di `tax_impact'*`kids_per_family'
di `FE_parent'
di "`par_tot_welfare_impact'-`tax_rate_parent'*`par_tot_earn_impact'"
di `program_cost'  + `FE_parent' 
di `govt_college_cost'
di `tax_rate_parent' -0.3
di `total_cost'

*************************
/* 6. WTP Calculations */
*************************

di `tot_earn_impact'
di `FE_parent'
di  `tax_impact'
di `govt_college_cost'* `kids_per_family'
di `priv_college_cost'* `kids_per_family'  

if "`wtp_valuation'" == "post tax" {
	local WTP = (`tot_earn_impact_aftertax' - `priv_college_cost')* `kids_per_family'  //In this scenario, we assume the parent willingness to pay to be 0.
	local WTP_kid = (`tot_earn_impact_aftertax' - `priv_college_cost')* `kids_per_family'  
	
	if "`proj_type'" == "no kids"{
	local WTP = `program_cost'
	local WTP_kid = 0
	}
	
}

if "`wtp_valuation'" == "cost" {
	local WTP = `program_cost'
	local WTP_kid = 0
}

if "`wtp_valuation'"=="lower bound" {
	local WTP = 0.01*`program_cost'
	local WTP_kid = 0
}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `tot_earn_impact_y'
di `tot_earn_impact_o'
di `tot_earn_impact_aftertax'
di `tax_impact'
di `govt_college_cost_old'
di `govt_college_cost_young'
di `govt_college_cost'*`kids_per_family'
di `program_cost'
di `total_cost'
di `priv_college_cost'
di `WTP'
di `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'

global age_stat_`1' = `age_stat'
if `WTP_kid'>`=`WTP'-`WTP_kid'' {
	global age_benef_`1' = `age_kid'
	}
else {
	global age_benef_`1' = `age_stat'
}	

* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `earn_control_1_10'*r(deflator)
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `year_move'+(1+10)/2 // 1-10 years after move average
global inc_age_stat_`1' = `age_stat'+(1+10)/2

local cfactual_income_26 = (`MTO_control_earn_26_young'*`frac_kids_young') + (`MTO_control_earn_26_old'*(1 - `frac_kids_young'))
local avg_age_move_int = (`avg_age_move_young_int'*`frac_kids_young') + (`avg_age_move_old_int'*(1 - `frac_kids_young'))

if `WTP_kid'>`=0.5*`WTP'' {
	global inc_benef_`1' = `cfactual_income_26'*r(deflator)
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `year_move'+26-`avg_age_move_int'
	global inc_age_benef_`1' = 26
}
else {
	global inc_benef_`1' = `earn_control_1_10'*r(deflator)
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `year_move'+(1+10)/2
	global inc_age_benef_`1' = `age_stat'+(1+10)/2
}

