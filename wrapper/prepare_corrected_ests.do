********************************************************************************
*						PREPARE CORRECTED ESTIMATES							   *
********************************************************************************
set matsize 2000
* Set file paths
global welfare_dropbox "${welfare_files}"
global assumptions "${welfare_dropbox}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global data_derived "${welfare_dropbox}/Data/derived"
global output "${welfare_dropbox}/Data/derived"
global input_data "${welfare_dropbox}/data/inputs"
global causal_ests_uncorrected "${input_data}/causal_estimates/uncorrected"
global causal_ests_corrected "${input_data}/causal_estimates/corrected"
global causal_draws_uncorrected "${input_data}/causal_estimates/uncorrected/draws"

*Set options
local replications 1000
local correlation 1

local files : dir "${causal_ests_uncorrected}" files "*.csv"
foreach file in `files' {
	local cleanfile = subinstr("`file'",".csv","",.)
	local all_functioning_programs `all_functioning_programs' `cleanfile'
}


local programs `all_functioning_programs'
* append all estimates
clear
tempfile all
save `all', emptyok
*Loop over programs
local i = 0
foreach program in `programs' {
	if strpos("`program'", "combined_kid_") | strpos("`program'", "_names") continue
	local ++i
	di "`program'"
	di `i'
	qui {
	import delimited "${causal_ests_uncorrected}/`program'.csv", clear
	cap ds selection
	if _rc != 0 noi di "`program'"
	g clusterid = `i'
	g program = "`program'"
	local name_`i' = "`program'"
	tostring p_value, replace force
	append using `all'
	save `all', replace
	}
}
local total_prog = `i'

* Estimate model only on baseline sample
preserve
	import excel "${welfare_files}/MVPF_Calculations/Further program details.xlsx", clear first
	replace program = lower(program)
	//keep if main_spec
	g ETI = program
	replace program = substr(program,1, strpos(program,"_")-1) if prog_type == "Top Taxes"
	replace ETI ="ETI_" + subinstr(subinstr(ETI, program, "",.),"_","",.)
	replace program = substr(program,1, 4) if prog_type == "Unemp. Ins."
	replace program = "mto" if strpos(program, "mto")==1
	replace program = "cpc" if strpos(program, "cpc_")

	drop if (inlist(program, "mto")| prog_type == "Top Taxes") & main_spec == 0
	keep program ETI main_spec prog_type earnings_type

	duplicates drop

	tempfile more_details
	save `more_details'
restore
merge m:1 program using `more_details', nogen keep(match) keepusing(main_spec earnings_type ETI prog_type)

* get rid of non baseline ETI estimates
replace main_spec = 0 if prog_type == "Top Taxes" & strpos(estimate, "ETI") & !strpos(estimate, ETI)

* clean p-values if we have a range of p-values
g p_value_range = p_value if (strpos(p_value, "[")|strpos(p_value, "]")) & mi(se) & mi(t_stat) & mi(ci_lo) & mi(ci_hi)
replace p_value = "" if p_value_range !=""

*Get SE from t-stat
replace se = abs(pe / t_stat) if se==. & t_stat!=.

*Get SE from ci range
replace se = abs(((ci_hi - ci_lo)/2)/invnormal(0.975)) if se==. & ci_lo!=. & ci_hi!=.

* get se from p-value if not a range
destring p_value, replace
replace se = abs(pe / invnormal(p_value/2)) if se==.

* save original estimates to re merge later
tempfile original_estimates
save `original_estimates'

********** Now make pub bias corrections ********************
* drop estimates for which we still don't have an se
drop if (se == . | se ==0 | selection == . | selection == 0 | primary_estimate == 0 )

* normalize sign
replace pe = mvpf_effect*pe
g t = pe/se

* make unique identifier
replace estimate = estimate +"_"+ strofreal(clusterid)
cap drop baseline // old flag in csv files
g baseline = 1
* Only do this on baseline sample
replace baseline = 0 if main_spec == 0
replace baseline = 0 if in_baseline == 0 // use only estimates that enter the baseline spec (as well as baseline sample)

g restricted = baseline
replace restricted = 0 if abs(t)>10


* export datasets for matlab
forval i = 0/1 {
	preserve
		keep if kid == `i'
		sort t
		order estimate
		count if baseline
		local count_`i'_baseline = r(N)
		count if restricted
		local count_`i'_restricted = r(N)
		export delimited "${causal_ests_uncorrected}/kid_`i'_names.csv", replace
		g id_num =_n
		tempfile old`i'
		save `old`i''
	restore
}

*Get counts in regions for text
count if t<-1.96 & kid == 1
count if t>1.96 & kid == 1
count if t<-1.96 & kid == 0
count if t>1.96 & kid == 0
di `count_1_baseline'
di `count_1_restricted'
di `count_0_baseline'
di `count_0_restricted'



* run the matlab script, creating folders if they do not already exist
cap mkdir "${causal_ests_corrected}"
cap mkdir "${causal_ests_corrected}/MLE"
forval mode = 1/4 {
	cap mkdir "${causal_ests_corrected}/MLE/mode_`mode'"
}
cd "${welfare_git}/pub_bias"
shell "C:\Program Files\MATLAB\R2018a\bin\matlab.exe" -nodisplay -nosplash -nodesktop -r "selection_welfare('${welfare_git}','${welfare_dropbox}');exit;"

* make sure the script has time to run
noi di as err "Pausing whilst publication bias script runs in Matlab, please wait for it to finish before continuing"
pause on
pause

* import corrected estimates from matlab output and export for programs
tempfile correct
forval mode = 1/4 {
foreach sample in baseline  {
	clear
	save `correct', emptyok replace
	forval i = 0/1 {
		import delimited "${causal_ests_corrected}/MLE/mode_`mode'/MLE_corrected_estimates_kid_`i'_sample_`sample'.csv", clear
		ren v1 corrected_t
		ren v2 t_temp
		g id_num =_n
		merge 1:1 id_num using `old`i'', nogen assert(match)

		corr t t_temp
		assert r(rho)>0.999
		drop t_temp

		g temp_cluster = "_"+ strofreal(clusterid)
		replace estimate = regexr(estimate, temp_cluster, "")

		append using `correct'
		save `correct', replace
	}
	assert mvpf_effect != .
	replace pe = mvpf_effect*pe
	g pe_corrected = mvpf_effect*corrected_t*se
	* merge with old estimates
	merge 1:1 estimate clusterid using `original_estimates'
	assert  (mi(se)|selection == 0 | primary_estimate == 0) if _merge == 2

	assert _merge == 2 if mi(pe_corrected)
	drop _merge
	replace pe_corrected = pe if mi(pe_corrected)
	drop pe
	ren pe_corrected pe

	* export into individual program csv
	levelsof program, local(programs)
	foreach program in `programs' {
		preserve
			keep if program == "`program'"
			keep estimate pe
			export delimited "${causal_ests_corrected}/MLE/mode_`mode'/`program'.csv", replace
		restore
	}
}
}
