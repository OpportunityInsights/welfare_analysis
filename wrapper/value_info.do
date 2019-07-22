/******************************************************************************* 
Calculate max wtp of government to find out true wtp and Cost of 
individual programs and program group averages 
*******************************************************************************/
/*
 
Experiment A: gain admin rather than PSID data for SNAP
i - Can spend 1$ on the program and have the option to spend an 
extra x dollars to gain admin information before doing so 
ii - Can spend $1 on policy and stay uninformed, or can pay x to gain admin information
but then only have 1- x dollars left to potentially spend on the policy

Experiment B: get rid of sampling uncertainty (all programs)
i - Can spend 1$ on the program and have the option to spend an 
extra x dollars to remove sampling uncertainty before doing so 
ii - Can spend $1 on policy and stay uninformed, or can remove sampling 
uncertainty but then only have 1- x dollars left to potentially spend on the policy
iii - B.i but with group averages
iv - B.ii but with group averages

In both cases we calculate the x for which the government is indifferent between 
learning the truth or not (in expectation)

See paper for further details.

Formulae for values of information:

Definitions:
	U(info) := max(wtp(info)-cost(info),0)
	info can be oracle, admin or psid in the context of A, oracle or baseline for B
	
Experiment A.i:

	E(U(psid)) = E(U(admin)|psid) - x
	
=> 			 x = E(U(admin)|psid) - E(U(psid))

Experiment A.ii:

	E(U(psid)) = (1-x)*E(U(admin)|psid) - x
	
=> 			 x = ( E(U(admin)|psid) - E(U(psid)) ) / ( 1 + E(U(admin)|psid) )

Here indifference is between making the optimal decision given the psid information
and raising x in taxes in order to acquire admin information, then making the optimal
decision given that information, evaluated in expectation given the psid information

Experiment B.i: 

	E(U(baseline)) = E(U(oracle)|baseline) - x
	
	=> 			 x = E(U(oracle)|baseline) - E(U(baseline))
	
Experiment B.ii: 

	E(U(baseline)) = (1-x)*E(U(oracle)|baseline) - x
	
	=> 			 x = ( E(U(oracle)|baseline) - E(U(baseline)) ) / ( 1 + E(U(oracle)|baseline) )

Here indifference is between making the optimal decision given the baseline information
and raising x in taxes in order to acquire oracle (perfect) information, then making the optimal
decision given that information, evaluated in expectation given the baseline information
*/

********************************************************************************
*	Calculate value of info 												
*********************************************************************************

*Filepaths
global output "${data_derived}/infovalue"
cap mkdir "$output"
global data_derived "${welfare_files}/Data/derived"

local replications 1000

*-------------------------------------------------------------------------------
*Experiment A: SNAP admin data
*-------------------------------------------------------------------------------

