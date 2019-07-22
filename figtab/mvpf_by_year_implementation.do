********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

local corr = 1

global output "${output_root}/scatter"
cap mkdir "$output"

use "${data_derived}/all_programs_baselines_corr_`corr'.dta", clear
drop if ///
	(prog_type == "Top Taxes" & main_spec == 0)
cap drop age
g age =age_benef
ds l_*
foreach var in `r(varlist)' {
	replace `var' = -1 if `var' < -1
}
g year = year_implementation
/*
bys kid_by_era : egen kid_by_era_mean_year = mean(year)
bys kid_by_era : gen plot_mean_here = _n==1
*/
bys kid_by_decade : egen kid_by_decade_mean_year = mean(year)

*-------------------------------------------------------------------------------
*	Scatter all by groups
*-------------------------------------------------------------------------------

sort prog_type

levelsof prog_type, local(types)
local graph_commands = ""
local leg_order = ""
local i = 0
foreach type in `types' {
	if "`type'"=="Welfare Reform" continue
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	label var `no_spaces' "`type'"
	local pos = mod(`i', 12)
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces' year_implementation , ${pe_scatter} mlabsize(vsmall) mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'})) "
	local leg_order = "`leg_order'" + "`i' "
}
local type_max = `i' + 1

tw `graph_commands' ///
	, legend(off) ///
	xtitle("Year") $ylabel $ytitle ///
	$title

graph export "${output}/scatter_mvpf_by_year_implementation.${img}", replace

*------------------------------------------------------------------------------
*	Scatter all by groups with labels
*-------------------------------------------------------------------------------

sort prog_type

levelsof prog_type, local(types)
local graph_commands = ""
local leg_order = ""
local i = 0
foreach type in `types' {
	if "`type'"=="Welfare Reform" continue

	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	cap drop `no_spaces'
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	label var `no_spaces' "`type'"
	local pos = mod(`i', 12)
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces' year_implementation , mlabel(small_label_name) ${pe_scatter} mlabsize(vsmall) mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'})) "
	local leg_order = "`leg_order'" + "`i' "
}
local type_max = `i' + 1

tw `graph_commands' ///
	, legend(off) ///
	xtitle("Year") $ylabel $ytitle ///
	$title

graph export "${output}/scatter_mvpf_by_year_implementation_w_labels.${img}", replace

*-------------------------------------------------------------------------------
*	Scatter Kids v adult policies
*-------------------------------------------------------------------------------

levelsof kid, local(kids)
local graph_commands = ""
local graph_commands2 = ""
local graph_commands3 = ""
local leg_order = ""
local leg_order2 = ""
local i = 0
local label_1 "Child Policies"
local label_2 "Young Adult Policies"
local label_0 "Adult Policies"
qui su era
local last = r(max)
cap destring kid, replace
g diamond_label = "Child Policies" if kid == 1 & inrange(kid_by_decade_mean_year,2000,2010)
replace diamond_label = "Adult Policies" if kid == 0 & inrange(kid_by_decade_mean_year,2010,2020)
bys kid_by_decade : g plot_mean=_n==1
qui su year_implementation if kid == 1
local last_1 = r(max)
qui su year_implementation if kid == 0
local last_0 = r(max)
g dot_label =  "Child Policies" if kid == 1 & year_implementation == `last_1'
replace dot_label =  "Adult Policies" if kid == 0 & year_implementation == `last_0'

*PEs in background
local i = 0
foreach type in `kids' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	cap drop mvpf_`no_spaces'*
	gen mvpf_`no_spaces' = mvpf if (kid == `type')
	label var mvpf_`no_spaces' "`label_`type''"
	local graph_commands = "`graph_commands'" + ///
		" (scatter mvpf_`no_spaces' year_implementation , ${pe_scatter} mstyle(p`i') mfcolor(%70) mlwidth(0) msize(0.8)) "
	local leg_order = "`leg_order'" + "`i' "
}
local type_max = `i' + 1

*Dollar average CI
local i = 0
foreach type in `kids' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	g l_mvpf_`no_spaces'_mean = l_avg_kid_by_decade_mvpf_ef if (kid == `type')
	g u_mvpf_`no_spaces'_mean = u_avg_kid_by_decade_mvpf_ef if (kid == `type')
	local graph_commands2 = "`graph_commands2'" + ///
		" (rcap l_mvpf_`no_spaces'_mean u_mvpf_`no_spaces'_mean kid_by_decade_mean_year if plot_mean , lwidth(0.15)  ${avg_rcap} lstyle(p`i')) "
	local leg_order2 = "`leg_order2'" + "`i' "
}

*Dollar averages
local i = 0
foreach type in `kids' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	local ++i
	gen mvpf_`no_spaces'_mean = avg_kid_by_decade_mvpf if (kid == `type')
	label var mvpf_`no_spaces'_mean "`label_`type''"
	local graph_commands3 = "`graph_commands3'" + ///
		" (scatter mvpf_`no_spaces'_mean kid_by_decade_mean_year if plot_mean , ${avg_scatter}  mstyle(p`i') mlabpos(2) mlabel(diamond_label) mlabstyle(p`i')) "
	local leg_order2 = "`leg_order2'" + "`i' "
}


tw  `graph_commands' ///
	`graph_commands2' ///
	`graph_commands3' ///
	, legend(off) ///
	xtitle("Year") $ylabel ///
	$ytitle ///
	$title yline(6, lcolor(green%50) lwidth(0.15))
graph export "${output}/scatter_mvpf_by_decade_implementation_means_2_groups.${img}", replace

tw  `graph_commands' ///
	`graph_commands3' ///
	, legend(off) ///
	xtitle("Year") $ylabel ///
	$ytitle ///
	$title yline(6, lcolor(green%50) lwidth(0.15))
graph export "${output}/scatter_mvpf_by_decade_implementation_means_2_groups_no_cis.${img}", replace

tw  `graph_commands3' ///
	, legend(off) ///
	xtitle("Year") $ylabel ///
	$ytitle ///
	$title yline(6, lcolor(green%50) lwidth(0.15))
graph export "${output}/scatter_mvpf_by_decade_implementation_means_2_groups_no_cis_no_ind_progs.${img}", replace

tw  `graph_commands2' ///
	`graph_commands3' ///
	, legend(off) ///
	xtitle("Year") $ylabel ///
	$ytitle ///
	$title yline(6, lcolor(green%50) lwidth(0.15))
graph export "${output}/scatter_mvpf_by_decade_implementation_means_2_groups_no_ind_progs.${img}", replace
