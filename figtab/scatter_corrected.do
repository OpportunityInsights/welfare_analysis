********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

local modes  corrected_mode_1 corrected_mode_4

* Set label positions
	global pos_Child_Education = "mlabpos(1)"
	global pos_Health_Child = "mlabpos(3)"
	global pos_College_Kids = "mlabpos(3)"
	global pos_Job_Training = "mlabpos(9)"
	global pos_Housing_Vouchers = "mlabpos(9)"
	global pos_UI = "mlabpos(3)"
	global pos_Cash_Transfers = "mlabpos(10)"
	global pos_Nutrition = "mlabpos(3)"
	global pos_DI = "mlabpos(2)"
	global pos_Top_Taxes = "mlabpos(3)"
	global pos_Health_Adult = "mlabpos(3)"
	global pos_College_Adult = "mlabpos(3)"
	global pos_SSI = "mlabpos(3)"

/* Options:
	- 	 corrected_mode_1,2,3,4
*/
foreach mode in `modes' {

* Set file paths
if "`mode'"=="baseline" global output "${output_root}/scatter"
else global output "${output_root}/scatter/`mode'"
cap mkdir "$output"
use "${data_derived}/all_programs_`mode'_corr_1.dta", clear
//assert program_cost >0

g age = age_benef
g stagger_age = stagger_age_benef


replace avg_prog_type_mvpf = -1 if avg_prog_type_mvpf < -1

g plot_indiv = inlist(prog_type, "MTO")
keep if main_spec // only keep "main" specifications
bys prog_type : g plot_avg = _n==1

*-------------------------------------------------------------------------------
*	Point estimates, no CIs
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
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_pes.${img}", replace
			
		}*/
	}

	tw `graph_commands' ///
		, legend(order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs8%0) lcolor(gs8%0))) ///
		$options
		
	if "${version}" == "slides" {
		tw `graph_commands_slides', legend(off) $options
		graph export "${output}/scatter_mvpf_by_age_all_pes.${img}", replace
		tw `graph_commands_slides2', legend(off) $options
		graph export "${output}/scatter_mvpf_by_age_all_pes_nolab.${img}", replace
	}
	
restore

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
	
	}

	tw `graph_commands_slides' ///
		, legend(off) ///
		$options
		
	graph export "${output}/scatter_mvpf_by_age_all_pes_w_labels.${img}", replace
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
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "

		/*if "${version}" == "slides" {
			tw (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces'_mean avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_dollar_avgs_w_cis.${img}", replace
		}*/
	}


	tw `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs.${img}", replace

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

	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab}  ${pos_`no_spaces'} msize(1.6) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "

		/*if "${version}" == "slides" {
			tw (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) ///
			(scatter `no_spaces'_mean avg_prog_type_age_benef if plot_indiv==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} ${pos_`no_spaces'} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})), ///
			legend(off) $options
			graph export "${output}/scatter_mvpf_by_age_`no_spaces'_dollar_avgs_w_cis.${img}", replace
		}*/
	}

	local leg_order = "`leg_order'" + "`i' "


	tw `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs_w_cis_grey_programs_behind.${img}", replace

restore


}