local q = 0
*loop over different WTP valuations
foreach mode in post_tax cost {
	use "${data_derived}/snap_intro_normal_estimates_`replications'_replications.dta", clear
	local ++q
	renvars *, lower
	g spec_n = _n
	*admin estimates are the baseline
	g admin = regexm(assumptions,"spec_type: baseline")|regexm(assumptions,"spec_type: lower bound wtp")
	* psid estimates are alternative specs
	g psid= regexm(assumptions,"kid_est_source: psid")
	if "`mode'"=="post_tax" keep if regexm(assumptions,"wtp_valuation: post tax")
	if "`mode'"=="cost" keep if regexm(assumptions,"wtp_valuation: lower bound")

	keep if admin|psid
	foreach type in admin psid {
		preserve
			keep if `type'
			assert _N==1
			*Normalise by program cost
			local prog_cost_`type' = program_cost[1]
			replace wtp = wtp / `prog_cost_`type''
			replace cost = cost / `prog_cost_`type''
			*Save normalised PEs
			local wtp_`type' = wtp[1]
			local cost_`type' = cost[1]
			assert _N==1
			su spec_n
			use "${data_derived}/snap_intro_normal_`replications'_draws_spec_`=r(mean)'.dta", clear
			renvars *, lower
			*Normalise draws
			replace wtp = wtp / `prog_cost_`type''
			replace cost = cost / `prog_cost_`type''
			tempfile draws_`type'
			save `draws_`type''
		restore
	}

	*Loop over all PSID draws to estimate payoff of acquiring and using admin data
	use `draws_psid', clear
	local reps = _N
	qui forval i = 1/`reps' {
		use `draws_psid', clear
		keep in `i'
		*This wtp/cost is the new truth
		local wtp`i' = wtp[1]
		local cost`i' = cost[1]
		
		*Now use variance of admin ests to bootstrap what is actually observed
		use `draws_admin', clear
		*Remean around the truth
		foreach var in wtp cost {
			su `var'
			replace `var' = `var' + (``var'`i''-r(mean))
		}
		*Find chosen action
		g dec = wtp>cost
		*And implied value
		g dec_val = dec*(`wtp`i''-`cost`i'')
		*Get expected value of future actions
		collapse (mean) dec_val
		*Convert to expected value of optimal decision
		tempfile val`i'
		save `val`i''
	}
	use `val1'
	forval i = 2/`reps' {
		append using `val`i''
	}

	*Get expected payoff of acquiring and using admin data
	collapse (mean) dec_val
	local admin_payoff = dec_val[1]

	*Get value of just using PSID
	use `draws_psid', clear
	if `wtp_psid'>`cost_psid' local decision 1
	else local decision 0
	*Calculate value of given policy for each draw
	g val = wtp-cost
	*Get expected value of doing the policy
	collapse (mean) val
	*Convert to expected value of optimal decision
	g dec_val = val*`decision'
	assert _N==1
	local psid_payoff = dec_val[1]

	*Get value of becoming the oracle
	use `draws_psid', clear
	local reps = _N
	qui forval i = 1/`reps' {
		use `draws_psid', clear
		keep in `i'
		*This wtp/cost is the truth, which is learnt
		local wtp`i' = wtp[1]
		local cost`i' = cost[1]
		if `wtp`i''>`cost`i'' local decision`i' 1
		else local decision`i' 0
		*Calculate value of the policy
		g val = wtp-cost
		*Convert to value of optimal decision
		g dec_val = val*`decision`i''
		assert _N==1
		tempfile val`i'
		save `val`i''
	}
	use `val1'
	forval i = 2/`reps' {
		append using `val`i''
	}
	*Get expected payoff of becoming oracle
	collapse (mean) dec_val
	local oracle_payoff = dec_val[1]

	clear 
	set obs 1
	g mode ="`mode'"
	g admin_p = `admin_payoff'
	g psid_p = `psid_payoff'
	g oracle_p = `oracle_payoff'
	tempfile temp`q'
	save `temp`q''
}
use `temp1', clear
append using `temp2'

*Estimate values of info:
g v_max_i = max(admin_p,0)-max(psid_p,0)
g v_max_ii = (max(admin_p,0)-max(psid_p,0))/(1+max(admin_p,0))
g v_oracle_i = max(oracle_p,0)-max(psid_p,0)
g v_oracle_ii = (max(oracle_p,0)-max(psid_p,0))/(1+max(oracle_p,0))

save "${data_derived}/infovalue/value_of_information_experiment_A.dta", replace

*-------------------------------------------------------------------------------
* Experiment B.i,ii,iii,iv
*-------------------------------------------------------------------------------

*Import baseline estimates
use "${data_derived}/all_programs_baselines_corr_1.dta", clear
replace prog_type = subinstr(subinstr(prog_type, " ", "_",.),".","",.)
foreach var in wtp cost {
	replace `var' = `var' / program_cost
}
keep program prog_type wtp cost program_cost avg_prog_type_w_on_pc avg_prog_type_c_on_pc

