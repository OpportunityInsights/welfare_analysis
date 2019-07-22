********************************************************************************
/* Program: MRDC Welfare to Work - All programs except Canadian ones 		  */
********************************************************************************
/* 
 "Greenberg et al.: A Synthesis of Benefit-Cost Studies of Welfare-to-Work Programs" 
 2010
 Journal of Benefit-Cost Analysis
https://www.cambridge.org/core/journals/journal-of-benefit-cost-analysis/article/synthesis-of-random-assignment-benefitcost-studies-of-welfaretowork-programs/9BD56730FB2C30D9B0E78CF62F9AC222

UNPAID WORK EXPERIENCE
FOR WELFARE RECIPIENTS:
Findings and Lessons from MDRC Research
1993
Thomas Brock
David Butler
David Long
https://www.mdrc.org/sites/default/files/full_596.pdf

JOB SEARCH OR
BASIC EDUCATION PARTICIPATION FIRST:
Which Improves Welfare Recipients’ Earnings More
in the Long Term?
Gayle Hamilton and Charles Michalopoulos
2016
https://www.mdrc.org/sites/default/files/NEWWS-final-Web.pdf

The Los Angeles Jobs-First GAIN Evaluation:
Final Report on a Work First Program
in a Major Urban Center
Stephen Freedman
Jean Tansey Knab
Lisa A. Gennetian
David Navarro
2000
https://www.mdrc.org/sites/default/files/full_568.pdf

National Evaluation
of Welfare-to-Work Strategies
How Effective Are Different Welfare-to-Work Approaches?
Five-Year Adult and Child Impacts for Eleven Programs
U.S. Department of Health and Human Services
Administration for Children and Families
Office of the Assistant Secretary for Planning and Evaluation
U.S. Department of Education
Office of the Deputy Secretary
Planning and Evaluation Service
Office of Vocational and Adult Education
December 2001
Prepared by:
Gayle Hamilton
Stephen Freedman
Lisa Gennetian
Charles Michalopoulos
Johanna Walter
Diana Adams-Ciardullo
Anna Gassman-Pines
Manpower Demonstration
Research Corporation
Sharon McGroder
Martha Zaslow
Jennifer Brooks
Surjeet Ahluwalia
Child Trends
With
Electra Small
Bryan Ricchetti
Manpower Demonstration 
https://www.mdrc.org/sites/default/files/full_391.pdf

The GAIN Evaluation
Working Paper 96.1
FIVE-YEAR IMPACTS ON EMPLOYMENT, EARNINGS, AND AFDC RECEIPT
Stephen Freedman, Daniel Friedlander, Winston Lin, and Amanda Schweder 
https://www.mdrc.org/sites/default/files/full_561.pdf
1996

Portland NEWWS:
National Evaluation
of Welfare-to-Work Strategies
How Effective Are Different Welfare-to-Work Approaches?
Five-Year Adult and Child Impacts for Eleven Programs
U.S. Department of Health and Human Services
Administration for Children and Families
Office of the Assistant Secretary for Planning and Evaluation
U.S. Department of Education
Office of the Deputy Secretary
Planning and Evaluation Service
Office of Vocational and Adult Education
December 2001
Prepared by:
Gayle Hamilton
Stephen Freedman
Lisa Gennetian
Charles Michalopoulos
Johanna Walter
Diana Adams-Ciardullo
Anna Gassman-Pines
Manpower Demonstration
Research Corporation
Sharon McGroder
Martha Zaslow
Jennifer Brooks
Surjeet Ahluwalia
Child Trends
With
Electra Small
Bryan Ricchetti
Manpower Demonstration 
https://www.mdrc.org/sites/default/files/full_391.pdf

Florida project independence:
Florida's project independence
Benefits, costs and two-year impacts
of Florida's JOBS program 
James j Kemple
Daniel Friedlander
Veronica Fellerath
1995
https://www.mdrc.org/sites/default/files/florida_project_independence_beefits_costs_fr.pdf

WRP
Final Report on Vermont’s
Welfare Restructuring Project
Susan Scrivener
Richard Hendra
Cindy Redcross
Dan Bloom
Charles Michalopoulos
Johanna Walter
https://www.acf.hhs.gov/sites/default/files/opre/vt_report.pdf
2002


mfip
Reforming Welfare and
Rewarding Work:
Final Report on the
Minnesota Family
Investment Program
Volume 1:
Effects on Adults
Cynthia Miller
Virginia Knox
Lisa A. Gennetian
Martey Dodoo
Jo Anna Hunter
Cindy Redcross
https://www.acf.hhs.gov/sites/default/files/opre/mfip_vol1_adult.pdf
2000

Connecticut Jobs first:
Jobs First
Final Report on
Connecticut’s Welfare Reform Initiative
Dan Bloom
Susan Scrivener 
Charles Michalopoulos 
Pamela Morris 
Richard Hendra 
Diana Adams-Ciardullo 
Johanna Walter
with
Wanda Vargas 
2002
https://www.acf.hhs.gov/sites/default/files/opre/ct_jobsfirst.pdf

Florida FTP :
The Family Transition Program:
Final Report on
Florida’s
Initial Time-Limited Welfare
Program
Dan Bloom
James J. Kemple
Pamela Morris
Susan Scrivener
Nandita Verma
Richard Hendra
with
Diana Adams-Ciardullo
David Seith
Johanna Walter 
https://www.mdrc.org/sites/default/files/final_report_on_ftp_fr.pdf
2000
*/

