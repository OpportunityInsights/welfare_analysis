********************************************************************************
* 	Table of College MVPFs for appendix
********************************************************************************

use "${welfare_files}/data/derived/all_programs_extendeds_corr_1_unbounded_averages.dta", clear
tempfile extendeds
save `extendeds'

levelsof program if regexm(prog_type,"College"), local(coll_progs)

clear
tempfile base
save `base', emptyok
foreach prog in `coll_progs' {
	use "${welfare_files}/data/derived/`prog'_normal_unbounded_estimates_1000_replications.dta", clear
	keep if regexm(assumptions,"spec_type: baseline")| regexm(assumptions,"spec_type: alt_spec_")
	cap g program = "`prog'"
	append using `base'
	save `base', replace
}
