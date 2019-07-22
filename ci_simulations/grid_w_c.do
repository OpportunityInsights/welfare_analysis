*-------------------------------------------------------------------------------
* Make a heatmap of the coverage of our bootstrap CIs
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

*Parallel options
parallel setclusters 4

cap parallel clean, all

*Grid options
global grid_step = 	0.25
local wtp_min = 	0
local wtp_max = 	4
local cost_min =   -1
local cost_max = 	3

confirm number ${welfare_seed}
set seed ${welfare_seed}

*Sampling options
global true_dist = "uniform"
global s_wtp 	2*${grid_step}
global s_cost 	2*${grid_step}
global rho 		runiform(-1,1)

cap confirm file "${data_derived}/interval_coverage_ests_grid.dta"
if "${reestimate}"=="yes" | _rc > 0{

*-------------------------------------------------------------------------------
* Estimate coverage heatmap
*-------------------------------------------------------------------------------

*Draw w,c from grid
clear
tempfile grid
save `grid', emptyok

local pct = 0

forval w = `wtp_min'(${grid_step})`wtp_max' {
	qui forval c = `cost_min'(${grid_step})`cost_max' {

		global w = `w'
		global c = `c'
		
		noi di "(`c', `w')"
		
		clear
		set obs `sim_reps'
		
		local vars 	covered covered_ef n_covered_u n_covered_l n_covered_u_ef n_covered_l_ef ///
					p_sw_hi p_sw p_low_mvpf wtp cost
					
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
label var n_covered_u_ef "% Above Interval Efron"
label var n_covered_l "% Below Interval"
label var n_covered_l_ef "% Below Interval Efron"

save "${data_derived}/interval_coverage_ests_grid.dta", replace

}

*-------------------------------------------------------------------------------
* Now graph
*-------------------------------------------------------------------------------

use "${data_derived}/interval_coverage_ests_grid.dta", clear
foreach var in cost wtp {
	su `var'
	local `var'_min = r(min)
	local `var'_max = r(max)
}

ds wtp cost, not
foreach var in `r(varlist)' {
	replace `var' = round(`var',0.001)
}

foreach var in covered covered_ef {
	format `var' %12.3f
	tw  (contour `var' cost wtp, heatmap levels(10)) ///
		(scatter cost wtp if inrange(wtp,`wtp_min'+0.001,`wtp_max'-0.001) & inrange(cost, `cost_min'+0.001,`cost_max'-0.001) ///
			, msymbol(none) mlabpos(0) mlabsize(tiny) mlabcolor(black) mlabel(covered_ef)) ///
		,  title(" ", size(vhuge))

	graph export "${output}/grid_heatmap_uniform_`var'.${img}", replace 
}

