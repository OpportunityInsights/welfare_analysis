********************************************************************************
* 	Graph mvpf v income of benef for top tax, eitc and such 
********************************************************************************

* Set file paths
global output "${output_root}/scatter"
cap mkdir "$output"

*Set graph restrictions
local u_cap = 50000
local l_cap = 0

use "${data_derived}/all_programs_baselines_corr_1.dta", clear

/*Add mto
preserve
	use "${data_derived}/all_programs_extendeds_corr_1.dta", clear
	keep if inlist(program,"mto_young","mto_teens")
	tempfile mto
	save `mto'
restore
append using `mto'

*add targetted SNAP + EITC with spillovers
preserve
	use "${data_derived}/snap_intro_normal_unbounded_estimates_1000_replications.dta", clear
	renvars *, lower
	keep if regexm(assumptions,"spec_type: only preschool")
	ren *efron *ef
	replace program = "snap_intro_targetted"
	g small_label_name = "Targetted SNAP"
	g prog_type="Nutrition"
	
	tempfile temp_snap
	save `temp_snap'
	use "${data_derived}/eitc_obra93_normal_unbounded_estimates_1000_replications.dta", clear
	renvars *, lower
	ren *efron *ef
	keep if regexm(assumptions,"wtp_valuation: cost")
	drop if regexm(assumptions,"kid_impact: none")
	g prog_type="Cash Transfers"
	g small_label_name="Alt EITC"

	append using `temp_snap'
	
	*Adjst incomes to be comparable
	*Adjust to common age in lifecycle: 30
	*Use same data as est_life_impact: ACS mean wages by age in 2015
	tempfile new
	save `new'
	use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear

	su age
	global acs_youngest = r(min)
	global acs_oldest = r(max)
	forval age = $acs_youngest / $acs_oldest {
		local index = `age' - 17
		global mean_wage_a`age'_2015 = wag[`index']
	}
	use `new', clear
	foreach type in benef stat {
		replace inc_age_`type' = round(inc_age_`type')
		g inc_age_`type'_15=.
		forval i = ${acs_youngest}/${acs_oldest} {
			replace inc_age_`type'_15=${mean_wage_a`i'_2015} if `i'==inc_age_`type'
		}
	}
	foreach type in benef stat {
		replace inc_`type' = inc_`type'*${mean_wage_a30_2015}/inc_age_`type'_15
		drop inc_age_`type'_15
	}

	*Adjust household towards individual:
	*Article source from census: http://www.aei.org/publication/explaining-us-income-inequality-by-household-demographics-2017-edition-2/
	local avg_eaners = (0.41+0.94+1.37+1.73+2.06)/5 // number of earners by quintile
	di `avg_eaners'

	foreach type in benef stat {
		replace inc_`type' = inc_`type'/`avg_eaners' if inc_type_`type'=="household"
	}
	foreach var in mvpf l_mvpf_ef u_mvpf_ef {
		replace `var' = 2 if `var'>2 & `var'<infinity
		replace `var' = 2.5 if `var'==infinity
		replace `var' = 0.5 if `var'<0.5
	}
	g alt_spec_progs = 1
	foreach var in  inc_stat inc_benef {
		replace `var' = `u_cap' if `var' > `u_cap' & `var' !=.
		replace `var' = `l_cap' if `var' < `l_cap'
		replace `var' = `var'/1000
	}
		g stagger_inc_benef = inc_benef

	tempfile alt_spec_progs
	save `alt_spec_progs'
restore

*/
foreach var in  inc_stat inc_benef {
	replace `var' = `u_cap' if `var' > `u_cap' & `var' !=.
	replace `var' = `l_cap' if `var' < `l_cap'
	replace `var' = `var'/1000
}

local l_mvpf = 0.5
local u_mvpf = 2
ds *mvpf* 
foreach var in `r(varlist)' {
	replace `var' = `l_mvpf' if `var'<`l_mvpf'
	replace `var' = `u_mvpf' if `var'>`u_mvpf' & `var' != 6 & `var' !=.
	replace `var' = `u_mvpf'+0.5 if `var'==6
}

drop if prog_type=="Top Taxes" & inlist(program,"egtrra01_h","erta81_s","obra93_c","aca13_kww","tra86_ac")==0

