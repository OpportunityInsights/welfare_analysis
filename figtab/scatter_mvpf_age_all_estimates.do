********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

local modes baseline robustness observed_forecast restricted lower_bound_wtp fixed_forecast  
/* Options:
	-	baseline
	-	lower_bound_wtp
	-	fixed_forecast
	-	observed_forecast
	-	corrected
	-	robustness
*/

foreach mode in `modes' {
* Set label positions
* make sure default is at 3
	global pos_Child_Education = "mlabpos(3)"
	global pos_Health_Child = "mlabpos(3)"
	global pos_College_Kids = "mlabpos(3)"
	global pos_Job_Training = "mlabpos(3)"
	global pos_Housing_Vouchers = "mlabpos(3)"
	global pos_UI = "mlabpos(3)"
	global pos_Cash_Transfers = "mlabpos(3)"
	global pos_Nutrition = "mlabpos(3)"
	global pos_DI = "mlabpos(3)"
	global pos_Top_Taxes = "mlabpos(3)"
	global pos_Health_Adult = "mlabpos(3)"
	global pos_College_Adult = "mlabpos(3)"
	global pos_SSI = "mlabpos(3)"

if "`mode'" == "baseline"{
	global pos_Child_Education = "mlabpos(2) mlabgap(*0.5)"
	global pos_Health_Child = "mlabpos(4) mlabgap(*0.5)"
	global pos_College_Kids = "mlabpos(4) mlabgap(*0.5)"
	global pos_Job_Training = "mlabpos(8) mlabgap(*0.5)"
	global pos_Housing_Vouchers = "mlabpos(9)"
	global pos_UI = "mlabpos(3)"
	global pos_Cash_Transfers = "mlabpos(11)"
	global pos_Nutrition = "mlabpos(3)"
	global pos_DI = "mlabpos(1)"
	global pos_Top_Taxes = "mlabpos(3)"
	global pos_Health_Adult = "mlabpos(3)"
	global pos_College_Adult = "mlabpos(3)"
	global pos_SSI = "mlabpos(2)"
}
else if "`mode'" == "robustness"{
	global pos_Child_Education = "mlabpos(1)"
	global pos_Health_Child = "mlabpos(3)"
	global pos_College_Kids = "mlabpos(3)"
	global pos_Job_Training = "mlabpos(8)"
	global pos_Housing_Vouchers = "mlabpos(10)"
	global pos_UI = "mlabpos(3)"
	global pos_Cash_Transfers = "mlabpos(11)"
	global pos_Nutrition = "mlabpos(3)"
	global pos_DI = "mlabpos(2)"
	global pos_Top_Taxes = "mlabpos(3)"
	global pos_Health_Adult = "mlabpos(3)"
	global pos_College_Adult = "mlabpos(1)"
	global pos_SSI = "mlabpos(2)"

}

else if "`mode'" == "fixed_forecast"{
	global pos_Job_Training = "mlabpos(9)"
	global pos_UI = "mlabpos(3)"
	global pos_Cash_Transfers = "mlabpos(10)"
	global pos_DI = "mlabpos(9)"

}

if "`mode'" == "lower_bound_wtp"{
	global pos_Health_Child = "mlabpos(9)"
	global pos_Housing_Vouchers = "mlabpos(9)"
	global pos_Cash_Transfers = "mlabpos(10)"
	global pos_DI = "mlabpos(9)"
	global pos_Health_Adult = "mlabpos(9)"
}
if "`mode'" == "restricted"{
	global pos_Job_Training = "mlabpos(9)"
	global pos_Cash_Transfers = "mlabpos(9)"
	global pos_DI = "mlabpos(9)"


}
* Set file paths
if "`mode'"=="baseline" global output "${output_root}/scatter"
else global output "${output_root}/scatter/`mode'"
cap mkdir "$output"
local file_mode `mode'
if inlist("`mode'","fixed_forecast","observed_forecast") local file_mode restricteds_`mode'
if inlist("`mode'","lower_bound_wtp","robustness") local file_mode baselines_`mode'

use "${data_derived}/all_programs_`file_mode's_corr_1.dta", clear

assert program_cost >0

