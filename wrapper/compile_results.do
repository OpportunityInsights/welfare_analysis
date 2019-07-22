********************************************************************************
*	Compile results, incorporating dollar spend averages
********************************************************************************

* Set file paths
global welfare_dropbox "${welfare_files}"
global assumptions "${welfare_dropbox}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global data_derived "${welfare_dropbox}/Data/derived"
global input_data "${welfare_dropbox}/data/inputs"
global output "${welfare_dropbox}/figtab/scratch"
global scalartex_out "${welfare_files}/data/scalartex/"
cap mkdir "$output"

*Import relevant programs
do "${ado_files}/est_life_impact.ado"
do "${ado_files}/int_outcome.ado"
do "${ado_files}/get_tax_rate.ado"

*Define groups and outcomes for dollar spend averages
local groups prog_type kid_ind  ///
	kid_by_decade k_by_pt ps_by_pt prog_by_age ///
	peer_by_type rct_by_type hi_obs_prog kid_cat kid kid_obs_by_type

local replications = 1000
local corr = 1
local outcomes w_on_pc mvpf cbr	c_on_pc

*Set types of estimates to compile
local compile_types baseline lower_bound_wtp fixed_forecast observed_forecast robustness
/* Working:
	-	baseline
	-	lower_bound_wtp
	-	fixed_forecast
	-	observed_forecast
	-	robustness
*/

*Set compile types if running externally
if "`1'"=="all_modes" local compile_types baseline lower_bound_wtp fixed_forecast observed_forecast robustness
else if "`1'"!="" local compile_types "`1'"

*Robustness compile settings:
local robustness_vars tax_rate_cont discount_rate
local list_discount_rate 0.01 0.03 0.05 0.07 0.1 0.15
local list_tax_rate_cont 0.1 0.15 0.2 0.3

local count_rvar : word count `robustness_vars'
local rspecs = 0
foreach var in `robustness_vars' {
	foreach num in `list_`var'' {
		local ++rspecs
		local rspec_type_`rspecs' `var'
		local rspec_val_`rspecs'="`num'"
	}
}

* Get a list of programs that use p-value ranges
local range_programs ""
local input_files : dir "${input_data}/causal_estimates/uncorrected" files "*.csv"
foreach file in `input_files' {
	local prog_name = regexr("`file'", ".csv", "")
	if strpos("`prog_name'", "combined_kid_") continue
	qui import delimited "${input_data}/causal_estimates/uncorrected/`file'", clear
	qui levelsof p_value, local(values)
	local range no
	foreach value in `values' {
		if strpos("`value'", "[") | strpos("`value'", "]") {
			local range yes
		}
		if "`range'" == "yes" break

	}
	if "`range'" == "yes" {
		di in red "`prog_name'"
		local range_programs `range_programs' `prog_name'
	}
}


foreach compile_type in `compile_types' {

if "`compile_type'"=="robustness" local loops `rspecs'
else local loops 1
forval loop = 1/`loops' {

*get relevant files
if "`compile_type'"=="baseline" local file_type csv
else local file_type dta
local files : dir "${data_derived}" files "*_`compile_type'_unbounded_estimates*`replications'_replications.`file_type'"

