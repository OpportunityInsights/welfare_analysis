******************************************************************
/* 0. Program: Paycheck Plus */
******************************************************************

/*
Miller, Cynthia, et al.
"Expanding the earned income tax credit for workers without dependent children:
Interim findings from the paycheck plus demonstration in New York City."
New York: MDRC, September (2017).
*/
/*
*WTP*
The avg bonus size is 1399 amongst those who take it, and 45.9% of people take it.
But, 0.9% of those people would not have taken it up had the bonus not been offered
in 2014. Hence, only 45% of the population "value" that transfer, leading to a "WTP"
of 1399*45% = 630. If we asked the control group how much they'd be willing to pay
for Paycheck plus, we'd expect the average to sum up to $630.
Note in 2015, the WTP is 1364 * (34.8 - 2.5) = 441.

*Costs*
Now, turning to costs, we need to know how much more money the government paid
out in terms of EITC, how much less they paid out in other govt programs
(e.g. food stamps), and how much more they got in state/federal tax revenue.
We can consider several cases:

1. Only Paycheck Plus
If the only government outlay were the increased payments from the bonus, then
the cost would simply be 45.9%*1,399 = $642, which would imply an MVPF of 0.98 in 2014.
For 2015, the cost would be 34.8*1364 = $475, implying an MVPF of 0.93.
Combining years, we would have a pooled MVPF of (630+441) / (642+475)=0.96

2. Paycheck Plus + Tax costs
However, we know that those who enter the labor market also get EITC benefits
and they also pay taxes. The paper provides an estimate of after tax income for
the treatment and control group, and an estimate of the earnings in the treatment
and control group. The difference in the impact on earnings relative to the impact
 on after-tax income is the net cost to the government. In 2014, the impact on
 earnings is $33 and the impact on after-tax income is $654. Hence, the impact
 on government costs is $621. This implies an MVPF of 630/621 = 1.01.
For 2015, the cost would be 645-192=453. Hence, the 2015 MVPF is 441/453=0.97.
Combining years, we have an MVPF of (441+630)/(453+621)=0.997.

3. Food stamps / etc
One concern with the approach in part 2 is that we are omitting potential impacts
 from marginal tax rates on other social programs for these folks. To that aim,
 it would be useful to include a marginal tax rate on earnings that corresponds
 to transfer revenue. To that aim, we can use the tax calculator. But, these
 are singles who will be non-representative of the bottom FPL categories. So,
 in this case (and in other EITC examples) we probably don't want to go that route.
 Instead, just for robustness we could do a spec with a 30% marginal tax rate on
 transfers like food stamps. In this case, we reduce the costs to the government
 by 30% * earnings_impact. So, in 2014, this is a reduction in costs of 30%*33=$10;
 this implies an MVPF of 630/611=1.03. In 2015, this is a reduction of costs of
 30%*192=58, this implies an MVPF of 441/395 = 1.12. Pooling, we get an MVPF of
 (630+441)/(611+395)=1.06.
*/
********************************
/* 1. Pull Global Assumptions */
********************************

local transfer_rate = $transfer_rate
local year = "${year}"
local correlation = $correlation
local costs_included = "$costs_included"

******************************
/* 2. Estimates from Paper */
******************************
/*
/*Percentage point increase (relative to control) in any earnings (employed) in 2014*/
local any_earn_y1_itt = .009 // Miller at al 2017, Table 5.1
local any_earn_y1_itt_p = .338 //Miller at al 2017, Table 5.1

/*Percentage point increase (relative to control) in any earnings (employed) in 2015*/
local any_earn_y2_itt = 0.025 // Miller at al 2017, Table 5.1
local any_earn_y2_itt_p = .012 //Miller at al 2017, Table 5.1

/*NOTE: after-bonus earnings =  earnings plus credit amount minus taxes*/

/*Increase(relative to control) in after-bonus earnings value in 2014*/
local after_bonus_y1_itt = 654 //Miller at al 2017, Table 5.1
local after_bonus_y1_itt_p = .001 //Miller at al 2017, Table 5.1

