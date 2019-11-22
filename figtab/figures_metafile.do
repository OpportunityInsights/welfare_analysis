/*******************************************************************************
			METAFILE FOR WELFARE PAPER FIGURES
********************************************************************************

	This file runs all the figures for the welfare paper.

*******************************************************************************/
* set the version of the figures (paper or slides)
global version slides

*set the file type (png, wmf, or pdf)
if "$version"=="slides" global img wmf
else global img pdf

* file paths
global assumptions "${welfare_files}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global figtab_code = "${welfare_git}/figtab"
global data_derived "${welfare_files}/Data/derived"
global input_data "${welfare_files}/data/inputs"
global output_root "${welfare_files}/figtab/${version}"
global scalartex_out "${welfare_files}/Data/scalartex"
cap mkdir "${output_root}"

* set the scheme and title size
if "${version}" == "slides" {
	set scheme welfare
    global title "title(" ", size(vhuge))"
	global tc = "gs9"
	global img wmf
}
else if "${version}" == "paper" {
	set scheme leap_slides
    global title "title("")"
	global tc = "black"
}

*set group colour styles
global style_Nutrition p1 //
global style_Child_Education p2
global style_College_Adult p3
global style_College_Child p4
global style_Cash_Transfers p5
global style_Welfare_Reform p5
global style_Disability_Ins p6
global style_Health_Adult p7
global style_Health_Child p8
global style_MTO p9
global style_MTO_Young p9
global style_MTO_Teens p9
global style_Housing_Vouchers p10
global style_Job_Training p11
global style_Unemp_Ins p12
global style_Top_Taxes p13
global style_Supp_Sec_Inc p14

* Set colours for figures that don't use default (eg bars)
global basecolour = "79 129 189"
global secondcolour = "192 80 77"
global finalcolour = "155 187 89"


* set formatting globals
global ylabel "ylabel(-1 "<-1" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5" 6 "`=uchar(8734)'")"
global xtitle "xtitle("Age of Beneficiaries")"
global xlabel "xlabel(0(20)80)"
global ytitle "ytitle("MVPF")"

global options "$title $ylabel $ytitle $xtitle $xlabel  yline(6, lcolor(green%50) lwidth(0.15))"

global pe_rcap "lwidth(thin) msize(vsmall) "
global pe_scatter "msize(*0.9)"
global pe_scatter_no_se "msymbol(circle_hollow) msize(*0.6)"
global pe_scatter_lab "mlabel(small_label_name) mlabsize(vsmall)"
global avg_rcap "lwidth(0.15)"
global avg_scatter "msymbol(D)  msize(1.6)"
global avg_scatter_lab "mlabel(prog_type) mlabsize(small)"

if "$version" == "slides" {
	global pe_scatter_lab "mlabel(small_label_name) mlabsize(small)"
	global avg_scatter_lab "mlabel(prog_type) mlabsize(small)"
}

/*******************************************************************************
								MAIN TEXT
*******************************************************************************/

* Figure I - WTP and Cost Components for Admission to Florida International University
*--------------------------------------------------
* A,C - FIU cost/wtp decompositions
qui include "${figtab_code}/wtp_cost_decompositions.do" 
* B- Cost Recovery by Age (FIU costs by age)
qui include "${figtab_code}/costs_by_age.do"

* Figure II - Medicaid WTP and cost decomposition
*--------------------------------------------------
* A,B - Medicaid WTP/Cost decompositions
//qui include "${figtab_code}/wtp_cost_decompositions.do" 

* Figure III - All estimates
*--------------------------------------------------
qui include "${figtab_code}/scatter_mvpf_age_all_estimates.do"

* Figure IV - All estimates (averages/CIs)
*--------------------------------------------------
//qui include "${figtab_code}/scatter_mvpf_age_all_estimates.do"

* Figure V - Normalised costs
*--------------------------------------------------
qui include "${figtab_code}/scatter_cost_over_program_cost.do"

* Figure VI - Robustness - in the same file as figs IV and V
*-----------------------------------------------------------
//qui include "${figtab_code}/scatter_mvpf_age_all_estimates.do"

* Figure VII - Sample restrictions
*--------------------------------------------------
// panel A
//qui include "${figtab_code}/scatter_mvpf_age_all_estimates.do" 
// panels B, C and D
qui include "${figtab_code}/scatter_mvpf_age_all_estimates_restrictions.do" 

* Figure VIII - Publication Bias
*--------------------------------------------------
cap qui include "${figtab_code}/scatter_corrected.do"


* Figure IX and X - MVPF by Income
*--------------------------------------------------
qui include "${figtab_code}/scatter_mvpf_income_cont.do"

* Figure XI - Value of Information
*--------------------------------------------------
qui include "${figtab_code}/scatter_value_info.do"

* Figure XII - Comparison to CBA
*--------------------------------------------------
qui include "${figtab_code}/scatter_mvpf_cba.do"
qui include "${figtab_code}/scatter_cba_age.do"


/********************************************************************************
									APPENDIX
********************************************************************************/

* Figure I - ACS forecast graphs
*--------------------------------------------------
qui include "${figtab_code}/acs_forecasts_graphs.do"


* Figure II - Normalised WTP
*--------------------------------------------------
qui include "${figtab_code}/scatter_wtp_over_program_cost.do"

* Figure III - Robustness to Child Effects
*--------------------------------------------------
qui include "${figtab_code}/bars_kids_vs_not.do"
* Figure IV - Robustness to Alternative Discount Rates
*--------------------------------------------------
//qui include "${figtab_code}/scatter_mvpf_age_all_estimates.do"

* Figure V - Robustness to Alternative Tax Rates
*--------------------------------------------------
//qui include "${figtab_code}/scatter_mvpf_age_all_estimates.do"

* Figure V - MVPFs by Decade
*--------------------------------------------------
qui include "${figtab_code}/mvpf_by_year_implementation.do"

* Figure IV - Welfare Reform
*--------------------------------------------------
qui include "${figtab_code}/scatter_wtw_specs.do"

* In appendix - Coverage simulations form MVPF confidence intervals
*--------------------------------------------------
qui include "${welfare_git}/ci_simulations/grid_w_c.do"
qui include "${welfare_git}/ci_simulations/vary_c_around_zero.do"



/********************************************************************************
									APPENDIX TABLES
********************************************************************************/

* Table 1 
qui include "${welfare_git}/figtab/table_all_programs_studied.do"

* Table 2
qui include "${welfare_git}/figtab/table_all_mvpf_wtp_cost.do"

* Table 3 produced during pub bias estimation

* Tables included directly in appendices:
*Job training
qui include "${welfare_git}/figtab/table_appendix_job_training.do"
*UI
qui include "${welfare_git}/figtab/table_appendix_ui.do"

* College
qui include "${welfare_git}/figtab/table_appendix_college.do"