local i = 0
foreach file in `files' {
	local ++i
	di "`file'"

	if "`file_type'"=="csv" import delimited "${data_derived}/`file'", clear
	else if "`file_type'"=="dta" use  "${data_derived}/`file'", clear
	if "`compile_type'" =="robustness" {
		g spec_n = _n
		g robust_type = substr(assumptions, ///
			strpos(assumptions,"robust_spec: ")+strlen("robust_spec: "), ///
			strpos(substr(assumptions,strpos(assumptions,"robust_spec: "),.),",")- strlen("robust_spec: ")-1)
		*Get specs from assumption
		foreach var in `robustness_vars' {
			g `var'_temp = substr(assumptions, ///
					strpos(assumptions,"`var': ")+strlen("`var': "), ///
					strpos(substr(assumptions,strpos(assumptions,"`var': "),.),",")- strlen("`var': ")-1)

			destring `var'_temp, replace
			g `var' = ""
			foreach j in `list_`var'' {
				replace `var' = "`j'" if round(`var'_temp,0.01)==`j'
			}
			drop `var'_temp
		}
		di "`rspec_val_`loop''"
		di "`rspec_type_`loop''"
		keep if `rspec_type_`loop''=="`rspec_val_`loop''" & robust_type=="`rspec_type_`loop''"
		local spec_n_`=program[1]'=spec_n[1]
	}
	if `corr' == 0 keep if regexm(assumptions,"correlation: 0")
	if `corr' == 1 keep if regexm(assumptions,"correlation: 1")
	if `=_N'>1 {
		assert assumptions[1] == assumptions[2]
		keep in 1
	}
	tempfile temp`i'
	save `temp`i'', replace
}

use `temp1', clear
forval j = 2/`i' {
	append using `temp`j'', force
}

replace program = lower(program)
renvars *, lower

*get name labels and groups
preserve
	import excel "${welfare_files}/MVPF_Calculations/Further program details.xlsx", clear first
	replace program = lower(program)
	drop if program==""
	tempfile more_details
	save `more_details'
restore
replace program = lower(program)
merge m:1 program using `more_details'

*Asserts to make sure sample is complete
if "`compile_type'"=="baseline" assert _merge==3
else if "`compile_type'"=="robustness" assert _merge==3 if regexm(program,"wtw")==0 & inlist(program,"job_corps","abecedarian")==0
else assert _merge==3 if regexm(program,"wtw")==0

*Only keep matches
keep if _merge==3 
drop _merge

*Adjust incomes to be comparable
*Adjust to common age in lifecycle: 30
*Use same data as est_life_impact: ACS mean wages by age in 2015
preserve
	use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear

	su age
	global acs_youngest = r(min)
	global acs_oldest = r(max)
	forval age = $acs_youngest / $acs_oldest {
		local index = `age' - 17
		global mean_wage_a`age'_2015 = wag[`index']
	}
restore
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


*Generate variable for broad category

destring years_observed, force gen(temp)
g obs_hi = temp>=5
tostring obs_hi, replace
g hi_obs_prog = prog_type+obs_hi

/*
local categories "In Kind Benefits" "Social Insurance" "Education" ""
g major_area = "In Kind Benefits" if inlist(prog_type,"Housing Vouchers")
*/
egen type_num = group(prog_type) if prog_type != ""
su type_num
local num_types = r(max)

gen yaxis = type_num
levelsof yaxis, local(covtoplot)

gen has_ses = ((u_c_on_pc - l_c_on_pc > 0) & (u_c_on_pc - l_c_on_pc != .)) | ((u_w_on_pc - l_w_on_pc > 0) & (u_w_on_pc - l_w_on_pc != .))
replace has_ses = 0 if program == "dctag" // only se's are from Zimmerman - pull out of averages
g p_val_range = regexm( "`range_programs'", program)
g prog_in_avg = (has_ses & p_val_range==0)
foreach age in age_stat age_benef {
	*Generate agebins
	gen `age'_bin = 1 if (`age' < 18)
	replace `age'_bin = 2 if (`age'>=18 & `age' < 25)
	replace `age'_bin = 3 if (`age'>=25 & `age' <40)
	replace `age'_bin = 4 if (`age'>=40 & `age' <65)
	replace `age'_bin = 5 if (`age'>=65 & `age' < .)
}
*Generate age_by_income/age_by_prog_type categories
tostring age_benef_bin, replace

g prog_by_age = prog_type+ "_" +age_benef_bin
destring age_benef_bin, replace

*Generate kid policy categories
g kid = age_benef<=23
g kid_ind = "Children" if kid
replace kid_ind = "Adults" if kid==0 | prog_type=="Job Training"

