********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

* Set file paths
global output "${output_root}/cost_decomposition"
global output_wtp "${output_root}/wtp_decomposition"
cap mkdir "${output}"
cap mkdir "${output_wtp}"

local basecolour = "${basecolour}"
local secondcolour = "${secondcolour}"
local finalcolour = "${finalcolour}"


*FIU Cost Decomposition:
run_program fiu
clear 
set obs 10
g xaxis = _n
*DATA INPUT:
	gen cost = ${fiu_total_cost} in 1 // total FIU cost
	replace cost = -${fiu_student_contribution} in 2 // Student contribution
	replace cost =  ${fiu_net_pub_spend} in 3 // FE via CC
	replace cost = -${fiu_tax_short} in 4 // ages 19-25 earnings
	replace cost = -${fiu_tax_med} in 5 // ages 26-33 earnings
	replace cost = -${fiu_tax_proj} in 6 // Projected 34+ earnings
count if cost != .
local items = r(N)

*Get CI for final cost
preserve
	use "${data_derived}/all_programs_baselines_corr_1.dta", clear
	keep if program == "fiu"
	foreach var in cost l_cost u_cost {
		su `var'
		local fiu_`var' = r(mean)
	}
restore

replace cost = cost/1000

local program_cost = cost[1]
local scale_interval = `program_cost'/5
tsset xaxis
gen start_cost = 0

forval i = 2/`items' {
	replace start_cost = L.start_cost + L.cost in `i'
}
g l_cost = `fiu_l_cost'/1000 in `items'
g u_cost = `fiu_u_cost'/1000 in `items'

gen finish_cost = start_cost + cost
gen xshift = xaxis + 1
gen label = "$"+ string(cost, "%4.1f")+"K"
gen finish_label = "$"+ string(finish_cost, "%4.1f")+"K"

local blue = "${basecolour}"
local red = "${secondcolour}"
local green = "${finalcolour}"

su finish_cost
di `fiu_cost'/1000
assert abs(r(min)-`fiu_cost'/1000)<0.01

