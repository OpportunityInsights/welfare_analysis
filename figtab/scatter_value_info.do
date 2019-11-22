********************************************************************************
* Graph value of information estimates
*********************************************************************************
global output "${output_root}/scatter/infovalue"

use "${data_derived}/infovalue/value_of_information_estimates.dta", clear

merge 1:1 program using "${data_derived}/all_programs_baselines_corr_1.dta", nogen assert(using match)

renvars *, lower
g stagger_age = stagger_age_benef

replace prog_type=subinstr(prog_type,"_"," ",.)

levelsof prog_type, local(types)

* Individual estimates
foreach exp in bi bii {
local graph_commands ""
	preserve
	g label_this = small_label_name if  v_experiment`exp'>0.1
	replace v_experiment`exp' = 1 if v_experiment`exp'>1 & v_experiment`exp'!=.
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_max_v = v_experiment`exp' if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_max_v stagger_age ,  ${pe_scatter} ${pe_scatter_lab} mlabel(label_this) mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'}) mlabcolor(gs11)) "		
	}

	tw `graph_commands' ///
		, legend(off) ///
		$xtitle ///
		ytitle("Max WTP for Information ($)") ${xlabel} ///
		$title  ylabel(0(0.25)0.75 1 ">1")

	graph export "${output}/scatter_max_v_age_experiment`exp'.${img}", replace
	restore
}

* Individual estimates with lower cap
foreach exp in bi bii {
local graph_commands ""
	preserve
	g label_this = small_label_name if  v_experiment`exp'>0.02
	replace v_experiment`exp' = 0.4 if v_experiment`exp'>0.4 & v_experiment`exp'!=.
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_max_v = v_experiment`exp' if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_max_v stagger_age ,  ${pe_scatter} ${pe_scatter_lab} mlabel(label_this) mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'}) mlabcolor(gs11)) "		
	}

	tw `graph_commands' ///
		, legend(off) ///
		$xtitle ///
		ytitle("Max WTP for Information ($)") ${xlabel} ///
		$title  ylabel(0(0.1)0.3 0.4 ">0.4")

	graph export "${output}/scatter_max_v_age_experiment`exp'_low_cap.${img}", replace
	restore
}
* domain averages
local graph_commands ""
cap drop plot_mean
bys prog_type: g plot_mean= (_n==1)
replace prog_type = subinstr(prog_type,"_"," ",.)
levelsof prog_type, local(types)
foreach exp in biii biv {
	preserve
			replace v_experiment`exp' = 0.02 if v_experiment`exp'>0.02
			foreach type in `types' {
				local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
				gen `no_spaces'_max_v = v_experiment`exp' if (prog_type == "`type'" & plot_mean == 1)
				local graph_commands = "`graph_commands'" + ///
					" (scatter `no_spaces'_max_v avg_prog_type_age_benef if plot_mean, ${avg_scatter} mlabel(prog_type) mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'})) "		
			}

		tw `graph_commands' ///
			, legend(off) ///
			$xtitle ///
			ytitle("Max WTP for Information ($)") ${xlabel} ///
			$title ylabel(0(0.004)0.016 0.02 ">0.02")
				graph export "${output}/scatter_max_v_age_experiment`exp'_avg.${img}", replace
	restore
}