********************************
/* 1. Pull Global Assumptions */
********************************

local wtp_valuation = "$wtp_valuation"
local wtw_program = subinstr("`1'", "wtw_", "",.)

********************************
/* 2. Estimates from the Paper */
*********************************
* All of these come from Greenberg et al 2010 Appendix Table 1
if "`wtw_program'" == "workexpcc" {
	* Mandatory Work Experience Program, Cook County
	local employment_inc = 280
	local transfers = 405
	local taxes_transfers = 308
	local program_cost = 57
	local other_gvt = 0
	local age_stat = 24*0.26 + 30 * 0.46 + 40*0.21 + 45*0.08 // Brock et al table 6, avg age is missing but give age bin proportions 
}

if "`wtw_program'" == "workexpsd" {
* Mandatory Work Experience Program, San Diego
	local employment_inc = 1133
	local transfers = -804
	local taxes_transfers = -1142
	local program_cost = 140
	local other_gvt = 0
	local age_stat = (33*3596 + 31*3408 )/(3596+3408) // Brock et al table 6
	


}

if "`wtw_program'" == "workexpwv"{
* Mandatory Work Experience Program, West Virginia
	local employment_inc = -206
	local transfers = -151
	local taxes_transfers = -177
	local program_cost = 505
	local other_gvt = 0
	local age_stat = (31*2798+35*3694)/(2798+3694) // Brock et al table 6


} 

if "`wtw_program'" == "jobsearcha"{
* Mandatory Job-Search-First Programs, Atlanta
	local employment_inc = 3236
	local transfers = -3040
	local taxes_transfers = -3878
	local program_cost = 4809
	local other_gvt = 0
	local age_stat = 32.8 // NEWWS report (2001) table 2.3

} 

if "`wtw_program'" == "jobsearchgr"{
* Mandatory Job-Search-First Programs, Grand Rapids
	local employment_inc = 2572
	local transfers = -5301
	local taxes_transfers = -5925
	local program_cost = 2405
	local other_gvt = 0
	
	local age_stat = 28.2 // NEWWS report (2001) table 2.3

} 


if "`wtw_program'" == "jobsearchla"{
* Mandatory Job-Search-First Programs, Los Angeles
	local employment_inc = 5249
	local transfers = -4354
	local taxes_transfers = -4765
	local program_cost = 1721
	local other_gvt = 0

local age_stat = (33.2 * 15683+ 36.2*5048)/(15683+5048) //Freedman et al. (200) Table 1. 4

	} 

if "`wtw_program'" == "jobsearchr"{
* Mandatory Job-Search-First Programs, Riverside
	local employment_inc = 3825
	local transfers = -5211
	local taxes_transfers = -5888
	local program_cost = 4018
	local other_gvt = 0
	local age_stat = 32.0 // NEWWS report (2001) table 2.3

} 