*Stagger incomes
local stagger_scale = 0.1
foreach var in   inc_stat inc_benef {
	sort `var' program
	by `var' : g obs_n = _n
	by `var' : egen obs_n_mean = mean(obs_n)
	g stagger_`var' = `var' + obs_n*`stagger_scale' if `var'!=.
	drop obs_n obs_n_mean
}
tempfile with_mto_young
save `with_mto_young'

drop if program == "mto_young"

*-------------------------------------------------------------------------------
* First plot just for cash transfers and top tax rates
*-------------------------------------------------------------------------------

cap drop plot 
g plot = inlist(prog_type,"Top Taxes","Cash Transfers")

levelsof prog_type, local(types)
local graph_commands = ""
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	cap drop `no_spaces'
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	label var `no_spaces' "`type'"
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces' stagger_inc_benef if plot, ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabel(small_label_name) mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabcolor(gs11%80) ) " ///
	

}

tw `graph_commands' ///
	, legend(off) ///
	ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
	$ytitle ///
	$title ///
	yline(2.5, lcolor(green%50) lwidth(0.15)) ///
	xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
	xtitle("Approximate Income of Beneficiary") 
	
graph export "${output}/scatter_mvpf_income_taxes_transfers.${img}", replace

*-------------------------------------------------------------------------------
* Add CIs
*-------------------------------------------------------------------------------

cap drop plot 
g plot = inlist(prog_type,"Top Taxes","Cash Transfers")

levelsof prog_type, local(types)
local graph_commands = ""
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	cap drop l_`no_spaces' u_`no_spaces'
	gen l_`no_spaces' = l_mvpf_ef if (prog_type == "`type'")
	gen u_`no_spaces' = u_mvpf_ef if (prog_type == "`type'")
	label var `no_spaces' "`type'"
	local graph_commands = "`graph_commands'" + ///
		" (rcap l_`no_spaces' u_`no_spaces' stagger_inc_benef if plot, ${pe_rcap} lstyle(${style_`no_spaces'})) "
}
foreach type in `types' {
	local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
	cap drop `no_spaces'
	gen `no_spaces' = mvpf if (prog_type == "`type'")
	label var `no_spaces' "`type'"
	local graph_commands = "`graph_commands'" + ///
		" (scatter `no_spaces' stagger_inc_benef if plot, ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabel(small_label_name) mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabsize(small) mlabcolor(gs11%80)) " 
}

tw `graph_commands' ///
	, legend(off) ///
	ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
	$ytitle ///
	$title ///
	yline(2.5, lcolor(green%50) lwidth(0.15)) ///
	xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
	xtitle("Approximate Income of Beneficiary") 

graph export "${output}/scatter_mvpf_income_taxes_transfers_w_cis.${img}", replace


*-------------------------------------------------------------------------------
* Add in kind transfers
*-------------------------------------------------------------------------------

cap drop plot 
cap drop label
g plot = inlist(prog_type,"Top Taxes","Cash Transfers","Nutrition","Housing Vouchers","MTO")
g label =  plot
preserve
	replace small_label_name="" if label==0
	levelsof prog_type, local(types)
	local graph_commands1 = ""
	local graph_commands2 = ""
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop l_`no_spaces' u_`no_spaces'
		gen l_`no_spaces' = l_mvpf_ef if (prog_type == "`type'")
		gen u_`no_spaces' = u_mvpf_ef if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands2 = "`graph_commands2'" + ///
			" (rcap l_`no_spaces' u_`no_spaces' stagger_inc_benef if plot, ${pe_rcap} lstyle(${style_`no_spaces'})) "
	}
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop `no_spaces'
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands1 = "`graph_commands1'" + ///
			" (scatter `no_spaces' stagger_inc_benef if plot, ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabel(small_label_name) mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabsize(small) mlabcolor(gs11%80) ) " ///
		

	}
	tw 	`graph_commands1' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 
	graph export "${output}/scatter_mvpf_income_taxes_transfers_in_kind.${img}", replace

	tw 	`graph_commands1' ///
		`graph_commands2' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 

	graph export "${output}/scatter_mvpf_income_taxes_transfers_in_kind_w_cis.${img}", replace
	
restore



*-------------------------------------------------------------------------------
* Add alt specs for in kind transfers
*-------------------------------------------------------------------------------
//use `with_mto_young', clear
//append using `alt_spec_progs'

