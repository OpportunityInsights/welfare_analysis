*****************************
/* 0. Program: Abecedarian */
*****************************

/*
Barnett, W. Steven, and Leonard N. Masse. "Comparative benefit–cost analysis of 
the Abecedarian program and its policy implications." Economics of Education 
Review 26, no. 1 (2007): 113-125.
* (Correction) https://ac.els-cdn.com/S027277570700012X/1-s2.0-S027277570700012X-main.pdf?_tid=827f40dc-bf02-448c-9486-b8a022168410&acdnat=1534176914_9793eb12dbde4cff6cff5f6a0017b570

Masse, Leonard N., and W. Steven Barnett. "A benefit-cost analysis of the Abecedarian 
early childhood intervention." Cost-Effectiveness and Educational Policy, 
Larchmont, NY: Eye on Education, Inc (2002): 157-173.
https://files.eric.ed.gov/fulltext/ED479989.pdf

*Helburn, Suzanne W. "Cost, Quality and Child Outcomes in Child Care Centers. 
Technical Report, Public Report, and Executive Summary." (1995).
https://files.eric.ed.gov/fulltext/ED386297.pdf

Campbell, Frances A, et al, "Adult outcomes as a function of an early childhood 
educational program: an Abecedarian Project follow-up.", Developmental 
psychology 48, 4 (2012), pp. 1033.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local discount_rate = $discount_rate
//Due to causal effects being PDVs, only allow 3, 5, and 7% discount rates.
if $discount_rate != 0.03 & $discount_rate != 0.05 & $discount_rate != 0.07 {
	di as err "Abecedarian allows only 3, 5 and 7% discount rates"
	exit
}
local tax_rate_assumption = "$tax_rate_assumption" //takes value "paper internal" or "continuous" or "cbo"
local tax_rate_cont = $tax_rate_cont 
local payroll_assumption = "$payroll_assumption" // "yes" or "no"

local wtp_valuation = "$wtp_valuation"
local proj_type = "$proj_type" //takes value paper internal or growth forecast 
local proj_age = $proj_age //takes on age at end of projection
local net_transfers = "$net_transfers" //takes value yes if adjustments for changes in net transfers/taxes
local correlation = $correlation

*Program-Specific Globals 
local abeced_beneficiary = "$abeced_beneficiary" // takes on "participants", "partic_mom" (participant and mom), or "all" (participant, mom, and descendents)
local include_smoking = "$include_smoking" //"yes" or "no"
local forecast_variable = "$forecast_variable" //"college" or "income"
local include_other_costs = "$include_other_costs" //"yes" or "no"
local years_enroll = $years_enroll //years of additional attainment associated with college enrollment

*****************************
/* 2. Estimates from Paper */
*****************************

