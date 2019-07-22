********************************************
/* 0. Program: FAFSA Help - Dependent */
********************************************

/*
Bettinger, Eric P., Bridget Terry Long, Philip Oreopoulos, and Lisa Sanbonmatsu. 
"The role of application assistance and information in college decisions: Results
from the H&R Block FAFSA experiment." 
The Quarterly Journal of Economics 127, no. 3 (2012): 1205-1242.
*/

* Provide assistance completing the FAFSA and information about aid estimates for
* nearby colleges. 

********************************
/* 1. Pull Global Assumptions */
********************************

*Project-Wide Globals
local discount_rate = $discount_rate
local proj_type = "$proj_type"
local proj_age = $proj_age
local wage_growth_rate = $wage_growth_rate
local wtp_valuation = "$wtp_valuation" 
local correlation = $correlation

*Program-Specific Globals
local years_enroll_bach = $years_enroll_bach
local years_enroll_cc = $years_enroll_cc
local outcome_type = "$outcome_type"
local val_given_marginal = $val_given_marginal 
local private_costs_gov = "$private_costs_gov"

*Tax Rate Globals 
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}


******************************
/* 2. Estimates from Paper */
******************************

/*
*Dependent Year Impact
local year_imp_dep = 0.191    //Bettinger et al.  2012, Table 6
local year_imp_dep_se = 0.085

*Dependent Pell Impact
local year_imp_dep_pell = 0.230 //Bettinger et al.  2012, Table 7
local year_imp_dep_pell_se = 0.093

*Dependent Enrollment Impact
local enroll_imp_dep = 0.081 //Bettinger et al.  2012, Table 3
local enroll_imp_dep_se = 0.035

*Dependent Enrollment Impact + Pell 
local enroll_imp_dep_pell = 0.106 //Bettinger et al.  2012, Table 3
local enroll_imp_dep_pell_se = 0.034
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


*****************************************************
/* 3. Exact Inputs + Assumptions from Paper */
*****************************************************

/*
Note: It is due to the estimated effect on years of enrollment here that we 
alter our baseline years_enroll_bach assumption to equal three years rather than 
two. This is because the total years in college relative to enrollment is slightly 
more than 2 times, and the according to Table VII the total number of years of 
Pell Grants received is also slightly more than two times the number of recipients
in the first year. Given that ~44% of new recipients enrollment in four-year colleges,
we need an average of three years of bachelors degree enrollment and one year of
community college enrollment to produce an average years of enrollment above slightly
above two. in particular, 3*0.44 + 0.56*1 = 2.16, exactly the ratio of total Pell 
Grant years to initial Pell Grant years reported in Table 1. 
*/
local years_enroll_bach = 3
di `years_enroll_bach'



local analysis_year = 2008 // Bettinger et al. 2012, page 1211
*The program was implemented starting January 2nd, 2008

local usd_year = 2008
*This is assumed because no reference to CPI adjustments is made

*Assumptions of Age for Initial Earnings Loss Projection
local proj_start_age = 18 // Bettinger et al. Table 2 indicates the average age is 17.713
local proj_short_end = 24
local impact_age = 34
local project_year = 2008 

*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2015 
	
*Dependent Cost Impact
local cost_imp_dep = 375 //Bettinger et al.  2012, page 1238
local cost_tot_dep = 3826
/*
Note: These costs referenced in the conclusion are used as the cost 
per individual made eligible. The cost per individual induced to receive 
a Pell Grant is determined by the .106 treatment effect found in Table 3. 

These cost figures are potentially inconsistent with those referenced in Table 5, but 
we defer to the costs used in the conclusion. 
*/

*Program Costs 
local participation_cost = 20
local hrblock_cost = 3 + 30 + 15 + 20 //Bettinger et al. 2012, Page 1238
*Household Income 
local hh_income = 23211 //Bettinger et al. 2012, Table 2
/*
This is the measure of income needed to generate eligibility. That makes
this number an upper bound, but no further information on parental income is provided. 
*/

*Effect on attendence by school type 
local attend_4_year = 0.037 //Bettinger et al. 2012, Table 4
local attend_2_year = 0.047 //Bettinger et al. 2012, Table 4
local attend_pub = 0.065 //Bettinger et al. 2012, Table 4
local attend_priv = 0.019 //Bettinger et al. 2012, Table 4

*Maximum Pell
local pell_2008 = 4731 // https://www2.ed.gov/finaid/prof/resources/data/pell-2009-10/pell-eoy-09-10.pdf

*********************************
/* 4. Intermediate Calculations */
*********************************

if "`outcome_type'" == "years"{
local years_impact = `year_imp_dep'

int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
local pct_earn_impact_pos = r(prog_earn_effect_pos)
local pct_earn_impact_neg = r(prog_earn_effect_neg)

}

*Calculate Fraction of Treatment Effect by School Type 
local frac_public = `attend_pub'/ (`attend_pub' + `attend_priv')
local frac_4_year = `attend_4_year'/ (`attend_4_year' + `attend_2_year')
/*
Note: We don't bootstrap these fractions because we are already bootstrapping the 
total enrollment effect. This prevents a contradiction between estiamtes if the 
correlation in the bootstrapped is reduced. 
*/

if "`outcome_type'" == "enrollment" {

