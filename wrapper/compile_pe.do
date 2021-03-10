********************************************************************************
* 	Compile robustness point estimate results
********************************************************************************

* Set file paths
global welfare_dropbox "${welfare_files}"
global assumptions "${welfare_dropbox}/MVPF_Calculations/program_assumptions"
global program_folder "${welfare_git}/programs/functioning"
global ado_files "${welfare_git}/ado"
global data_derived "${welfare_dropbox}/Data/derived"
global input_data "${welfare_dropbox}/data/inputs"
global output "${welfare_dropbox}/figtab/scratch"
cap mkdir "$output"

*Set compile types
local compile_types corrected_mode_4 corrected_mode_1

*Set compile types if running externally
if "`1'"=="all_modes" local compile_types robustness_pe corrected_mode_1 corrected_mode_4
else if "`1'"!="" local compile_types "`1'"


foreach compile_type in `compile_types' {
	*get relevant files
	if "`compile_type'" == "robustness_pe" {
		local files : dir "${data_derived}" files "*_robustness_pe_estimates.dta"
		local samples baseline extended restricted

	}
	if "`compile_type'" == "corrected_mode_1" {
		local files : dir "${data_derived}/corrected/MLE/mode_1" files "*_baseline_unbounded_estimates_0_replications.csv"
		local mode 1
		local samples baseline extended restricted

	}
	if "`compile_type'" == "corrected_mode_4" {
		local files : dir "${data_derived}/corrected/MLE/mode_4" files "*_baseline_unbounded_estimates_0_replications.csv"
		local mode 4
		local samples baseline extended restricted
	}

	local i = 0
	foreach file in `files' {
		local ++i
		if "`compile_type'" == "robustness_pe" use "${data_derived}/`file'", clear
		else import delimited "${data_derived}/corrected/MLE/mode_`mode'/`file'", clear
		renvars * ,lower
		if "`compile_type'" == "robustness_pe" {
			*Get discount rate from assumption
			g disc_rate_temp = substr(assumptions, ///
					strpos(assumptions,"discount_rate: ")+strlen("discount_rate: "), ///
					strpos(substr(assumptions,strpos(assumptions,"discount_rate: "),.),",")- strlen("discount_rate: ")-1)

			destring disc_rate_temp, replace
			g disc_rate = ""
			foreach j in ".01" ".03" ".05" ".07" ".1" ".15" {
				replace disc_rate = "`j'" if round(disc_rate_temp,0.01)==`j'
			}
			drop disc_rate_temp

			*Get tax rate from assumptions
			g tax_rate_temp = substr(assumptions, ///
					strpos(assumptions,"tax_rate_cont: ")+strlen("tax_rate_cont: "), ///
					strpos(substr(assumptions,strpos(assumptions,"tax_rate_cont: "),.),",")- strlen("tax_rate_cont: ")-1)

			destring tax_rate_temp, replace
			levelsof tax_rate_temp, local(rates)
			g tax_rate = ""
			foreach j in ".1" ".15" ".2" ".3"  {
				replace tax_rate = "`j'" if round(tax_rate_temp,0.01)==`j'
			}
			drop tax_rate_temp


			gen wage_growth_rate = ""
			foreach j in "0" ".005" {
				replace wage_growth_rate = "`j'" if regexm(assumptions, "wage_growth_rate: `j'")
			}
		}
		cap drop inc_* // not used anyway and were causing issues in the append (byte/string mismatch)

		tempfile temp`i'
		save `temp`i''
	}
	use `temp1', clear
	forval j = 2/`i' {

		append using `temp`j''

	}

	preserve
		import excel "${welfare_files}/MVPF_Calculations/Further program details.xlsx", clear first
		replace program = lower(program)
		drop if program==""
		tempfile more_details
		save `more_details'
	restore
	replace program = lower(program)
	merge m:1 program using `more_details', keep(3) nogen
	drop if prog_type == "Top Taxes" & main_spec == 0 // even in extended sample exclude alternative top taxes

	tempfile all_programs

	save `all_programs'
	foreach sample in `samples' {
	use `all_programs', clear
		keep if prog_type!=""
		if inlist("`sample'", "baseline") keep if main_spec
		if "`sample'"=="restricted" keep if 	main_spec==1 & ///
											(earnings_type==""|earnings_type=="observed")
		else drop if prog_type == "Welfare Reform"
		merge m:1 program using "${data_derived}/all_programs_`sample's_corr_1.dta",  ///
		keepusing(has_ses p_val_range stagger_age_benef) ///
		assert(match using) keep(match)  nogen // using should just be abecedarian and job corps

		tab program
		duplicates report program, gen(specs)


		if "`compile_type'" == "robustness_pe" {
			order program *rate, first
			replace wage_growth_rate = ".000" if wage_growth_rate == "0"

			*Generate point ests for $1 spend avgs for each group

			g robust_type = substr(assumptions, ///
						strpos(assumptions,"robust_spec: ")+strlen("robust_spec: "), ///
						strpos(substr(assumptions,strpos(assumptions,"robust_spec: "),.),",")- strlen("robust_spec: ")-1)

			replace robust_type = "tax_rate" if robust_type=="tax_rate_cont"
			replace robust_type = "disc_rate" if robust_type=="discount_rate"

			replace tax_rate="" if robust_type!="tax_rate"
			replace disc_rate="" if robust_type!="disc_rate"
		}
		tempfile base
		save `base'
		if "`compile_type'" == "robustness_pe" {
			foreach var in tax_rate disc_rate {
				levelsof `var'
				foreach lev in `r(levels)' {
					preserve
						cap drop n_cost
						cap drop n_wtp

						keep if prog_type != "" & `var'=="`lev'" & robust_type=="`var'"
						keep if has_ses & p_val_range == 0 // no program has_ses in robustness or corrected, but restrict to same sample as other domain avgs

						*Collapse to estimate group means
						g n_wtp = wtp / program_cost
						g n_cost = cost / program_cost
						g count_temp = 1

						collapse (mean) n_wtp n_cost age_benef age_stat (rawsum) count_temp, by(prog_type robust_type)

						gen avg_mvpf = min(n_wtp/n_cost, 5) if ((n_wtp>0 & n_cost >0)|(n_wtp<0 & n_cost <0)) & count_temp >1
						replace avg_mvpf = 6 if (n_wtp >= 0 & n_cost <=0) & count_temp >1
						replace avg_mvpf = max(-1, n_wtp/n_cost) if (n_wtp<=0 & n_cost>=0) & count_temp >1
						foreach avg_var in n_cost n_wtp age_benef age_stat {
							replace `avg_var' = . if count_temp <=1
						}

						keep prog_type avg_mvpf n_cost n_wtp age_benef age_stat robust_type
						ren age_stat avg_prog_type_age_stat
						ren age_benef avg_prog_type_age_benef
						g `var'="`lev'"
						tempfile means
						save `means', replace

					restore

					merge m:1 prog_type robust_type `var' using `means', nogen update
				}
			}
		}
		else {
		preserve
			cap drop n_cost
			cap drop n_wtp

			keep if prog_type != ""
			keep if has_ses & p_val_range==0 // no program has_ses in robustness or corrected, but restrict to same sample as other domain avgs

			*Collapse to estimate group means
			g n_wtp = wtp / program_cost
			g n_cost = cost / program_cost
			g count_temp = 1
			collapse (mean) n_wtp n_cost age_benef age_stat (rawsum) count_temp, by(prog_type)

			local inf 99999
			gen avg_mvpf = n_wtp/n_cost if ((n_wtp>0 & n_cost>0) |(n_wtp<0 & n_cost<0)) & count_temp >1
			replace avg_mvpf = n_wtp/n_cost if (n_wtp<=0 & n_cost>0) & count_temp >1
			su avg_mvpf
			local inf = max(99999,abs(r(max)),abs(r(min)))
			replace avg_mvpf = `inf' if (n_wtp > 0 & n_cost <=0)
			replace avg_mvpf = -`inf' if (n_wtp<0 & n_cost == 0)

			g infinity_prog_type_mvpf = `inf'

			keep prog_type avg_mvpf n_cost n_wtp age_benef age_stat infinity_prog_type_mvpf
			ren age_stat avg_prog_type_age_stat
			ren age_benef avg_prog_type_age_benef
		tempfile means
		save `means', replace
		restore

		merge m:1 prog_type using `means', nogen update

		}
		ren avg_mvpf avg_prog_type_mvpf
		ren n_cost avg_prog_type_c_on_pc
		ren n_wtp avg_prog_type_w_on_pc


		duplicates tag program, gen(specs)
		su specs
		assert specs == r(max)
		drop specs
		if "`compile_type'" == "robustness_pe" {
			assert robust_type!=""
			assert tax_rate!="" if robust_type=="tax_rate_cont"
			assert disc_rate!="" if robust_type=="discount_rate"
		}

		*save unbounded
		if "`sample'" == "baseline" save "${data_derived}/all_programs_`compile_type'_corr_1_unbounded_averages.dta", replace
		else save "${data_derived}/all_programs_`compile_type'_`sample's_corr_1_unbounded_averages.dta", replace

		* bound mvpf
		foreach var in mvpf avg_prog_type_mvpf {
			if "`var'" == "mvpf" local inf_var infinity
			else local inf_var infinity_prog_type_mvpf
			replace `var' = min(`var', 5) if `var' != `inf_var' & !mi(`var')
			replace `var' = 6 if `var' >5 & !mi(`var')
			replace `var' = max(-1,`var') if !mi(`var')
			}
		if "`sample'" == "baseline" save "${data_derived}/all_programs_`compile_type'_corr_1.dta", replace
		else save "${data_derived}/all_programs_`compile_type'_`sample's_corr_1.dta", replace
		}
}
