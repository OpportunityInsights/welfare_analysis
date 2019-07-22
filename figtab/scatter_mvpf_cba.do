********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

local modes baseline extended

foreach mode in `modes' {

* Set file paths
if "`mode'"=="baseline" global output "${output_root}/scatter"
else global output "${output_root}/scatter/`mode'"
cap mkdir "$output"
local file_mode `mode'
if inlist("`mode'","fixed_forecast","observed_forecast") local file_mode restricteds_`mode'
if inlist("`mode'","lower_bound_wtp") local file_mode baselines_`mode'

use "${data_derived}/all_programs_`file_mode's_corr_1.dta", clear

drop if prog_type == "Welfare Reform"

*-------------------------------------------------------------------------------
*	Scatter all
*-------------------------------------------------------------------------------


gen to_label = inlist(program,"erta81_s","job_corps","obra93_c","eitc_obra93") | ///
	inlist(program,"perry_pre_school","mc_83","fiu") | ///
	strpos(program,"cpc")==1

drop if prog_type=="Top Taxes" & inlist(program,"obra93_c","erta81_s","egtrra01_h","aca_13_k")==0

*Impose 50% DWL
replace cbr = cbr/1.5

replace cbr = -1 if cbr < -1
preserve
replace label_name = "" if mvpf >=0.7 & mvpf <2
levelsof prog_type, local(types)
local graph_commands = ""
local i = 0
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	cap drop `no_spaces'*
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	gen `no_spaces'_cba = cbr if (prog_type == "`type'")
	label var `no_spaces'_cba "`type'"
	replace `no_spaces'_cba = 5 if `no_spaces'_cba > 5 & `no_spaces'_cba < .
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces'_cba `no_spaces' if to_label==0, msize(vsmall) mstyle(${style_`no_spaces'})) "
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces'_cba `no_spaces' if to_label, msize(vsmall) mstyle(${style_`no_spaces'}) mlabpos(9) mlabcolor(gs11%80) mlabel(small_label_name)) "
}

tw `graph_commands' ///
	, legend(off) ///
	xtitle("MVPF") ///
	xlabel(-1 "<-1" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5" 6 "`=uchar(8734)'") ///
	ylabel(-1 "<-1"  0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	xline(1, lpattern(dash) lcolor(gs8)) ///
	yline(1, lpattern(dash) lcolor(gs8)) ///
	ytitle("BCR") ///
	$title

graph export "${output}/scatter_mvpf_vs_cba_w_labels_50p_dwl.${img}", replace
restore
list program mvpf cbr if inlist(program,"obra93_c","eitc_obra93")

*-------------------------------------------------------------------------------
*	Scatter Category averages
*-------------------------------------------------------------------------------
bys prog_type: g plot_avg = _n==1
levelsof prog_type, local(types)
local graph_commands = ""
local i = 0
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	cap drop `no_spaces'*
	gen `no_spaces' = avg_prog_type_mvpf if (prog_type == "`type'" & plot_avg)
	gen `no_spaces'_cba = avg_prog_type_cbr if (prog_type == "`type'" & plot_avg)
	label var `no_spaces'_cba "`type'"
	replace `no_spaces'_cba = 5 if `no_spaces'_cba > 5 & `no_spaces'_cba != .
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces'_cba `no_spaces', ${avg_scatter} ${avg_scatter_lab} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
}

tw `graph_commands' ///
	, legend(off) ///
	xtitle("MVPF") ///
	xlabel(-1 "<-1" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5" 6 "`=uchar(8734)'") ///
	ylabel(-1 "<-1"  0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	xline(1, lpattern(dash) lcolor(gs8)) ///
	yline(1, lpattern(dash) lcolor(gs8)) ///
	ytitle("BCR") ///
	$title

graph export "${output}/scatter_mvpf_vs_cba_avg_50p_dwl.${img}", replace



exit


*-------------------------------------------------------------------------------
*	Scatter all with separate group colours
*-------------------------------------------------------------------------------
ren *cbr* *cba*

levelsof prog_type, local(types)
local graph_commands = ""
local i = 0
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	gen `no_spaces'_cba = cba if (prog_type == "`type'")
	label var `no_spaces'_cba "`type'"
	replace `no_spaces'_cba = 5 if `no_spaces'_cba > 5 & `no_spaces'_cba < .
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces'_cba `no_spaces' , msymbol(circle_hollow) mstyle(p`i')) "
}

tw `graph_commands' ///
	, legend(off) ///
	xtitle("MVPF") ///
	xlabel(-1 "<-1" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	ylabel(-1 "" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	xline(1, lpattern(dash) lcolor(gs8)) ///
	yline(1, lpattern(dash) lcolor(gs8)) ///
	ytitle("CBA") ///
	title(" ", size(huge))

graph export "${output}/scatter_mvpf_vs_cba.${img}", replace

*-------------------------------------------------------------------------------
*	Separately with labels
*-------------------------------------------------------------------------------

replace label_name = "" if mvpf >=0.7 & mvpf <2
levelsof prog_type, local(types)
local graph_commands = ""
local i = 0
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	cap drop `no_spaces'*
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	gen `no_spaces'_cba = cba if (prog_type == "`type'")
	label var `no_spaces'_cba "`type'"
	replace `no_spaces'_cba = 5 if `no_spaces'_cba > 5 & `no_spaces'_cba < .
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces'_cba `no_spaces' , msymbol(circle_hollow) mstyle(p`i') mlabel(label_name)) "
}

tw `graph_commands' ///
	, legend(off) ///
	xtitle("MVPF") ///
	xlabel(-1 "<-1" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	ylabel(-1 ""  0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	xline(1, lpattern(dash) lcolor(gs8)) ///
	yline(1, lpattern(dash) lcolor(gs8)) ///
	ytitle("CBA") ///
	title(" ", size(huge))

graph export "${output}/scatter_mvpf_vs_cba_w_labels.${img}", replace

*-------------------------------------------------------------------------------
*	Separately with labels for 50%DWL
*-------------------------------------------------------------------------------
replace cba = cba/1.5
replace label_name = "" if mvpf >=0.7 & mvpf <2
levelsof prog_type, local(types)
local graph_commands = ""
local i = 0
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	cap drop `no_spaces'*
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	gen `no_spaces'_cba = cba if (prog_type == "`type'")
	label var `no_spaces'_cba "`type'"
	replace `no_spaces'_cba = 5 if `no_spaces'_cba > 5 & `no_spaces'_cba < .
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces'_cba `no_spaces' , msymbol(circle_hollow) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})  mlabel(label_name) mlabcolor(gs11%80)) "
}

tw `graph_commands' ///
	, legend(off) ///
	xtitle("MVPF") ///
	xlabel(-1 "<-1" 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	ylabel(-1 ""  0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 ">5") ///
	xline(1, lpattern(dash) lcolor(gs8)) ///
	yline(1, lpattern(dash) lcolor(gs8)) ///
	ytitle("CBA") ///
	title(" ", size(huge))

graph export "${output}/scatter_mvpf_vs_cba_w_labels_50p_dwl.${img}", replace

}