g kid_cat = inlist(prog_type, "Health Child", "Child Education", "College Child", "Job Training")
tostring kid_cat, replace
replace kid_cat = "" if program == "mto_all"
g age_d = kid
replace age_d = 2 if inrange(age_benef,18,23)
* Generate decades
g decade = floor(year_implementation/10)*10
g era = (2*(floor(year_implementation/20)*20)+20)/2
tostring kid decade age_d era, replace force
g kid_by_decade = "kid_"+kid +"_decade_"+ decade
g age_d_by_decade = "age_d_"+age_d +"_decade_"+ decade
g kid_by_era = "kid_"+kid +"_era_"+ era

* generate kid_in_baseline by prog_type group
g kid_obs_by_type = strofreal(kid_in_baseline)+ "_" + prog_type


*Generate broad groups
g group = ""
replace group = "Social Insurance" if inlist(prog_type, "Disability Ins.", "Health Adult", "Health Child", "Unemp. Ins.", "Supp. Sec. Inc.")
replace group = "In Kind Transfers" if inlist(prog_type, "Nutrition", "Housing Vouchers", "MTO", "MTO Teens", "MTO Young")
replace group = "Education" if inlist(prog_type, "Child Education", "Job Training", "College Child", "College Adult")
replace group = "Taxes" if inlist(prog_type, "Top Taxes", "Cash Transfers")

* program type with restrictions
g peer_by_type = peer_reviewed+ "_" + prog_type
g rct_by_type = RCT_lottery_RD + "_" + prog_type
g temp_obs = "y" if (earnings_type=="0" | earnings_type=="observed")
replace temp_obs = "n" if mi(temp_obs)
g obs_by_type = temp_obs + "_" + prog_type
drop temp_obs
*gen kid by prog_type
g k_by_pt = "k"+kid+"p"+prog_type

g ps_by_pt = prog_type

replace ps_by_pt = prog_type+" K12" if inlist(program, "k12_spend_mich", "k12_spend","cpc_school_age","cpc_extended")

*split Unemp. Ins.
replace ps_by_pt = "Unemp. Ins. Ben" if prog_type =="Unemp. Ins."
replace ps_by_pt =  "Unemp. Ins. Ext" if regexm(program,"ui_e_") & prog_type=="Unemp. Ins."

*Health no mc_83
replace ps_by_pt = "exclude" if program=="mc_83"

*college program subtypes
replace ps_by_pt = "College Information" if inlist(program,"hail_aid","fafsa_help_dep","fafsa_help_ind")
replace ps_by_pt = "Tuition Support" if inlist(program,"dctag","cal_grant_gpa", "cal_grant_inc", "fsag") ///
	| inlist(program,"cuny_pell","georgiahope","kalamazoo") ///
	| inlist(program,"ohio_pell","ss_benefit","texas_pell") ///
	|  program=="adult_pell"
replace ps_by_pt = "College Other" if inlist(program,"nat_spend","nat_tuition","fiu")
replace ps_by_pt = "Parental Investment" if prog_type=="College Adult" & program!="adult_pell"

replace ps_by_pt = "Earnings Supplement" if strpos(program, "wtw_earnsupp")
replace ps_by_pt = "Mandatory Education" if strpos(program, "wtw_educ")
replace ps_by_pt = "Job Search First" if strpos(program, "wtw_jobsearch")

replace ps_by_pt = "Mixed Init Activity" if strpos(program, "wtw_mixed")
replace ps_by_pt = "Time Limit" if strpos(program, "wtw_timelim")
replace ps_by_pt = "Work Experience" if strpos(program, "wtw_workexp")

destring decade era age_d , replace force

drop if prog_type == ""
drop if program == ""


*Change prog_type grouping for top tax temporarily to be within reform
foreach reform in aca13 egtrra01 erta81 obra93 tra86 {
	replace ps_by_pt = prog_type+" "+"`reform'" if prog_type=="Top Taxes" & regexm(program,"`reform'")
}

*Generate variable for whether to show group average
g show_grp_avg = inlist(prog_type,"MTO","Top Taxes")==0

**********************************************
* Estimate and merge on dollar spend averages
**********************************************

tostring age_stat_bin age_benef_bin, replace

