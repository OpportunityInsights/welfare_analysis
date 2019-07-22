*-------------------------------------------------------------------------------
* Vary c around zero and see if we have "weak instruments" problem
*-------------------------------------------------------------------------------

cap ssc install parallel

chdir "${welfare_git}/ci_simulations"
global data_derived "${welfare_files}/Data/derived"
global figtab "${welfare_files}/figtab"
global output "${figtab}/ci_simulations"
cap mkdir "$figtab"
cap mkdir "$output"

if "$img"=="" global img pdf

global bootstrap_reps = 1000
local sim_reps = 3000
global inf = 99999

parallel setclusters 4

global grid_step = 0.1
local cost_min = -1
local cost_max = 1

confirm number ${welfare_seed}
set seed ${welfare_seed}

*Sampling options
global true_dist = "uniform"
global s_wtp 	0
global s_cost 	2*${grid_step}
global rho 		0

cap confirm file "${data_derived}/sim_coverage_around_zero_cost.dta"

if _rc>0 | "${reestimate}"=="yes" {

*-------------------------------------------------------------------------------
* Estimate coverage for our mvpf
*-------------------------------------------------------------------------------

clear
tempfile grid
save `grid', emptyok

local pct = 0

foreach w in 1 {
	forval c = `cost_min'(${grid_step})`cost_max' {
		global w = `w'
		global c = `c'
		
		local ++pct
		noi di "`=round(100*`pct'/(((`cost_max'-`cost_min')/($grid_step))+1),1)'%"
		
		clear
		set obs `sim_reps'
		
		local vars 	covered covered_ef n_covered_u n_covered_l n_covered_u_ef n_covered_l_ef ///
					p_sw_hi p_sw p_low_mvpf wtp cost covered_ef_n_sw covered_n_sw
					
		qui foreach var in `vars' {
			g `var' = .
		}
		
		parallel do "sim_fragment_uniform.do", randtype(current)
			
		collapse (mean) `vars'
		
		append using `grid'
		save `grid', replace
	}
}

parallel clean, all

label var wtp "WTP"
label var cost "Cost"
label var covered "Coverage"
label var covered_ef "Efron Coverage"
label var n_covered_u "% Above Interval"
label var n_covered_l "% Below Interval"

tempfile our_mvpfs
save `our_mvpfs'

*-------------------------------------------------------------------------------
* Estimate coverage for weak iv mvpf
*-------------------------------------------------------------------------------

clear
tempfile grid
save `grid', emptyok

local pct = 0

foreach w in 1 {
	forval c = `cost_min'(${grid_step})`cost_max' {
		global w = `w'
		global c = `c'
		
		local ++pct
		noi di "`=round(100*`pct'/(((`cost_max'-`cost_min')/($grid_step))+1),1)'%"
		
		clear
		set obs `sim_reps'
		
		local vars 	covered covered_ef n_covered_u n_covered_l n_covered_u_ef n_covered_l_ef ///
					p_sw_hi p_sw p_low_mvpf wtp cost covered_ef_n_sw covered_n_sw
					
		qui foreach var in `vars' {
			g `var' = .
		}
		
		parallel do "sim_fragment_uniform_weak_iv.do", randtype(current)
			
		collapse (mean) `vars'
		
		append using `grid'
		save `grid', replace
	}
}

parallel clean, all

label var wtp "WTP"
label var cost "Cost"
label var covered "Coverage"
label var covered_ef "Efron Coverage"
label var n_covered_u "% Above Interval"
label var n_covered_l "% Below Interval"

ds wtp cost, not
foreach var in `r(varlist)' {
	ren `var' weak_`var'
}

merge 1:1 wtp cost using `our_mvpfs', nogen assert(3)
order wtp cost, first

*Save 
save "${data_derived}/sim_coverage_around_zero_cost.dta", replace
}

*-------------------------------------------------------------------------------
* Make graph
*-------------------------------------------------------------------------------

use "${data_derived}/sim_coverage_around_zero_cost.dta", clear

tw 	(line covered cost, lstyle(p1)) ///
	(line weak_covered cost , lstyle(p1) lpattern(-)) ///
	(line covered_ef cost, lstyle(p2)) ///
	(line weak_covered_ef cost , lstyle(p2)lpattern(-)) ///
	, legend( region(color(gs8%0)) label(1 "Our MVPF coverage") label(2 "W/C coverage") ///
	label(3 "Our MVPF Efron coverage") label(4 "W/C Efron coverage") ///
	ring(0) cols(1) pos(7)) yline(0.95) ytitle("Coverage")

graph export "${output}/line_ours_vs_iv.${img}", replace 