if "`wtw_program'" == "jobsearchsd"{
* Mandatory Job-Search-First Programs, San Diego
	local employment_inc = 3533
	local transfers = -3432
	local taxes_transfers = -3958
	local program_cost = 1692
	local other_gvt = 0
	local age_stat = 31 // Can't find an individual report for the SD site but most ages for other WtW policies in the Greenberg MRDC report are around 31 

} 
if "`wtw_program'" == "educa"{
*Mandatory Education-First Programs, Atlanta
	local employment_inc = 2546
	local transfers = -1977
	local taxes_transfers = -2689
	local program_cost = 6632
	local other_gvt = 0
	
	local age_stat = 32.8 // NEWWS report (2001) table 2.3

} 

if "`wtw_program'" == "educci"{
*Mandatory Education-First Programs, Columbus Integrated
	local employment_inc = 2708
	local transfers = -4513
	local taxes_transfers = -5358
	local program_cost = 5062
	local other_gvt = 0
	
	local age_stat = 31.8 // NEWWS report (2001) table 2.3

} 

if "`wtw_program'" == "educct"{
*Mandatory Education-First Programs, Columbus Traditional
	local employment_inc = 1959
	local transfers = -3263
	local taxes_transfers = -3784
	local program_cost = 4565
	local other_gvt = 0
	local age_stat = 31.8 // NEWWS report (2001) table 2.3

} 

if "`wtw_program'" == "educd"{
*Mandatory Education-First Programs, Detroit
	local employment_inc = 1795
	local transfers = -1478
	local taxes_transfers = -2084
	local program_cost = 2485
	local other_gvt = 0

	local age_stat = 30.0 //NEWWS report (2001) table 2.3

	} 

if "`wtw_program'" == "educgr"{
*Mandatory Education-First Programs, Grand Rapids
	local employment_inc = 1299
	local transfers = -3668
	local taxes_transfers = -4192
	local program_cost = 4566
	local other_gvt = 0
	local age_stat = 28.2 // NEWWS report (2001) table 2.3
	} 

if "`wtw_program'" == "educr"{
*Mandatory Education-First Programs, Riverside
	local employment_inc = 2316
	local transfers = -5888
	local taxes_transfers = -6268
	local program_cost = 5533
	local other_gvt = 0

	local age_stat = 32.0 // NEWWS report (2001) table 2.3

} 


if "`wtw_program'" == "mixedb"{
*Mandatory Mixed-Initial-Activity Programs, Butte GAIN
	local employment_inc = 4972
	local transfers = -2778
	local taxes_transfers = -4146
	local program_cost = 4053
	local other_gvt = 17
	local age_stat = 31 // the GAIN report does not report summary statistics, but all other wtw policies in the MRDC Greenberg reports seem to have partic ages around 31


} 

if "`wtw_program'" == "mixedp"{
*Mandatory Mixed-Initial-Activity Programs, Portland
	local employment_inc = 6793
	local transfers = -7538
	local taxes_transfers = -9804
	local program_cost = 3467
	local other_gvt = 0
	local age_stat = 30.4 // NEWWS report (2001) table 2.3

} 
if "`wtw_program'" == "mixedr"{
*Mandatory Mixed-Initial-Activity Programs, Riverside
	local employment_inc = 7526
	local transfers = -4997
	local taxes_transfers = -6447
	local program_cost = 2229
	local other_gvt = 123
	
	local age_stat = 31 // the GAIN report does not report summary statistics, but all other wtw policies in the MRDC Greenberg reports seem to have partic ages around 31

} 
if "`wtw_program'" == "mixedsd"{
*Mandatory Mixed-Initial-Activity Programs, San Diego
	local employment_inc = 4101
	local transfers = -2869
	local taxes_transfers = -3828
	local program_cost = 2668
	local other_gvt = 91
	
	local age_stat = 31 // the GAIN report does not report summary statistics, but all other wtw policies in the MRDC Greenberg reports seem to have partic ages around 31

} 
if "`wtw_program'" == "mixedt"{
*Mandatory Mixed-Initial-Activity Programs, Tulane
	local employment_inc = 2466
	local transfers = -169
	local taxes_transfers = -565
	local program_cost = 3815
	local other_gvt = -96
	local age_stat = 31 // the GAIN report does not report summary statistics, but all other wtw policies in the MRDC Greenberg reports seem to have partic ages around 31

} 