g age = age_benef
g stagger_age = stagger_age_benef

ds l_*
foreach var in `r(varlist)' {
	replace `var' = -1 if `var' < -1
}
replace avg_prog_type_mvpf = -1 if avg_prog_type_mvpf < -1

keep if main_spec // only keep "main" specifications

if "`mode'"=="robustness" {
	levelsof robust_spec, local(robust_specs)
	local spec_var robust_spec
	local nspec=0
	foreach spec in `robust_specs' {
		local ++nspec
		local name_`nspec' = "`spec'"
	}
}
else local nspec 1
tempfile base
save `base'
forval z = 1/`nspec' {
if `nspec'>1 {
	use `base', clear
	keep if `spec_var'=="`name_`z''"
	local save_mod="_"+subinstr(subinstr(subinstr("`name_`z''"," ","_",.),".","_",.),":","",.)
}
else local save_mod = ""
*-------------------------------------------------------------------------------
*	Point estimates, no CIs
*-------------------------------------------------------------------------------
bys prog_type : g plot_avg = _n==1

local i=0
preserve
	local graph_commands
	local graph_commands_slides
	local graph_commands_slides2
	local leg_order
	levelsof prog_type, local(types)

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"

		* exclude wtw from combined graph
		if "`no_spaces'" != "Welfare_Reform" {
			local ++i
			local ++j
			local graph_commands = "`graph_commands'" + ///
				" (scatter `no_spaces' stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'})) "
			local graph_commands_slides = "`graph_commands_slides'" + ///
				" (scatter `no_spaces' stagger_age , ${pe_scatter} ${pe_scatter_lab} mlabsize(vsmall) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
			local graph_commands_slides2 = "`graph_commands_slides2'" + ///
			" (scatter `no_spaces' stagger_age , ${pe_scatter} mlabsize(vsmall) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
		}

		* For slides export the scatters by category
		/*if "${version}" == "slides"  {
			tw (scatter `no_spaces' stagger_age , ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			di "`no_spaces'"
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_pes`save_mod'.${img}", replace
		}*/
	}

	tw `graph_commands' ///
		, legend(order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs11%0) lcolor(gs11%0))) ///
		$options

	if "${version}" == "slides" {
		tw `graph_commands_slides', legend(off) $options
		graph export "${output}/scatter_mvpf_by_age_all_pes`save_mod'.${img}", replace
		tw `graph_commands_slides2', legend(off) $options
		graph export "${output}/scatter_mvpf_by_age_all_pes_nolab`save_mod'.${img}", replace
	}

restore

*-------------------------------------------------------------------------------
*	Slides calling out specific programs
*-------------------------------------------------------------------------------
if "${version}" == "slides" {
	* call out job corps and ssi review
	tw (scatter mvpf stagger_age if program != "job_corps" & program != "ssi_review", ${pe_scatter} mcolor(gs11) ) ///
		(scatter mvpf stagger_age if program == "job_corps", ${pe_scatter} ${pe_scatter_lab} mlabsize(vsmall) mlabcolor(gs11) mstyle(${style_Job_Training})) ///
		(scatter mvpf stagger_age if program == "ssi_review", ${pe_scatter} ${pe_scatter_lab} mlabsize(vsmall) mlabcolor(gs11) mstyle(${style_Supp_Sec_Inc})) ///
		,legend(off) $options

	graph export "${output}/scatter_mvpf_by_age_all_pes_callout_job_corps_ssi`save_mod'.${img}", replace

	* call out Top Tax 1981
	tw (scatter mvpf stagger_age if program != "erta81_s", ${pe_scatter} mcolor(gs11) ) ///
		(scatter mvpf stagger_age if program == "erta81_s", ${pe_scatter} ${pe_scatter_lab} mlabsize(vsmall) mlabcolor(gs11) mstyle(${style_Top_Taxes})) ///
		(rcap l_mvpf_ef u_mvpf_ef stagger_age if program == "erta81_s", lstyle(${style_Top_Taxes}) ${pe_rcap} lwidth(0.05)) ///
		,legend(off) $options

	graph export "${output}/scatter_mvpf_by_age_all_pes_callout_ERTA81`save_mod'.${img}", replace

		* call out MTO
	tw (scatter mvpf stagger_age if program != "mto_all", ${pe_scatter} mcolor(gs11) ) ///
		(scatter mvpf stagger_age if program == "mto_all", ${pe_scatter} ${pe_scatter_lab} mlabsize(vsmall) mlabcolor(gs11) mstyle(${style_MTO})) ///
		,legend(off) $options

	graph export "${output}/scatter_mvpf_by_age_all_pes_callout_MTO`save_mod'.${img}", replace


}
*-------------------------------------------------------------------------------
*	Point estimates with labels
*-------------------------------------------------------------------------------

