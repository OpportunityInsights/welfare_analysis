*************************************************
/* 0. Program: Alaska Permanent Fund Dividend  */
*************************************************

/*Jones, Damon and Ioana Marinescu. 2018. 
"The Labor Market Impacts of Universal and Permanent Cash Transfers: Evidence 
from the Alaska Permanent Fund." 
NBER Working Paper No. 24312. http://www.nber.org/papers/w24312.

Other papers used for assumptions:

Ackerman, Deena, Janet Holtzblatt, and Karen Masken. 2009. 
“The Pattern of EITC Claims over Time: A Panel Data Analysis.” 
In Conference Paper from IRS RC’09: Internal Revenue Service Research Conference. 
Washington, DC: Department of the Treasury.
*http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.551.7315

Blank, Rebecca M., and Patricia Ruggles. 
"When do women use AFDC & food stamps? The dynamics of eligibility vs. participation."
No. w4429. National Bureau of Economic Research, 1993.
https://www.jstor.org/stable/pdf/146043.pdf

Hotz, V. Joseph and John Karl Scholz. 
"The earned income tax credit." 
In Means-tested transfer programs in the United States, pp. 141-198. 
University of Chicago press, 2003.
http://www.nber.org/chapters/c10256.pdf

Meyer, Bruce D., and Dan T. Rosenbaum. 
"Welfare, the earned income tax credit, and the labor supply of single mothers." 
The quarterly journal of economics 116, no. 3 (2001): 1063-1114.
https://academic.oup.com/qje/article/116/3/1063/1899757

Moffitt, Robert. 
Welfare programs and labor supply. 
No. w9168. National bureau of economic research, 2002.
http://www.nber.org/papers/w9168.pdf
(Data) http://www.econ2.jhu.edu/people/moffitt/datasets.html
*/

/*


* Expand Alaska PFD by $1 p.c.
 
NOTES: We are only considering extensive-margin labor supply responses as part of 
FE (i.e. only effects on employment-population ratio). We further assume that there 
are no migration responses, so all Alaska residents - i.e. everyone receiving 
the benefit - is inframarginal.
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local calc_int_margin = "$calc_int_margin"
local tax_rate = $tax_rate_cont

*********************************
/* 2. Causal Inputs from Paper */
*********************************

/*
*NOTE: Jones and Marinescu 2018 use permutation inference. We assume normality 
*and back out an SE from their reported 95% confidence interval.

*Change in employment rate (Jones and Marinescu (2018), Table 2) 
local epop_effect = 0.001 //
local epop_effect_ci_lo = -0.031
local epop_effect_ci_hi = 0.032
local epop_effect_se = (`epop_effect_ci_hi' - `epop_effect_ci_lo')/(2*invnormal(0.975))

*Change in part-time employment rate (Jones and Marinescu (2018), Table 2) 
local pt_effect = 0.018
local pt_effect_ci_lo = 0.004
local pt_effect_ci_hi = 0.032
local pt_effect_se = (`pt_effect_ci_hi' - `pt_effect_ci_lo')/(2*invnormal(0.975))
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
/* 3. Exact Inputs from Paper  */
*********************************

*APFD amounts for 1982-2014 in nominal dollars (years included in paper)
*From: https://pfd.alaska.gov/Division-Info/Summary-of-Applications-and-Payments
* Accessed 1/29/2019

local apfd_amt_2014 1884
local apfd_amt_2013 900
local apfd_amt_2012 878
local apfd_amt_2011 1174
local apfd_amt_2010 1281
local apfd_amt_2009 1305
local apfd_amt_2008 2069
local apfd_amt_2007 1654
local apfd_amt_2006 1106.96
local apfd_amt_2005 845.76
local apfd_amt_2004 919.84
local apfd_amt_2003 1107.56
local apfd_amt_2002 1540.76
local apfd_amt_2001 1850.28
local apfd_amt_2000 1963.86
local apfd_amt_1999 1769.84
local apfd_amt_1998 1540.88
local apfd_amt_1997 1296.54
local apfd_amt_1996 1130.68
local apfd_amt_1995 990.3
local apfd_amt_1994 983.9
local apfd_amt_1993 949.46
local apfd_amt_1992 915.84
local apfd_amt_1991 931.34
local apfd_amt_1990 952.63
local apfd_amt_1989 873.16
local apfd_amt_1988 826.93
local apfd_amt_1987 708.19
local apfd_amt_1986 556.26
local apfd_amt_1985 404
local apfd_amt_1984 331.29
local apfd_amt_1983 386.15
local apfd_amt_1982 1000

*CPI-U for Urban Alaska (offset by six months since reference years in paper run July-June)
*From: https://www.bls.gov/cpi/regional-resources.htm
*Accessed 1/29/2019
local cpi_ak_1982 97.750
local cpi_ak_1983 101.567
local cpi_ak_1984 104.300
local cpi_ak_1985 107.600
local cpi_ak_1986 107.850
local cpi_ak_1987 108.250
local cpi_ak_1988 109.900
local cpi_ak_1989 114.700
local cpi_ak_1990 121.850
local cpi_ak_1991 126.000
local cpi_ak_1992 130.300
local cpi_ak_1993 133.550
local cpi_ak_1994 137.000
local cpi_ak_1995 140.650
local cpi_ak_1996 143.900
local cpi_ak_1997 146.050
local cpi_ak_1998 147.800
local cpi_ak_1999 149.150
local cpi_ak_2000 153.150
local cpi_ak_2001 156.750
local cpi_ak_2002 160.050
local cpi_ak_2003 164.750
local cpi_ak_2004 168.700
local cpi_ak_2005 175.400
local cpi_ak_2006 178.647
local cpi_ak_2007 185.370
local cpi_ak_2008 190.684
local cpi_ak_2009 194.145
local cpi_ak_2010 197.867
local cpi_ak_2011 203.896
local cpi_ak_2012 208.735
local cpi_ak_2013 214.344
local cpi_ak_2014 216.972
local cpi_ak_2015 216.853
local cpi_ak_2016 218.638
local cpi_ak_2017 221.115

