********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

local modes baseline lower_bound_wtp
/* Options:
	-	baseline
	-	lower_bound_wtp
	-	fixed_forecast
	- 	corrected
*/

* Set label positions
global pos_Child_Education = "mlabpos(3)"
global pos_Health_Child = "mlabpos(3)"
global pos_College_Kids = "mlabpos(3)"
global pos_Job_Training = "mlabpos(3)"
global pos_Housing_Vouchers = "mlabpos(9)"
global pos_UI = "mlabpos(3)"
global pos_Cash_Transfers = "mlabpos(2)"
global pos_Nutrition = "mlabpos(3)"
global pos_DI = "mlabpos(3)"
global pos_Top_Taxes = "mlabpos(3)"
global pos_Health_Adult = "mlabpos(3)"
global pos_College_Adult = "mlabpos(3)"
global pos_SSI = "mlabpos(3)"


foreach mode in `modes' {

* Set file paths
if "`mode'"=="baseline" global output "${output_root}/scatter"
else global output "${output_root}/scatter/`mode'"
cap mkdir "$output"
local file_mode `mode'
if inlist("`mode'","fixed_forecast","observed_forecast") local file_mode restricteds_`mode'
if inlist("`mode'","lower_bound_wtp") local file_mode baselines_`mode'

use "${data_derived}/all_programs_`file_mode's_corr_1.dta", clear

cap g w_on_pc = wtp / program_cost
g age = age_benef 

*Set up age stagger for when needed
local stagger_scale 0.8
set seed 503198
gen stagger_rand = rnormal()
sort prog_type age stagger_rand
by prog_type age : gen stagger_num = _n
by prog_type age : egen stagger_mean = mean(stagger_num)
gen stagger = (stagger_num - stagger_mean) * `stagger_scale'
gen stagger_age = age + stagger

*-------------------------------------------------------------------------------
*	Scatter all
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)
	
	replace w_on_pc = -1 if w_on_pc<-1
	replace w_on_pc = 5 if w_on_pc>5
	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = w_on_pc if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age , $pe_scatter  mstyle(${style_`no_spaces'})) "
		local leg_order = "`leg_order'" + "`i' "
	}

	tw `graph_commands' ///
		, legend(off) ///
		$xtitle ylabel(-1 "<-1" 0(1)4 5 ">5") ///
		$xlabel ///
		ytitle("WTP Over Program Cost") ///
		$title
		
	graph export "${output}/scatter_wtp_over_program_cost_all.${img}", replace

restore

*-------------------------------------------------------------------------------
*	Scatter dollar spend averages with CIs
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)
	
	ds *w_on_pc*
	foreach var in `r(varlist)' {
		replace `var' = -1 if `var' <-1
		replace `var' = 5 if `var' > 5 & `var' != .
	}
	
	cap drop plot_mean
	bys prog_type : gen plot_mean = _n==1
	
	*CIs
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen l_`no_spaces' = l_avg_prog_type_w_on_pc_ef if (prog_type == "`type'")
		gen u_`no_spaces' = u_avg_prog_type_w_on_pc_ef if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (rcap l_`no_spaces' u_`no_spaces' avg_prog_type_age_benef if plot_mean , ${avg_rcap} lstyle(${style_`no_spaces'})) "
		local leg_order = "`leg_order'" + "`i' "
	}	
	
	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces'_pe = w_on_pc if (prog_type == "`type'")
		label var `no_spaces'_pe "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_pe stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'}) mfcolor(%65) mlwidth(0) msize(0.8)) "
		local leg_order = "`leg_order'" + "`i' "
	}

	*Dollar spend averages
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		if "`type'"=="MTO" continue
		gen `no_spaces' = avg_prog_type_w_on_pc if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' avg_prog_type_age_benef if plot_mean, ${avg_scatter} ${avg_scatter_lab} ${pos_`no_spaces'} mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'})) "
		local leg_order = "`leg_order'" + "`i' "
	}

	tw `graph_commands' ///
		, legend(off) ///
		$xtitle ylabel(-1 "<-1" 0(1)4 5 ">5") ///
		$xlabel ///
		ytitle("WTP Over Program Cost") ///
		$title
		
	graph export "${output}/scatter_wtp_over_program_cost_dollar_spend_avgs_w_cis.${img}", replace
restore


}
