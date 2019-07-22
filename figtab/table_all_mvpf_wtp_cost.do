********************************************************************************
* 	Table for all programs wtp/cost/mvpf
********************************************************************************
global output "${welfare_files}/figtab/tables"
cap mkdir "$output"

use "${data_derived}/all_programs_extendeds_corr_1_unbounded_averages.dta", clear

drop if inlist(prog_type, "Welfare Reform")
replace prog_type = "MTO" if regexm(prog_type, "MTO") 

*Get averages from baseline sample
drop *avg_prog_type*
preserve
	use "${data_derived}/all_programs_baselines_corr_1_unbounded_averages.dta", clear
	keep prog_type *avg_prog_type*
	duplicates drop
	tempfile new_avgs
	save `new_avgs'
restore
merge m:1 prog_type using `new_avgs'

* rename the averages for convenience
ren *avg_prog_type_* **_avg
ren infinity_prog_type_mvpf infinity_avg


sort group prog_type long_description
order group prog_type label_name mvpf l_mvpf_ef u_mvpf_ef w_on_pc l_w_on_pc u_w_on_pc c_on_pc ///
	l_c_on_pc u_c_on_pc program_cost, first

local round_to = 0.01

*Drop non-sample MTO & taxes
drop if prog_type=="Top Taxes" & main_spec==0
drop if regexm(prog_type,"MTO") & main_spec==0


*Format MVPFs
foreach suff in "_avg" ""  {

	tostring infinity`suff', replace force
	foreach var in mvpf l_mvpf_ef u_mvpf_ef {
		replace `var'`suff' = round(`var'`suff',`round_to')
		
		tostring `var'`suff', replace force format(%12.2f)
		
		replace `var'`suff' = "`=uchar(8734)'" if `var'`suff'==infinity`suff'+".00"
		replace `var'`suff' = "-`=uchar(8734)'" if `var'`suff'=="-"+infinity`suff'+".00"
	}
	g mvpf_ci`suff' = "["+l_mvpf_ef`suff'+", "+u_mvpf_ef`suff'+"]"
	if "`suff'" == "" replace mvpf_ci = "" if has_ses==0 | mvpf_ci=="[., .]"
	//note need the if condition because stata will think you are using a shortcut 
	*for the avg if the ci for the point estimate hasn't been generated yet
	
	*Format wtp/cost
	foreach var in w_on_pc c_on_pc {
		foreach subvar in `var' l_`var' u_`var' {
			if "`suff'" =="" replace `subvar'`suff' = `subvar'`suff'
			tostring `subvar'`suff', replace force format(%12.2f)
		}
		g `var'_ci`suff' = "["+l_`var'`suff'+", "+u_`var'`suff'+"]"
		if "`suff'" == "" {
			replace `var'_ci = "" if has_ses==0
			replace `var'_ci = "" if has_ses & `var'_ci=="[., .]"
		}
	}
}

*Order groups
g group_order = 0
replace group_order = 1 if group=="Education"
replace group_order = 2 if group=="Social Insurance"
replace group_order = 3 if group=="In Kind Transfers"
replace group_order = 4 if group=="Taxes"
replace group_order = 5 if group=="Welfare Reform"

sort group_order prog_type long_description
g correct_order = _n

foreach g in group prog_type {
	bys `g' : egen min_temp = min(correct_order)
	replace `g' = "" if correct_order != min_temp
	drop min_temp
}

*Note programs not in averages as p value ranges
foreach var in mvpf w_on_pc c_on_pc {
	replace `var'_ci = `var'_ci+"*" if p_val_range & !mi(`var'_ci)
}
sort correct_order

*Order variables
drop group
local vars_ordered  prog_type small_label_name mvpf mvpf_ci w_on_pc w_on_pc_ci c_on_pc c_on_pc_ci main_spec
* names of variables for the avgs
local avg_mvpf avg_
order `vars_ordered', first
keep `vars_ordered' mvpf_avg mvpf_ci_avg w_on_pc_avg w_on_pc_ci_avg c_on_pc_avg c_on_pc_ci_avg

*Introduce panel breaks
cap drop correct_order
g correct_order = _n
expand 2, gen(id)
sort correct_order id
replace id =-1 if prog_type!="" & id == 1
keep if id <1

replace small_label_name = prog_type if id==-1
gsort correct_order id

ds small_label_name prog_type main_spec id correct_order *_avg, not

foreach var in `r(varlist)' {
	replace `var' = `var'_avg if id == -1
	cap replace `var' = "" if id == -1 & prog_type == "MTO"
	cap replace `var' = . if id == -1 & prog_type == "MTO"
}
replace main_spec = . if id == -1
* add blank lines between categories
cap drop correct_order
g correct_order = _n

expand 2 if id == -1, gen(id2)
gsort correct_order -id2

ds id2 correct_order id, not
foreach var in `r(varlist)' {
	cap replace `var' = "" if id2 == 1 
	cap replace `var' = . if id2 == 1 

}

drop prog_type
gsort correct_order id -id2

keep small_label_name mvpf mvpf_ci w_on_pc w_on_pc_ci c_on_pc c_on_pc_ci main_spec
tostring main_spec, replace
replace main_spec = "x" if main_spec=="1"
replace main_spec = "" if main_spec!="x"

label var small_label_name

export excel  "${output}/table_all_mvpf_wtp_cost_cis.xlsx", sheetmodify sheet("RAW")
