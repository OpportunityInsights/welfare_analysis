********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

* Set file paths
global output "${output_root}/scatter/restricted"
cap mkdir "$output"

local modes baseline lower_bound_wtp observed_forecast fixed_forecast  robustness
/* Options
	-	baseline
	-	lower_bound_wtp
	-	fixed_forecast
	-	observed_forecast
	-	robustness
*/

foreach mode in `modes' {

* Set file paths
if "`mode'"=="baseline" global output "${output_root}/scatter"
else global output "${output_root}/scatter/`mode'"
cap mkdir "$output"
local file_mode `mode'
if inlist("`mode'","fixed_forecast","observed_forecast") local file_mode restricteds_`mode'
if inlist("`mode'","lower_bound_wtp","robustness") local file_mode baselines_`mode'

use "${data_derived}/all_programs_`file_mode's_corr_1.dta", clear

foreach restriction in kid_in_baseline years_observed peer_reviewed identification {
	use "${data_derived}/all_programs_`file_mode's_corr_1.dta", clear
	keep if main_spec == 1
	drop if strpos(program, "mto")
	* set label positions
	levelsof prog_type, local(types)
	foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'", " ", "_",.),".","",.)

		global pos_`no_spaces' = "mlabpos(3)"
	}
	if "`restriction'" == "kid_in_baseline" {
		keep if kid_in_baseline == 1
		local groupname kid_obs_by_type
	}

	if "`restriction'" == "years_observed" {
		drop if substr(hi_obs_prog,strlen(hi_obs_prog),1) == "0"
		local groupname hi_obs_prog
		* for this one graph ONLY, have dollar spend averages for single policies
		bys hi_obs_prog: g count_group = _N

		replace avg_hi_obs_prog_mvpf = mvpf if count_group == 1 & has_ses ==1 & p_val_rang == 0 
		replace l_avg_hi_obs_prog_mvpf_ef = l_mvpf_ef if count_group == 1 & has_ses ==1 & p_val_rang == 0 
		replace u_avg_hi_obs_prog_mvpf_ef = u_mvpf_ef if count_group == 1 & has_ses ==1 & p_val_rang == 0 
		replace avg_hi_obs_prog_age_benef = age_benef if count_group == 1 & has_ses ==1 & p_val_rang == 0 
		
		global pos_Cash_Transfers = "mlabpos(10)"
		global pos_Job_Training = "mlabpos(9)"
		global pos_Nutrition = "mlabpos(4)"



	}


	if "`restriction'" == "peer_reviewed" {
		keep if peer_reviewed == "y"
		local groupname peer_by_type
		global pos_Cash_Transfers = "mlabpos(10)"
		global pos_Child_Education = "mlabpos(1)"

		global pos_Housing_Vouchers = "mlabpos(9)"
		global pos_SSI = "mlabpos(10)"
		global pos_Nutrition = "mlabpos(2)"
		global pos_Job_Training = "mlabpos(9)"

	}
	if "`restriction'" == "identification" {
		keep if RCT_lottery_RD == "y"
		local groupname rct_by_type
		global pos_Housing_Vouchers = "mlabpos(10)"
		global pos_Job_Training = "mlabpos(9)"

	}

	ds l_*
	foreach var in `r(varlist)' {
		replace `var' = -1 if `var' < -1
	}
	cap drop age
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

	bys prog_type : gen plot_avg = _n==1
	if "`restriction'" == "years_observed" {
		replace plot_avg = 1 if count_group == 1 & has_ses ==1 & p_val_rang == 0 

		}
	*-------------------------------------------------------------------------------
	*	Point estimates - no prior taxes/eitc, dollar spend avgs, no CIs
	*-------------------------------------------------------------------------------

	local i=0

	preserve
		local graph_commands = ""
		local graph_commands2 = ""

		local leg_order = ""
		levelsof prog_type, local(types)

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
				" (scatter `no_spaces' stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'})) "
				* version with labels
			local graph_commands2 = "`graph_commands2'" + ///
				" (scatter `no_spaces' stagger_age , ${pe_scatter} ${pe_scatter_lab} mlabcolor(gs11%80) mlabstyle(${style_`no_spaces'})  mstyle(${style_`no_spaces'})) "
			local leg_order = "`leg_order'" + "`i' "
		}

		tw `graph_commands' ///
			, legend(off) ///
			${options}

		graph export "${output}/scatter_mvpf_by_age_all_pes_`restriction'.${img}", replace

		tw `graph_commands2' ///
			, legend(off) ///
			${options}

		graph export "${output}/scatter_mvpf_by_age_all_pes_`restriction'_w_labels.${img}", replace
	restore

	*-------------------------------------------------------------------------------
	*	Point estimates - no prior taxes/eitc, dollar spend avgs, with CIs
	*-------------------------------------------------------------------------------

	local i=0

	preserve
		local graph_commands = ""
		local leg_order = ""
		levelsof prog_type, local(types)

		levelsof prog_type, local(types)

		*point CIs
		local j=0
		foreach type in `types' {
			local ++j
			local ++i
			local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
			cap drop `no_spaces'*

			gen `no_spaces'_ci_l = l_mvpf_ef if (prog_type == "`type'")
			gen `no_spaces'_ci_u = u_mvpf_ef if (prog_type == "`type'")

			local graph_commands = "`graph_commands'" + ///
				" (rcap `no_spaces'_ci_l `no_spaces'_ci_u stagger_age, ${pe_rcap} lstyle(${style_`no_spaces'})) "
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
				" (scatter `no_spaces' stagger_age , ${pe_scatter} ${pe_scatter_lab} mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'})) "
			local leg_order = "`leg_order'" + "`i' "
		}

		tw `graph_commands' ///
			, legend(order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs8%0) lcolor(gs8%0))) ///
			legend(off) $options

		graph export "${output}/scatter_mvpf_by_age_all_pes_w_cis_`restriction'.${img}", replace
	restore

//if "`restriction'" == "kid_in_baseline" continue //no dollar avgs for these
*-------------------------------------------------------------------------------
*	Dollar spend avgs only except taxes/eitc
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)


	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_`groupname'_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_`groupname'_age_benef  if plot_avg, ${avg_scatter} ${avg_scatter_lab} mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
	}

	tw `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs_`restriction'.${img}", replace

restore


*-------------------------------------------------------------------------------
*	Dollar spend avgs only except taxes/eitc (w CIs)
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local graph_commands2 = ""

	local leg_order = ""
	levelsof prog_type, local(types)


	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands2 = "`graph_commands2'" + ///
			" (scatter `no_spaces' stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'}) mfcolor(%65) mlwidth(0) msize(0.8)) "
		local leg_order = "`leg_order'" + "`i' "
	}

	*add dollar_spend CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)

		gen `no_spaces'_dollar_ci_l = l_avg_`groupname'_mvpf_ef if (prog_type == "`type'")
		gen `no_spaces'_dollar_ci_u = u_avg_`groupname'_mvpf_ef if (prog_type == "`type'")

		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_`groupname'_age_benef if plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) "
	}

	*Group dollar spend mvpf dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_`groupname'_mvpf if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_`groupname'_age_benef if  plot_avg, ${avg_scatter} ${pos_`no_spaces'} ${avg_scatter_lab} mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
	}

	tw `graph_commands' ///
		, legend(off) ///
		$options
	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs_w_cis_`restriction'.${img}", replace

		tw  `graph_commands2' `graph_commands' ///
		, legend(off) ///
		$options

	graph export "${output}/scatter_mvpf_by_age_all_dollar_avgs_w_cis_grey_programs_behind_`restriction'.${img}", replace

restore
}
}