tw 	(bar cost xaxis if xaxis==1, barw(0.6) lcolor(%0) color("`red'")) /// initial
	(bar start_cost xaxis if inrange(xaxis,2,3)|inrange(xaxis,5,6), barw(0.6) lcolor(white%0) color("`blue'")) /// savings
	(bar finish_cost xaxis if inrange(xaxis,2,3)|inrange(xaxis,5,6),  barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xaxis in 4,  barw(0.6) lcolor(white%0) color("`red'")) ///
	(bar start_cost xaxis in 4, barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xaxis if inrange(xaxis,5,6), barw(0.6) lcolor(white%0) color("`blue'")) ///
	(bar start_cost xaxis if xaxis==6, barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xshift in `items', barw(0.6) lcolor(%0) color("$finalcolour")) ///
	(scatter cost xaxis if  xaxis==1, mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(12) mlabs(small)) ///
	(scatter finish_cost xaxis if  xaxis==4, mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(12) mlabs(small)) ///
	(scatter finish_cost xaxis if inrange(xaxis,2,3)|inrange(xaxis,5,6), mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(6) mlabs(small)) ///	
	(scatter finish_cost xshift in `items', mlab(finish_label) msym(none) mlabc("$tc") ///
		mlabpos(6) mlabs(small)) ///
	///(rcap l_cost u_cost xshift in `items', lcolor(gs7) ) /// 
	(function y =0, lcolor(gs8%60) lwidth(thin) range(0.5 `=`items'+1.5')) ///
	, ///
 	///yline(0, lcolor(gs8%50) lpattern(-)) ///
	ylabel( 15 "15K" 0 -15 "-15K" -30 "-30K"  , nogrid) ///
	xlabel(1(1)`items') ///
	ytitle("Government Costs ($)") ///
	${title}  ///
	xlabel( ///
	1 `""Total" "FIU cost""' ///
	2 `""Student" "contribution""' ///
	3 `""Community" "college exp.""' ///
	4 `""Taxes from" "age 19-25" "earnings""' ///
	5 `""Taxes from" "age 26-33" "earnings""' ///
	6 `""Taxes from" "projected" "earnings""' ///
	`=`items'+1' `""Net cost to""government""' , labsize(small)) ///
	legend(off)

graph export "${output}/fiu_cost_decomposition.${img}", replace


*FIU WTP decomposition:
run_program fiu
clear
set obs 10
gen xaxis = _n
*DATA INPUT:
	local program_cost = ${program_cost_fiu}
	gen wtp = ${fiu_lbwtp} in 1 // "lower bound"
	replace wtp = -${fiu_priv_cost} in 2 // private costs
	replace wtp = ${fiu_short_post_tax}  in 3 // initial earnings loss
	replace wtp = ${fiu_med_post_tax} in 4 // observed earnings gain
	replace wtp = ${fiu_long_post_tax} in 5 // projected earnings gain
	replace wtp = ${WTP_fiu} in 6 //total wtp
	replace wtp = . in 7 // "lower bound"
	replace wtp = wtp / 1000
	g wtp2 = wtp
	
forval i = 3(1)5 {
	replace wtp2 = wtp2 + wtp2[`i'-1] in `i'
}

*Get CI for final WTP
preserve
	use "${data_derived}/all_programs_baselines_corr_1.dta", clear
	keep if program == "fiu"
	foreach var in wtp l_wtp u_wtp {
		su `var'
		local fiu_`var' = r(mean)
	}
restore

g white_out = wtp2 - wtp
count if wtp != .
drop if wtp == .

*Add rcap bars for 95% CI on total WTP
su xaxis
gen need_ci = xaxis==r(max)
g l_wtp = `fiu_l_wtp'/1000
g u_wtp = `fiu_u_wtp'/1000 
su wtp2
assert abs(`fiu_wtp'/1000 - r(max))<0.001

gen label = "$"+ string(wtp, "%4.1f")+"K"

replace xaxis = 0.8 in 1

tw 	(scatter wtp xaxis if xaxis<1, mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(12)) /// lower bound
	(bar wtp xaxis if xaxis<1, barwidth(0.6)  lcolor(%0) color("${finalcolour}"))  ///
	(bar wtp xaxis if xaxis==6, barwidth(0.6)  lcolor(%0) color("${finalcolour}"))  ///
	(bar wtp2 xaxis if wtp>=0 & inrange(xaxis,2,5), barwidth(0.6)  lcolor(%0) color("`blue'")) ///
	(bar wtp2 xaxis if wtp<0 & inrange(xaxis,2,5), barwidth(0.6)  lcolor(%0) color("`red'")) ///
	(bar white_out xaxis if inrange(xaxis,4,5), color(white) barwidth(0.6)) ///
	(bar white_out xaxis if wtp<0, color(white) barwidth(0.6)) ///
	(bar white_out xaxis if xaxis==4, color("${basecolour}")  lcolor(%0) barwidth(0.6)) ///
	(scatter wtp2 xaxis if inrange(xaxis,4,5), mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(12)) ///
	(scatter wtp2 xaxis if inrange(xaxis,2,3), mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(6)) ///
	(scatter wtp xaxis if xaxis==6, mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(12)) ///
	///(rcap l_wtp u_wtp xaxis if need_ci, lcolor(gs7) ) /// 
	(function y =0, lcolor(gs8%60) lwidth(thin) range(0.3 `=6.5')) ///
	, ///
	ylabel(-25 "-25K" 0 50 "50K" 100 "100K" , valuelabel) ///
	legend(off) ytitle("WTP ($)") xtitle("")  ylabel(,nogrid notick) ///
	xlabel( ///
	2 `""Private tuition""payments""' ///
	3 `""Age 19-25""after-tax" "earnings""' ///
	4 `""Age 26-33""after-tax" "earnings""' ///
	5 `""Age 34+""after-tax" "earnings""' ///
	6 `""Baseline" "WTP""' ///
	0.8 `""WTP via""private tuition""payments""' ///
	, labsize(small) notick ) ///
	xline(1.4, lcolor(gs8%50) lpattern(-)) ///
	///note("Lower Bound WTP", ring(0) pos(10) size(small)) ///
	 $title
graph export "${output_wtp}/fiu_wtp_decomposition.${img}", replace




*Miller Wherry costs:
clear
run_program mc_preg_women
set obs 10
gen xaxis = _n
*DATA INPUT:
	gen cost = ${mw_unadjusted_cost}  in 1 //unadjusted total costs
	replace cost = -${mw_mum_tax_impact}  in 2 // mother lfp impact
	replace cost = -${mw_eligibility_adjustment} in 3 // adjusted for eligibility
	replace cost = -${mw_hosp_cost}  in 4 // hospitalisation costs
	replace cost = ${mw_college_cost}  in 5 // college costs
	replace cost = -${mw_tax_save} in 6 // tax rev
	
count if cost != .
local items = r(N)

local program_cost = cost[1]
local scale_interval = `program_cost'/5
tsset xaxis
gen start_cost = 0

forval i = 2/`items' {
	replace start_cost = L.start_cost + L.cost in `i'
	
}

gen finish_cost = start_cost + cost
gen xshift = xaxis + 1
gen label = "$"+ string(cost, "%4.0f")
gen finish_label = "$"+ string(finish_cost, "%4.0f")

local max_cost = finish_cost[2]
drop if cost == .

*Get CI for final cost
preserve
	use "${data_derived}/all_programs_baselines_corr_1.dta", clear
	keep if program == "mc_preg_women"
	foreach var in cost l_cost u_cost {
		su `var'
		local mw_`var' = r(mean)
	}
restore

su xaxis
g need_ci = xaxis==r(max)
g l_cost = `mw_l_cost'
g u_cost = `mw_u_cost'
su finish_cost 
di `mw_cost'
assert abs(`mw_cost'-r(min))<1

drop if cost==.

tw 	(bar cost xaxis in 1, barw(0.6) lcolor(%0) color("${secondcolour}")) /// program cost
	(bar finish_cost xaxis if cost > 0 , barw(0.6) lcolor(%0) color("${secondcolour}")) /// mother lfp impact
	(bar start_cost xaxis if cost > 0 , barw(0.62) lcolor(%0) color(white)) /// mother lfp impact
	(bar start_cost xaxis if cost < 0, barw(0.6) lcolor(white%0) color("${basecolour}")) ///
	(bar finish_cost xaxis if cost < 0, barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xaxis in `items', barw(0.6) lcolor(%0) color("${basecolour}")) ///
	(bar finish_cost xshift in `items', barw(0.6) lcolor(%0) color("${finalcolour}")) ///
	(scatter finish_cost xaxis if cost > 0, mlab(label) mlabs(small) msym(none) mlabc("$tc") ///
		mlabpos(12)) ///
	(scatter finish_cost xaxis if cost < 0, mlab(label) mlabs(small) msym(none) mlabc("$tc") ///
		mlabpos(6)) ///
	(scatter finish_cost xshift in `items', mlab(finish_label)  mlabs(small) msym(none) mlabc("$tc") ///
		mlabpos(6)) ///
	///(rcap l_cost u_cost xshift if need_ci, lcolor(gs7) ) /// 
	(function y =0, lcolor(gs8%60) lwidth(thin) range(0.5 7.5)) ///
	,  ///
	ylabel(-7500 "-7.5K" -5000 "-5K"  -2500 "-2.5K" 0 2500 "2.5K" 5000 "5K", nogrid  ) ///
	ytitle("Government Costs ($)") ///
	${title}  ///
	xlabel( ///
	1 `""Program" "Costs""' ///
	2 `""Taxes from""reduced" "mother""earnings""' ///
	3 `""Govt." "spending on" "uncompensated""care""' ///
	4 `""Age 19-65" "health" "costs""'  ///
	5 `""Govt." "college""costs""' ///
	6 `""Taxes" "from future" "earnings""' ///
	`=`items'+1' `""Net Cost To""Government""', labsize(small) notick) ///
	legend(off) 

graph export "${output}/MW_cost_decomposition.${img}", replace




*Miller Wherry WTP decomposition:
clear
run_program mc_preg_women
set obs 10
gen xaxis = _n
*DATA INPUT:
	g wtp = ${mw_par_crowd_out}  in 1 // crowd out savings
	replace wtp = ${mw_vsl_ben}  in 2 // value life saved
	replace wtp = -${mw_coll_priv_cost}  in 3 // induced private college costs
	replace wtp = ${mw_earn_ben_obs} in 4 // earnings benef 14 years
	replace wtp = ${mw_earn_ben_proj} in 5 // earnings benef beyond 14 years
	replace wtp = 0 in 6
	replace wtp = wtp / 1000
g t = _n
tsset t
g tot_wtp = wtp 
su t 
forval i = 2/`=r(max)' {
	replace tot_wtp = wtp + L.tot_wtp in `i'
}
replace tot_wtp = wtp if t == 1
g white_out = tot_wtp - wtp

count if wtp != .
drop if wtp == .

g second_axis = -0.2 in 1

*Add rcap bars for 95% CI on total WTP
g final = _n==_N

*Get CI for final WTP
preserve
	use "${data_derived}/all_programs_baselines_corr_1.dta", clear
	keep if program == "mc_preg_women"
	foreach var in wtp l_wtp u_wtp {
		su `var'
		local mw_`var' = r(mean)
	}
restore

*Add rcap bars for 95% CI on total WTP
su xaxis
g l_wtp = `mw_l_wtp'/1000 if final
g u_wtp = `mw_u_wtp'/1000  if final
su tot_wtp
assert abs(`mw_wtp'/1000-r(max))<0.0001

gen label = "$"+ string(wtp, "%4.1f")+"K"
replace label = "$"+ string(tot_wtp, "%4.1f")+"K" if final

tw 	(bar tot_wtp xaxis if wtp > 0, barwidth(0.6) color("$basecolour") lcolor(%0))  ///
	(bar white_out xaxis if wtp > 0, barwidth(0.6) color(white))  ///
	(bar white_out xaxis if wtp < 0, barwidth(0.6) color("${secondcolour}") lcolor(%0))  ///
	(bar tot_wtp xaxis if wtp < 0, barwidth(0.6) color(white))  ///
	(bar tot_wtp xaxis if final, barwidth(0.6) color("$finalcolour") lcolor(%0)) ///
	(bar wtp xaxis if final, barwidth(0.6) color("$finalcolour") lcolor(%0)) ///
	(bar wtp second_axis, color("$finalcolour") lcolor(%0) barwidth(0.6)) ///
	(scatter tot_wtp xaxis if wtp >=0, mlab(label) msym(none) mlabc("$tc") mlabs(small) mlabpos(12)) ///
	(scatter tot_wtp second_axis if wtp >=0, mlab(label) msym(none) mlabc("$tc") mlabs(small) mlabpos(12)) ///
	(scatter tot_wtp xaxis if wtp <0, mlab(label) msym(none) mlabc("$tc")  mlabs(small) mlabpos(6)) ///
	///(rcap l_wtp u_wtp xaxis , lcolor(gs7)) ///
	(function y =0, lcolor(gs8%60) lwidth(thin) range(-0.7 6.5)) ///
	, ///
	legend(off) xtitle("") ylabel(,nogrid notick ) ytitle("WTP ($)") ///
	xlabel( ///
	-0.2  `" "Private" "Insurance""Crowd Out""WTP""' ///
	1 `" "Private" "Insurance""Crowd Out""' ///
	2 "VSL WTP" ///
	3 `""Private" "College" "Costs""' ///
	4 `""Age 23-36""after-tax" "earnings""' ///
	5 `""Age 37+""after-tax" "earnings" "' ///
	6 `""Baseline" "WTP"' ///
	, labsize(small) notick ) ///
	ytitle(`"WTP"', )  ///
	ylabel(0 15 "15K" 30 "30K" 45 "45K", valuelabel) ///
	xline(0.4, lcolor(gs8%50) lpattern(-)) ///
	$title
graph export "${output_wtp}/MW_wtp_decomposition.${img}", replace

/*

*CalGrant Cost Decomposition:
run_program Cal_Grant_GPA
clear 
set obs 10
g xaxis = _n

*DATA INPUT:
	gen cost = ${cal_gpa_grant} in 1 // initial Cal Grant Cost 
	replace cost = ${cal_gpa_ed_exp} in 2 // additional Ed Cost 
	replace cost =  -${cal_gpa_14y_tax} in 3 // Tax Revenue through Year 14
	replace cost = -${cal_gpa_life_tax} in 4 // tax revenue through lifecycle
count if cost != .
local items = r(N)

local cal_gpa_cost = ${cal_gpa_cost}

replace cost = cost/1000

local program_cost = cost[1]
local scale_interval = `program_cost'/5
tsset xaxis
gen start_cost = 0

forval i = 2/`items' {
	replace start_cost = L.start_cost + L.cost in `i'
}

gen finish_cost = start_cost + cost
gen xshift = xaxis + 1
gen label = "$"+ string(cost, "%4.1f")+"K"
gen finish_label = "$"+ string(finish_cost, "%4.1f")+"K"

local blue = "${basecolour}"
local red = "${secondcolour}"
local green = "${finalcolour}"

su finish_cost
di `cal_gpa_cost'/1000
*assert abs(r(min)-`cal_gpa_cost'/1000)<0.01

tw 	(bar cost xaxis if xaxis==1, barw(0.6) lcolor(%0) color("`red'")) /// initial
	(bar start_cost xaxis if inrange(xaxis,2,3)|inrange(xaxis,5,6), barw(0.6) lcolor(white%0) color("`blue'")) /// savings
	(bar finish_cost xaxis if inrange(xaxis,2,3)|inrange(xaxis,5,6),  barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xaxis in 4,  barw(0.6) lcolor(white%0) color("`red'")) ///
	(bar start_cost xaxis in 4, barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xaxis if inrange(xaxis,5,6), barw(0.6) lcolor(white%0) color("`blue'")) ///
	(bar start_cost xaxis if xaxis==6, barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar finish_cost xshift in `items', barw(0.6) lcolor(%0) color("$finalcolour")) ///
	(scatter cost xaxis if  xaxis==1, mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(12) mlabs(small)) ///
	(scatter finish_cost xaxis if  xaxis==4, mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(12) mlabs(small)) ///
	(scatter finish_cost xaxis if inrange(xaxis,2,3)|inrange(xaxis,5,6), mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(6) mlabs(small)) ///	
	(scatter finish_cost xshift in `items', mlab(finish_label) msym(none) mlabc("$tc") ///
		mlabpos(6) mlabs(small)) ///
	(function y =0, lcolor(gs8%60) lwidth(thin) range(0.5 `=`items'+1.5')) ///
	, ///
 	///yline(0, lcolor(gs8%50) lpattern(-)) ///
	ylabel( 15 "15K" 0 -15 "-15K" -30 "-30K"  , nogrid) ///
	xlabel(1(1)`items') ///
	ytitle("Government Costs ($)") ///
	${title}  ///
	xlabel( ///
	1 `""Total" "Cal Grant cost""' ///
	2 `""Additional" "Ed Costs""' ///
	3 `""14yr" "tax rev.""' ///
	4 `""lifetime" "revenue""' ///
	`=`items'+1' `""Net cost to""government""' , labsize(small)) ///
	legend(off)

graph export "${output}/calgrant_cost_decomposition.${img}", replace

/*



*FIU WTP decomposition:
run_program fiu
clear
set obs 10
gen xaxis = _n
*DATA INPUT:
	local program_cost = ${program_cost_fiu}
	gen wtp = ${fiu_lbwtp} in 1 // "lower bound"
	replace wtp = -${fiu_priv_cost} in 2 // private costs
	replace wtp = ${fiu_short_post_tax}  in 3 // initial earnings loss
	replace wtp = ${fiu_med_post_tax} in 4 // observed earnings gain
	replace wtp = ${fiu_long_post_tax} in 5 // projected earnings gain
	replace wtp = ${WTP_fiu} in 6 //total wtp
	replace wtp = . in 7 // "lower bound"
	replace wtp = wtp / 1000
	g wtp2 = wtp
	
forval i = 3(1)5 {
	replace wtp2 = wtp2 + wtp2[`i'-1] in `i'
}

*Get CI for final WTP
preserve
	use "${data_derived}/all_programs_baselines_corr_1.dta", clear
	keep if program == "fiu"
	foreach var in wtp l_wtp u_wtp {
		su `var'
		local fiu_`var' = r(mean)
	}
restore

g white_out = wtp2 - wtp
count if wtp != .
drop if wtp == .

*Add rcap bars for 95% CI on total WTP
su xaxis
gen need_ci = xaxis==r(max)
g l_wtp = `fiu_l_wtp'/1000
g u_wtp = `fiu_u_wtp'/1000 
su wtp2
assert abs(`fiu_wtp'/1000 - r(max))<0.001

gen label = "$"+ string(wtp, "%4.1f")+"K"

replace xaxis = 0.8 in 1

tw 	(scatter wtp xaxis if xaxis<1, mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(12)) /// lower bound
	(bar wtp xaxis if xaxis<1, barwidth(0.6) color("${finalcolour}"))  ///
	(bar wtp xaxis if xaxis==6, barwidth(0.6) color("${finalcolour}"))  ///
	(bar wtp2 xaxis if wtp>=0 & inrange(xaxis,2,5), barwidth(0.6) color("${basecolour}")) ///
	(bar wtp2 xaxis if wtp<0 & inrange(xaxis,2,5), barwidth(0.6) color("${secondcolour}")) ///
	(bar white_out xaxis if inrange(xaxis,4,5), color(white) barwidth(0.6)) ///
	(bar white_out xaxis if wtp<0, color(white) barwidth(0.6)) ///
	(bar white_out xaxis if xaxis==4, color("${basecolour}") barwidth(0.6)) ///
	(scatter wtp2 xaxis if inrange(xaxis,4,5), mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(12)) ///
	(scatter wtp2 xaxis if inrange(xaxis,2,3), mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(6)) ///
	(scatter wtp xaxis if xaxis==6, mlab(label) mlabs(small) msym(none) mlabc("$tc") mlabpos(12)) ///
	///(rcap l_wtp u_wtp xaxis if need_ci, lcolor(gs7) ) /// 
	(function y =0, lcolor(gs8%60) lwidth(thin) range(0.3 `=6.5')) ///
	, ///
	ylabel(-25 "-25K" 0 50 "50K" 100 "100K" , valuelabel) ///
	legend(off) ytitle("WTP ($)") xtitle("")  ylabel(,nogrid notick) ///
	xlabel( ///
	2 `""Private tuition""payments""' ///
	3 `""Age 19-25""after-tax" "earnings""' ///
	4 `""Age 26-33""after-tax" "earnings""' ///
	5 `""Age 34+""after-tax" "earnings""' ///
	6 `""Baseline" "WTP""' ///
	0.8 `""WTP via""private tuition""payments""' ///
	, labsize(small) notick ) ///
	xline(1.4, lcolor(gs8%50) lpattern(-)) ///
	///note("Lower Bound WTP", ring(0) pos(10) size(small)) ///
	 $title
graph export "${output_wtp}/fiu_wtp_decomposition.${img}", replace
















*MC Intro (Finkelstein Mc Knight)
clear all
set obs 10
gen xaxis = _n

*DATA INPUT:
	gen cost = 623.8  in 1 //unadjusted total costs
	replace cost = 142.3 in 2 // moral hazard
	replace cost = cost[1] + cost[2] in 3
	replace cost = 974 - 142.3 in 4 //moral hazard including ge
	replace cost = cost[1] + cost[2] + cost[4] in 5
	g white_out = 0 
	g cost_end = cost 
	replace white_out = cost[1] in 2
	replace white_out = cost[1] + cost[2] in 4
	replace  cost_end = white_out + cost
	count if cost != .
	local items = r(N)
	gen label ="$" +  string(cost, "%4.0f")
	
tw 	(bar cost_end xaxis in 1, barw(0.6) lcolor(%0) color("`basecolour'")) ///
	(bar cost_end xaxis in 2/`=`items'-1', barw(0.6) lcolor(white%0) color("`secondcolour'")) ///
	(bar white_out xaxis in 2/`items', barw(0.62) lwidth(thick) lcolor(white) color(white)) ///
	(bar cost_end xaxis in `items', barw(0.6) lcolor(%0) color("`finalcolour'")) ///
	(bar cost_end xaxis in 3, barw(0.6) lcolor(%0) color("`finalcolour'")) ///
	(scatter cost_end xaxis in 1, mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(12) mlabs(medium)) ///
	(scatter cost_end xaxis in 2/`items', mlab(label) msym(none) mlabc("$tc") ///
		mlabpos(12) mlabs(medium)) ///
	,  ///
	ylabel(, nogrid  ) ///
	xlabel(1(1)`items', notick)  ///
	$title xtitle("") ytitle("") ///
	xlabel( ///
	1 "Program Costs" ///
	2 `""Moral Hazard" "Costs""' 3`""Net Cost to" "Government excl." "GE Costs""'  4 `""Moral Hazard" "GE Costs""' ///
	`items' `""Net Cost to""Government""', labsize(small) notick) ///
	legend(off) 

graph export "${output}/MC_intro_cost_decomposition.${img}", replace

* MC Intro WTP decomposition:
clear all
set obs 10
gen xaxis = _n


*DATA INPUT: 
/*
	local program_cost = 623.8
	gen wtp = 1245.373 in 1 //total wtp
	replace wtp = 117.3  in 2 // oop spending
	replace wtp = 507.1  in 3 // private insurance
	replace wtp = 585 in 4 // insurance value
	replace wtp = 35.9730134949384 in 5 // health effects
	*/
	local program_cost = 623.8
	g wtp =.
	replace wtp = 117.3  in 1 // oop spending
	replace wtp = 507.1  in 2 // private insurance
	replace wtp = 35.9730134949384 in 3 // health effects	
	replace wtp = wtp[1] + wtp[2] + wtp[3] in 4	
	replace wtp = 585 in 5 // insurance value
	replace wtp = wtp[1]+ wtp[2] + wtp[3] +wtp[5] in 6 
	//replace wtp = wtp/`program_cost'
g wtp2 = wtp
g white_out = 0 
forval i = 2/3 {
	replace wtp2 = wtp2 + wtp2[`i'-1] in `i'
	replace white_out = wtp2[`i' - 1] in `i'
}
	replace wtp2 = wtp2 + wtp2[4] in 5
	replace white_out = wtp2[4] in 5

count if wtp != .
drop if wtp == .

gen label = "$"+ string(wtp, "%4.0f")
tw 	(bar wtp2 xaxis, barwidth(0.6) color("`finalcolour'")) ///
 	(bar wtp2 xaxis if xaxis == 6 | xaxis == 4, barwidth(0.6) color("`basecolour'")) ///
	(bar white_out xaxis,  barwidth(0.6) color(white)) ///
	(scatter wtp2 xaxis, mlab(label) msym(none) mlabc("$tc") mlabpos(12)), ///
	legend(off) xtitle("") ylabel(,nogrid notick ) xlabel(1 ///
	`""Reduc. in" "OOP" "Spending" "' 2 ///
	`""Reduc. in" "Priv. Insurance" "Spending" "' 3 `""Health" "Effects""' 4 `""Baseline" "WTP" "' 5 ///
	`""Insurance" "value""' 6 `""Ex-Ante" "WTP""', labsize(small) notick) ///
	ytitle("",) ///
	 $title

graph export "${output_wtp}/MC_intro_wtp_decomposition2.${img}", replace
*/

