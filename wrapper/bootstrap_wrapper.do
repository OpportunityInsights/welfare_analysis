********************************************************************************
*								BOOTSTRAP WRAPPER							   *
********************************************************************************
set matsize 2000

* Set file paths
global welfare_git "${github}/Welfare"
global welfare_dropbox "${welfare_files}"
global assumptions "${welfare_dropbox}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global data_derived "${welfare_dropbox}/Data/derived"
global output "${welfare_dropbox}/Data/derived"
global input_data "${welfare_dropbox}/data/inputs"

*Set options
local debug = 0 // 1 noisily displays running .do files

*Set modes
local modes all //lower_bound_wtp baselines fixed_forecast robustness normal //lower_bound_wtp fixed_forecast robustness_pe

/*
Note: modes can contain any of the following:
- baselines: only runs the baseline specification
- lower_bound_wtp: only runs the lower bound wtp specification
- fixed_forecast: baseline but with a fixed forwards earnings forecast
- observed_forecast: doesn't project past ages at which earnings are observed
- corrected_mode_k - estimates baseline with corrected estimates from specification k in {1,2,3,4}
- costs_by_age: runs baseline with different interest rates and makes age files
- robustness: runs baseline and varies discount and tax rate
- robustness_pe: runs baseline and varies discount and tax rate but doesn't bootstrap
- normal: runs all specifications as in the program assumptions file
- all: all except robustness_pe

Corrected estimates modes:
1 - skip estimating betap and assume kid estimates abs(t)>1.64 are 34.48x more
2 - estimate break at +/-1.64 on all estimates
3 - estimate break at +/-1.96 on all estimates
4 - estimate breaks at +/-1.64 and +/-1.96 on all estimates
*/
*Set modes if running externally
if "`2'"!="" local modes "`2'"

*Set all
if "`modes'"=="all" local modes baselines costs_by_age lower_bound_wtp fixed_forecast observed_forecast ///
						corrected_mode_1 corrected_mode_4 robustness normal

*Set estimates to be used

local use_estimates uncorrected
global replications 1000

*Robustness settings
if regexm("`modes'","robustness_pe") {
	local robustness_vars tax_rate_cont discount_rate
	local list_discount_rate 0.01 0.03 0.05 0.07 0.1 0.15
	local list_tax_rate_cont 0.1  0.15 0.2 0.3
}
else if regexm("`modes'","robustness") {
	local robustness_vars tax_rate_cont discount_rate
	local list_discount_rate 0.01 0.03 0.05 0.07 0.1 0.15
	local list_tax_rate_cont 0.1 0.15 0.2 0.3
}

*Import relevant programs
local ado_files 	est_life_impact int_outcome get_tax_rate deflate_to ///
					cost_of_college get_mother_age convert_rank_dollar ///
					scalartex

foreach ado in `ado_files' {
	do "${ado_files}/`ado'.ado"
}
*Reset data in memory assumption for est_life_impact
global data_in_mem = "no"

*-------------------------------------------------------------------------------
*	0. Define programs to run for
*-------------------------------------------------------------------------------
*Get all programs
local files : dir "${program_folder}" files "*.do"
foreach file in `files' {
	local cleanfile = subinstr("`file'",".do","",.)
	local all_functioning_programs `all_functioning_programs' `cleanfile'
}
local count_programs : word count `all_functioning_programs'
local half_progs = round(`count_programs'/2)
forval i = `half_progs'/`count_programs' {
	local prog: word `i' of `all_functioning_programs'
	local second_half `second_half' `prog'

}
local ui ""
local wtw ""
foreach file in `all_functioning_programs' {
	if strpos(lower("`file'"), "wtw") local wtw `wtw' `file'
	if strpos(lower("`file'"), "ui_") local ui `ui' `file'
}

local first_half : list all_functioning_programs - second_half

local except wtw_all

local run : list all_functioning_programs - except


local programs `all_functioning_programs'

*Set programs if running externally
if "`1'"!="" {
	if "`1'"=="all_programs" local programs `all_functioning_programs'
	else local programs "`1'"
}


