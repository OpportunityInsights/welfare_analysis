************************************************
/* 0. Program: Massachusetts Health Insurance*/
************************************************

/*Finkelstein, Amy, Nathaniel Hendren, and Mark Shepard. Subsidizing health 
insurance for low-income adults: Evidence from Massachusetts. No. w23668. 
National Bureau of Economic Research, 2017.*/

/*Hendren, Nathaniel. Measuring ex-ante welfare in insurance markets. No. w24470.
 National Bureau of Economic Research, 2018.*/

 
********************************
/* 1. Pull Global Assumptions */
********************************

local uncomp_incidence = "$uncomp_incidence" 
/*Options include "no uncompensated care", "government", "low income uninsured", and "affluent"*/
local ex_ante = "$ex_ante" //"yes" or "no", do we calc ex-ante MVPF from Hendren (2018) 
/*uncomp_incidence must equal "government" if set to "yes"*/
local percent_insured = "$percent_insured" //options are 30p or "90p"


******************************
/* 2. Estimates from Paper */
******************************


*******************************
/* 3. Assumptions from Paper */
*******************************

if $FPL == 150 {
	*This corresponds to 90% insured
	*if "`percent_insured'" == "90p" {
		if "`uncomp_incidence'" == "no uncompensated care"{
			local mvpf_internal_post = .56 //Finkelstein et al. (2017), Figure 14 on pg. 35
		}
		if "`uncomp_incidence'" == "government"{
			local mvpf_internal_post = .80 //Finkelstein et al. (2017), Figure 14 on pg. 35
			local mvpf_internal_ante = .80 //Hendren (2018), Figure 7 on pg. 34
		}
		if "`uncomp_incidence'" == "low income uninsured"{
			local mvpf_internal_post = .86 //Finkelstein et al. (2017), Figure 14 on pg. 35
		}
		if "`uncomp_incidence'" == "affluent"{
			local mvpf_internal_post = .71 //Finkelstein et al. (2017), Figure 14 on pg. 35
		}
	*}
}

if $FPL == 200 {
	*This corresponds to 60% insured, see Figure 11 in Finkelstein et al. (2019)
	*we then take the MVPF for 60% insured from MA_Health_MVPF_table.xlsx in figtab/Appendix
	if "`uncomp_incidence'" == "government"{
		local mvpf_internal_post = 0.847386889
		local mvpf_internal_ante = 0.847386889
	}
}

if $FPL == 250 {
	*This corresponds to 36% insured, see Figure 11 in Finkelstein et al. (2019)
	*we then take MVPFs for 36% insured from MA_Health_MVPF_table.xlsx in figtab/Appendix
	if "`uncomp_incidence'" == "government"{
		local mvpf_internal_post = 1.089454189
		local mvpf_internal_ante = 1.089454189
	}
}

local WTP_marginal = 0 

local avg_age = 44.4 //Finkelstein et al. (2017) table 1
local age_stat = `avg_age'
local age_benef = `avg_age'

local percFPL = 1.93 // Finkelstein et al. (2017) table 1
local fpl_h4_c2_2011 22811 //https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-poverty-thresholds.html

*********************************
/* 4. Intermediate Calculations */
*********************************

local cost_backed_out = 1/`mvpf_internal_post'

if "`ex_ante'" == "no"{
	local WTP_inframarginal = 1
}

if "`ex_ante'" == "yes"{
	local WTP_inframarginal = `mvpf_internal_ante'/`mvpf_internal_post'
}

* get 2015 income
deflate_to 2015, from(2011)
local income_2015 = r(deflator)*`percFPL'*`fpl_h4_c2_2011'
local income_year = 2011

**************************
/* 5. Cost Calculations */
**************************

local total_cost = `cost_backed_out'
local program_cost = 1

*************************
/* 6. WTP Calculations */
*************************

local WTP = `WTP_inframarginal' + `WTP_marginal'

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
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `income_year'
global inc_age_stat_`1' = `age_stat'

global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "household"
global inc_year_benef_`1' = `income_year'
global inc_age_benef_`1' = `age_stat'