/*Increase(relative to control) in after-bonus earnings value in 2015*/
local after_bonus_y2_itt = 645 //Miller at al 2017, Table 5.1
local after_bonus_y2_itt_p = .015 //Miller at al 2017, Table 5.1

/*Increase (relative to control) in earnings value in 2014*/
local earn_y1_itt = 33 //Miller at al 2017, Table 5.1
local earn_y1_itt_p = .893 //Miller at al 2017, Table 5.1

/*Increase (relative to control) in earnings value in 2015*/
local earn_y2_itt = 192 //Miller at al 2017, Table 5.1
local earn_y2_itt_p = .56 //Miller at al 2017, Table 5.1
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
*********************************
/* 3. Assumptions from Paper */
*********************************

/*Average value of bonus received, among recipients, by year*/
local avg_bonus_y1 = 1399 //Miller at al 2017, Table 4.1
local avg_bonus_y2 = 1364 //Miller at al 2017, Table 4.1

/*Share of bonus recipients in full sample, by year*/
local bonus_receipt_y1 = 0.459 //Miller et al 2017, table 4.1
local bonus_receipt_y2 = 0.348 //Miller et al 2017, table 4.1

*Get age
local age_stat = 35
*This is a rough approximation: in table 3.1 53% are aged 35 and younger.

local age_benef=`age_stat' // single beneficiary

local y_paycheck_plus = 12693 //  2015 fig from Miller at al 2017, Table 5.1.
local year_paycheck_plus = 2015 // Can't find a mention of inflation adjustment so assume 2015 dollars.
**********************************
/* 4. Intermediate Calculations */
**********************************


***************************
/* 5. Cost Calculations */
***************************

/* Define the program cost (by year and pooled) as the bonuses paid to recipients
but excluding those recipients who took up employment as a result of the program. */
local program_cost_y1 = (`bonus_receipt_y1' - `any_earn_y1_itt')*`avg_bonus_y1'
local program_cost_y2 = (`bonus_receipt_y2' - `any_earn_y2_itt')*`avg_bonus_y2'
local program_cost_pooled = `program_cost_y1' + `program_cost_y2'
local program_cost = `program_cost_`year''

/* See beginning of do-file for an explanation regarding the different
costs_included definitions */
if "`costs_included'" == "paycheck_plus" {
	local total_cost_y1  = `bonus_receipt_y1'*`avg_bonus_y1'
	local total_cost_y2  = `bonus_receipt_y2'*`avg_bonus_y2'
}

if "`costs_included'" == "paycheck_plus+taxes" {
	// The difference in the impact on earnings relative to the impact on
	// after-tax income is the net cost to the government.
	local total_cost_y1 = `after_bonus_y1_itt' - `earn_y1_itt'
	local total_cost_y2  = `after_bonus_y2_itt' - `earn_y2_itt'
	}

if "`costs_included'" == "paycheck_plus+taxes+transfers" {
	local total_cost_y1 = `after_bonus_y1_itt' - `earn_y1_itt' -`transfer_rate' * `earn_y1_itt'
	local total_cost_y2 = `after_bonus_y2_itt' - `earn_y2_itt'  -`transfer_rate' * `earn_y2_itt'

}
local total_cost_pooled = `total_cost_y1' + `total_cost_y2'
local total_cost = `total_cost_`year''
*************************
/* 6. WTP Calculations */
*************************
// Remove the people who would not have taken up the bonus without behaviour
// change (envelope theorem). Here, this equals program cost.
local WTP_y1 = `program_cost_y1'
local WTP_y2 = `program_cost_y2'
local WTP_pooled = `program_cost_pooled'
local WTP = `program_cost'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 8. Outputs */
****************

di `bonus_receipt_y1' //*`avg_bonus_y1'
di `program_cost'
di `total_cost'
di `WTP'
di `WTP_y1'
di `WTP_y2'
di `MVPF'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
global inc_stat_`1' = `y_paycheck_plus'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = `year_paycheck_plus'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `y_paycheck_plus'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = `year_paycheck_plus'
global inc_age_benef_`1' = `age_stat'