*Naming exceptions
if strpos("`programs'", "cpc") & !strpos("`programs'", "cpc_") {
	local programs = subinstr("`programs'", "cpc", "cpc_preschool cpc_school_age cpc_extended",.)
}
if strpos("`programs'", "mto") & !strpos("`programs'", "mto_") {
	local programs = subinstr("`programs'", "mto", "mto_young mto_old mto_all",.)
}
if regexm("`programs'", "mass_hi") & !regexm("`programs'", "mass_hi_") {
	local programs = subinstr("`programs'", "mass_hi", "mass_hi_150 mass_hi_200 mass_hi_250",.)
}
if strpos(lower("`programs'"), "wtw_all") {
	local programs = subinstr("`programs'", "wtw_all", "wtw_earnsuppmfip wtw_earnsuppwrp wtw_educa wtw_educci wtw_educct wtw_earnsuppmfip wtw_earnsuppwrp wtw_educa wtw_educci wtw_educct wtw_educd wtw_educgr wtw_educr wtw_jobsearcha wtw_jobsearchgr wtw_jobsearchla	wtw_jobsearchr wtw_jobsearchsd wtw_mixeda wtw_mixedb wtw_mixedf wtw_mixedla wtw_mixedp wtw_mixedr wtw_mixedsd wtw_mixedt wtw_timelimc wtw_timelimf wtw_timelimv wtw_workexpcc wtw_workexpsd wtw_workexpwv",.)
}
if strpos(lower("`programs'"), "erta81") {
	local programs = subinstr("`programs'", "erta81", "erta81_s erta81_gs erta81_k erta81_bz",.)
}
if strpos(lower("`programs'"), "tra86") {
	local programs = subinstr("`programs'", "tra86", "tra86_ac tra86_mw tra86_gs tra86_k tra86_w tra86_bz",.)
}
if strpos(lower("`programs'"), "obra93") {
	local programs = subinstr("`programs'", " obra93 ", " obra93_c obra93_g obra93_hl obra93_giertz obra93_bz ",.)
}
if strpos(lower("`programs'"), "egtrra01") {
	local programs = subinstr("`programs'", "egtrra01", "egtrra01_h egtrra01_acg egtrra01_kww egtrra01_bz",.)
}
if strpos(lower("`programs'"), "aca13") {
	local programs = subinstr("`programs'", "aca13", "aca13_kww aca13_s",.)
}
if strpos(lower("`programs'"), "ui_b") {
	local programs = subinstr("`programs'", "aca13 ", "aca13_kww aca13_s",.)
}
if strpos(lower("`programs'"), "ui_b") {
	local programs = subinstr("`programs'", "ui_b", "ui_b_card_exp ui_b_card_rec ui_b_chetty ui_b_katz_meyer ui_b_kroft_noto ui_b_landais ui_b_meyer_hi ui_b_solon",.)
}
if strpos(lower("`programs'"), "ui_e") {
	local programs = subinstr("`programs'", "ui_e", "ui_e_johnston ui_e_katz_meyer",.)
}

*-------------------------------------------------------------------------------
*	1. Import default assumptions
*-------------------------------------------------------------------------------

import excel "${assumptions}/default_assumptions.xlsx", clear first
ds
foreach assumption in `r(varlist)' {
	global `assumption' = `assumption'[1]
}
global bootstrap_enrollment_effects = "yes"
global bootstrap_attainment_effects = "yes"
global redraw_college_effects = "no"
global redraw_bw_effects = "no"
if "${redraw_college_effects}" == "yes" {
	* re run all college programs after re drawing enrollment effect
	preserve
		import excel "${welfare_files}/MVPF_Calculations/Further program details.xlsx", clear first
		replace program = lower(program)
		levelsof program if inlist(prog_type, "College Tax Code", "College"), local(college_prog)
	restore
	local programs `programs' `college_prog'
	local programs: list uniq programs
}

global num_years = $proj_age
global correlation = 1
local replications = $replications
local num_years = $num_years
local prog_num = wordcount("`programs'")
local top_tax_reforms aca13 egtrra01 erta81 obra93 tra86