*Convert initial enrollment into total years of schooling
local years_impact = `enroll_imp_dep'*`years_enroll_bach'*`frac_4_year' + ///
	`enroll_imp_dep'*`years_enroll_cc'*(1-`frac_4_year')

int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
local pct_earn_impact_pos = r(prog_earn_effect_pos)
local pct_earn_impact_neg = r(prog_earn_effect_neg)

}

*Calculate Private Contribution 
local person_contribution = `pell_2008' - `cost_tot_dep'
/*
Note: We asssume private tuition contributions are the maximum pell amount 
net of the average grant cost per enrolled invididual. This is a conservative 
assumption because the average grant cost per enrolled individual includes
those who simply receive more pell aid but have no individual contributions
*/

if "`proj_type'" == "growth forecast" {

	*Initial Earnings Decline 
	local impact_age_neg = 21
	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`hh_income') income_info_type(parent_income) ///
		parent_income_year(`project_year') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)
	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_neg = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_shortrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(no) /// don't forecast short-run earnings, this will give an artificially high MTR.
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`=`project_year'+`impact_age_neg'-`proj_start_age'') /// year of income measurement
		 earnings_type(individual) /// individual earnings
		 program_age(`impact_age_neg') // age we're projecting from
	  local tax_rate_shortrun = r(tax_rate)
	}
	
	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	local total_earn_impact_aftertax_neg = `total_earn_impact_neg' - `increase_taxes_neg'
	
	*Earnings Gain
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`proj_start_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`hh_income') income_info_type(parent_income) ///
		parent_income_year(`project_year') ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)
	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local total_earn_impact_pos = ((1/(1+`discount_rate'))^7) * r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(yes) /// forecast long-run earnings to get a realistic lifetime MTR
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`=`project_year_pos'+`impact_age_pos'-`proj_start_age_pos'') /// year of income measurement
		 earnings_type(individual) /// individual, because that is what int_outcome produces
		 program_age(`impact_age_pos') // age we're projecting from
	  local tax_rate_longrun = r(tax_rate)
	}
	
	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'
	local total_earn_impact_aftertax_pos = `total_earn_impact_pos' - `increase_taxes_pos'

		
	*Combine Estimates
	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'
}
else {
		di as err "Only growth forecast allowed"
		exit
}