/*
*Age- 30 income - Campbell et al (2012) table 4 treatment - control income at age 30:
local income_effect = 12730
local income_effect_p_value = 0.11

*Increase in 4-year college attendance - Masse and Barnett, p. 5
local incr_higher_ed = 0.23
local incr_higher_ed_p_value = 0.01

*Probability of age-21 AFDC receipt - Masse and Barnett, p. 5:
local afdc_effect = -0.08
local afdc_effect_p_value = 0.234

*Net marginal cost PDV - Masse and Barnett, Table 8.4:
local net_marginal_cost03 = 35864
local net_marginal_cost05 = 34599
local net_marginal_cost07 = 33421

*K-12 savings PDV - Masse and Barnett, Table 2 (SE: Placement in special education (E=31%, C=49%, N=99, p=.0672)):
local pdv_k1203 = 8836
local pdv_k1205 = 7375
local pdv_k1207 = 6205
local pdv_k12_p_value = 0.0672

*Participant earnings PDV - Masse and Barnett, Table 8.5:
local pdv_partic_earn03 = 37531
local pdv_partic_earn05 = 16460
local pdv_partic_earn07 = 6376

*Benefits from reduced smoking PDV - Masse and Barnett, Table 2 (SE: Rates of smoking (E=39%, C=55%, p =.106)):
local smoking_benefits03 = 17781
local smoking_benefits05 = 4166
local smoking_benefits07 = 1008
local smoking_benefits_p_value = 0.106

*Maternal earnings PDV - Masse and Barnett, Table 2 (SE: Effect on primary caregiver mean earnings is $3085 (p =.012, N= 101, R2 = .053)):
local pdv_mom_earn03 = 68728
local pdv_mom_earn05 = 48496
local pdv_mom_earn07 = 35560
local pdv_mom_earn_p_value = 0.012

*Descendant earnings PDV - Masse and Barnett, Table 8.5:
local pdv_descen_earn03 = 5722
local pdv_descen_earn05 = 1586
local pdv_descen_earn07 = 479
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
		}
	restore
}

*Set locals for the chosen discount rate (.03, .05, or .07)
local disc_rate_clean = subinstr("`discount_rate'",".","",.)
foreach est in net_marginal_cost pdv_k12 pdv_partic_earn pdv_mom_earn pdv_descen_earn smoking_benefits {
	local `est' = ``est'`disc_rate_clean''
}

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local program_year = 1975 //children born between 1972 and 1977 (Masse 2002, p. 6)
local usd_year = 2002 // usd year for all numbers except income numbers from Campbell et al 
local per_cost_np_care = 0.66 //% of Cost from Non-parental Care; Masse (2002), Table 4.17
local prob_center_care = (0.18/0.44 + 0.29/0.49 + 1 + 1 + 0.73/0.77)/5 //Probability of Center-based Care (Out of Non-Parental Care); Masse (2002), Table 4.6
local per_center_pub_cash = 0.22 //*% of Child Care Centers Cash Inflows from Public Sources, Helburn (1995),  Table 8.1

local program_cost_total = 67225 // Masse and Barnett 2002, Table 8.3; estimated observed costs per child
local program_cost_y1 = 10799 // Masse and Barnett 2002, Table 8.3; estimated observed costs per child
local program_cost_y2 = 16222 // Masse and Barnett 2002, Table 8.3; estimated observed costs per child
local program_cost_y3 = 16222 // Masse and Barnett 2002, Table 8.3; estimated observed costs per child
local program_cost_y4 = 11991 // Masse and Barnett 2002, Table 8.3; estimated observed costs per child
local program_cost_y5 = 11991 // Masse and Barnett 2002, Table 8.3; estimated observed costs per child

local control_mean_earn = 20710 // Campbell et al 2012 Table 4
local usd_year_inc = (2003+2009)/2 // no indication of inflation adjustment so use "Follow-up assessments for age 30 took place between 2003 and 2009"
local income_effect_age = 30 // follow up at age 30

* cost of college
local higher_ed_cost_03 = 8128 // Masse and Barnett (2002) Table 8.2 2002 usd
local higher_ed_cost_05 = 5621 // Masse and Barnett (2002) Table 8.2 2002 usd
local higher_ed_cost_07 = 3920 // Masse and Barnett (2002) Table 8.2 2002 usd
local higher_ed_cost = `higher_ed_cost_`disc_rate_clean''

* Average AFDC payment (in 1995 dollars)
deflate_to `usd_year', from (1995)
local afdc_amt = 3935 * r(deflator) //Masse and Barnett (2002) p. 32

* Probability of AFDC continuation after five years
local p_afdc_cont = 0.2 //Masse and Barnett (2002) p. 32


********************************
/* 4. Intermediate Calculations */
*********************************

*Get ages
local age_benef = (0+5)/2 // it's a preschool program
local age_stat = `age_benef' // program is an in kind benefit to child

*Aggregate discounted program cost:
local program_cost = 0
forvalues j = 1/5{
	local program_cost = `program_cost' + `program_cost_y`j''/((1+`discount_rate')^(`j'-1)) 
}

* Back out cost of care for control from program cost and Masse & Barnett (2002)'s net marginal cost estimates
local control_cost = `program_cost' - `net_marginal_cost'

* Government savings from kids not being in other programs
local govt_savings = `control_cost'*`per_cost_np_care'*`prob_center_care'*`per_center_pub_cash'

* Parent savings because they have to pay for less care elsewhere
local parent_savings = `control_cost'*`per_cost_np_care'*`prob_center_care'*(1-`per_center_pub_cash')

* Relatives savings because they have to provide less care
local relatives_savings = `control_cost'*`per_cost_np_care'*(1-`prob_center_care')

*Compute savings from AFDC payments:
//NOTE: Masse and Barnett (2002)'s savings from welfare payments are focused
//solely on the administrative savings from reduced AFDC caseloads at age 21, and
//not on changes in benefits per se. We compute the latter based on M&B's assumptions
//that AFDC receipt is for 5 years beginning at age 21 with a 20% probability that
//benefits continue (we assume for 20 years) - see pp. 31-33 for details.
local pdv_welfare = 0
forval i = 21/45 {
	if `i' < 26	local pdv_welfare = `pdv_welfare' + (-`afdc_effect')					* `afdc_amt' * (1/(1+`discount_rate')^(`=`i'-round(`age_benef')'))
	else		local pdv_welfare = `pdv_welfare' + `p_afdc_cont' * (-`afdc_effect')	* `afdc_amt' * (1/(1+`discount_rate')^(`=`i'-round(`age_benef')'))
}

