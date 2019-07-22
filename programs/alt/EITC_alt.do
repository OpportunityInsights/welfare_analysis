********************************************
/* 0. Program: EITC Adults - TRA 1986 Eissa & Liebman Estimates */
********************************************
/*
Eissa, Nada, and Jeffrey B. Liebman. 
"Labor supply response to the earned income tax credit." 
The quarterly journal of economics 111, no. 2 (1996): 605-637.
https://academic.oup.com/qje/article/111/2/605/1938452 
Eissa, Nada and Hoynes, Hilary.
"Taxes and the labor market participation of married couples: the earned income 
tax credit."
Journal of Public Economics (2004)
https://gspp.berkeley.edu/assets/uploads/research/pdf/Eissa-Hoynes-JPUBE-2004.pdf
Meyer and Rosenbaum QJE 2001
*/


local bootstrap = "`2'"

********************************
/* 1. Pull Global Assumptions */
*********************************
local spec = "$spec"
*********************************
/* 2. Causal Inputs from Paper */
*********************************
* This section should have EVERY causal effect that we draw upon from the paper, with references to the original paper (Table # or pg.)
if "`spec'" == "EH_slope" {
	local welf_gain_per_dollar  = 1.391 //Eissa and Hoynes (2011) table 7b
}
if "`spec'" == "EH_expansion" {
	local welf_gain_per_dollar  = 1.086 //Eissa and Hoynes (2011) table 7b
}
if "`spec'" == "EKK_1986" {
	local welf_gain_per_dollar  = 3.84 //Eissa Kleven and Kreiner (2008) table 2
}
if "`spec'" == "EKK_1990" {
	local welf_gain_per_dollar  = 2.02 //Eissa Kleven and Kreiner (2008) table 2
}
if "`spec'" == "EKK_1993" {
	local welf_gain_per_dollar  = 1.42 //Eissa Kleven and Kreiner (2008) table 2
}
if "`spec'" == "EKK_2001" {
	local welf_gain_per_dollar  = 1.57 //Eissa Kleven and Kreiner (2008) table 2
}

*Get age
local pct_w_kids = 20810/(20810+46287) //Eissa and Liebman (1996), Table I
local age_kids = 31.17 //Eissa and Liebman (1996), Table I
local age_no_kids = 26.78 //Eissa and Liebman (1996), Table I
local age_stat = `pct_w_kids'*`age_kids' + (1-`pct_w_kids')*`age_no_kids'
local age_benef = `age_stat' // single beneficiary

* Percent of pop in different EITC segments, from Eissa and Hoynes 2002 Table 8
local prop_phasein = 0.088
local prop_flat = 0.06
local prop_phaseout = 0.429
local prop_above = 0.423

* Gross Transfers in different EITC segments - from Eissa and Hoynes 2002 Table 8
local gross_phasein = 1144
local gross_flat = 2424
local gross_phaseout = 1591
local gross_above = 0

* Net transfers in different EITC segments - from Eissa and Hoynes 2002 Table 8
local net_phasein = 1289
local net_flat = 2355
local net_phaseout = 1455
local net_above = -41




*********************************
/* 2.b If bootstrapping replace estimates with their random draw */
*********************************



****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

local frac_married = 0.523 // Liebman 2000 table 6
local tax_rate_marr = 0.15  // 1996 from https://files.taxfoundation.org/legacy/docs/fed_individual_rate_history_nominal.pdf

* 1993 EITC rate in different EITC segments - from https://www.taxpolicycenter.org/sites/default/files/legacy/taxfacts/content/pdf/historical_eitc_parameters.pdf
*note: take max children of 2
local eitc_rate_phasein = -0.4
local eitc_rate_flat = 0
local eitc_rate_phaseout = 0.2106
local eitc_rate_above = 0



*********************************
/* 4. Intermediate Calculations */
*********************************

local FE_single =  1/`welf_gain_per_dollar' - 1

local total_gross = 0 
local total_rev_impact = 0
foreach seg in phasein flat phaseout above {
	local tax_`seg' = `tax_rate_marr' + `eitc_rate_`seg'' 
	local rev_impact_`seg' = (`net_`seg'' - `gross_`seg'')*`tax_`seg''/(1-`tax_`seg'')
	local total_gross = `total_gross' + `gross_`seg''*`prop_`seg''
	local total_rev_impact = `total_rev_impact' + `rev_impact_`seg''*`prop_`seg''
}

local FE_married = -`total_rev_impact'/`total_gross'

* If bootstrapping, redraw the FE now (because we use the earnings impact t-stat for the entire FE. We take the t-stat for married men in table 4 of Eissa and Hoynes (2004)
if "`bootstrap'" == "yes" {
	local FE_married_t = 0.011/0.010
	local FE_married_se = abs(`FE_married'/`FE_married_t')
	local FE_married = rnormal(`FE_married', `FE_married_se')
}




**************************
/* 5. Cost Calculations */
**************************

local program_cost = 1
local total_cost = `program_cost' + `FE_single'*(1 - `frac_married') ///
	+ `frac_married'*`FE_married' 

*************************
/* 6. WTP Calculations */
*************************

local WTP = `program_cost'

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
di `T_0'
di `T_y'
di `lfp_effect'
di `FE_single'
di `FE_married'

global program_cost_`1' = `program_cost'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global MVPF_`1' = `MVPF'
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