*Find Fraction of New Pell Recipients Induced to Attend School
if "`outcome_type'" == "years"{
	di `year_imp_dep'
	local induced_fraction = `year_imp_dep' / `year_imp_dep_pell'

	/*Note: We assume that the fraction of induced individuals is determined by 
	the number of new years of college enrollment as a fraction of the total 
	number of new individuals receiving Pell Grants.*/

	if (`induced_fraction' > 1 ){
		local induced_fraction = 1
	}
	/*Note: This corrects for the case where a correlation between the treatment 
	effects for pell recipients and	new enrollees set at 1. In that case we might 
	find that the number of new years of schooling exceeds the number of total 
	new years of Pell receipt. Given that the nature of the FAFSA form in securing
	student aid, we rule out the unlikely occurence that the policy induces individuals
	to enroll in school without	securing aid. 
	*/

}

if "`outcome_type'" == "enrollment"{
	local induced_fraction = (`enroll_imp_dep'/`enroll_imp_dep_pell')
	
	/* Note: We assume that the fraction of induced individuals is determined by the number of new college 
	attending as a fraction of the total number of new individuals receiving Pell Grants.*/

	if (`induced_fraction' > 1 ){
		local induced_fraction = 1
	}
	
	/* Note: This corrects for the case where a correlation between the treatment 
	effects for pell recipients and	new enrollees isn't implemented. In that case 
	we might find that the number of new enrollees exceeds the number of total 
	new pell recipients. Given that the nature of the FAFSA form in securing student 
	aid, we rule out the unlikely occurence that the policy induces individuals 
	to enroll in school without	securing aid. */

}



	
**************************
/* 5. Cost Calculations */
**************************
*Discounting for cost calculations:
*4-Year School
	local years_enroll_bach_disc = 0
	local end = ceil(`years_enroll_bach')
	forval i=1/`end' {
		local years_enroll_bach_disc = `years_enroll_bach_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_bach' - floor(`years_enroll_bach')
	if `partial_year' != 0 {
		local years_enroll_bach_disc = `years_enroll_bach_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}

*2-Year School
	local years_enroll_cc_disc = 0
	local end = ceil(`years_enroll_cc')
	forval i=1/`end' {
		local years_enroll_cc_disc = `years_enroll_cc_disc' + (1)/((1+`discount_rate')^(`i'-1))
	}
	local partial_year = `years_enroll_cc' - floor(`years_enroll_cc')
	if `partial_year' != 0 {
		local years_enroll_cc_disc = `years_enroll_cc_disc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
	}


if "`outcome_type'" == "years"{
*For all cost-of-enrollment effects based on years, we conservatively assume 
*that they occur at the beginning of the program:
	local years_impact_disc = `years_impact'

}
if "`outcome_type'" == "enrollment"{
	local years_impact_disc = `enroll_imp_dep'*`years_enroll_bach_disc'*`frac_4_year' + `enroll_imp_dep'*`years_enroll_cc_disc'*(1-`frac_4_year')

}

