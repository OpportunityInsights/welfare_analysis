global output "${output_root}/scatter"
clear
local files : dir "${data_derived}" files "wtw_*_normal_estimates_1000_replications.dta"

foreach file in `files' {
	local cleanfile = subinstr("`file'","","",.)
	local wtw `wtw' `cleanfile'
}
local i = 0
foreach file in `wtw' {
	local ++i
	if `i' == 1 {
		use "${data_derived}/`file'", clear
	}
	else {
		append using "${data_derived}/`file'"
	}
}
renvars * , lower
drop if program == "wtw_mills"
drop mvpf
g mvpf = min(5, wtp/cost) if wtp/cost >0
replace mvpf = 6 if cost <=0 & wtp>0
replace mvpf = max(-1, wtp/cost) if wtp<0 & cost>0

g wtp_valuation = ""
foreach val in "cost" "post tax" "transfer change" {
	replace wtp_valuation = "`val'" if strpos(assumptions, "wtp_valuation: `val'")
}
g wtw_cat = ""
local name_educ "Mandatory Education"
local name_earnsupp "Earnings Supplements"
local name_jobsearch "Job Search First"
local name_mixed "Mixed Programs"
local name_timelim "Time Limits"
local name_workexp "Mandatory Work Experience"
foreach cat in educ earnsupp jobsearch mixed timelim workexp {
	replace wtw_cat = "`name_`cat''" if strpos(program, "`cat'")
}

sort wtp_valuation wtw_cat

g prog = _n

replace prog = . if wtp_valuation != "cost"
bys program: egen prog_num = mean(prog)
qui su prog_num
local last = r(max)
replace prog_num = prog_num +`last' if wtw_cat == "Earnings Supplements"
qui su prog_num
local last = r(max)
local first = r(min)
local xline ""
foreach cat in educ earnsupp jobsearch mixed timelim workexp {
	qui su prog_num if wtw_cat == "`name_`cat''"
	local line = r(max) + 0.5
	if `line' == `last' + 0.5 continue
	local xline =  "`xline'" + " `line'"
}
preserve
import excel "${welfare_files}/MVPF_Calculations/Further program details.xlsx", firstrow clear
drop if program == ""
tempfile details
save `details'
restore
merge m:1 program using `details', nogen keep(master match) keepusing(small_label_name)
merge m:1 program using  "${data_derived}/all_programs_baselines_corr_1.dta", nogen keep(master match) keepusing(age_benef prog_type)
labmask prog_num, val(small_label_name)
g num_stagger = prog_num
replace num_stagger = num_stagger - 0.2 if wtp_valuation == "cost"
replace num_stagger = num_stagger + 0.2 if wtp_valuation == "transfer change"
labmask num_stagger if num_stagger == prog_num, val(small_label_name)