* For baseline loop over different sample restrictions

if "`compile_type'"=="baseline" local samples baseline restricted extended
else if inlist("`compile_type'","fixed_forecast","observed_forecast") local samples restricted
else local samples baseline restricted extended // need this in the website data
tempfile full_sample_base
save `full_sample_base'

foreach sample in `samples' {

use `full_sample_base', clear

*Impose sample restrictions
*Keep main specs only
if "`sample'"=="baseline" 	keep if 	main_spec==1

*Keep if earnings effects not relevant or are observed, i.e. exclude intermediate extrapolations
if "`sample'"=="restricted" keep if 	main_spec==1 & ///
										(earnings_type==""|earnings_type=="observed")

*Keep everything
if "`sample'"=="extended" 	keep if 	1

*Always remove top tax policies that are separate estimates of the same policy
drop if prog_type == "Top Taxes" & main_spec!=1

if "`compile_type'"!="baseline" & "`compile_type'"!="robustness" local sample `sample's_`compile_type'

tempfile master_base
save `master_base', replace

*Loop over group types and outcomes
foreach outcome in `outcomes' {
	local groups_temp `groups'
	//if "`outcome'" == "cbr" local groups_temp  agebin prog_type :(
	if "`outcome'"=="w_on_pc" local groups_temp  prog_type
	foreach group_var in `groups_temp' {
		di as result "MODE : `compile_type'"
		di as result "GROUP : `group_var'"
		di as result "OUTCOME : `outcome'"
		qui {

			use `master_base', clear

			tempfile base
			save `base', replace

			levelsof `group_var', local(groups2)

			local i = 0
			foreach type in `groups2' {
				*noi di as result "`type'"

				*DEFINE PROGRAMS TO RUN FOR
				use `base', clear
				keep if `group_var' == "`type'" & has_ses & p_val_range==0
				levelsof program, local(all_programs)
				if r(r) <= 1 continue // don't make avg if only one program

				local use_programs
				foreach program in `all_programs' {
					*Confirm saved draws exist
					if "`compile_type'"=="robustness" cap confirm file "${data_derived}/`program'_`compile_type'_`replications'_draws_spec_`spec_n_`program''.dta"
					else cap confirm file "${data_derived}/`program'_`compile_type'_`replications'_draws_corr_1.dta"
					if _rc == 0 local use_programs `use_programs' `program' //If all exist then use
				}

				if "`use_programs'" == "" continue
				assert has_ses

				***GET POINT ESTIMATES***
				use `base', clear
				drop if regexm("`use_programs'",program)==0 | `group_var' != "`type'"
				assert has_ses
				assert p_val_range==0
			
				*Normalise each policy by cost
				replace wtp = wtp/program_cost
				replace cost = cost/program_cost
				local type_nospace = subinstr("`type'", " ", "_" ,.)

				*Estimate mean wtp/cost per dollar
				g count_programs = 1 if !mi(wtp) & !mi(cost)
				collapse (mean) wtp cost age_stat age_benef inc_stat inc_benef (rawsum) count_programs
				qui su count_programs
				local count_programs = r(mean)
				ren * mean_*

				*Estimate outcome
				local inf = 99999
				if "`outcome'"=="c_on_pc" gen avg_`outcome' = mean_cost
				if "`outcome'"=="w_on_pc" gen avg_`outcome' = mean_wtp
				if "`outcome'"=="cbr" gen avg_`outcome' = mean_wtp + (1 - mean_cost)
				if "`outcome'"=="mvpf" {
					* Calculate MVPF
					gen avg_`outcome' = mean_wtp/mean_cost if ((mean_wtp>0 & mean_cost>0) |(mean_wtp<0 & mean_cost<0))
					replace avg_`outcome' = `inf' if (mean_wtp > 0 & mean_cost <=0)
					replace avg_`outcome' = mean_wtp/mean_cost if (mean_wtp<=0 & mean_cost>0)
					replace avg_`outcome' = -`inf' if (mean_wtp<0 & mean_cost == 0)
					if (mean_wtp>=0 | mean_cost>=0) local quadrant NE
					else local quadrant SW

				}
				su avg_`outcome'
				assert (r(sd) == 0 | r(sd) == .)
				local point_est = r(mean)
				foreach age in age_stat age_benef inc_stat inc_benef {
					su mean_`age'
					assert (r(sd) == 0 | r(sd) == .)
					local avg_`age' = r(mean)
				}

				***GET CI***
				*IMPORT DRAWS
				local k = 0
				foreach program in `use_programs' {
					local ++k
					if `k' == 1 {
						if "`compile_type'"=="robustness" use "${data_derived}/`program'_`compile_type'_`replications'_draws_spec_`spec_n_`program''.dta", clear
						else use "${data_derived}/`program'_`compile_type'_`replications'_draws_corr_`corr'.dta", clear
					}
					else {
						if "`compile_type'"=="robustness"  merge 1:1 draw_id using "${data_derived}/`program'_`compile_type'_`replications'_draws_spec_`spec_n_`program''.dta", nogen assert(3)
						else  merge 1:1 draw_id using "${data_derived}/`program'_`compile_type'_`replications'_draws_corr_`corr'.dta", nogen assert(3)
					}
				}
				renvars *, lower
				cap ds wtp_*
				if _rc != 0 continue

				*ESTIMATE `OUTCOME' ON EACH ROUND OF DRAWS
				*Normalise each policy by cost, then collapse
				foreach var in wtp cost {
					local c_list_`var'
					foreach prog in `use_programs' {
						replace `var'_`prog' = `var'_`prog' * (1/ `count_programs') / program_cost_`prog'
						local c_list_`var' `c_list_`var'' `var'_`prog'
					}
					egen mean_`var' = rowtotal(`c_list_`var'')
				}


				*Estimate outcome
				if "`outcome'"=="c_on_pc" gen avg_`outcome' = mean_cost
				if "`outcome'"=="w_on_pc" gen avg_`outcome' = mean_wtp
				if "`outcome'"=="cbr" gen avg_`outcome' = mean_wtp + (1 - mean_cost)
				if "`outcome'" == "pc_mvpf" gen avg_`outcome' = 1/mean_cost if mean_cost >0
				if "`outcome'"=="mvpf" {
					if "`quadrant'" == "NE" {
						gen avg_`outcome' = mean_wtp/mean_cost if (mean_wtp>0 & mean_cost >0)
						replace avg_`outcome' = `inf' if (mean_wtp >= 0 & mean_cost <=0)
						replace avg_`outcome' = mean_wtp/mean_cost if (mean_wtp<=0 & mean_cost>0)
						replace avg_`outcome' = -`inf' if (mean_wtp<0 & mean_cost == 0)
						replace avg_`outcome' = . if (mean_wtp<0 & mean_cost< 0)
						}
					else {
						gen avg_`outcome' = mean_wtp/mean_cost if (mean_wtp<0 & mean_cost <0)
						replace avg_`outcome' = `inf' if (mean_wtp >= 0 & mean_cost <=0)
						replace avg_`outcome' = mean_wtp/mean_cost if (mean_wtp<=0 & mean_cost>0)
						replace avg_`outcome' = -`inf' if (mean_wtp<0 & mean_cost==0)
						replace avg_`outcome' = . if (mean_wtp>0 & mean_cost> 0)

					}
				}


				* If 99999 is not high enough, set new infinity
				if inlist("`outcome'", "mvpf") {
					 su avg_`outcome' if !mi(avg_`outcome')
					recast double avg_mvpf
					local max = r(max)
					local min = r(min)
					assert `point_est' != .
					local infinity_`outcome' = max(abs(`max'), abs(`min'), `inf', abs(`point_est'))
					if `infinity_`outcome''>`inf' {
						local infinity_`outcome' = `infinity_`outcome'' * 10
						replace avg_`outcome' = `infinity_`outcome'' if avg_`outcome' == `inf'
						replace avg_`outcome' = -`infinity_`outcome'' if avg_`outcome' == -`inf'
						if `point_est' == `inf' local point_est = `infinity_`outcome''
						if `point_est' == -`inf' local point_est = -`infinity_`outcome''
					}
				}

				* COLLAPSE DRAWS TO GET BOOTSTRAPPED ESTIMATES
				* For mvpf change relevant percentiles depending on % draws in missing quadrant
				local p_low = 2.5
				local p_high = 97.5
				if "`outcome'" == "mvpf" {
					count if avg_`outcome' ==.
					local n1 = r(N)
					if "`quadrant'"=="NE" count if mean_wtp <0 & mean_cost<0
					else if "`quadrant'"=="SW" count if mean_wtp >0 & mean_cost >0
					else di as error "Something went wrong"
					local n2 = r(N)
					assert `n1' == `n2'

					count
					local n3 = r(N)
					local prop = `n1'/`n3'
					* what pctiles to use for the CIs once we account for the draws that fall in the missing quadrant
					local p_low = (5 - 100*`prop')/2
					local p_high = 100 - `p_low'
				}
				if `p_low' <= 0 {
					local l_avg_`outcome' = -1
					local u_avg_`outcome' = 6
				}
				else {
					_pctile avg_`outcome', p(`p_low' `p_high')
					local l_avg_`outcome' = r(r1)
					local u_avg_`outcome' = r(r2)
				}


				*ESTIMATE EFRON BIAS-CORRECTED CIS
				*Estimate d(alpha) = F^-1(Phi(2z_0 + z_alpha)) - new upper and lower CIs
				*z_alpha = Phi^-1(alpha)
				*z_0 = Phi^-1(F(x))
				*x: point estimate
				*F(): bootstrap distribution

				su avg_`outcome'
				local dist_sd = r(sd)
				if `dist_sd' > 0.0000001 & `p_low'>0 & `dist_sd' !=0{ // only do this when we have distributions - have run into issues where the sd for some reason isn't exactly 0 but there is clearly no variation so compare to very small number instead of 0 
					sort avg_`outcome'
					*get pctile of point estimate in bootstrap distribution
					gen pctile = _n/`replications'
					count if (`point_est' == avg_`outcome')
					if `=r(N)' > 0 {
						su pctile if (`point_est' == avg_`outcome')
						if `=r(min)' > 0.5 local point_est_pctile = `=r(min)'
						if `=r(max)' < 0.5 local point_est_pctile = `=r(max)'
						if inrange(0.5,`=r(min)',`=r(max)') local point_est_pctile = 0.5
					}
					else {
						su pctile if (`point_est' <= avg_`outcome')
						local upper_p = r(min)
						su pctile if (`point_est' >= avg_`outcome')
						local lower_p = r(max)
						local point_est_pctile = (`lower_p' + `upper_p')/2
					}

					local l = 0
					local alpha1 = `p_low'/100
					local alpha2 = `p_high'/100
					foreach alpha in `alpha1' `alpha2' {
						local ++l
						local z_alpha = invnormal(`alpha')
						local z_0 = invnormal(`point_est_pctile')
						local new_alpha_`l' = normal(`z_alpha' + 2*`z_0')
						di `=`new_alpha_`l''*100'

						_pctile avg_`outcome', p(`=`new_alpha_`l''*100')
						local d_`l' = `r(r1)'

					}
				}
				else if `dist_sd' == 0 & `p_low' > 0 {
					su avg_`outcome'
					local pe = r(mean)
					foreach var in l_avg_`outcome' u_avg_`outcome' d1 d2 {
						local `var' = `pe'
					}
				}
				else if `p_low' <=0 {
					local l_avg_`outcome' = -`infinity_`outcome''
					local u_avg_`outcome' = `infinity_`outcome''
					local d_1 = -`infinity_`outcome''
					local d_2 = `infinity_`outcome''
				}

				clear
				set obs 1
				gen `group_var' = "`type'"
				if strpos("`outcome'", "mvpf") g infinity_`group_var'_`outcome' = `infinity_`outcome''
				gen avg_`group_var'_`outcome' = `point_est'
				foreach age in age_stat age_benef inc_stat inc_benef {
					g avg_`group_var'_`age' = `avg_`age''
				}
				foreach bound in l_avg u_avg {
					g `bound'_`group_var'_`outcome' = ``bound'_`outcome''
				}
				if `dist_sd'>0 {
					cap gen l_avg_`group_var'_`outcome'_ef = `d_1'
					cap gen u_avg_`group_var'_`outcome'_ef = `d_2'
				}


				local ++i
				tempfile temp_est`i'
				save `temp_est`i'', replace
			}

			use `temp_est1', clear
			forval j = 2/`i' {
				*di `j'
				append using `temp_est`j''
			}

			tempfile `group_var'_`outcome'
			save ``group_var'_`outcome'', replace
		}
	}
}

