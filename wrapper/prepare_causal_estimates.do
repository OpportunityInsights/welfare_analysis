********************************************************************************
*						PREPARE CAUSAL ESTIMATES							   *
********************************************************************************
set matsize 2000
* Set file paths
global welfare_dropbox "${welfare_files}"
global assumptions "${welfare_files}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global data_derived "${welfare_files}/Data/derived"
global output "${welfare_files}/Data/derived"
global input_data "${welfare_files}/data/inputs"
global causal_ests_uncorrected "${input_data}/causal_estimates/uncorrected"
global causal_ests_corrected "${input_data}/causal_estimates/corrected"
global causal_draws_uncorrected "${input_data}/causal_estimates/uncorrected/draws"

*Set options
local replications 1000
local correlation 1

*-------------------------------------------------------------------------------
*	0. Define programs to run for
*-------------------------------------------------------------------------------

local files : dir "${causal_ests_uncorrected}" files "*.csv"
foreach file in `files' {
	local cleanfile = subinstr("`file'",".csv","",.)
	local all_functioning_programs `all_functioning_programs' `cleanfile'
}

di "`all_functioning_programs'"

local programs `all_functioning_programs'

*Allow file to be ran externally from metafile
if "`1'"!="" { // file is being run externally
	if "`1'"=="all_programs" local programs `all_functioning_programs'
	else local programs "`1'"
}

*Set the seed to the value defined in the metafile
confirm number ${welfare_seed}
set seed ${welfare_seed}

*Loop over programs
foreach program in `programs' {

set seed ${welfare_seed}

*check if draws exist
cap confirm file "${causal_draws_uncorrected}/`program'.dta"
if _rc==0 & "${redraw_causal_estimates}"!="yes" {
	di in red "Skipping redrawing for `program'"
	continue
	}

*Skip non-standard files not meant to be drawn from
if regexm("`program'","combined_kid_")|strpos("`program'","kid_")==1 continue

capture {

noi di "`program' "
qui {
import delimited "${causal_ests_uncorrected}/`program'.csv", clear
sort estimate

*Get SE from t-stat
replace se = abs( pe / t_stat ) if se==. & t_stat!=.

*Get SE from ci range (Assumed to be 95% CI)
replace se = ((ci_hi - ci_lo)/2)/invnormal(0.975) if se==. & ci_lo!=. & ci_hi!=.

*Allow for p-value ranges
cap tostring p_value, replace force
g p_value_range = p_value if regexm(p_value,"\[")|regexm(p_value,"\]")
replace p_value="" if p_value_range!=""
destring p_value, replace force
replace se = abs(pe / invnormal(p_value/2)) if p_value_range=="" & se==.
g p_val_low = strtrim(substr(p_value_range,strpos(p_value_range,"[")+1,strpos(p_value_range,";")-strpos(p_value_range,"[")-1)) if p_value_range!=""
g p_val_high = strtrim(substr(p_value_range,strpos(p_value_range,";")+1,strpos(p_value_range,"]")-strpos(p_value_range,";")-1)) if p_value_range!=""
destring p_val_low p_val_high, replace

*Get PE matrix
mkmat pe, matrix(pes)

*Get correlation matrix
/*Here blocks are indicated by different base numbers and the sign determines
the correlation direction. E.g. if we have four variable with corr_directions
1, -1, 2, 2 respectively, then 1 and 2 are negatively correlated, 3 and 4 are
positively correlated, and 1 and 2 are uncorrelated with 3 and 4.*/
matrix corr = J(`=_N', `=_N', 0)
local namelist
forval j = 1/`=_N' {
	local name_`j' = estimate[`j']
	forval k = 1/`=_N' {
		if `j' == `k' matrix corr[`j',`k'] = 1
		else {
			if abs(corr_direction[`j'])==abs(corr_direction[`k']) {
				matrix corr[`j', `k'] = sign(corr_direction[`j']*corr_direction[`k'])*`correlation'
			}
			else matrix corr[`j',`k'] = 0
		}
	}
	local namelist `namelist' `name_`j''
}

*Loop over replications to get SE matrix (can vary due to p-value ranges)
forval i = 1/`replications' {
	matrix se_`i' = J(`=_N', 1, 0)
	forval j = 1/`=_N' {
		if se[`j']!=. {
			matrix se_`i'[`j',1] = se[`j']
		}
		if se[`j']==. & p_value_range[`j']!="" {
			matrix se_`i'[`j',1] = abs(pe[`j']/invnormal(runiform(p_val_low[`j'],min(p_val_high[`j'],0.9))/2))
		}
	}
}

*Draw uncorrected, save dataset
forval i = 1/`replications' {
	clear
	set obs 1
	drawnorm "`namelist'", n(1) sds(se_`i') corr(corr) means(pes)
	local j = 0
	foreach var in `namelist' {
		local ++j
		g `var'_pe = pes[`j',1]
	}
	tempfile temp`i'
	save `temp`i''
}

forval i = 1/`=`replications'-1' {
	append using `temp`i''
}

g draw_number = _n
order draw_number, first

save "${causal_draws_uncorrected}/`program'.dta", replace

}

} // end of capture

if _rc>0 {
	if _rc==1 continue, break
	local error_progs = "`error_progs'"+"`program'  "
	di as err "`program' broke"
}

}

*Throw errors if things didn't run
if _rc!=1 {
global error_progs = "`error_progs'"
if "`error_progs'"!="" di as err "Finished running but the following programs threw errors: `error_progs'"
else di in red "Finished running with no errors"
}