*Annual AK CPI-U average for calendar years 1994 and 1999 (for use in T(y) and T(0)
*adjustments below):
local cpi_ak_cy1994 = 135.0
local cpi_ak_cy1999 = 148.4

*Because Jones and Marinescu do not report effects on earnings, we use the same
*assumptions for T(y) and T(0) for those induced to enter employment by the policy
*as those used in the calculations for EITC MVPFs.
local taxes_if_work_1996 = 79 //Meyer and Rosenbaum (2001) appendix 2
local welfare_if_work_1996 = 1488 //Meyer and Rosenbaum (2001) appendix 2

local welfare_takeup = 0.684 // Blank and Ruggles (1996), Table 1
local monthly_afdc = 373 // https://aspe.hhs.gov/report/welfare-indicators-and-risk-factors-thirteenth-report-congress/afdctanf-program-data
local monthly_snap_pp = 67.95 // https://www.fns.usda.gov/sites/default/files/SNAPsummary.xls
local avg_fam_size = 3 //Meyer and Rosenbaum 2001 show that in 1984 the average single mother has 1.681 children

*U.S. Census Bureau, Real Median Household Income in Alaska
*Retrieved from FRED, Federal Reserve Bank of St. Louis
*https://fred.stlouisfed.org/series/MEHOINUSAKA672N, April 16, 2019
local median_ak_income_1996 = 82374 *(`cpi_ak_2014'/`cpi_ak_2017') 

local per_capita_income_1996 = 26953 * (`cpi_ak_2014'/`cpi_ak_1996') 
*https://fred.stlouisfed.org/series/AKPCPI

*Get ages
local age_stat = 33.5 // https://datausa.io/profile/geo/alaska/ median age in Alaska
local age_benef = `age_stat' //everyone

local usd_year = 2014

*********************************
/* 4. Intermediate Calculations */
*********************************

*Get inflation adjustment factors (doing everything in 2014 program-year dollars):
forval y = 1982/2014 {
	local infl_adj_`y' = `cpi_ak_2014'/`cpi_ak_`y''
}
foreach y in 1994 1999 {
	local infl_adj_cy`y'= `cpi_ak_2014'/`cpi_ak_cy`y''
}

*Average real AFPD payment amount from 1982 to 2014:
local afpd_amt_avg 0
forval y = 1982/2014 {
	local afpd_amt_avg = `afpd_amt_avg' + (`apfd_amt_`y''*`infl_adj_`y'')/(2014-1982+1)
}

* T(0) (cost to the government of an individual out of the labor force)
local T_0_1993 = -`welfare_takeup'*12*(`monthly_afdc' + `avg_fam_size'*`monthly_snap_pp')
* Inflation Adjust:
local T_0 = `T_0_1993'*`infl_adj_1993'

* T(y) (cost to the government of an average individual in the labor force)
local T_y_1996 = `taxes_if_work_1996' - `welfare_if_work_1996'
* Inflation adjust:
local T_y = `T_y_1996'*`infl_adj_1996'

local ext_margin_FE = -(`T_y' - `T_0')*`epop_effect'*(1/`afpd_amt_avg')
di "`ext_margin_FE'"

*If calculating an intensive-margin FE (and thus lower-bound MVPF), assume:
*	i. 	All of the increase in part-time work is due to hours reductions among the 
*		already-employed (as opposed to individuals jumping from nonemployment to 
*		part-time work).
*	ii. For those reducing hours, net effect on government revenue is equal to T(0)
*		(from claiming transfers) plus `tax_rate'% of the average earnings among EITC
*		recipients.
* Assume 50% reduction in earnings
if "`calc_int_margin'" == "yes" {
	local int_margin_FE = `pt_effect' *`tax_rate'*0.5*`median_ak_income_1996'/`afpd_amt_avg'
}
if "`calc_int_margin'" == "no" {
	local int_margin_FE = 0
}

* get income in 2015 usd for wrapper
deflate_to 2015, from(`usd_year')
local income_2015 = `per_capita_income_1996'*r(deflator)

**************************
/* 5. Cost Calculations */
**************************

*Mechanical program cost:
local program_cost = 1

*Totacl cost per mechanical dollar:
local total_cost = `program_cost' + `ext_margin_FE' + `int_margin_FE'
di "`program_cost' + `ext_margin_FE' + `int_margin_FE'"

*************************
/* 6. WTP Calculations */
*************************

local WTP = 1

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

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
global age_stat_`1' = `age_stat'
global age_benef_`1' = `age_benef'

* income globals
global inc_stat_`1' = `income_2015'
global inc_type_stat_`1' = "individual"
global inc_year_stat_`1' = 1996
global inc_age_stat_`1' = `age_stat'


global inc_benef_`1' = `income_2015'
global inc_type_benef_`1' = "individual"
global inc_year_benef_`1' = 1996
global inc_age_benef_`1' = `age_stat'

