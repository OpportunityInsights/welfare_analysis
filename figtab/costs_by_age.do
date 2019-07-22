********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

local reps 1000

* Set file paths
global output "${output_root}/costs_by_age"
cap mkdir "$output"

* colors
local colour0 = "navy"
local colour1 = "maroon"
local colour2 = "dkgreen"
local colour3 = "dkorange"
local colour4 = "orange"

*get relevant files
local files : dir "${data_derived}" files "*_costs_by_age_`reps'_replications.dta"

*append all files into one dataset
local i = 0
foreach file in `files' {
	local ++i
	use "${data_derived}/`file'", clear
	gen program = subinstr("`file'","_costs_by_age_`reps'_replications.dta","",.)

	cap drop if program=="medicai_mw_v2" & MW_spec!= 1
	
	tempfile temp`i'
	save `temp`i''
}

use `temp1', clear
forval j = 2/`i' {
	append using `temp`j''
}

levelsof program, local(programs)

*Manually input age at which and beyond which we forecast for each program
local castlemanlong_proj = 22
local fiu_proj = 33
local medicai_mw_v2_proj = 37
local mc_state_exp_proj = 29
local mc_83_proj = 25
local georgiahope_proj = 22
local demingspend_proj = 22
local tuition_s_pe_proj = 22


replace discount_rate = round(discount_rate,0.01)
gen disc_rate = string(discount_rate, "%4.2f")
drop discount_rate
levelsof disc_rate, local(discounts)
qui {
	foreach prog in `programs' {
		foreach disc in `discounts' {
		foreach suff in "" "u_" "l_" {
				su age if !mi(`suff'cost) & program == "`prog'" & disc_rate == "`disc'"
				local max1 = r(max)
				su age if program == "`prog'" & disc_rate == "`disc'"
				local max2 = r(max)
				if `max1'<`max2' {
					su `suff'cost if age == `max1' & program == "`prog'" & disc_rate == "`disc'"
					local final_cost = r(mean)
					replace `suff'cost = `final_cost' if age >=`max1' & mi(`suff'cost) & program == "`prog'" & disc_rate == "`disc'"
				}
			}
		}
	}
}

ds *cost
foreach var in `r(varlist)' {
	replace `var' = `var' / 1000
}

*-------------------------------------------------------------------------------
*	Produce individual cost by age graphs
*-------------------------------------------------------------------------------