*Earnings forecasts:
if "`proj_type'" == "growth forecast" {

	if "`forecast_variable'" == "income" {
		*Use impact on age-30 income (from Campbell et al. followup) to project earnings:
		local proj_start_age = 18
		local project_year = round(`program_year'+`proj_start_age'-`age_benef')

		est_life_impact `income_effect', ///
			impact_age(`income_effect_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
			project_year(`project_year') usd_year(`usd_year_inc') ///
			income_info(`control_mean_earn') income_info_type(counterfactual_income) ///
			earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
			percentage(no) max_age_obs(`income_effect_age') 
	
		local pdv_partic_earn = r(tot_earn_impact_d) / ((1+`discount_rate')^(`=`proj_start_age'-round(`age_benef')'))
	}
	*Forecast over lifecycle:	
	if "`forecast_variable'" == "college" {
		/* Here we use the impact on the program on college enrollment rates (as done in Masse and Barnett). From 
		Zimmerman et al 2014 we can translate college attendance into % earnings impact. */
		
		local years_impact = `incr_higher_ed'*`years_enroll'
		int_outcome, outcome_type(attainment) impact_magnitude(`years_impact') usd_year(`usd_year') 
		local pct_earn_impact_neg = r(prog_earn_effect_neg)
		local pct_earn_impact_pos = r(prog_earn_effect_pos)

		*Initial earnings decline
		local proj_start_age = 18
		local proj_short_end = 24
		local project_year = round(`program_year'+`proj_start_age'-`age_benef')
		
		est_life_impact `pct_earn_impact_neg', ///
			impact_age(`income_effect_age') project_age(`proj_start_age') end_project_age(`proj_short_end') ///
			project_year(`project_year') usd_year(`usd_year_inc') ///
			income_info(`control_mean_earn') income_info_type(counterfactual_income) ///
			earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
			percentage(yes)
		
		local total_earn_impact_neg = r(tot_earn_impact_d)*(1/(1+`discount_rate')^(`=`proj_start_age'-round(`age_benef')'))

		*Later earnings increase
		local proj_start_age = 25
		local impact_age = 34
		local project_year = round(`program_year'+`proj_start_age'-`age_benef')
		
		est_life_impact `pct_earn_impact_pos', ///
			impact_age(`impact_age') project_age(`proj_start_age') end_project_age(`proj_age') ///
			project_year(`project_year') usd_year(`usd_year') ///
			income_info(`control_mean_earn') income_info_type(counterfactual_income) ///
			earn_method(${earn_method}) tax_method(${tax_method}) transfer_method(${transfer_method}) ///
			percentage(yes)
		
		local total_earn_impact_pos = r(tot_earn_impact_d)*(1/(1+`discount_rate')^(`=`proj_start_age'-round(`age_benef')'))
		
		local pdv_partic_earn = `total_earn_impact_neg' + `total_earn_impact_pos'
	}

	*Adjust PDV of earnings impacts for inflation:
	deflate_to `usd_year', from(`usd_year_inc')
	local pdv_partic_earn = `pdv_partic_earn' * r(deflator)

}
if "`proj_type'" == "paper internal" {
	*Use Barnett/Masse's projected participant earnings figure:
	local pdv_partic_earn = `pdv_partic_earn'
}

*Get tax rates:
if "`tax_rate_assumption'" ==  "cbo" {
	*Because we lack direct info on maternal/descendant income, we assume they
	*face the same tax rate as participants do later in life: 
	get_tax_rate `control_mean_earn', ///
		include_transfers(yes) ///
		include_payroll(`payroll_assumption') /// "yes" or "no"
		forecast_income(yes) /// "yes" or "no"
		usd_year(`usd_year_inc') /// USD year of income
		inc_year(`usd_year_inc') /// year of income measurement 
		program_age(`income_effect_age') ///
		earnings_type(individual) // individual or household
	foreach x in partic mom descen {
		local tax_rate_`x' = r(tax_rate)
	}
}
if "`tax_rate_assumption'" == "paper internal" {
	foreach x in partic mom descen {
		local tax_rate_`x' = 0.35 //Masse 2002 p 99 assumes a 25% tax rate + 10% employer costs that go to the taxpayer
		*NOTE: The tax rate assumption used in the paper here is not the observed tax rate but rather a predicted one. 
	}
}
if "`tax_rate_assumption'" == "continuous"  {
	foreach x in partic mom descen {
		local tax_rate_`x' =`tax_rate_cont'
	}
}

*Get tax impacts:
foreach x in partic mom descen {
	local `x'_fut_tax_rev = `pdv_`x'_earn'*`tax_rate_`x''
	local `x'_aft_tax_ben = `pdv_`x'_earn'*(1-`tax_rate_`x'')
}

*Use college cost calculator to get proportion of the cost of college paid privately:
if "$got_abeced_cost"!="yes" {
	cost_of_college , year(`=round(`program_year'+18-`age_benef')') state(NC)
	global abeced_college_cost = r(cost_of_college)
	global abeced_tuition_cost = r(tuition)
	global got_abeced_cost = "yes"
}
local priv_cost_prop = (${abeced_tuition_cost}/${abeced_college_cost})


**************************
/* 5. Cost Calculations */
**************************

*Calculate program costs net of fiscal externalities:
if "`abeced_beneficiary'" == "participants" {
	local FE = `pdv_welfare' + `partic_fut_tax_rev' + `govt_savings' - (1-`priv_cost_prop')*`higher_ed_cost'
}
if "`abeced_beneficiary'" == "partic_mom" {
	local FE = `pdv_welfare' + `partic_fut_tax_rev' + `govt_savings' - (1-`priv_cost_prop')*`higher_ed_cost' + `mom_fut_tax_rev'
}
if "`abeced_beneficiary'" == "all" {
	local FE = `pdv_welfare' + `partic_fut_tax_rev' + `govt_savings' - (1-`priv_cost_prop')*`higher_ed_cost' + `mom_fut_tax_rev' + `descen_fut_tax_rev'
}
if "`include_other_costs'" == "yes" local FE = `FE' + `pdv_k12' 

local total_cost = `program_cost' -  `FE'

*************************
/* 6. WTP Calculations */
*************************

*Calculate post-tax-and-transfer WTP:
*Participants:
local WTP_post_tax_p = `partic_aft_tax_ben' - `priv_cost_prop'*`higher_ed_cost'
//Potentially net out loss of future welfare
if "`net_transfers'"=="yes" local WTP_post_tax_p = `WTP_post_tax_p' -`pdv_welfare'
//Potentially add smoking benefits
if "`include_smoking'"=="yes" local WTP_post_tax_p = `WTP_post_tax_p' + `smoking_benefits'

*Parents and relatives also have willingness to pay from savings - note that we
*assume to be conservative that additional maternal earnings are due to changes 
*in labor supply and thus are not valued:
local WTP_post_tax_m = `parent_savings' + `relatives_savings'

*Sum mother and participant benefits
local WTP_post_tax_p_m = `WTP_post_tax_p' + `WTP_post_tax_m'

*Participant, mother and descendent willingness to pay adds the impact of the earnings of descendents
local WTP_post_tax_all = `WTP_post_tax_p_m' + `descen_aft_tax_ben'

*Set WTP:
if "`abeced_beneficiary'" == "participants" {
	if "`wtp_valuation'"== "post tax" 					local WTP = `WTP_post_tax_p'
	if "`wtp_valuation'"== "reduction private spending" local WTP = 0
	if "`wtp_valuation'"== "cost" 						local WTP = `program_cost' -`govt_savings'
}

if "`abeced_beneficiary'" == "partic_mom" {
	if "`wtp_valuation'"== "post tax" 					local WTP = `WTP_post_tax_p_m'
	if "`wtp_valuation'"== "reduction private spending" local WTP = `parent_savings' + `relatives_savings'
	if "`wtp_valuation'"== "cost" 						local WTP = `program_cost' -`govt_savings'
}

if "`abeced_beneficiary'" == "all" {
	if "`wtp_valuation'"== "post tax" 					local WTP = `WTP_post_tax_all'
	if "`wtp_valuation'"== "reduction private spending" local WTP = `parent_savings' + `relatives_savings'
	if "`wtp_valuation'"== "cost"						local WTP = `program_cost' -`govt_savings'
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
deflate_to 2015, from(`usd_year_inc')

global inc_stat_`1' = `control_mean_earn'*r(deflator)
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `usd_year_inc'
global inc_age_stat_`1' = `income_effect_age'

global inc_benef_`1' = `control_mean_earn'*r(deflator)
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `usd_year_inc'
global inc_age_benef_`1' = `income_effect_age'
