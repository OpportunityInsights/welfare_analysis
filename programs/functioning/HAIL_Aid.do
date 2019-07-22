********************************************************
/* 0. Program: Hail Michigan Aid Awareness Letter  */
********************************************************

/*
Dynarski, Susan, C. J. Libassi, Katherine Michelmore, and Stephanie Owen. Closing 
the Gap: The Effect of a Targeted, Tuition-Free Promise on College Choices of High-Achieving, 
Low-Income Students. No. w25349. National Bureau of Economic Research, 2018.

*Provide tuition waivers to high-achieving, low-income students for the University
*of Michigan 

Hoekstra, Mark. "The effect of attending the flagship state university on earnings:
A discontinuity-based approach." The Review of Economics and Statistics 91,
no. 4 (2009): 717-724.
*/
 

********************************
/* 1. Pull Global Assumptions */
********************************

*Project-Wide Globals
local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" 
local tax_rate_cont = $tax_rate_cont
local proj_type = "$proj_type" 
local proj_age = $proj_age
local correlation = $correlation
local wtp_valuation = "$wtp_valuation" 
local val_given_marginal = $val_given_marginal 

*Program-Specific globals
local years_enroll_bach = $years_enroll_bach
local years_enroll_cc = $years_enroll_cc
local selective_earnings = "$selective_earnings"

*Tax Rate Globals
local tax_rate_assumption = "$tax_rate_assumption" // "continuous" or "cbo"
local payroll_assumption = "$payroll_assumption" // "yes" or "no"
local transfer_assumption = "$transfer_assumption" // "yes" or "no"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate_longrun  = $tax_rate_cont
	local tax_rate_shortrun = $tax_rate_cont
}


*************************************
/* 2. Causal Inputs from Paper */
*************************************

/*Enrollment Impact
local enroll_any = 0.039 //Dynarski et al.  2018, Table 7
local enroll_any_se = 0.018

local enroll_from_cc = 0.035 //Dynarski et al.  2018, Table 7
local enroll_from_cc_se = 0.013
/*
Note: We assume that all those showing a reduction in
2-year enrollment switch to UM enrollment. This is consistent with the 0.074
increase in 4-year enrollment, which is equal to the sum of the new enrollees, 0.039
and the reductions in community college enrollees, 0.035. Note that this is why
we change the sign of the coefficient from negative (as reported in the paper) to 
positive. 
*/

local enroll_imp = 0.141 //Dynarski et al.  2018, Table 3
local enroll_imp_se = 0.016
*/


/*
Note: Unlike the case in the dependent sample, we do not deviate from the assumption 
that years_enroll_bach is set equal to two years. This is because the enrollment data
from the NSC suggests that total years attended is slightly more than two times 
intial enrollment, but the DOE data suggests total years of pell reciept is only 
approximates 1.5 times initial reciept. Given this divergence in results we rely
on our traditional enrollment assumptions. */
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




*********************************
/* 3. Assumptions from Paper */
*********************************
local packet_cost = 10
/*
Note: The paper suggests the packet costs less than $10 to produce and 
deliver (Dynarski et al. 2018, pg 7). There may be additional costs associated 
with parent and school notification and the accompanying online portal, but those 
costs are not documented in the paper. As a fraction of total educational expenses
they remain very small and are, therefore, very unlikley to impact the MVPF. 
*/

local usd_year = 2015

local analysis_year = 2015
*2015-2016 is referred to as the 2nd year of analysis, so this is an appropriate midpoint. 

*Assumptions of Age for Initial Earnings Loss Projection
local proj_start_age = 18
local proj_short_end = 24
local project_year = 2015 
local short_proj_age = 24
local impact_age_neg = 21

	
*Assumptions of Age for Earnings Gain Projection
local proj_start_age_pos = 25
local impact_age_pos = 34
local project_year_pos = 2022

local impact_year = `project_year_pos' + `impact_age_pos'-`proj_start_age_pos'
local impact_year_neg = `project_year_pos' + `impact_age_neg'-`proj_start_age'

*********************************
/* 4. Intermediate Calculations */
*********************************
local hh_income = ((44863+31525)/2)*0.3 + 24250*0.7
/*
Note: No estimate of average household income is provided in the paper. The author's
note that "The majority of students in the sample qualified for a free lunch (70 percent)
while the remaining 30 percent qualified for a reduced-price lunch." We therefore
take a weighted average of those two groups, assuming that those in the reduced-price
lunch group have a mean income between the two thresholds and those in the free lunch
group have a mean income at 100% of the Federal Poverty Line. Data eligibility thresholds
can be found at: https://www.govinfo.gov/content/pkg/FR-2015-03-31/pdf/2015-07358.pdf
*/