*Calculate Cost of Pell Grants Amongst Those Who Would Have Already Enrolled
local pell_cost_non_induced = `cost_imp_dep'*(1/`enroll_imp_dep_pell')*`years_impact_disc'*((`enroll_imp_dep_pell' - `enroll_imp_dep')/`enroll_imp_dep_pell')
/*
Note: We discount costs over the number of years of enrollment. We assume that the fraction of total years when treated individuals 
receive new Pell Grants is equal to the fraction of new pell grant recipients who were not new enrollees. This is a reasonable 
assumption given that ratio of new enrollees recipients to new Pell recipients in Table 3 is relatively close to the ratio of 
years of Pell receipt to years of college enrollment in Tables 6 and 7.  

The Pell costs for those who would have already enrolled is equal to the cost of a year for a new enrollee "`cost_imp_dep'*(1/`enroll_imp_dep_pell')"
times the number of years of new enrollment "`discounted_years_impact'" times the years of new pell receipt without enrollment relative to the years of new enrollment 
((`enroll_imp_dep' - `enroll_imp_dep_pell')/`enroll_imp_dep_pell'). 
*/
if "${got_Fafsa_help_dep_OH_costs}"!="yes" {
	cost_of_college, year(2008) state("OH") type_of_uni("any")
	global cost_of_college_2008_oh_any_dep = `r(cost_of_college)'

	global got_Fafsa_help_dep_OH_costs yes
}
local cost_of_college_2008_oh_any = $cost_of_college_2008_oh_any_dep


if "${got_Fafsa_help_dep_NC_costs}"!="yes" {
	cost_of_college, year(2008) state("NC") type_of_uni("any")
	global cost_of_college_2008_nc_any_dep = `r(cost_of_college)'
	
	global got_Fafsa_help_dep_NC_costs yes
	}
local cost_of_college_2008_nc_any = $cost_of_college_2008_nc_any_dep

if "`private_costs_gov'"=="no" {
	local induced_cost_private = `years_impact_disc'*`cost_imp_dep'*(1/`enroll_imp_dep_pell')*(1-`frac_public')
}
if "`private_costs_gov'"=="yes" {
	local induced_cost_private =  `years_impact_disc'* ((`cost_of_college_2008_oh_any'+`cost_of_college_2008_nc_any')/2)*(1-`frac_public')
}
local induced_cost_public = `years_impact_disc'* ((`cost_of_college_2008_oh_any'+`cost_of_college_2008_nc_any')/2)*`frac_public'
local induced_contribution = `years_impact_disc'*`person_contribution'

/*
Note: We use average costs per year of additional schooling averaged over four-year and two-year schools. We do this because 
years of additional schooling is our primary specification and we do not have a good way of determining whether those years 
were at two-year or four-year schools. An alternate method would split the sample by the fraction of two-year attendees and 
then apply our assumptions regarding the number of years of enrollment at each type of institution, but such an alternative 
requires making a substantial number of additional assumptions. 
*/

local base_program_cost = `participation_cost' + `hrblock_cost' + `pell_cost_non_induced' 

local enroll_cost = `induced_cost_private' + `induced_cost_public'

local FE = `increase_taxes' 

local total_cost = `base_program_cost' + `enroll_cost' - `FE'

*Calculate program costs (Administrative costs and Pell costs without additional costs crowded in) 
local pell_cost_induced = `years_impact_disc'*`cost_imp_dep'*(1/`enroll_imp_dep_pell')
local program_cost = `base_program_cost'

*************************
/* 6. WTP Calculations */
*************************

*Calculate WTP based on valuation assumption
if "`wtp_valuation'" == "post tax"{

local WTP = `total_earn_impact_aftertax' + `participation_cost' + `pell_cost_non_induced' - `induced_contribution'
/*
NOTE: This analysis assumes that all individuals value the $20 participation incentives at the full $20, but do not value the 
cost incurred by H&R Block
*/

}

if "`wtp_valuation'" == "cost"{
	local wtp_not_induced = `participation_cost' + `pell_cost_non_induced'
	
	local wtp_induced = (`pell_cost_induced' + `participation_cost')*`val_given_marginal'
	
	local WTP = `wtp_induced' + `wtp_not_induced'

}

if "`wtp_valuation'" == "nudge"{
	// no clear lower bound on valuation, choose valuation at 1% of program cost
	local WTP = `participation_cost'

}


**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

/*
Figures for Attainment Graph 
*/
di `years_impact' //enrollment gain
di `participation_cost' +`hrblock_cost' // Mechanical Cost 
di `pell_cost_non_induced' + `pell_cost_induced' // Behavioral Cost Program
di 	`enroll_cost' - `pell_cost_induced' // Behavioral Cost Crowd-In
di `wtp_induced' //WTP induced
di `wtp_not_induced' //WTP Non-Induced
di 	`counterfactual_income_longrun' // Income Counter-Factual


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
global age_stat_`1' = (18+22)/2 // College program assumption
global age_benef_`1' = (18+22)/2 // College program assumption


* income globals
deflate_to 2015, from(`usd_year')
global inc_stat_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `project_year_pos' + `proj_start_age_pos' - `proj_start_age_pos'
global inc_age_stat_`1' = `impact_age_pos' 

global inc_benef_`1' = `counterfactual_income_longrun' * r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `project_year_pos' + `proj_start_age_pos' - `proj_start_age_pos'
global inc_age_benef_`1' = `impact_age_pos' 