* Get baseline decisions for each program
g dec_naive = wtp>=cost
levelsof program, local(programs)
foreach program in `programs' {
	su dec_naive if program =="`program'"
	assert r(sd)==.
	local dec_naive_`program' = r(mean)
	su program_cost if program =="`program'"	
	assert r(sd)==.
	local pc_`program' = r(mean)
}

*Get baseline decisions for group averages
g dec_prog_type = avg_prog_type_w_on_pc > avg_prog_type_c_on_pc
levelsof prog_type, local(prog_types)
foreach prog_type in `prog_types' {
	levelsof program if prog_type=="`prog_type'", local(progs_`prog_type')
	su dec_prog_type if prog_type=="`prog_type'"
	assert r(sd)==0|r(sd)==.
	local dec_naive_`prog_type'=r(mean)
}
preserve
	collapse (sum) program_cost, by(prog_type)
	foreach prog_type in `prog_types' {
		su program_cost if prog_type=="`prog_type'"
		assert r(sd)==0|r(sd)==.
		local pc_`prog_type'=r(mean)
	}
restore

* Load draws for all programs simultaneously, estimate value of decisions/information
* normalise by point estimates of program cost
local k = 0
local neg_cost_progs ""
foreach program in `programs' {
	local ++k
	if `k'==1 use "${data_derived}/`program'_baseline_`replications'_draws_corr_1.dta", clear
	else merge 1:1 draw_id using "${data_derived}/`program'_baseline_`replications'_draws_corr_1.dta", assert(3) nogen
	renvars *, lower
	foreach var in wtp cost {
		replace `var'_`program' = `var'_`program' / `pc_`program''
	}
	g dec_`program'=wtp_`program'>=cost_`program'
	g inform_val_`program' = dec_`program'*(wtp_`program'-cost_`program')
	g naive_val_`program' = `dec_naive_`program''*(wtp_`program'-cost_`program')
	
	*Get expected values of policy under each information set
	foreach info in inform naive {
		su `info'_val_`program'
		local `info'_val_`program'=r(mean)
	}
	count if program_cost_`program'<0
	if `=r(N)'>0 local neg_cost_progs "`neg_cost_progs' `program'"
}
di "`neg_cost_progs'"

ren program_cost* pc* 
* Estimate expected value of information sets for group averages
* normalise by point estimates of program cost
foreach prog_type in `prog_types' {
	foreach program in `progs_`prog_type'' {
		foreach var in wtp cost pc {
			*If first program in category generate category wtp/cost
			cap g `var'_`prog_type' = `var'_`program'
			*If not first then add to existing wtp/cost
			if _rc>0 replace `var'_`prog_type' = `var'_`prog_type' + `var'_`program'
		}
	}
	*Normalise
	foreach var in wtp cost {
		replace `var'_`prog_type' = `var'_`prog_type'/ `pc_`prog_type''
	}
	*Generate informed decisions
	g dec_`prog_type'=wtp_`prog_type'>=cost_`prog_type'
	*Generate informed and baseline/naive decisions values by draw
	g inform_val_`prog_type' = dec_`prog_type'*(wtp_`prog_type'-cost_`prog_type')
	g naive_val_`prog_type' = `dec_naive_`prog_type''*(wtp_`prog_type'-cost_`prog_type')
	
	*Collapse to get expectation
	foreach info in inform naive {
		su `info'_val_`prog_type'
		local `info'_val_`prog_type'=r(mean)
	}
}

*Combine results
clear
set obs 1000
local k=0
g program = ""
g prog_type = ""
g inform_val = .
g naive_val = .
*Get program results
foreach program in `programs' {
	local ++k
	replace program = "`program'" in `k'
	foreach info in inform naive {
		replace `info'_val = ``info'_val_`program'' in `k'
	}
}
*Get group average results
foreach prog_type in `prog_types' {
	local ++k
	replace prog_type = "`prog_type'" in `k'
	foreach info in inform naive {
		replace `info'_val = ``info'_val_`prog_type'' in `k'
	}
}
*Trim extra observations
drop if program==""&prog_type==""

*Generate values
g v_experimentBi = max(inform_val,0) - max(naive_val,0) if prog_type==""
g v_experimentBii = (max(inform_val,0) - max(naive_val,0))/(1+max(inform_val,0)) if prog_type==""
g v_experimentBiii = max(inform_val,0) - max(naive_val,0) if prog_type!=""
g v_experimentBiv = (max(inform_val,0) - max(naive_val,0))/(1+max(inform_val,0)) if prog_type!=""

*Reformat data
ren prog_type temp
merge m:1 program using "${data_derived}/all_programs_baselines_corr_1.dta", keepusing(prog_type) nogen keep(3 1)
replace prog_type = subinstr(subinstr(prog_type, " ", "_",.),".","",.)
preserve
	keep if program==""
	drop prog_type
	ren temp prog_type
	keep prog_type v_experimentBiii v_experimentBiv
	tempfile avgs
	save `avgs'
restore
drop temp 
keep if program!=""
merge m:1 prog_type using `avgs', nogen update

*Export
save "${data_derived}/infovalue/value_of_information_estimates.dta", replace