qui su prog_num
local max = r(max)
tw (scatter mvpf num_stagger if wtp_valuation == "cost", mstyle(${style_Welfare_Reform}) ) ///
	(scatter mvpf num_stagger if wtp_valuation == "post tax", msymbol(triangle) mstyle(${style_Welfare_Reform})) ///
	(scatter mvpf num_stagger if wtp_valuation == "transfer change",msymbol(X) msize(large) mstyle(${style_Welfare_Reform}) ) ///
	, xlabel(`first'(1)`max', valuelabel angle(45) labsize(vsmall)) ///
	xtitle("") ytitle("MVPF") $ylabel legend(label(1 "Cost" ) ///
	label(2 "Post Tax Income") label(3 "Net Transfers") ring(0) col(1) ) ///
	legend(off) $title xline(`xline', lc(gs9) lp(dash))

	graph export "${output}/scatter_wtw_specs.${img}", replace


tw (scatter mvpf num_stagger if wtp_valuation == "cost", mstyle(${style_Welfare_Reform}) ) ///
	(scatter mvpf num_stagger if wtp_valuation == "post tax", msymbol(triangle) mstyle(${style_Welfare_Reform})) ///
	(scatter mvpf num_stagger if wtp_valuation == "transfer change",msymbol(X) msize(large) mstyle(${style_Welfare_Reform}) ) ///
	, xlabel(`first'(1)`max', valuelabel angle(45) labsize(vsmall)) ///
	xtitle("") ytitle("MVPF") $ylabel legend(label(1 "Cost" ) ///
	label(2 "Post Tax Income") label(3 "Net Transfers") ring(0) col(1) ) ///
	$title xline(`xline', lc(gs9) lp(dash))



	graph export "${output}/scatter_wtw_specs_LEGEND.${img}", replace

		g age = age_benef

	*Set up age stagger for when needed
	local stagger_scale 0.8
	set seed 503198
	gen stagger_rand = rnormal()
	sort prog_type age stagger_rand
	by prog_type age : gen stagger_num = _n
	by prog_type age : egen stagger_mean = mean(stagger_num)
	gen stagger = (stagger_num - stagger_mean) * `stagger_scale'
	gen stagger_age = age + stagger



	tw (scatter mvpf stagger_age if wtp_valuation == "cost",  mstyle(${style_Welfare_Reform}) mlabel(small_label_name) mlabstyle(${style_Welfare_Reform})) ///
	(scatter mvpf stagger_age if wtp_valuation == "post tax", msymbol(triangle) mstyle(${style_Welfare_Reform}) mlabel(small_label_name) mlabstyle(${style_Welfare_Reform}) ) ///
	(scatter mvpf stagger_age if wtp_valuation == "transfer change",msymbol(X) msize(large) mstyle(${style_Welfare_Reform}) mlabel(small_label_name) mlabstyle(${style_Welfare_Reform}) ) ///
	, $xlabel  ///
	xtitle("") $ytitle $ylabel legend(off)  ///
	$title $xtitle


	graph export "${output}/scatter_wtw_specs_age.${img}", replace
* Make "domain avg" by wtp method - note avg age doesn't get computed in compile baselines because all ses missing
	foreach est in wtp cost {
	replace `est' = `est'/program_cost
	}
collapse(mean) wtp cost age_benef, by(wtp_valuation)	
g mvpf = min(wtp/cost,5) if (wtp/cost>0 | wtp<0) // ok with lower left quadrant
replace mvpf =6 if cost<0 & wtp>=0
g label = "Welfare Reform - " + proper(wtp_valuation)
	tw (scatter mvpf age_benef if wtp_valuation == "cost",  mstyle(${style_Welfare_Reform}) mlabel(label) mlabstyle(${style_Welfare_Reform})) ///
	(scatter mvpf age_benef if wtp_valuation == "post tax", msymbol(triangle) mstyle(${style_Welfare_Reform}) mlabel(label) mlabstyle(${style_Welfare_Reform}) ) ///
	(scatter mvpf age_benef if wtp_valuation == "transfer change",msymbol(X) msize(large) mstyle(${style_Welfare_Reform}) mlabel(label) mlabstyle(${style_Welfare_Reform}) ) ///
	, $xlabel  ///
	xtitle("") $ytitle $ylabel legend(off)  ///
	$title $xtitle


	graph export "${output}/scatter_wtw_specs_age_avgs.${img}", replace
	replace label= "Welfare Reform"
	tw (scatter cost age_benef if wtp_valuation == "cost", msymbol(D) mstyle(${style_Welfare_Reform}) mlabel(label) mlabstyle(${style_Welfare_Reform})) ///
	, $xlabel  ///
	xtitle("") $ytitle ylabel(-2(2)2) legend(off)  ///
	$title $xtitle
		graph export "${output}/scatter_wtw_specs_c_on_pc_age_avgs.${img}", replace

	e
/*
keep mvpf program small_label_name wtp_valuation wtw_cat prog_num
preserve
	replace wtp_valuation = subinstr(wtp_valuation , " " , "_",.)
	reshape wide mvpf, i(program prog_num small_label_name) j(wtp_valuation) string
	tempfile valuations
	save `valuations'
restore
drop wtp_valuation
sort program mvpf
bys program: gen order = _n
reshape wide mvpf, i(program prog_num small_label_name wtw_cat) j(order)
merge 1:1 prog_num using `valuations', nogen assert(match)
tw (rcap mvpf1 mvpf3 prog_num, msize(*0.1) lcolor(gs8)) ///
	(scatter mvpfcost prog_num , mcolor(navy) ) ///
	(scatter mvpfpost_tax prog_num, mc(maroon) ) ///
	(scatter mvpftransfer_change prog_num, mc(dkgreen)) ///
	, xlabel(1(1)`max', valuelabel angle(45) labsize(vsmall)) ///
	xtitle("") ytitle("MVPF") $ylabel legend(label(1 "Cost" ) ///
	label(2 "Post Tax Income") label(3 "Net Transfers") ring(0) col(1) ) ///
	legend(off) $title xline(`xline', lc(gs9) lp(dash))
	
graph export "${output}/scatter_wtw_specs_connected.${img}", replace
tw (rcap mvpf1 mvpf3 prog_num) (scatter mvpf2 prog_num, color(navy)) ///
	, xlabel(1(1)`max', valuelabel angle(45) labsize(vsmall)) ///
	xtitle("") ytitle("MVPF") $ylabel legend(label(1 "Cost" ) ///
	label(2 "Post Tax Income") label(3 "Net Transfers") ring(0) col(1) ) ///
	legend(off) $title xline(`xline', lc(gs9) lp(dash))
	
graph export "${output}/scatter_wtw_specs_rcap.${img}", replace