foreach program in `programs' {

	cap conf e ``program'_proj'
	if _rc > 0 local `program'_proj = 99
		tw 	(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.03", ls(p1) lc(`colour0') ) ///
			(line u_cost age if program == "`program'" & age<=``program'_proj' & disc_rate == "0.03", lp(dot) lc(`colour0') ls(p1) ) ///
			(line l_cost age if program == "`program'" & age<=``program'_proj' & disc_rate == "0.03", lp(dot) lc(`colour0') ls(p1) ) ///
			(line u_cost age if program == "`program'"  & age>``program'_proj' & disc_rate == "0.03", lp(dot) ls(p1) lc(white)) ///
			(line l_cost age if program == "`program'" & age>``program'_proj' & disc_rate == "0.03", lp(dot) ls(p1) lc(white) ) ///
			, legend(off) xlabel(0(10)70) ///
			note("Note: Costs discounted to age 0 using 3% interest rate", color(gs8) size(small)) ///
			ytitle("Cumulative Government Cost") xtitle("Age") ${title}
	
	graph export "${output}/`program'_costs_by_age_observed_only.${img}", replace
	
	su cost
	local interval_size = round((r(max) - r(min))/3,10)
	local min_axis = floor(r(min)/`interval_size')*`interval_size'
	local max_axis = -floor(-r(max)/`interval_size')*`interval_size'
	local ylabels 
	forval i = `min_axis'(`interval_size')`max_axis' {
		if `i' != 0 local ylabels `"`ylabels' `i' "`i'K""'		
		if `i' == 0 local ylabels `"`ylabels' `i' "`i'""'
	}
	di `interval_size'
	di `min_axis'
	di `max_axis'
		tw 	(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.03", ls(p1) lc(`colour0') ) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.03", lp(dash) lc(`colour0') ls(p1) ) ///
			(line u_cost age if program == "`program'" & disc_rate == "0.03", lp(dot) ls(p1) lc(`colour0') ) ///
			(line l_cost age if program == "`program'" & disc_rate == "0.03", lp(dot) ls(p1) lc(`colour0')) ///
			, legend(off) xlabel(0(10)70) ///
			ylabel(`ylabels') ///
			ytitle("Cumulative Government Cost ($)") xtitle("Age of Beneficiary") ${title}
			
	graph export "${output}/`program'_costs_by_age.${img}", replace
}
e
*Normalised version for CastlemanLong
bys program disc_rate : egen temp = max(cost)
foreach var of varlist *cost {
	gen norm_`var' = `var'/temp
}
drop temp

sort age

tw 	(line norm_cost age if age<=`castlemanlong_proj' & program == "castlemanlong" & disc_rate == "0.03", ls(p1) lc(`colour0')) ///
	(line norm_cost age if age>=`castlemanlong_proj' & program == "castlemanlong" & disc_rate == "0.03", lp(dash) ls(p1) lc(`colour0') ) ///
	(line norm_u_cost age if program == "castlemanlong" & disc_rate == "0.03", lp(dot) ls(p1) lc(`colour0')) ///
	(line norm_l_cost age if program == "castlemanlong" & disc_rate == "0.03", lp(dot) ls(p1) lc(`colour0')) ///
	, legend(off) graphregion(fcolor(white)) xlabel(0(10)70) ///
	ytitle("Cumulative Govt Cost") xtitle("Age") ${title} ///
	ylabel(-2(1)2)

graph export "${output}/castlemanlong_costs_by_age_normalised.${img}", replace

*Decomposed version for medicai_mw_v2

local year_medical_saving = 36.05 //point estimate
local discount_to = 0

gen cost_no_health = cost + (age-18)*`year_medical_saving'*(1/1.03^age) if age >= 19 & program=="medicai_mw_v2"
cap drop base_cost
egen base_cost = max(cost) if program=="medicai_mw_v2" & disc_rate=="0.03"
gen cost_only_health = base_cost - (age-18)*`year_medical_saving'*(1/1.03^age) if age >= 19 & program=="medicai_mw_v2"
drop base_cost

sort age
local medicai_mw_v2_proj = 37
tw 	(line cost age if age<=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", ls(p1) lc(`colour0') ) ///
	(line cost age if age>=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", lp(dash) ls(p1) lc(`colour0')) ///
	(line cost_no_health age if age<=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", ls(p2) lc(`colour1')) ///
	(line cost_no_health age if age>=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", lp(dash) ls(p2) lc(`colour1')) ///
	(line cost_only_health age if age<=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", ls(p3) lc(`colour2') ) ///
	(line cost_only_health age if age>=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", lp(dash) ls(p3) lc(`colour2') ) ///
	(line u_cost age if program == "medicai_mw_v2" & disc_rate == "0.03", lp(dot) ls(p1) lc(`colour0') ) ///
	(line l_cost age if program == "medicai_mw_v2" & disc_rate == "0.03", lp(dot) ls(p1) lc(`colour0') ) ///
	, legend( off order(1 3 5) cols(1) label(1 "Cumulative cost") label(3 "Only earnings effect") label(5 "Only health effect") ring(0) pos(8)) xlabel(0(10)70) ///
	ytitle("Cumulative Govt Cost") xtitle("Age") ${title} //

graph export "${output}/medicai_mw_v2_costs_by_age_decomposition.${img}", replace

*-------------------------------------------------------------------------------
*	Produce individual cost by age graphs with varying discount rates
*-------------------------------------------------------------------------------
	*(rcap u_cost l_cost year if year_ci ==1 & program =="Medicaid_MillWher18" , color(navy)) ///

foreach program in `programs' {
	cap conf e ``program'_proj'
	if _rc > 0 local `program'_proj = 99
	
	egen id_num = group(disc_rate)
	gen temp = age + id_num
	gen plot_rcap = mod(temp,10)==0 if age > 23 & age < 63
	drop temp id_num
	*gen plot_
	if "`program'" == "medicai_mw_v2" {
		preserve
		foreach var in l_cost u_cost cost {
			replace `var' = . if `var' <-14990
		}
		tw 	(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.01" & plot_rcap == 1 & 0, ls(p1) lc(`colour0')) ///
			(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.03" & plot_rcap == 1 & 0, ls(p2) lc(`colour1') ) ///
			(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.05" & plot_rcap == 1 & 0, ls(p3) lc(`colour2')) ///
			(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.07" & plot_rcap == 1 & 0, ls(p4) lc(`colour3') ) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.01", ls(p1)lc(`colour0') ) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.01", lp(dash) ls(p1) lc(`colour0') ) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.03", ls(p2) lc(`colour1')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.03", lp(dash) ls(p2) lc(`colour1')) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.05", ls(p3) lc(`colour2')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.05", lp(dash) ls(p3) lc(`colour2')) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.07", ls(p4) lc(`colour3')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.07", lp(dash) ls(p4) lc(`colour3')) ///
			, graphregion(fcolor(white)) xlabel(0(10)70) ///
			legend(order(5 7 9 11) label(5 "1%") label(7 "3%") label(9 "5%") label(11 "7%") size(small) cols(4)) ///
			ytitle("Cumulative Govt Cost") xtitle("Age") ${title}
		restore
		}
	else {	

		tw 	(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.01" & plot_rcap == 1, ls(p1) lc(`colour0') ) ///
			(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.03" & plot_rcap == 1, ls(p2) lc(`colour1')) ///
			(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.05" & plot_rcap == 1, ls(p3) lc(`colour2')) ///
			(rcap u_cost l_cost age if program == "`program'" & disc_rate == "0.07" & plot_rcap == 1, ls(p4) lc(`colour3')) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.01", ls(p1) lc(`colour0')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.01", lp(dash) ls(p1) lc(`colour0')) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.03", ls(p2) lc(`colour1')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.03", lp(dash) ls(p2) lc(`colour1')) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.05", ls(p3) lc(`colour2')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.05", lp(dash) ls(p3) lc(`colour2')) ///
			(line cost age if age<=``program'_proj' & program == "`program'" & disc_rate == "0.07", ls(p4) lc(`colour3')) ///
			(line cost age if age>=``program'_proj' & program == "`program'" & disc_rate == "0.07", lp(dash) ls(p4) lc(`colour3')) ///
			, graphregion(fcolor(white)) xlabel(0(10)70) ///
			legend(order(5 7 9 11) label(5 "1%") label(7 "3%") label(9 "5%") label(11 "7%") ring(0) pos(8) size(small) cols(1)) ///
			ytitle("Cumulative Normalized Govt Cost") xtitle("Age") ${title}
	}
	
	graph export "${output}/`program'_costs_by_age_varying_discount_rates.${img}", replace
	
	drop plot_rcap
}


*-------------------------------------------------------------------------------
*	Combine graphs for comparison
*-------------------------------------------------------------------------------

preserve	
	*normalise cost to one
	bys program disc_rate : egen temp = max(cost)
	foreach var of varlist *cost {
		replace `var' = `var'/temp
	}
	drop temp
sort age
	keep if inlist(program, "castlemanlong", "zimmerman", "georgiahope", ///
	"demingspend", "tuition_s_pe")
	egen id_num = group(program)
	gen temp = age + id_num
	gen plot_rcap = mod(temp,10)==0 if age > 23 & age < 63
	drop temp id_num
	
	ds *cost*
	foreach var in `r(varlist)' {
		replace `var' = -2 if `var' < -2
		replace `var' = 2 if `var' >2
		*replace `var' = . if inrange(`var',-2,2)==0
	}

	*plot for college programs
	tw 	(rcap u_cost l_cost age if program == "castlemanlong" & disc_rate == "0.03" & plot_rcap == 1, ls(p1)  lc(`colour0') ) ///
		(rcap u_cost l_cost age if program == "zimmerman" & disc_rate == "0.03" & plot_rcap == 1,  ls(p2)  lc(`colour1') ) ///
		(rcap u_cost l_cost  age if program == "georgiahope" & disc_rate == "0.03" & plot_rcap == 1,  ls(p3)  lc(`colour2') ) ///
		(rcap u_cost l_cost  age if program == "demingspend" & disc_rate == "0.03" & plot_rcap == 1, ls(p4)  lc(`colour3') ) ///
		(rcap u_cost l_cost age if program == "tuition_s_pe" & disc_rate == "0.03" & plot_rcap == 1, lc(gs8) ) ///
		(line cost age if age<=`castlemanlong_proj' & program == "castlemanlong" & disc_rate == "0.03", ls(p1)  lc(`colour0')) ///
		(line cost age if age>=`castlemanlong_proj' & program == "castlemanlong" & disc_rate == "0.03", lp(dash) ls(p1)  lc(`colour0') ) ///
		(line cost age if age<=`zimmerman_proj' & program == "zimmerman" & disc_rate == "0.03", ls(p2)  lc(`colour1') ) ///
		(line cost age if age>=`zimmerman_proj' & program == "zimmerman" & disc_rate == "0.03", lp(dash) ls(p2)  lc(`colour1') ) ///
		(line cost age if age<=`georgiahope_proj' & program == "georgiahope" & disc_rate == "0.03", ls(p3)  lc(`colour2') ) ///
		(line cost age if age>=`georgiahope_proj' & program == "georgiahope" & disc_rate == "0.03", lp(dash) ls(p3)  lc(`colour2') ) ///
		(line cost age if age<=`demingspend_proj' & program == "demingspend" & disc_rate == "0.03", ls(p4)  lc(`colour3') ) ///
		(line cost age if age>=`demingspend_proj' & program == "demingspend" & disc_rate == "0.03", lp(dash) ls(p4)  lc(`colour3') ) ///
		(line cost age if age<=`tuition_s_pe_proj' & program == "tuition_s_pe" & disc_rate == "0.03", lc(gs8) ) ///
		(line cost age if age>=`tuition_s_pe_proj' & program == "tuition_s_pe" & disc_rate == "0.03", lp(dash) lc(gs8) ) ///
		, legend( ///
		label(6 "Florida Grant") label(8 "Florida GPA")  ///
		label(10 "Georgia HOPE") label(12 "College Spending") ///
		label(14 "Tuition Deduction (Single, end)") ///
		size(vsmall) order(6 8 10 12 14) ///
		ring(0) pos(8) col(1)) graphregion(fcolor(white)) xlabel(0(10)70) ///
		ytitle("Cumulative Normalized Govt Cost") xtitle("Age") ${title}
		
	graph export "${output}/college_programs_costs_by_age.${img}", replace
	
restore

preserve
/*	
	*normalise cost to one
	bys program disc_rate : egen temp = max(cost)
	foreach var of varlist *cost {
		replace `var' = `var'/temp
	}
	drop temp
	*/
sort age
	*plot for health programs
	tw 	(line u_cost age if program == "medicai_mw_v2" & disc_rate == "0.03", lp(dot) ls(p1)  lc(`colour0') ) ///
		(line l_cost age if program == "medicai_mw_v2" & disc_rate == "0.03", lp(dot) ls(p1)  lc(`colour0') ) ///
		(line u_cost age if program == "mc_state_exp" & disc_rate == "0.03", lp(dot) ls(p2)  lc(`colour1') ) ///
		(line l_cost age if program == "mc_state_exp" & disc_rate == "0.03", lp(dot) ls(p2)  lc(`colour1') ) ///
		(line u_cost age if program == "mc_83" & disc_rate == "0.03", lp(dot) ls(p3)  lc(`colour2') ) ///
		(line l_cost age if program == "mc_83" & disc_rate == "0.03", lp(dot) ls(p3)  lc(`colour2') ) ///
		(line cost age if age<=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", ls(p1)  lc(`colour0')) ///
		(line cost age if age>=`medicai_mw_v2_proj' & program == "medicai_mw_v2" & disc_rate == "0.03", lp(dash) ls(p1)  lc(`colour0') ) ///
		(line cost age if age<=`mc_state_exp_proj' & program == "mc_state_exp" & disc_rate == "0.03", ls(p2)  lc(`colour1')) ///
		(line cost age if age>=`mc_state_exp_proj' & program == "mc_state_exp" & disc_rate == "0.03", lp(dash) ls(p2)  lc(`colour1') ) ///
		(line cost age if age<=`mc_83_proj' & program == "mc_83" & disc_rate == "0.03", ls(p3)  lc(`colour2') ) ///
		(line cost age if age>=`mc_83_proj' & program == "mc_83" & disc_rate == "0.03", lp(dash) ls(p3)  lc(`colour2') ) ///
		, legend(order(7 9 11) label(7 "MC to Pregnant Women & Infants") label(9 "SCHIP") label(11 "Medicaid to 1983+")  size(vsmall) ring(0) pos(8) col(1)) graphregion(fcolor(white)) xlabel(0(10)60) ///
		ytitle( "Cumulative Govt Cost") xtitle("Age") ${title}
		
	graph export "${output}/child_health_programs_costs_by_age.${img}", replace
		*plot for only 83+ 

	tw 	(line u_cost age if program == "mc_83" & disc_rate == "0.03" & age<=`mc_83_proj', lp(dot) ls(p3)  lc(`colour2') ) ///
		(line l_cost age if program == "mc_83" & disc_rate == "0.03" & age<=`mc_83_proj', lp(dot) ls(p3)  lc(`colour2') ) ///
		(line cost age if age<=`mc_83_proj' & program == "mc_83" & disc_rate == "0.03", ls(p3)  lc(`colour2') ) ///
		(line cost age if age>=`mc_83_proj' & program == "mc_83" & disc_rate == "0.03", lp(dash) ls(p3)  lc(white) ) ///
		(line u_cost age if program == "mc_83" &  age>=`mc_83_proj' & disc_rate == "0.03", lp(dot) ls(p3)  lc(white) ) ///
		(line l_cost age if program == "mc_83" &  age>=`mc_83_proj'& disc_rate == "0.03", lp(dot) ls(p3)  lc(white) ) ///
		, legend(off) graphregion(fcolor(white)) xlabel(0(10)60)  ///
		ytitle( "Cumulative Govt Cost") xtitle("Age") ${title}
	
	graph export "${output}/mc_83_costs_by_age_observed_only.${img}", replace

	graph export "${output}/mc_83_costs_by_age.${img}", replace
	tw 	(line u_cost age if program == "mc_83" & disc_rate == "0.03", lp(dot) ls(p3)  lc(`colour2') ) ///
		(line l_cost age if program == "mc_83" & disc_rate == "0.03", lp(dot) ls(p3)  lc(`colour2') ) ///
		(line cost age if age<=`mc_83_proj' & program == "mc_83" & disc_rate == "0.03", ls(p3)  lc(`colour2') ) ///
		(line cost age if age>=`mc_83_proj' & program == "mc_83" & disc_rate == "0.03", lp(dash) ls(p3)  lc(`colour2') ) ///
		, legend(off) graphregion(fcolor(white)) xlabel(0(10)60)   ///
		ytitle( "Cumulative Govt Cost") xtitle("Age") ${title}
		
	graph export "${output}/mc_83_costs_by_age.${img}", replace
	
restore


*-------------------------------------------------------------------------------
* Make MW graph for the different income effect estimates
*-------------------------------------------------------------------------------
use "${data_derived}/medicai_mw_v2_costs_by_age.dta", clear
keep if strofreal(discount_rate) == ".03"

local medicai_mw_v2_proj = 37

forval spec = 1/3 {
	local command `command' (line u_cost age if MW_spec == `spec', lp(dot) ls(p`spec') lc(`colour`=`spec'-1'')) ///
		(line l_cost age if MW_spec == `spec', lp(dot) ls(p`spec') lc(`colour`=`spec'-1''))	///
		(line cost age if age<=`medicai_mw_v2_proj' & MW_spec == `spec', ls(p`spec') lc(`colour`=`spec'-1'')) ///
		(line cost age if age>=`medicai_mw_v2_proj' & MW_spec == `spec' , lp(dash) ls(p`spec') lc(`colour`=`spec'-1''))

}
tw `command' , graphregion(fcolor(white)) xlabel(0(10)60) ///
		ytitle("Cumulative Govt Cost") xtitle("Age") ///
		${title} legend(off)
				
graph export "${output}/MW_costs_by_age_varying_specs.${img}", replace