cap drop plot 
cap drop label
g plot = inlist(prog_type,"Top Taxes","Cash Transfers","Nutrition","Housing Vouchers","MTO","MTO Young")
g label =  plot
preserve
	replace small_label_name="" if label==0
	levelsof prog_type, local(types)
	local graph_commands1 = ""
	local graph_commands2 = ""
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop l_`no_spaces' u_`no_spaces'
		gen l_`no_spaces' = l_mvpf_ef if (prog_type == "`type'")
		gen u_`no_spaces' = u_mvpf_ef if (prog_type == "`type'")
		//label var `no_spaces' "`type'"
		local graph_commands2 = "`graph_commands2'" + ///
			" (rcap l_`no_spaces' u_`no_spaces' stagger_inc_benef if plot, ${pe_rcap} lstyle(${style_`no_spaces'})) "
	}
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop `no_spaces'
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		//label var `no_spaces' "`type'"
		local graph_commands1 = "`graph_commands1'" + ///
			" (scatter `no_spaces' stagger_inc_benef if plot, ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabel(small_label_name) mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabsize(small) mlabcolor(gs11%80) ) " ///
		

	}
	tw 	`graph_commands1' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 
	graph export "${output}/scatter_mvpf_income_taxes_transfers_in_kind.${img}", replace

	tw 	`graph_commands1' ///
		`graph_commands2' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 

	graph export "${output}/scatter_mvpf_income_taxes_transfers_in_kind_w_alt_specs_and_cis.${img}", replace
restore



*-------------------------------------------------------------------------------
* Add child health college and education programs to eitc+taxes
*-------------------------------------------------------------------------------
//use `with_mto_young', clear
//append using `alt_spec_progs'

cap drop plot 
cap drop label
g plot = inlist(prog_type,"Top Taxes","Cash Transfers","Health Child","Child Education","College Child")
g label =  plot
preserve
	replace small_label_name="" if label==0
	levelsof prog_type, local(types)
	local graph_commands1 = ""
	local graph_commands2 = ""
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop l_`no_spaces' u_`no_spaces'
		gen l_`no_spaces' = l_mvpf_ef if (prog_type == "`type'")
		gen u_`no_spaces' = u_mvpf_ef if (prog_type == "`type'")
		//label var `no_spaces' "`type'"
		local graph_commands2 = "`graph_commands2'" + ///
			" (rcap l_`no_spaces' u_`no_spaces' stagger_inc_benef if plot, ${pe_rcap} lstyle(${style_`no_spaces'})) "
	}
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop `no_spaces'
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		//label var `no_spaces' "`type'"
		local graph_commands1 = "`graph_commands1'" + ///
			" (scatter `no_spaces' stagger_inc_benef if plot, ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabel(small_label_name) mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabsize(small) mlabcolor(gs11%80) ) " ///
		

	}
	tw 	`graph_commands1' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 
	graph export "${output}/scatter_mvpf_income_taxes_transfers_w_child_health_college_educ.${img}", replace

	tw 	`graph_commands1' ///
		`graph_commands2' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 

	graph export "${output}/scatter_mvpf_income_taxes_transfers_w_child_health_college_educ_w_cis.${img}", replace
restore

*-------------------------------------------------------------------------------
* Add all kid policies
*-------------------------------------------------------------------------------
* add MTO young 
use `with_mto_young', clear

 
cap drop plot 
g plot = inlist(prog_type,"Top Taxes","Cash Transfers","Nutrition","Housing Vouchers","MTO")

preserve
	//replace small_label_name = ""
	levelsof prog_type, local(types)
	local graph_commands = ""
	foreach type in `types' {
		local no_spaces = subinstr(subinstr("`type'"," ","_",.),".","",.)
		cap drop `no_spaces'
		gen `no_spaces' = mvpf if (prog_type == "`type'")
		label var `no_spaces' "`type'"
		local graph_commands = "`graph_commands'" + ///
			" (scatter `no_spaces' stagger_inc_benef if plot, ${pe_scatter} ${pe_scatter_lab} mstyle(${style_`no_spaces'}) mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabcolor(gs11%80) ) " ///
		 + 	" (scatter `no_spaces' stagger_inc_benef if age_benef<=23, ${pe_scatter} ${pe_scatter_lab}  mstyle(${style_`no_spaces'})  mlabpos(9) mlabstyle(${style_`no_spaces'}) mlabcolor(gs11%80) ) " ///
	
	}

	tw `graph_commands' ///
		, legend(off) ///
		ylabel(0.5 "<0.5" 1(0.5)1.5 2 ">2" 2.5 "`=uchar(8734)'") ///
		$ytitle ///
		$title ///
		yline(2.5, lcolor(green%50) lwidth(0.15)) ///
		xlabel(0(10)`=`u_cap'/1000' `=`u_cap'/1000' ">`=`u_cap'/1000'K") ///
		xtitle("Approximate Income of Beneficiary") 

	graph export "${output}/scatter_mvpf_income_taxes_transfers_in_kind_w_kids.${img}", replace

restore