if `replications' >0 {

*-------------------------------------------------------------------------------
*	1.b Induce correlation between draws of College estimates
*-------------------------------------------------------------------------------
preserve
	local college_effects enrollment_earn_effect_pos enrollment_earn_effect_neg ///
		attainment_earn_effect_pos attainment_earn_effect_neg  ///
		community_earn_effect_pos community_earn_effect_neg

	cap confirm file "${welfare_files}/data/inputs/effect_draws/college_effects_`replications'_draws.dta"
	if (_rc!=0 | "${redraw_college_effects}" == "yes") & "`mode'" !="robustness_pe" {
		noi di in red "Redrawing the college effects, may want to make sure you re make all college programs"
		pause on
		pause
		pause off

		clear
		set obs $replications
		g draw = _n
		set seed 802648379
		foreach var in `college_effects' {
			g `var' = runiform()
		}
		save "${welfare_files}/data/inputs/effect_draws/college_effects_`replications'_draws.dta", replace
	}
	else {
		use "${welfare_files}/data/inputs/effect_draws/college_effects_`replications'_draws.dta", clear
	}
	mkmat `college_effects' , ///
		matrix(college_effects) rownames(draw)
restore

*-------------------------------------------------------------------------------
*	1.c Set a common series of draws for birth weight earnings effect
*-------------------------------------------------------------------------------

preserve
	cap confirm file "${welfare_files}/data/inputs/effect_draws/bw_effects_`replications'_draws.dta"
	if (_rc!=0 | "${redraw_bw_effects}" == "yes") & "`mode'" !="robustness_pe" &{
		noi di in red "Redrawing the bw effects, may want to make sure you re make all programs that use bw as intermediate outcome"
		pause on
		pause
		pause off

		clear
		set obs $replications
		g draw = _n
		set seed 634529276
		g bw_earn_effect = runiform()
		save "${welfare_files}/data/inputs/effect_draws/bw_effects_`replications'_draws.dta", replace
	}
	else {
		use "${welfare_files}/data/inputs/effect_draws/bw_effects_`replications'_draws.dta", clear
	}
	mkmat  bw_earn_effect, ///
		matrix(bw_effects) rownames(draw)
restore
}

*-------------------------------------------------------------------------------
*	2. Simulations
*-------------------------------------------------------------------------------
*Save external replications number as it may vary over specs
global replications_master = $replications

foreach mode in `modes' {

local m = 0 // reset counter
di "`mode'"
if "`mode'"=="robustness_pe"|regexm("`mode'","corrected") global replications 0
else global replications $replications_master
local replications $replications

*move to corrected estimates if corrected mode
if regexm("`mode'","corrected") {
	local pub_bias_mode = subinstr("`mode'","corrected_mode_","",1)
	local use_estimates "corrected/MLE/mode_`pub_bias_mode'"
	global output_corrected "${welfare_dropbox}/data/derived/`use_estimates'"
	cap mkdir "$output_corrected"
}
else local use_estimates uncorrected

foreach program in `programs' {
	if regexm("`program'", "wtw_") & !inlist("`mode'", "baselines", "normal") continue

capture {

*Skip certain programs on certain modes
if regexm("`mode'","robustness") & inlist("`program'","abecedarian") continue // no ability to vary discount rate there
if "`mode'"=="costs_by_age" & inlist("`program'","medicai_mw_v2","fiu")==0 continue //only needed for two programs

*Re-import default assumptions to memory
preserve
	import excel "${assumptions}/default_assumptions.xlsx", clear first
	ds
	foreach assumption in `r(varlist)' {
		global `assumption' = `assumption'[1]
	}
restore

