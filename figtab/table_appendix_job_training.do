********************************************************************************
* 	Table of job training estimates by projection length for appendix
********************************************************************************
pause on
local programs jtpa_adult jtpa_youth work_advance yearup jobstart nsw_adult_women nsw_youth job_corps

* Set file paths
global data_derived "${welfare_dropbox}/Data/derived"
global output "${welfare_files}/figtab/Appendix"
cap mkdir "${welfare_files}/figtab"
cap mkdir "$output"

*Pull appendix table specs for each program:
foreach prog in `programs' {
	use  "${welfare_dropbox}/Data/derived/`prog'_normal_unbounded_estimates_1000_replications.dta", clear
	
	*Drop non-table specs and drop extraneous variables:
	keep if strpos(assumptions,"spec_type: table_")>0
	split assumptions, p(",")
	ren assumptions1 spec
	replace spec = subinstr(spec,"spec_type: table_","",.)
	
	*Drop cases where there is both negative WTP and negative cost:
	foreach var of varlist MVPF l_MVPF_efron u_MVPF_efron {
		replace `var' = . if WTP<0 & cost<0
	}
	keep program MVPF l_MVPF_efron u_MVPF_efron spec
	
	
	*Round estimates and convert to string:
	foreach var of varlist MVPF l_MVPF_efron u_MVPF_efron {
		gen `var'_str = string(`var', "%12.2f")		
		replace `var'_str = "+∞" if `var'_str == "99999.00"
		replace `var'_str = "-∞" if `var'_str == "-99999.00"		
		drop `var'
		ren `var'_str `var'
	}
	
	*Format confidence interval:
	gen CI = "[" + l_MVPF_efron + ", " + u_MVPF_efron + "]"
	*replace CI = subinstr(CI,"[-∞","(-∞",.)
	*replace CI = subinstr(CI,"[∞","(+∞",.)	
	*replace CI = subinstr(CI,"-∞]","-∞)",.)
	*replace CI = subinstr(CI,"∞]","+∞)",.)
	drop l_MVPF_efron u_MVPF_efron
	
	*Reshape:
	ren MVPF MVPF1
	ren CI MVPF2
	reshape long MVPF, i(program spec) j(row)
	reshape wide MVPF, i(program row) j(spec) str
	ren MVPF* _*
	
	*Drop selected estimates (because observed program length is longer 
	*than projection length in question)
	if inlist("`prog'","jtpa_adult", "jtpa_youth","work_advance", "yearup", "jobstart") {
		local  droplist ""
	}
	if inlist("`prog'","nsw_adult_women", "nsw_youth") {
		local droplist "_30mo"
	}
	if inlist("`prog'","job_corps") {
		local droplist "_30mo _8yr"
	}
	foreach drop in `droplist' {
		foreach var of varlist `drop'* {
			replace `var' = "-" in 1
			replace `var' = "" in 2
		}
	}
	
	*Save estimate files:
	foreach wtp in post_tax cost {
		preserve
		keep program *`wtp'
		order program _30mo _8yr _21yr _age65
		tempfile `prog'_`wtp'
		save ``prog'_`wtp''
		restore
	}
}

*Append estimates to form table and export to Excel:
foreach wtp in post_tax cost {
	foreach prog in `programs' {
		if "`prog'" == "jtpa_adult" {
			use ``prog'_`wtp'', clear
		}
		else {
			append using ``prog'_`wtp''
		}
	}
	
	export excel "$output/Job_Training.xlsx", sheetrep sheet("stata_`wtp'") first(variables)
}
