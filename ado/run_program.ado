* Load assumptions and run a welfare program

cap program drop run_program

program define run_program, rclass

syntax anything(name=program id="Program") 

* Set file paths
global assumptions "${welfare_files}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global data_derived "${welfare_files}/Data/derived"
global input_data "${welfare_files}/data/inputs"
global correlation=1

local ado_files : dir "${welfare_git}/ado" files "*.ado"
foreach file in `ado_files' {
	if regexm("`file'","run_program")==0 do "${welfare_git}/ado/`file'"
}
local program = lower("`program'")

* deal with the programs whose assumptions files and or do files have different names
local do_file = "`program'"
local assumption_name = "`program'"
foreach reform in aca13 egtrra01 erta81 obra93 tra86 {
	if strpos(lower("`program'"), "`reform'") & strpos(lower("`program'"), "eitc") == 0{
		local assumption_name `reform'
		local do_file `reform'
		}
}

foreach ui in ui_b ui_e {
	if regexm(lower("`program'"), "^`ui'_") {
		local assumption_name `program'
		local do_file `ui'
	}
}

if regexm("`program'","^mass_hi") local do_file = "mass_hi"

if inlist("`program'","mto_young","mto_old","mto_all") {
	local assumption_name `program'
	local do_file mto
}

foreach type in earnsupp educ jobsearch mixed timelim workexp {
	if strpos("`program'", "wtw_`type'") {
		local assumption_name wtw_`type'
		local do_file wtw_all
		}
}



preserve
	import excel "${welfare_files}/MVPF_Calculations/program_assumptions/default_assumptions.xlsx", clear first
	ds
	foreach assumption in `r(varlist)' {
		global `assumption' = `assumption'[1]
	}
	import excel "${welfare_files}/MVPF_Calculations/program_assumptions/`assumption_name'.xlsx", clear first
	keep if spec_type=="baseline"
	qui count
	assert r(N)==1
	qui ds spec_type, not
	foreach assumption in `r(varlist)'  {
		global `assumption' = `assumption'[1]
	}
restore

if (strpos("`program'", "cpc")) & regexm("`program'","ui")==0 {
	local type_cpc = substr("`program'", strpos("`program'", "_") + 1, .)
	global policy = "`type_cpc'"
	local program = subinstr("`program'", "_`type_cpc'", "",.)
	local do_file = "`program'"
}
global draw_number = 0

do "${welfare_git}/programs/functioning/`do_file'.do" `program' no uncorrected

end
