********************************************************************************
* 	Scatter CBA vs age
********************************************************************************

* Set file paths
global output "${output_root}/scatter"
cap mkdir "$output"


* Set label positions
	global pos_Child_Education = "mlabpos(3)"
	global pos_Health_Child = "mlabpos(3)"
	global pos_College_Kids = "mlabpos(3)"
	global pos_Job_Training = "mlabpos(9)"
	global pos_Housing_Vouchers = "mlabpos(10)"
	global pos_UI = "mlabpos(3)"
	global pos_Cash_Transfers = "mlabpos(11)  mlabgap(*3)"
	global pos_Nutrition = "mlabpos(3)"
	global pos_DI = "mlabpos(11)"
	global pos_Top_Taxes = "mlabpos(3)"
	global pos_Health_Adult = "mlabpos(3)"
	global pos_College_Adult = "mlabpos(3)"
	global pos_SSI = "mlabpos(3)"



use "${data_derived}/all_programs_baselines_corr_1.dta", clear
g age = age_benef
g stagger_age = stagger_age_benef
ds l_* 

g tax_or_eitc = inlist(prog_type,"EITC","Top Taxes")
bys prog_type : gen plot_avg = _n==1

ds *cbr*
foreach var in `r(varlist)' {
	replace `var' = `var' / 1.5 // add DWL

	replace `var' = 10 if `var'>10 & `var'!=.

	replace `var' = -1 if `var'<-1 & `var'!=.
}


*-------------------------------------------------------------------------------
*	Point estimates - no prior taxes/eitc, dollar spend avgs, no CIs
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)

	*Only keep paycheck plus and 1993 EITC within that category
	keep if prog_type!="EITC"|(program=="paycheck_plus"|program=="meyer_eitc")

	*Only keep 1993 tax cuts
	keep if prog_type!="Top Taxes"|(program=="tax_obra_93")

	levelsof prog_type, local(types)

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = cbr if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age , ${pe_scatter} mstyle(${style_`no_spaces'})) "
		local leg_order = "`leg_order'" + "`i' "
	}

	tw `graph_commands' ///
		, legend(order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs8%0) lcolor(gs8%0))) ///
		$xtitle $xlabel ylabel(-1 "<-1" 0(2)8 10 ">10") ///
		ytitle("BCR") ///
		$title

	graph export "${output}/scatter_cbr_by_age_all_pes.${img}", replace
restore


*-------------------------------------------------------------------------------
*	Point estimates - no prior taxes/eitc, dollar spend avgs, with CIs
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)

	*Only keep paycheck plus and 1993 EITC within that category
	keep if prog_type!="Cash Transfers"|(program=="paycheck_plus"|program=="meyer_eitc")

	*Only keep 1993 tax cuts
	keep if prog_type!="Top Taxes"|(program=="tax_obra_93")

	levelsof prog_type, local(types)

	*point CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop `no_spaces'*

		gen `no_spaces'_ci_l = l_cbr_ef if (prog_type == "`type'")
		gen `no_spaces'_ci_u = u_cbr_ef if (prog_type == "`type'")

		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_ci_l `no_spaces'_ci_u stagger_age if has_ses == 1, ${pe_rcap} lstyle(${style_`no_spaces'})) "
	}

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++j
		local ++i
		gen `no_spaces' = cbr if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		if strpos("`no_spaces'", "MTO") label var `no_spaces' MTO
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age if has_ses == 1, ${pe_scatter} mstyle(${style_`no_spaces'})) "
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age if has_ses == 0, ${pe_scatter_no_se} mstyle(${style_`no_spaces'})) "
		if "`type'" != "MTO Teens" local leg_order = "`leg_order'" + "`i' "
		local ++i
	}

	tw `graph_commands' ///
		, legend(order(`leg_order') size(vsmall) ring(0) pos(2) cols(1) region(fcolor(gs8%0) lcolor(gs8%0))) ///
		$xtitle $xlabel ylabel(-1 "<-1" 0(2)8 10 ">10") ///
		ytitle("BCR") ///
		$title

	graph export "${output}/scatter_cbr_by_age_all_pes_w_cis.${img}", replace
restore

*-------------------------------------------------------------------------------
*	Dollar spend avgs only except taxes/eitc
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)

	*Only keep paycheck plus and 1993 EITC within that category
	keep if prog_type!="EITC"|(program=="paycheck_plus"|program=="meyer_eitc")

	*Only keep 1993 tax cuts
	keep if prog_type!="Top Taxes"|(program=="tax_obra_93")

	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = cbr if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age if tax_or_eitc, msymbol(circle_hollow) mlabel(label_name) mlabstyle(${style_`no_spaces'})  mstyle(${style_`no_spaces'})) "
		local leg_order = "`leg_order'" + "`i' "
	}

	*Group dollar spend cbr dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_cbr if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if tax_or_eitc==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} mlabstyle(${style_`no_spaces'}) mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
	}

	tw `graph_commands' ///
		, legend(off) ///
		$xtitle $xlabel ylabel(-1 "<-1" 0(2)8 10 ">10") ///
		ytitle("BCR") ///
		$title

	graph export "${output}/scatter_cbr_by_age_all_dollar_avgs.${img}", replace

restore


*-------------------------------------------------------------------------------
*	Dollar spend avgs  (w CIs)
*-------------------------------------------------------------------------------

local i=0

preserve
	local graph_commands = ""
	local leg_order = ""
	levelsof prog_type, local(types)

	*Only keep paycheck plus and 1993 EITC within that category
	g plot_indiv= prog_type=="MTO"
	
	*Program dots
	local j = 0
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		local ++i
		local ++j
		gen `no_spaces' = cbr if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_age,  ${pe_scatter} mstyle(${style_`no_spaces'}) mfcolor(%65) mlwidth(0) msize(0.8)) "
		local leg_order = "`leg_order'" + "`i' "
	}
	*add dollar_spend CIs
	local j=0
	foreach type in `types' {
		local ++j
		local ++i
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)

		gen `no_spaces'_dollar_ci_l = l_avg_prog_type_cbr_ef if (prog_type == "`type'")
		gen `no_spaces'_dollar_ci_u = u_avg_prog_type_cbr_ef if (prog_type == "`type'")

		local graph_commands = "`graph_commands'" + ///
			" (rcap `no_spaces'_dollar_ci_l `no_spaces'_dollar_ci_u avg_prog_type_age_benef if tax_or_eitc==0 & plot_avg, ${avg_rcap} lstyle(${style_`no_spaces'})) "
	}


	*Group dollar spend cbr dots
	local j = 0
	foreach type in `types' {
		local ++i
		local ++j
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		gen `no_spaces'_mean = avg_prog_type_cbr if (prog_type == "`type'")
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces'_mean avg_prog_type_age_benef if tax_or_eitc==0 & plot_avg, ${avg_scatter} ${avg_scatter_lab} ${pos_`no_spaces'} mstyle(${style_`no_spaces'}) mlabstyle(${style_`no_spaces'})) "
	}

	tw `graph_commands' ///
		, legend(off) ///
		$xlabel ///
		$xtitle ylabel(-1 "<-1" 0(2)8 10 ">10") ///
		ytitle("BCR") ///
		$title

	graph export "${output}/scatter_cbr_by_age_all_dollar_avgs_w_cis.${img}", replace

restore