local i=0
preserve
	local graph_commands
	local graph_commands_slides
	local graph_commands_slides2
	local leg_order
	levelsof prog_type, local(types)

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr(subinstr("`type'"," ","_",.),".","",.),".","",.)
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"

		* exclude wtw from combined graph
		if "`no_spaces'" != "Welfare_Reform" {
			local ++i
			local ++j
			local graph_commands = "`graph_commands'" + ///
				" (scatter `no_spaces' stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'})) "
			local graph_commands_slides = "`graph_commands_slides'" + ///
				" (scatter `no_spaces' stagger_age , ${pe_scatter} ${pe_scatter_lab} mlabsize(vsmall) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'}) mlabcolor(gs11%80)) "
			local graph_commands_slides2 = "`graph_commands_slides2'" + ///
			" (scatter `no_spaces' stagger_age , ${pe_scatter} mlabsize(vsmall) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
		}

	}

if "$version" == "slides" { // add legend manually to avoid jiggle in the slides
		tw `graph_commands_slides' ///
		, legend( off) ///
		$options
}
else { 
		tw `graph_commands_slides' ///
		, legend( order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs11%0) lcolor(gs11%0))) ///
		$options
}
	graph export "${output}/scatter_mvpf_by_age_all_pes_w_labels`save_mod'.${img}", replace

restore

*-------------------------------------------------------------------------------
*	Point estimates, with CIs
*-------------------------------------------------------------------------------

local i=0
preserve
	local graph_commands
	local leg_order
	levelsof prog_type, local(types)

	*point CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr(subinstr("`type'"," ","_",.),".","",.),".","",.)
		cap drop `no_spaces'*

		gen `no_spaces'_ci_l = l_mvpf_ef if (prog_type == "`type'")
		gen `no_spaces'_ci_u = u_mvpf_ef if (prog_type == "`type'")

		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_ci_l `no_spaces'_ci_u stagger_age, lstyle(${style_`no_spaces'}) ${pe_rcap} lwidth(0.05)) "
	}

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age if has_ses == 1, ${pe_scatter} mstyle(${style_`no_spaces'})) "
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age if has_ses == 0, ${pe_scatter_no_se} mstyle(${style_`no_spaces'})) "
		local leg_order = "`leg_order'" + "`i' "

		* For slides export the scatters by category
		/*if "${version}" == "slides" {
			tw (rcap `no_spaces'_ci_l `no_spaces'_ci_u stagger_age, lstyle(${style_`no_spaces'}) ${pe_rcap}) ///
			(scatter `no_spaces' stagger_age if has_ses == 1, ${pe_scatter} mstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces' stagger_age if has_ses == 0, ${pe_scatter_no_se} mstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_pes_w_cis`save_mod'.${img}", replace
		}*/

	}

	tw `graph_commands' ///
		, legend(off order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs11%0) lcolor(gs11%0))) ///
		$options

	if "$version" == "slides" {
		tw `graph_commands' ///
			, legend(off) ///
			$options
	}
	graph export "${output}/scatter_mvpf_by_age_all_pes_w_cis`save_mod'.${img}", replace
restore

*-------------------------------------------------------------------------------
*	Dollar spend avgs only
*-------------------------------------------------------------------------------

local i=0
preserve
	local graph_commands
	local leg_order
	levelsof prog_type, local(types)

	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr(subinstr("`type'"," ","_",.),".","",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if plot_avg, ${avg_scatter} ${pos_`no_spaces'} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "

		if 0 /*"${version}" == "slides" */{
			tw (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces'_mean avg_prog_type_age_benef if plot_avg, ${avg_scatter} ${pos_`no_spaces'} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_dollar_avgs_w_cis`save_mod'.${img}", replace
		}
	}


	tw `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs`save_mod'.${img}", replace