*Merge all back together
use `master_base'
foreach group in `groups' {
	foreach outcome in `outcomes' {
		if "`outcome'"=="w_on_pc"&"`group'"!="prog_type" continue
		merge m:1 `group' using ``group'_`outcome'', nogen
	}
}

drop if prog_type == ""
drop if program == ""

ren *cba* *cbr*
cap ren *efron *ef

*Set up age stagger for when needed
local stagger_scale 0.8
foreach type in stat benef {
	sort prog_type age_`type' program
	by prog_type age_`type' : g stagger_num = _n
	by prog_type age_`type' : egen stagger_mean = mean(stagger_num)
	g stagger = (stagger_num - stagger_mean) * `stagger_scale'
	g stagger_age_`type' = age_`type' + stagger
	drop stagger stagger_num stagger_mean
}

bys prog_type : egen avg_prog_type_year_imp = mean(year_implementation) if !mi(avg_prog_type_mvpf)

if "`compile_type'"!="robustness" {
	save "${data_derived}/all_programs_`sample's_corr_`corr'_unbounded_averages.dta", replace
	ren infinity infinity_mvpf
	ds avg*mvpf mvpf 
	local varlist `r(varlist)'
	foreach var in `varlist' {
		local var_group = subinstr("`var'", "avg_","",.)
		foreach var2 in `var' l_`var' u_`var' l_`var'_ef u_`var'_ef {
			*di "`infinity_`var_group''"
			replace `var2' = 5 if (`var2'>5 & `var2'<infinity_`var_group' & `var2'!=.)
			replace `var2' = 6 if `var2' == infinity_`var_group' & `var2'!=.
			replace `var2' = -1 if `var2'<-1 & `var2'!=.
		}
	}

	drop infinity*
	save "${data_derived}/all_programs_`sample's_corr_`corr'.dta", replace
} 
else {
	g robust_spec = "`rspec_type_`loop'': `rspec_val_`loop''"
	tempfile rob_`loop'_`sample'
	save `rob_`loop'_`sample''
	local max_loop `loop'
}
}
}
if "`compile_type'"=="robustness" {
	foreach sample in baseline extended restricted {
		use `rob_1_`sample'', clear
		forval z = 2/`max_loop' {
			append using `rob_`z'_`sample''
		}
		save "${data_derived}/all_programs_`sample's_`compile_type's_corr_`corr'_unbounded_averages.dta", replace
		ren infinity infinity_mvpf
		ds avg*mvpf mvpf 
		local varlist `r(varlist)'
		foreach var in `varlist' {
			local var_group = subinstr("`var'", "avg_","",.)
			foreach var2 in `var' l_`var' u_`var' l_`var'_ef u_`var'_ef {
				*di "`infinity_`var_group''"
				replace `var2' = 5 if (`var2'>5 & `var2'<infinity_`var_group' & `var2'!=.)
				replace `var2' = 6 if `var2' == infinity_`var_group' & `var2'!=.
				replace `var2' = -1 if `var2'<-1 & `var2'!=.
			}
		}

		drop infinity*
		save "${data_derived}/all_programs_`sample's_`compile_type's_corr_`corr'.dta", replace
	}
}
}
