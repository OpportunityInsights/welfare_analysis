********************************************************************************
* 	Table of UI MVPFs for appendix
********************************************************************************
pause on
local programs 	ui_e_johnston 	///
				ui_e_katz_meyer ///
				ui_b_card_exp 	///
				ui_b_card_rec  	///
				ui_b_chetty  	///
				ui_b_katz_meyer	///
				ui_b_kroft_noto ///
				ui_b_landais 	///
				ui_b_meyer_hi 	///
				ui_b_solon 		

* Set file paths
global data_derived "${welfare_dropbox}/Data/derived"
global output "${welfare_files}/figtab/Appendix/"

*Pull appendix table specs for each program:
foreach prog in `programs' {
	use  "${welfare_dropbox}/Data/derived/`prog'_normal_unbounded_estimates_1000_replications.dta", clear
	
	*Drop non-table specs and drop extraneous variables:
	keep if strpos(assumptions,"spec_type: table_")>0
	split assumptions, p(",")
	ren assumptions1 spec
	replace spec = subinstr(spec,"spec_type: table_","",.)
	
	*Subtract 1 from all cost figures to get FEs:
	gen FE 		= cost - 1
	gen l_FE 	= l_cost - 1
	gen u_FE 	= u_cost - 1
	
	
	keep program spec MVPF l_MVPF_efron u_MVPF_efron WTP l_WTP u_WTP FE l_FE u_FE 
	order program spec FE l_FE u_FE WTP l_WTP u_WTP MVPF l_MVPF_efron u_MVPF_efron  
	ren *_efron *
	
	*Round estimates and convert to string:
	foreach var of varlist FE l_FE u_FE WTP l_WTP u_WTP MVPF l_MVPF u_MVPF {
		gen `var'_str = string(`var', "%12.2f")		
		drop `var'
		ren `var'_str `var'
	}
	
	*Format confidence interval:
	foreach x in FE WTP MVPF {
		gen CI_`x' = "[" + l_`x' + ", " + u_`x' + "]"
		*replace CI = subinstr(CI,"[-∞","(-∞",.)
		*replace CI = subinstr(CI,"[∞","(+∞",.)	
		*replace CI = subinstr(CI,"-∞]","-∞)",.)
		*replace CI = subinstr(CI,"∞]","+∞)",.)
		drop l_`x' u_`x'
	}
	
	*Reshape:
	foreach x in FE WTP MVPF {
		ren `x' `x'1
		ren CI_`x' `x'2
	}
	reshape long FE WTP MVPF, i(program spec) j(row)
	reshape wide FE WTP MVPF, i(program row) j(spec) str
	ren *DI *_DI
	ren *no_DI *_no_DI
	
	*Format table:
	assert WTP_DI == WTP_no_DI
	drop WTP_DI
	ren WTP_no_DI WTP
	keep 	program FE_no_DI FE_DI WTP MVPF_no_DI MVPF_DI
	order 	program FE_no_DI FE_DI WTP MVPF_no_DI MVPF_DI

	
	*Save estimate files:
	tempfile `prog'
	save ``prog''

}

*Append estimates to form table and export to Excel:
foreach prog in `programs' {
	if "`prog'" == "ui_e_johnston" {
			use ``prog'', clear
	}
	else {
		append using ``prog''
	}
	}
	
export excel "$output/UI.xlsx", sheetrep sheet("stata") first(variables)