if "`wtw_program'" == "mixedf"{
*Mandatory Mixed-Initial-Activity Programs, Florida
	local employment_inc = 932
	local transfers = -1481
	local taxes_transfers = -1739
	local program_cost = 1605
	local other_gvt = 33
	
	local age_stat = 32.1 //Florida report (Florida's Project Independence) (1995) table 2.2 on pg. 31
} 

if "`wtw_program'" == "mixeda"{
*Mandatory Mixed-Initial-Activity Programs, Alameda
	local employment_inc = 4062
	local transfers = -2597
	local taxes_transfers = -3606
	local program_cost = 7811
	local other_gvt = 56
	local age_stat = 31 // the GAIN report does not report summary statistics, but all other wtw policies in the MRDC Greenberg reports seem to have partic ages around 31

} 
if "`wtw_program'" == "mixedla"{
*Mandatory Mixed-Initial-Activity Programs, Los Angeles
	local employment_inc = 829
	local transfers = -3030
	local taxes_transfers = -3298
	local program_cost = 8079
	local other_gvt = 22
	
	local age_stat = 31 // the GAIN report does not report summary statistics, but all other wtw policies in the MRDC Greenberg reports seem to have partic ages around 31
} 
if "`wtw_program'" == "earnsuppmfip"{
*Earnings Supplement Programs, MFIP (Minnesota)
	local employment_inc = 1096
	local transfers = 8958
	local taxes_transfers = 11299
	local program_cost = 10958
	local other_gvt = 0
	
	local age_stat = (3208*30.4 + 6009*29.0)/(3208 + 6009) // MFIP report (2000) table 2.2
} 
if "`wtw_program'" == "earnsuppwrp"{
*Earnings Supplement Programs, WRP (Vermont)
	local employment_inc = -218
	local transfers = 448
	local taxes_transfers = 516
	local program_cost = 232
	local other_gvt = -4
	
	local age_stat = 30.8 //WRP Vermont report table 3

} 
if "`wtw_program'" == "timelimf"{
*Time-Limit-Mix Programs, FTP (Florida)
	local employment_inc = 3435
	local transfers = -1744
	local taxes_transfers = -2094
	local program_cost = 10175
	local other_gvt = 46
	
	local age_stat = 29.1 //FTP report table 1.3


} 


if "`wtw_program'" == "timelimc"{
*Time-Limit-Mix Programs, Jobs First (Connecticut)
	local employment_inc = 3570
	local transfers = 1791
	local taxes_transfers = 2385
	local program_cost = 2725
	local other_gvt = 0
	
	local age_stat = 30.7 // Connecticut report table 1.4


} 


if "`wtw_program'" == "timelimv"{
*Time-Limit-Mix Programs, Full WRP (Vermont)
	local employment_inc = 3242
	local transfers = -2086
	local taxes_transfers = -2048
	local program_cost = 1568
	local other_gvt = 78
	
	local age_stat = 30.8 // WRP Vermont report table 3

} 

**************************
/* 5. Cost Calculations */
**************************

if strpos("`wtw_program'", "earnsupp")==0 {
	local total_cost = `program_cost' + `taxes_transfers' + `other_gvt'
}
if strpos("`wtw_program'", "earnsupp") {
	local total_cost = `program_cost' + `other_gvt' // for earnings supp, program costs already include transfers
}
 
*************************
/* 6. WTP Calculations */
*************************

if "`wtp_valuation'" == "post tax" local WTP = `employment_inc' + `transfers' 
else if "`wtp_valuation'" == "cost" local WTP = `program_cost'
else if "`wtp_valuation'" == "transfer change" local WTP = `transfers' 

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
global age_benef_`1' = `age_stat'
