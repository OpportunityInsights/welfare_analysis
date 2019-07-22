*Bar charts for kids imapcts vs not

global output "${output_root}/bars"
cap mkdir "$output"

*-------------------------------------------------------------------------------
* Panel A : Non-EITC Policies
*-------------------------------------------------------------------------------

use "${data_derived}/all_programs_extendeds_corr_1.dta", clear // use extended because want to include WIC
//keep if main_spec == 1
keep if kids_observed == 1
drop if inlist(prog_type, "College Child", "College Parents", "College Adult" , ///
	"Child Education", "Job Training", "Health Child") // can't exclude kids

drop if program == "eitc_obra93"
drop if strpos(program,"mto")
drop if program == "snap_intro" // replaced by wic
g spec = ""
expand 2
bys program: g id = _n

replace spec = "baseline" if kid_in_baseline & id == 1
replace spec = "baseline" if kid_in_baseline ==0 & id ==2
replace spec = "exclude kids" if mi(spec) & id == 2
replace spec = "kids" if mi(spec) & id == 1
replace spec = "include kids post tax" if spec == "kids" & program == "hous_vou_chicago" // relevant spec has a different name here

keep id spec program prog_type small_label_name

levelsof program, local(prog_list)
tempfile all
save `all'
foreach program in `prog_list' {
	*Import other specs from normal estimates
	use "${data_derived}/`program'_normal_estimates_1000_replications.dta", clear
	g spec = strtrim(substr(assumptions, strlen("spec_type:")+1, strpos(assumptions, ",") - strlen("spec_type:") -1))
	drop if spec == ""
	merge 1:1 spec program using `all', keep(using match) nogen
	save `all', replace
}

renvars *, lower

gsort program -id
g x = _n
labmask x , values(small_label_name)
replace x = x -0.15 if id == 1
replace x = x +0.15 if id == 2

local labels
local i = 0
levelsof program, local(programs)
foreach prog in `programs' {
	su x if program=="`prog'"
	local labels ="`labels'"+" `=r(mean)'"
}

di "`labels'"

tw 	(bar mvpf x if id == 2, barwidth(0.7) color("$secondcolour")) ///
	(bar mvpf x if id == 1, barwidth(0.7) color("$basecolour")) ///
	(rcap l_mvpf_efron u_mvpf_efron x , lcolor(gs6)), ///
	$ytitle $ylabel ///
	xlabel(1.5 "AFDC" 	///
	3.5 `""Housing" "Vouchers" "AFDC""' 	///
	5.5 `""Housing""Vouchers""Chicago""' 	///
	7.5 `""Negative""Income""Tax""' ///
	9.5 `"WIC"') ///
	 yline(6, lcolor(green%50) lwidth(0.15)) ///
	legend(order(1 2) label(1 "No Kid Impacts") label(2 "With Kid Impacts") ring(0) pos(10) size(small) cols(1)) ///
	xtitle("") $title

graph export "${output}/bar_impacts_kids_vs_not.${img}", replace

*-------------------------------------------------------------------------------
* Panel B : EITC OBRA93 baseline with no kid impacts and potential kid impacts
*-------------------------------------------------------------------------------

use "${data_derived}/eitc_obra93_normal_estimates_1000_replications.dta", clear
renvars *, lower
g kid_impact = strtrim(substr(assumptions, ///
	strpos(assumptions , "kid_impact:")+ strlen("kid_impact:"), ///
	strpos(assumptions, ", discount_rate")-strpos(assumptions , "kid_impact:") - ///
	strlen("kid_impact:")))

foreach wtp in post_tax cost {
preserve
	if "`wtp'" == "post_tax" drop if strpos(assumptions, "paper: Meyer")|(strpos(assumptions, "wtp_valuation: cost") & kid_impact != "none")
	if "`wtp'" == "cost" drop if strpos(assumptions, "paper: Meyer")|(strpos(assumptions, "wtp_valuation: post tax") & kid_impact != "none")
	g x = .
	g label = ""
	replace x = 1 if kid_impact == "none"
	replace label = "No Impact" if kid_impact == "none"

	replace x = 2 if kid_impact == "BM"
	replace label = "Bastian and Michelmore (2018)" if kid_impact == "BM"

	replace x = 3 if kid_impact == "BM_college"
	replace label = "Bastian and Michelmore (2018) (college impact)" if kid_impact == "BM_college"

	replace x = 4 if kid_impact == "michelmore"
	replace label = "Michelmore (2018)" if kid_impact == "michelmore"

	replace x = 5 if kid_impact == "MT"
	replace label = "Manoli and Turner (2018)" if kid_impact == "MT"

	replace x = 6 if kid_impact == "DL"
	replace label = "Dahl and Lochner (2012)" if kid_impact == "DL"

	replace x = 7 if kid_impact == "CFR"
	replace label = "CFR (2011)" if kid_impact == "CFR"

	replace x = 8 if kid_impact == "maxfield"
	replace label = "Maxfield (2013)" if kid_impact == "maxfield"

	labmask x, values(label)
	qui su x
	local max = r(max)
	tw 	(bar mvpf x if x == 1, barwidth(0.4) color("$secondcolour")) ///
		(bar mvpf x if x > 1, barwidth(0.4) color("$basecolour")) ///
		(rcap l_mvpf_efron u_mvpf_efron x, lcolor(gs6)), ///
		$ytitle $ylabel ///
		xlabel(1 `""No" "Impact""' ///
		2 `""Bastian and" "Michelmore" "(2018)" "[Earnings]""' /// earnings
		6 `""Dahl and" "Lochner" "(2018)" "[Test scores]""' /// test scores
		7 `""CFR" "(2011)""[Test scores]""' /// test scores
		8`""Maxfield" "(2013)""[Test scores]""' /// test scores
		5 `" "Manoli and" "Turner (2018)""[College]""' ///
		4 `""Michelmore" "(2018)""[College]""' ///
		3 `""Bastian and" "Michelmore" "(2018)" "[College]""' ///
		, labsize(small)) ///
		yline(6, lcolor(green%50) lwidth(0.15)) ///
		xtitle("") legend(off) $title

	graph export "${output}/bar_eitc_kids_impacts_`wtp'.${img}", replace
restore
}