restore

*-------------------------------------------------------------------------------
*	Dollar spend avgs only (w CIs)
*-------------------------------------------------------------------------------

local i=0
preserve
	local graph_commands
	local leg_order
	levelsof prog_type, local(types)

	*add dollar_spend CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr(subinstr("`type'"," ","_",.),".","",.),".","",.)

		gen `no_spaces'_dollar_ci_l = l_avg_prog_type_mvpf_ef if (prog_type == "`type'")
		gen `no_spaces'_dollar_ci_u = u_avg_prog_type_mvpf_ef if (prog_type == "`type'")

		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) "
	}

	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr(subinstr("`type'"," ","_",.),".","",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if  plot_avg, ${avg_scatter} ${avg_scatter_lab} ${pos_`no_spaces'} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "

		/*if "${version}" == "slides" {
			tw (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if  plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces'_mean avg_prog_type_age_benef if plot_avg, ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_dollar_avgs_w_cis`save_mod'.${img}", replace
		}*/
	}


	tw `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs_w_cis`save_mod'.${img}", replace

restore

*-------------------------------------------------------------------------------
*	Everything stacked
*-------------------------------------------------------------------------------

local i=0
preserve
	local graph_commands
	local leg_order
	levelsof prog_type, local(types)

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'}) mfcolor(%65) mlwidth(0) msize(0.8)) "
		local leg_order = "`leg_order'" + "`i' "
	}

	*add dollar_spend CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)

		gen `no_spaces'_dollar_ci_l = l_avg_prog_type_mvpf_ef if (prog_type == "`type'")
		gen `no_spaces'_dollar_ci_u = u_avg_prog_type_mvpf_ef if (prog_type == "`type'")

		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if  plot_avg, lwidth(0.15)  ${avg_rcap} lstyle(${style_`no_spaces'})) "
	}

	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if plot_avg, ${avg_scatter} ${avg_scatter_lab} ${pos_`no_spaces'} msize(1.6) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "

		if 0 /*"${version}" == "slides" */{
			tw (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces'_mean avg_prog_type_age_benef if  plot_avg, ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_dollar_avgs_w_cis`save_mod'.${img}", replace
		}
	}

	local leg_order = "`leg_order'" + "`i' "


	tw `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs_w_cis_grey_programs_behind`save_mod'.${img}", replace

restore


/*
*-------------------------------------------------------------------------------
*	Dollar spend avgs only (w CIs and icv weighting)
*-------------------------------------------------------------------------------
local i=0
preserve
	keep if main_spec
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)
	replace avg_prog_type_mvpf_icv = -1 if avg_prog_type_mvpf_icv < -1
	*add point CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop `no_spaces'*
		gen `no_spaces'_ci_l = l_mvpf_ef if (prog_type == "`type'")
		gen `no_spaces'_ci_u = u_mvpf_ef if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_ci_l `no_spaces'_ci_u age_benef if plot_indiv, ${rcap_pe} lstyle(${style_`no_spaces'})) "
	}
	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' age_benef if  plot_indiv, ${pe_scatter} ${pe_scatter_lab} mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'})) "
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' age_benef if  plot_indiv==0, ${pe_scatter} msize(tiny) mcolor(gs8%50)) "
		local leg_order = "`leg_order'" + "`i' "
	}
	*add dollar_spend CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_dollar_ci_l = l_avg_prog_type_mvpf_icv_ef if (prog_type == "`type'")
		gen `no_spaces'_dollar_ci_u = u_avg_prog_type_mvpf_icv_ef if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) "
	}
	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_mvpf_icv if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
		if "${version}" == "slides" {
			tw (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces'_mean avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_icv_by_age_`no_spaces'_dollar_avgs_w_cis.${img}", replace
		}
	}
	tw `graph_commands' ///
		, legend(off) ///
		$options
	graph export "${output}/scatter_mvpf_icv_by_age_all_dollar_avgs_w_cis.${img}", replace
restore
*/
}
}