local selective_years = 2 // Hoekstra 2009, Table 1
/*
Note: The estimates from Hoekstra 2009 suggest that attending a flagship university
increases earnings by approximately 20%. (The values vary by specification). For simplicity, 
we translate this into the approximate number of additional years of average schooling 
that would produce such an effect. This allows us to apply the same uncertainty to this
earnings effect and the other college earnings effects incorporated from Zimmerman. 
*/

*Estimate Earnings Effect Using Additional Enrollment 
local years_impact = `enroll_any'*`years_enroll_bach' + `enroll_from_cc'*`years_enroll_cc'

local selective_impact = `enroll_imp' - `enroll_any' - `enroll_from_cc'

if "`selective_earnings'" == "yes" {

local years_impact = `years_impact' + `selective_impact'*`selective_years'
}

int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year')
local pct_earn_impact_pos = r(prog_earn_effect_pos)
local pct_earn_impact_neg = r(prog_earn_effect_neg)

*Estimate Long-Run Earnings Effect Using Growth Forecast Method 
if "`proj_type'" == "growth forecast" {
	
	*Initial Earnings Decline 

	est_life_impact `pct_earn_impact_neg', ///
		impact_age(`impact_age_neg') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
		project_year(`project_year') usd_year(`usd_year') ///
		income_info(`hh_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		percentage(yes)

	local counterfactual_income_shortrun = r(cfactual_income) // For CBO tax rates.
	local earn_proj = r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
		get_tax_rate `counterfactual_income_shortrun', ///
			include_transfers(yes) ///
			include_payroll(`payroll_assumption') /// "yes" or "no"
			forecast_income(no) /// don't forecast short-run earnings, this will give an artificially high MTR.
			usd_year(`usd_year') /// USD year of income
			inc_year(`impact_year') /// year of income measurement
			earnings_type(individual) /// individual earnings
			program_age(`impact_age_neg') // age we're projecting from
		local tax_rate_shortrun = r(tax_rate)
	}
	
	di `tax_rate_shortrun'
	
	
	local total_earn_impact_neg = `earn_proj'
	di `total_earn_impact_neg'

	local increase_taxes_neg = `tax_rate_shortrun' * `total_earn_impact_neg'
	di `increase_taxes_neg'
	local total_earn_impact_aftertax_neg = `total_earn_impact_neg' - `increase_taxes_neg'
	
	*Earnings Gain
	est_life_impact `pct_earn_impact_pos', ///
		impact_age(`impact_age_pos') project_age(`proj_start_age_pos') end_project_age(`proj_age') ///
		project_year(`project_year_pos') usd_year(`usd_year') ///
		income_info(`hh_income') income_info_type(parent_income) ///
		earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
		 percentage(yes)

	local counterfactual_income_longrun = r(cfactual_income) // For CBO tax rates.
	local earn_proj = ((1/(1+`discount_rate'))^7) *r(tot_earn_impact_d)

	* Get marginal tax rate using counterfactual earnings, if we're using CBO tax rates.
	if "`tax_rate_assumption'" ==  "cbo" {
	  get_tax_rate `counterfactual_income_longrun', ///
		 include_transfers(yes) ///
		 include_payroll(`payroll_assumption') /// "yes" or "no"
		 forecast_income(yes) /// forecast long-run earnings to get a realistic lifetime MTR
		 usd_year(`usd_year') /// USD year of income
		 inc_year(`impact_year') /// year of income measurement
		 earnings_type(individual) /// individual, because that is what int_outcome produces
		 program_age(`impact_age_pos') // age we're projecting from
	  local tax_rate_longrun = r(tax_rate)
	}
	
	local total_earn_impact_pos = `earn_proj'
	local increase_taxes_pos = `tax_rate_longrun' * `total_earn_impact_pos'

	local total_earn_impact_aftertax_pos = `total_earn_impact_pos' - `increase_taxes_pos'

	*Combine Estimates
	local total_earn_impact = `total_earn_impact_neg' + `total_earn_impact_pos'
	local increase_taxes = `increase_taxes_neg' + `increase_taxes_pos'
	local total_earn_impact_aftertax = `total_earn_impact_aftertax_pos' + `total_earn_impact_aftertax_neg'

	}
    di `total_earn_impact'
	di `increase_taxes'
else {
		di as err "Only growth forecast allowed"
		exit
}
* get income in 2015 dollars
deflate_to 2015, from(`usd_year')
local income_2015 = r(deflator)* `counterfactual_income_longrun'

**************************
/* 5. Cost Calculations */
**************************

*Discounting for costs:
local discounted_years_bach = 0
local end = ceil(`years_enroll_bach')
forval i=1/`end' {
	local discounted_years_bach = `discounted_years_bach' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_enroll_bach' - floor(`years_enroll_bach')
if `partial_year' != 0 {
	local discounted_years_bach = `discounted_years_bach' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}

local discounted_years_cc = 0
local end = ceil(`years_enroll_cc')
forval i=1/`end' {
	local discounted_years_cc = `discounted_years_cc' + (1)/((1+`discount_rate')^(`i'-1))
}
local partial_year = `years_enroll_cc' - floor(`years_enroll_cc')
if `partial_year' != 0 {
	local discounted_years_cc = `discounted_years_cc' - (1-`partial_year')*(1)/((1+`discount_rate')^(`end'-1))
}


*Calculate Cost of Additional enrollment

if "${got_HAIL_Aid_UM_costs}"!="yes" {	
cost_of_college, year(2015) name("university of michigan-ann arbor")
	global cost_of_college_umich_2015 = `r(cost_of_college)'
	global fte_count_umich_2015 = `r(fte_count)'
	
	global got_HAIL_Aid_UM_costs yes
	}
local cost_of_college_umich_2015 = $cost_of_college_umich_2015
local fte_count_umich_2015 = $fte_count_umich_2015

if "${got_HAIL_Aid_cc_costs}"!="yes" {
	cost_of_college, year(2015) state("MI") type_of_uni("community")
	global cost_of_college_community_2015 = `r(cost_of_college)'
	
	global got_HAIL_Aid_cc_costs yes
	}
local cost_of_college_community_2015 = $cost_of_college_community_2015

if "${got_HAIL_Aid_rmb_costs}"!="yes" {
	cost_of_college, year(2015) state("MI") type_of_uni("rmb")
	global cost_2015_mi_r = `r(cost_of_college)'
	global count_2015_mi_r = `r(fte_count)'

	global got_HAIL_Aid_rmb_costs yes
	}
local cost_2015_mi_r = $cost_2015_mi_r
local count_2015_mi_r = $count_2015_mi_r


*Calculate cost of college per student for universities other than UofM
* (total cost for all MI universities - total cost for UofM)/(# of non-UofM students)
local cost_of_college_rmb_not_um_2015 = ((`cost_2015_mi_r'*`count_2015_mi_r') - ///
	(`cost_of_college_umich_2015' * `fte_count_umich_2015')) ///
	/ (`count_2015_mi_r' - `fte_count_umich_2015')
	
	
local enroll_cost = `enroll_any'*`discounted_years_bach'*`cost_of_college_umich_2015' + ///
	`enroll_from_cc'*`discounted_years_cc'*(`cost_of_college_umich_2015'-`cost_of_college_community_2015') + /// 
	`selective_impact'*`discounted_years_bach'*(`cost_of_college_umich_2015'-`cost_of_college_rmb_not_um_2015')
/*
First cost is new UMich Enrollment, second cost is switch from CC, third is switching to 
more selective four year. 
*/

local program_cost = `packet_cost' + `enroll_cost'

local FE = `increase_taxes' 

local total_cost = `program_cost' - `FE'

*************************
/* 6. WTP Calculations */
*************************

*Calculate WTP based on valuation assumption
if "`wtp_valuation'" == "post tax"{

local WTP_induced = `total_earn_impact_aftertax'
local WTP_non_induced = `packet_cost'*(1-`enroll_imp')
local WTP = `WTP_non_induced' + `WTP_induced'
/*
NOTE: This analysis assumes that individuals who receive a packet from
the university of michigan and do not attend value that packet at
the cost to produce it.
*/

}

if "`wtp_valuation'" == "cost"{
local WTP_induced = `enroll_cost'*`val_given_marginal'
local WTP_non_induced = 0
local WTP = `WTP_non_induced' + `WTP_induced'
}

if "`wtp_valuation'" == "nudge"{

local WTP = (1/100)*`program_cost'
// no clear lower bound on valuation, choose valuation at 1% of program cost

}

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP' / `total_cost'

/*
Figures for Attainment Graph 
*/
di `years_impact' //enrollment gain
di  0 // baseline enrollment
di  `packet_cost'  // Mechanical Cost 
di  0 // Behavioral Cost Program
di 	`enroll_cost'   // Behavioral Cost Crowd-In
di `WTP_induced' //WTP induced
di `WTP_non_induced' //WTP Non-Induced
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
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `impact_year'
global inc_age_stat_`1' = `impact_age_pos'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `impact_year'
global inc_age_benef_`1' = `impact_age_pos'