*Sort issues where names of assumption files don't line up with do file names
local do_file = "`program'"
local assumption_name = "`program'"
foreach reform in `top_tax_reforms' {
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
	if strpos(lower("`program'"), "wtw_`type'") {
		local assumption_name wtw_`type'
		local do_file wtw_all
		}
}

*Import program specific assumptions
cap import excel "${assumptions}/`assumption_name'.xlsx", clear first
if _rc > 0 {
	di as err "No program specific assumptions for `assumption_name' found!"
	local ++m
	exit
}
if _rc == 0 {
	duplicates drop // drop rows of assumptions that are identical
	count
	local columns = r(N)

	ds
	local varying_assumptions "`r(varlist)'"

	if inlist("`mode'","baselines","lower_bound_wtp","fixed_forecast","observed_forecast") | regexm("`mode'","corrected") {
		cap confirm var spec_type // check for specification type indicator
		if _rc==0 {
			if "`mode'"=="lower_bound_wtp" keep if spec_type=="lower bound wtp"
			else keep if spec_type=="baseline"
			assert _N==1
			if inlist("`mode'","fixed_forecast","observed_forecast") {
				cap g earn_method = subinstr("`mode'","_forecast","",1)
				if _rc>0 cap replace earn_method = subinstr("`mode'","_forecast","",1)
				assert _rc==0
			}
			qui ds spec_type, not
			local varying_assumptions `r(varlist)'
			foreach assumption in `r(varlist)'  {
				local `assumption'_1 = `assumption'[1]
			}
		}
		else if spec_type!="lower bound wtp" {
			keep in 1 // where not specified the first row is the baseline specification
			if inlist("`mode'","fixed_forecast","observed_forecast"){
				cap g earn_method = subinstr("`mode'","_forecast","",1)
				if _rc>0 cap replace earn_method = subinstr("`mode'","_forecast","",1)
				assert _rc==0
			}
			qui ds
			local varying_assumptions `r(varlist)'
			foreach assumption in `r(varlist)' {
				local `assumption'_1 = `assumption'[1]
			}
		}
		local correlation_1 = 1
		local varying_assumptions `varying_assumptions' correlation
		local columns = _N
	}
	else if "`mode'" == "costs_by_age" {
		local columns = 4
		cap confirm var discount_rate
		if !_rc {
			qui ds discount_rate, not
			local other_assumptions "`r(varlist)'"
		}
		else {
			qui ds
			local other_assumptions "`r(varlist)'"
		}
		forval i =1/`columns' {
			foreach assumption in `other_assumptions' {
				local `assumption'_`i' = `assumption'[1]
			}
			*Iterate over discount rates 0.01, 0.03, 0.05 and 0.07
			local discount_rate_`i' = 0.01 + 0.02*(`i'-1)
			local correlation_`i' = 1
		}
	}
	else if regexm("`mode'","robustness") {
		local robust_spec = 0
		*Keep baseline assumptions to modify
		cap confirm var spec_type
		if _rc==0 {
			keep if spec_type=="baseline"
			assert _N==1
		}
		else keep in 1

		tempfile baseline_assum
		save `baseline_assum'
		local n_var = 0
		foreach var in `robustness_vars' {
			local ++n_var
			use `baseline_assum', clear
			local count_specs : word count `list_`var''
			expand `count_specs'
			local n_spec = 0
			foreach spec in `list_`var'' {
				local ++n_spec
				cap replace `var' = `spec' in `n_spec'
				if _rc>0 g `var' = `spec' in `n_spec'
			}
			if "`var'"=="tax_rate_cont" {
				cap drop tax_rate_assumption
				g tax_rate_assumption = "continuous"
			}
			g robust_spec = "`var'"
			tempfile rob_pe_`n_var'
			save `rob_pe_`n_var''

			local varying_assumptions robust_spec `varying_assumptions'
			if regexm("`varying_assumptions'","`var'")==0 local varying_assumptions  `var' `varying_assumptions'
		}

		forval i = 1/`=`n_var'-1' {
			append using  `rob_pe_`i''
		}
		local columns = _N
		forval i =1/`columns' {
			foreach assumption in `varying_assumptions' {
				local `assumption'_`i' = `assumption'[`i']
			}
		}
	}

	else if "`mode'" == "normal" {
		forval i =1/`columns' {
			foreach assumption in `varying_assumptions' {
				local `assumption'_`i' = `assumption'[`i']
			}
		}
	}
}

local ++m

if (strpos("`program'", "cpc")) & regexm("`program'","ui")==0 {
	local type_cpc = substr("`program'", strpos("`program'", "_") + 1, .)
	global policy = "`type_cpc'"
	local program = subinstr("`program'", "_`type_cpc'", "",.)
	local do_file = "`program'"
}

*Loop over types of assumptions
forval c = 1/`columns' {
	noi di "Specification `c' of `columns', program `m' of `prog_num' (`program')"

	*set assumptions
	foreach assumption in `varying_assumptions' {
		global `assumption' ``assumption'_`c''
	}

	*generate estimates
	clear
	set obs `replications'

	* Generate variables to store the estimates and clean globals
	local ests MVPF cost WTP CBA program_cost c_on_pc w_on_pc
	foreach est in `ests' {
		gen `est'_`program' = .
		cap macro drop `est'_`program'
	}

	* if program has net costs by age, generate age variables too
	if "`mode'"=="costs_by_age" {
		forval j = 0/`num_years' {
			qui gen y_`j'_cost_`program' = .
		}
	}

	*Simulations: run each do file ~1000 times and store the estimates from each run
	if `replications'>0 {
		forvalues i = 1/`replications' {
		global draw_number = `i'
		di "${program_folder}/`do_file'"
			* Run the program with the "bootstrap" option and store estimates for this draw
			if `debug' == 0 qui do "${program_folder}/`do_file'" `program' yes `use_estimates'
			if `debug' == 1 noi do "${program_folder}/`do_file'" `program' yes `use_estimates'

			qui cap replace cost_`program' = ${cost_`program'} in `i'
			if _rc == 0 {
				replace program_cost_`program' = ${program_cost_`program'} in `i'
				replace WTP_`program' = ${WTP_`program'} in `i'

				* if available, store net costs by age
				if "`mode'" == "costs_by_age" {
					forval j = 0/${proj_age} {
						qui replace y_`j'_cost_`program' = ${y_`j'_cost_`program'} in `i'
					}
				}
			}
		}
	}

	* Now get the point estimate and calculate the MVPF
	* (need to know which quadrant the pe lies in to calculate the MVPF for the draws)
	* Get point estimates
	global draw_number = 0
	if `debug' == 1 noi do "${program_folder}/`do_file'" `program' no `use_estimates'
	else qui do "${program_folder}/`do_file'" `program' no `use_estimates'
	local inf = 99999
	local infinity_`program' = `inf'
	* Calculate MVPF
	if (${WTP_`program'}>0 & ${cost_`program'}>0)| (${WTP_`program'}<0 & ${cost_`program'}<0){
		global MVPF_`program' = ${WTP_`program'}/${cost_`program'}
	}
	if ${WTP_`program'}>=0 & ${cost_`program'}<=0 {
		global MVPF_`program' = `inf'
	}
	if ${WTP_`program'}<=0 & ${cost_`program'}>0 {
		global MVPF_`program' = ${WTP_`program'}/${cost_`program'}
	}
	if ${WTP_`program'}<0 & ${cost_`program'}==0 {
		global MVPF_`program' = -`inf'
	}
	global CBA_`program' = 1 + (${WTP_`program'} - ${cost_`program'})/${program_cost_`program'}

	* normalised WTP and cost
	global c_on_pc_`program' = ${cost_`program'}/${program_cost_`program'}
	global w_on_pc_`program' = ${WTP_`program'}/${program_cost_`program'}

	* Calculate MVPF for the draws:
	if `replications' >0 {
		if (${WTP_`program'} >=0 | ${cost_`program'}>=0) {
			global quadrant_`program' = "NE"
			replace MVPF_`program' = WTP_`program'/cost_`program' if (WTP_`program' >0 & cost_`program' >0)
			replace MVPF_`program' = `inf' if (WTP_`program' >= 0 & cost_`program' <=0)
			replace MVPF_`program' = WTP_`program'/cost_`program' if (WTP_`program' <=0 & cost_`program' >0)
			replace MVPF_`program' = -`inf' if (WTP_`program' <0 & cost_`program' ==0)

			replace MVPF_`program' = . if (WTP_`program'<0 & cost_`program' < 0)
			}
		else {
			global quadrant_`program' = "SW"
			replace MVPF_`program' = WTP_`program'/cost_`program' if (WTP_`program'<0 & cost_`program' <0)
			replace MVPF_`program' = `inf' if (WTP_`program' >= 0 & cost_`program' <=0)
			replace MVPF_`program' = WTP_`program'/cost_`program' if (WTP_`program' <=0 & cost_`program' >0)
			replace MVPF_`program' = -`inf' if (WTP_`program' <0 & cost_`program' ==0)
			replace MVPF_`program' = . if (WTP_`program'>0 & cost_`program'> 0)
		}

		*Calculate CBA
		replace CBA_`program' = 1 + (WTP_`program' - cost_`program')/program_cost_`program'

		*Get normalised WTP and cost
		replace c_on_pc_`program' = cost_`program'/program_cost_`program'
		replace w_on_pc_`program' = WTP_`program'/program_cost_`program'

	}

	if `replications' >0 {
		if inlist("`mode'","baselines","lower_bound_wtp","fixed_forecast","observed_forecast")  {
			*Save draws
			gen draw_id = _n
			if strpos("`program'", "cpc")  {
				local program_temp = "`program'" + "_`type_cpc'"
				local cap_name = substr("`program_temp'",1,19)
				ren *_`program' *_`cap_name'
			}
			else local program_temp `program'
			if "`mode'"=="baselines" local mode_temp baseline
			else local mode_temp `mode'
			save "${output}/`program_temp'_`mode_temp'_`replications'_draws_corr_1.dta", replace
			drop draw_id
		}
		if "`mode'" == "robustness"  {
			*Save draws
			local ++robust_spec
			g draw_id = _n
			if strpos("`program'", "cpc")  {
				local program_temp = "`program'" + "_`type_cpc'"
				local cap_name = substr("`program_temp'",1,19)
				ren *_`program' *_`cap_name'
			}
			else local program_temp `program'
			*list assumptions
			g robust_spec=`robust_spec'
			g program = "`program'"
			save "${output}/`program_temp'_robustness_`replications'_draws_spec_`robust_spec'.dta", replace emptyok
			drop draw_id program robust_spec
		}

		if "`mode'" == "normal"  {
			*Save draws
			gen draw_id = _n
			if strpos("`program'", "cpc")  {
				local program_temp = "`program'" + "_`type_cpc'"
				local cap_name = substr("`program_temp'",1,19)
				ren *_`program' *_`cap_name'
			}
			else local program_temp `program'
			*list assumptions
			gen assumptions = ""
			foreach assumption in `varying_assumptions' {
				replace assumptions = assumptions + "`assumption': $`assumption', "
			}
			foreach other in correlation replications {
				replace assumptions = assumptions + "`other': $`other', "
			}
			gen program = "`program'"
			save "${output}/`program_temp'_normal_`replications'_draws_spec_`c'.dta", replace emptyok
			drop draw_id assumptions program
		}

		* If 99999 is not high enough, set new infinity
		qui su MVPF_`program' if !mi(MVPF_`program')
		local max = r(max)
		local min = r(min)
		local infinity_`program' = max(abs(`max'), abs(`min'), `inf' , abs(${MVPF_`program'}))
		if `infinity_`program''>`inf' {
			local infinity_`program' = `infinity_`program'' * 10
			replace MVPF_`program' = `infinity_`program'' if MVPF_`program' == `inf'
			replace MVPF_`program' = -`infinity_`program'' if MVPF_`program' == -`inf'
			if ${MVPF_`program'} == `inf' {
				global MVPF_`program' = `infinity_`program''
			}
			if ${MVPF_`program'} == -`inf' {
				global MVPF_`program' = -`infinity_`program''
			}

		}

			if `replications'>1 {
			foreach est in `ests' {
				qui su `est'_`program'
				if r(N) >0  & (r(min) != r(max)) {
					_pctile `est'_`program', p(2.5, 97.5) //store the CI bounds from the bootstrap distribution
					global l_`est'_`program' = `r(r1)'
					global u_`est'_`program' = `r(r2)'
					qui su `est'_`program'
					global sd_`est'_`program' = r(sd)
				}
				else {
					global l_`est'_`program' = .
					global u_`est'_`program' = .
					global sd_`est'_`program' = .

				}
			}

			* Treat mvpf differently to account for the missing quadrant
			count if MVPF_`program' == . & !mi( WTP_`program') & !mi(cost_`program')
			local n1 = r(N)
			if "${quadrant_`program'}"=="NE" count if WTP_`program' <0 & cost_`program'<0
			else if "${quadrant_`program'}"=="SW" count if WTP_`program' >0 & cost_`program' >0
			else di as error "Something went wrong"
			local n2 = r(N)
			if "`mode'"!="robustness_pe" assert `n1' == `n2'
			count
			local n3 = r(N)
			local prop_`program' = `n1'/`n3'
			* what pctiles to use for the CIs once we account for the draws that fall in the missing quadrant
			local p_low_MVPF = (5 - 100*`prop_`program'')/2
			local p_high_MVPF = 100 - `p_low_MVPF'

			* If more than 5% of draws fall in missing quadrant the CI covers everything
			if `p_low_MVPF' <=0 {
				global l_MVPF_`program' = -`infinity_`program''
				global u_MVPF_`program' = `infinity_`program''
				global sd_MVPF_`program' = .
			}

			else if `replications'>1 {
				_pctile MVPF_`program', p(`p_low_MVPF' `p_high_MVPF') //store the CI bounds from the bootstrap distribution
				global l_MVPF_`program' = `r(r1)'
				global u_MVPF_`program' = `r(r2)'
				global sd_MVPF_`program' = .
			}

			*ESTIMATE EFRON BIAS-CORRECTED CIS
			*Estimate d(alpha) = F^-1(Phi(2z_0 + z_alpha)) - new upper and lower CIs
			*z_alpha = Phi^-1(alpha)
			*z_0 = Phi^-1(F(x))
			*x: point estimate
			*F(): bootstrap distribution
			local p_low_CBA = 2.5
			local p_high_CBA = 97.5
			foreach var in MVPF CBA {
				global l_`var'_ef_`program' = .
				global u_`var'_ef_`program' = .
				if "`mode'" != "robustness_pe" & `replications'>1 {
					su `var'_`program'
					local dist_sd_`program' = r(sd)
					*only do this when we have distributions, i.e. not for environmental currently
					if `dist_sd_`program'' > 0 & `p_low_`var'' >0 {
						sort `var'_`program'
						cap drop pctile_`program'
						count if !mi(`var'_`program')
    					local n_`var'_`program' = `r(N)'
    					gen pctile_`program' = _n/`n_`var'_`program'' if !mi(`var'_`program')
						count if (`var'_`program' == ${`var'_`program'}) == 1
						if `=r(N)' > 0 {
							su pctile_`program' if (`var'_`program' == ${`var'_`program'})
							if `=r(min)' > 0.5 local `var'_pe_p_`program' = `=r(min)'
							if `=r(max)' < 0.5 local `var'_pe_p_`program' = `=r(max)'
							if inrange(0.5,`=r(min)',`=r(max)') local `var'_pe_p_`program' = 0.5
						}
						else {
							su pctile_`program' if (${`var'_`program'} >= `var'_`program')
							local lower_p_`program' = r(max)
							su pctile_`program' if (${`var'_`program'} <= `var'_`program')
							local upper_p_`program' = r(min)
							local `var'_pe_p_`program' = (`lower_p_`program'' + `upper_p_`program'')/2
						}
						*Allow a fix for where point estimate lies outside bootstrap draws
						*due to being at a lower bound and rounding issues
						if ``var'_pe_p_`program'' == . {
							if `=r(N)' > 0 {
								su pctile_`program' if inrange(`var'_`program',`=${`var'_`program'}-0.0001',`=${`var'_`program'}+0.0001')
								if `=r(min)' > 0.5 local `var'_pe_p_`program' = `=r(min)'
								if `=r(max)' < 0.5 local `var'_pe_p_`program' = `=r(max)'
								if inrange(0.5,`=r(min)',`=r(max)') local `var'_pe_p_`program' = 0.5
							}
						}
						local l = 0

						local alpha1 = `p_low_`var''/100
						local alpha2 = `p_high_`var''/100
						foreach alpha in `alpha1' `alpha2' {
							local ++l
							local z_alpha = invnormal(`alpha')
							local z_0_`program' = invnormal(``var'_pe_p_`program'')
							local new_alpha_`l'_`program' = normal(2*`z_0_`program'' + `z_alpha')
							_pctile `var'_`program' , p(`=`new_alpha_`l'_`program'' * 100')
							local d_`var'_`l'_`program' = `r(r1)'
						}
					}

					else if `dist_sd_`program'' == 0 & `p_low_`var''>0 {
						su WTP_`program'
						local sd_1 = r(sd)
						su cost_`program'
						local sd_2 = r(sd)
						if `sd_1'>0 | `sd_2'>0 {
							_pctile `var'_`program', p(`p_low_`var'' `p_high_`var'')
							local d_`var'_1_`program' = r(r1)
							local d_`var'_2_`program' = r(r2)
						}
						else{
							forval l = 1/2 {
								local d_`var'_`l'_`program' = .
							}
						}
					}
					else if `p_low_`var'' <= 0 {
						local d_`var'_1_`program' = -`infinity_`program''
						local d_`var'_2_`program' = `infinity_`program''
					}
					global l_`var'_ef_`program' = `d_`var'_1_`program''
					global u_`var'_ef_`program' = `d_`var'_2_`program''
				}
			}

			local k = 0
			if "`mode'"=="costs_by_age" {
				forval j = 0/`num_years' {
					*Get costs by age
					su y_`j'_cost_`program'
					global y_`j'_cost_`program' = r(mean)
					global sd_y_`j'_cost_`program' = r(sd)
					_pctile y_`j'_cost_`program', p(2.5 97.5)
					global l_y_`j'_cost_`program' = r(r1)
					global u_y_`j'_cost_`program' = r(r2)
				}
			}
		}
	}

	*Save all estimates as a single row of data
	clear
	set obs 1
	g col = `c'
	g program = "`program'"

	foreach est in `ests' {
		gen `est' = ${`est'_`program'}
		if `replications' >1 {
			if "`est'" != "MVPF" gen `est'_sd = ${sd_`est'_`program'}
			gen l_`est' = ${l_`est'_`program'}
			gen u_`est' = ${u_`est'_`program'}
			if inlist("`est'","MVPF","CBA") {
				gen l_`est'_efron = ${l_`est'_ef_`program'}
				gen u_`est'_efron = ${u_`est'_ef_`program'}
			}
		}
	}
	g infinity = `infinity_`program''
	*Get age variables
	foreach age in age_stat age_benef {
		cap g `age' = ${`age'_`program'}
		if _rc>0 g `age'=.
	}
	*Get income variables
	foreach type in stat benef {
		foreach var in inc inc_year inc_age {
			cap g `var'_`type' = ${`var'_`type'_`program'}
			if _rc>0 g `var'_`type' = .
		}
		g inc_type_`type' = "${inc_type_`type'_`program'}"
	}
	foreach est in WTP cost {
		gen `est'_over_prog_cost = `est' / program_cost
	}
	* specify proportion of draws that fell in missing quadrant
	if `replications'>0 gen perc_switch = `prop_`program''

	*list assumptions
	gen assumptions = ""
	foreach assumption in `varying_assumptions' {
		replace assumptions = assumptions + "`assumption': $`assumption', "
	}
	foreach other in correlation replications {
		replace assumptions = assumptions + "`other': $`other', "
	}

	if "`mode'" == "robustness" gen robust_var = "`robust_var_`c''"
	if "`mode'" == "robustness_pe" & "`robustness_vars'" == "proj_age" {
		g proj_age = $proj_age
	}

	tempfile `program'_ests_`c'
	save ``program'_ests_`c'', emptyok

	*Save costs by age for baseline spec if relevant
	if 	"`mode'" == "costs_by_age" {
		clear
		set obs `=`num_years'+1'
		gen age = _n - 1
		gen cost = .
		gen sd_cost = .
		gen l_cost = .
		gen u_cost = .

		forval j = 0/`num_years' {
			local index = `j' + 1
			replace cost = ${y_`j'_cost_`program'} in `index'
			replace sd_cost = ${sd_y_`j'_cost_`program'} in `index'
			replace l_cost = ${l_y_`j'_cost_`program'} in `index'
			replace u_cost = ${u_y_`j'_cost_`program'} in `index'
		}
		gen discount_rate = `discount_rate_`c''
		if "`program'" == "medicai_mw_v2" gen MW_spec = `MW_spec_`c''
		tempfile costs_by_age_`c'
		save `costs_by_age_`c''
	}
}

*-------------------------------------------------------------------------------
*	3. Export estimates
*-------------------------------------------------------------------------------

qui {
use ``program'_ests_1', clear

if `columns' > 1 {
	forval c = 2/`columns' {
		append using ``program'_ests_`c''
	}
}

drop col
if (strpos("`program'", "cpc") ) & regexm("`program'","ui")==0 {
	local program = "`program'" + "_" + "`type_cpc'"
	replace program = "`program'"
}
tempfile `program'_unbdd_ests
save ``program'_unbdd_ests'

* now censor everything at 6:
qui ds *MVPF*
local mvpf_vars `r(varlist)'
foreach var in `mvpf_vars' {
	replace `var' = 5 if `var'>5 & `var'<infinity
	replace `var' = 6 if `var' == infinity
	replace `var' = -1 if `var'<-1
}
drop infinity
tempfile `program'_ests
save ``program'_ests'


if "`mode'" == "baselines" | regexm("`mode'","corrected") {
	if regexm("`mode'","corrected") local out_temp ${output_corrected}
	else local out_temp ${output}
	export delimited using "`out_temp'/`program'_baseline_estimates_`replications'_replications.csv", replace
	use ``program'_unbdd_ests', clear
	export delimited using "`out_temp'/`program'_baseline_unbounded_estimates_`replications'_replications.csv", replace
	continue
}
if inlist("`mode'","lower_bound_wtp","fixed_forecast","observed_forecast") {
	save "${output}/`program'_`mode'_estimates_`replications'_replications.dta", replace
	use ``program'_unbdd_ests', clear
	save "${output}/`program'_`mode'_unbounded_estimates_`replications'_replications.dta", replace
	continue
}
if "`mode'"=="normal" {
	save "${output}/`program'_`mode'_estimates_`replications'_replications.dta", replace
	use ``program'_unbdd_ests', clear
	save "${output}/`program'_`mode'_unbounded_estimates_`replications'_replications.dta", replace
}

