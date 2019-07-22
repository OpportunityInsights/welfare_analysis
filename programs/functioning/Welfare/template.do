****************************************
/* 0. Program: College GPA Threshold Reduction  */
****************************************

*Line that allows bootstrap wrapper to externally toggle the random drawing of
*estimates on or off
local bootstrap = "`2'"

/*
[paper reference (s)]
*/

/*
[Description of thought experiment of marginal policy, e.g. extending a scholarship
to one more student]
*/

********************************
/* 1. Pull Global Assumptions */
********************************

*Only use locals in calculations, pull necessary globals into locals:
local discount_rate = $discount_rate
local tax_rate_assumption = "$tax_rate_assumption" // "continuous"
if "`tax_rate_assumption'" ==  "continuous" {
	local tax_rate = $tax_rate_cont
	local tax_rate_cont = $tax_rate_cont
}
local discount_rate = $discount_rate

local proj_type = "$proj_type" // "fixed forecast" or "growth forecast" or "observed"
local proj_age = $proj_age

local wage_growth_rate = $wage_growth_rate
local wtp_valuation = "$wtp_valuation" // "post tax" or "cost"
local correlation = $correlation
local val_given_marginal = $val_given_marginal // [0,1]

********************************************************************************
/* 2. Estimated Inputs from Paper 											  */
********************************************************************************

*Anything that has standard errors we can then use in simulations:
*Include references to paper inline
*Example:
local policy_effect = [number] // Author pg. ??
local policy_effect_se = [number] // Author pg. ??

********************************************************************************
/* 2.b If bootstrapping replace estimates with their random draw 			  */
********************************************************************************

*Assumes all estimated effects are positively correlated. To achieve negative 
*correlation include names in the negative corr local below

local neg_corr [negatively correlated local names]

*flip signs on negatively correlated items
foreach item in `neg_corr' {
	local `item' = - ``item''
}

*list all estimates stored in locals with SEs
local estimates [all local names that have ses]

preserve
	if "`bootstrap'" == "yes" {
		matrix corr = J(`=wordcount("`estimates'")', `=wordcount("`estimates'")', 0)

		forval i = 1/`=wordcount("`estimates'")' {
			forval j = 1/`=wordcount("`estimates'")' {
				if `i' == `j' matrix corr[`i',`j'] = 1
				else matrix corr[`i', `j'] = `correlation'
			}
		}
		local i = 1
		foreach est in `estimates' {
			if `i' ==1 {
				matrix mean = ``est''
				matrix sd = ``est'_se'
			}
			else {
				matrix sd = sd\(``est'_se')
				matrix mean = mean \ (``est'')
			}
			local ++i
		}
		drawnorm "`estimates'", clear n(1) sds(sd) corr(corr) means(mean)
		foreach est in `estimates' {
			local `est' = `est'[1]
		}
	}
restore

*Flip signs back
foreach item in `neg_corr' {
	local `item' = - ``item''
}

*********************************
/* 3. Exact Inputs from Paper  */
*********************************

*Include here any relevant data, e.g. the dollar year of estimates or the program 
*cost, that don't have standard errors

local usd_year = ??? // author pg. ??

local prog_cost = ??? // author pg. ??

local parent_age = ??? // author pg. ??

local child_age = ??? // author pg. ??

*********************************
/* 4. Intermediate Calculations */
*********************************



**************************
/* 5. Cost Calculations */
**************************

*Estimate program cost
local prog_cost = ??

*Estimate total cost, e.g. program cost net tax receipts etc.
local total_cost = ??

*************************
/* 6. WTP Calculations */
*************************

*estimate WTP of policy
local WTP = ??
local WTP_kid = ??

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

*Determine beneficiary age
local age_stat = `parent_age'
local age_kid = (18+22)/2 // college age kids
local WTP_kid = `total_earn_impact_aftertax'
if `WTP_kid'>`=0.5*`WTP'' local age_benef = `age_kid'
else local age_benef = `parent_age'

****************
/* 8. Outputs */
****************

*display outputs
di `MVPF'
di `WTP'
di `total_cost'
di `program_cost'

*store outputs in local for wrapper
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global WTP_`1' = `WTP'
global age_stat_`1' = `age_stat' // age of statutory beneficiaries
global age_benef_`1' = `age_benef' // age of economic beneficiaries - those with highest WTP

*********************************
/* 9.	    Cost by age    	   */
*********************************

*Where relevant store total cost by age in globals (not done in all programs)