if "`mode'"=="robustness" {
	local no_space = subinstr("`robustness_vars'"," ","",.)
	save "${output}/`program'_`mode'_estimates_`replications'_replications.dta", replace
	use ``program'_unbdd_ests', clear
	save "${output}/`program'_`mode'_unbounded_estimates_`replications'_replications.dta", replace
}


if "`mode'" == "robustness_pe" {
	* note no need to export unbdd estimates here since only pe's (and unbdd PE of mvpf can easily be reconstructed)
	if "`robustness_vars'" == "proj_age" {
		save "${output}/`program'_`mode'_proj_age_estimates.dta", replace
	}
	else {
		save "${output}/`program'_`mode'_estimates.dta", replace
	}
}
if "`mode'" == "costs_by_age" {
	use `costs_by_age_1', clear
	forval i = 2/`columns' {
		append using `costs_by_age_`i''
	}
	save "${output}/`program'_costs_by_age_`replications'_replications.dta", replace
}
*Get back bounded estimates for inspection
use ``program'_ests', clear
}

} // end of capture

if _rc>0 {
	if _rc==1 continue, break
	local error_progs = "`error_progs'"+"`program' on `mode', "
	di as err "`program' broke"
}

}
}

*Throw errors if things didn't run
if _rc!=1 {
global error_progs = "`error_progs'"
if "`error_progs'"!="" di as err "Finished running but the following programs threw errors: `error_progs'"
else di in red "Finished running with no errors"
}
