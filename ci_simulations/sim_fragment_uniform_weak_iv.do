* Simulation fragment for CIs

local sim_reps = _N
local inf = $inf
local bootstrap_reps = $bootstrap_reps
local c = $c
local w = $w
local grid_step = $grid_step

set trace on

clear
tempfile sims
save `sims', emptyok

forval i = 1/`sim_reps' {
	if "$true_dist"=="uniform" {
		local cost = runiform(`c'-0.5*`grid_step',`c'+0.5*`grid_step')
		local wtp = runiform(`w'-0.5*`grid_step',`w'+0.5*`grid_step')
	}
	else if "$true_dist"=="precise" {
		local cost = `c'
		local wtp = `w'
	}
	else if "$true_dist"=="c uniform" {
		local cost = runiform(`c'-0.5*`grid_step',`c'+0.5*`grid_step')
		local wtp = `w'
	}
	
	*redefine mvpf to have +ve wtp if necessary
	if `wtp' < 0 {
		local wtp = -`wtp'
		local cost = -`cost'
	}
	
	*Define true mvpf
	local mvpf = `wtp'/`cost'
	if `wtp' > 0 & `cost' == 0 local mvpf = `inf'
	if `wtp' < 0 & `cost' == 0 local mvpf = -`inf'
	
	*Draw sampling parameters
	local rho = ${rho} 
	local s_wtp = ${s_wtp}
	local s_cost = ${s_cost}
	matrix define true_pe_mat = [`wtp' \ `cost']
	matrix define sd_mat = [`s_wtp' \ `s_cost']
	matrix define corr_mat = [1 , `rho' \ `rho' , 1]
	
	*Draw estimated cost and wtp
	drawnorm wtp cost, n(1) clear means(true_pe_mat) sds(sd_mat) corr(corr_mat)
	local wtp_est = wtp[1]
	local cost_est = cost[1]
	
	*Flip if estimated in SW:
	if `wtp_est'<0 & `cost_est'< 0 {
		local wtp_est = -`wtp_est'
		local cost_est = -`cost_est'
		
		*flip truth because we're doing the opposite direction
		local wtp = -`wtp'
		local cost = -`cost'
		local mvpf = `wtp'/`cost'
		if `wtp'> 0 & `cost' <= 0 local mvpf = `inf'
		if `wtp'<0 & `cost' == 0 local mvpf = -`inf'
	}
	
	local mvpf_est = `wtp_est'/`cost_est'
	if `wtp_est' > 0 & `cost_est' == 0 local mvpf_est = `inf'
	if `wtp_est' < 0 & `cost_est' == 0 local mvpf_est = -`inf'
	
	matrix define pe_mat = [`wtp_est' \ `cost_est']
	
	*Draw bootstrapped estimates
	drawnorm wtp cost, n(`bootstrap_reps') clear  means(pe_mat) sds(sd_mat) corr(corr_mat)
	
	g mvpf = wtp/cost
	g SW = (wtp<0 & cost <0)
	
	*Redefine infinity
	recast double mvpf
	su mvpf	
	if max(`=r(max)',`=abs(r(min))',abs(`mvpf_est')) > `inf' {
		local inf_`i' = max(r(max),abs(r(min)),abs(`mvpf_est'))*10
	}
	else local inf_`i' = `inf'
	
	*Code some mvpfs to infinity
	replace mvpf = `inf_`i'' 	if wtp > 0 & cost == 0 
	replace mvpf = -`inf_`i'' 	if wtp < 0 & cost == 0
	replace mvpf = . if SW
	
	*Fix mvpf_est to new infinity if required
	if `wtp_est' > 0 & `cost_est' == 0 local mvpf_est = `inf_`i''
	if `wtp_est' < 0 & `cost_est' == 0 local mvpf_est = -`inf_`i''
	
	*Fix true mvpf to new infinity if required
	if `wtp' > 0 & `cost' == 0 local mvpf = `inf_`i''
	if `wtp' < 0 & `cost' == 0 local mvpf = -`inf_`i''
	
	*Estimate simple CIs
	*Expand percentiles to account for estimates in the SW region
	su SW
	local prop = r(mean)
	local p_low_mvpf = (5 - 100*`prop')/2
	local p_high_mvpf = 100 - `p_low_mvpf'
	
	if `p_low_mvpf' <=0 {
		local l_mvpf = -`inf_`i''
		local u_mvpf = `inf_`i''
	}
	else {
		_pctile mvpf if SW==0, p(`p_low_mvpf' `p_high_mvpf')
		local l_mvpf = r(r1)
		local u_mvpf = r(r2)
	}
	
	*Estimate Efron bias corrected CIs 
	su mvpf
	local mvpf_sd = r(sd)
	sort mvpf
	g pctile = _n/_N
	if `p_low_mvpf'>0 & `mvpf_sd'>0 {
		count if mvpf == `mvpf_est'
		*If PE corresponds to draws take minimum bias amongst possible set
		if `=r(N)' > 0 {
			su pctile if mvpf == `mvpf_est'
			if r(min) > 0.5 local mvpf_pe_p = r(min)
			if r(max) < 0.5 local mvpf_pe_p = r(max)
			if inrange(0.5,r(min),r(max)) local mvpf_pe_p = 0.5
		}
		*Else find midpoint of closest draws
		else {
			su pctile if (`mvpf_est' >= mvpf)
			local lower_p = r(max)
			if `lower_p'==. & r(N)==0 {
				su pctile
				local lower_p = r(min)
			}
			su pctile if (`mvpf_est' <= mvpf)
			local upper_p = r(min)
			if `upper_p'==. & r(N)==0 {
				su pctile
				local upper_p = r(max)
			}
			local mvpf_pe_p = (`lower_p' + `upper_p')/2
			if `mvpf_pe_p'!=. {
				if `mvpf_pe_p'>0.99 local mvpf_pe_p = 0.99
				if `mvpf_pe_p'<0.01 local mvpf_pe_p = 0.01
			}
		}
		
		*Now estimate new alphas and thus CIs
		local l = 0
		local alpha1 = `p_low_mvpf'/100
		local alpha2 = `p_high_mvpf'/100
		foreach alpha in `alpha1' `alpha2' {
			local ++l
			local z_alpha = invnormal(`alpha')
			local z_0 = invnormal(`mvpf_pe_p')
			local new_alpha_`l' = normal(2*`z_0' + `z_alpha')
			_pctile mvpf , p(`=`new_alpha_`l'' * 100')
			local d_mvpf_`l' = `r(r1)'
		}
	}
	*If no variance in mvpf draws then assign whole CI at draws conditional on there being variance in wtp/cost
	else if `mvpf_sd' == 0 & `p_low_mvpf'>0 {
		su wtp
		local sd_1 = r(sd)
		su cost
		local sd_2 = r(sd)
		if `sd_1'>0 | `sd_2'>0 {
			_pctile mvpf, p(`p_low_mvpf' `p_high_mvpf')
			local d_mvpf_1 = r(r1)
			local d_mvpf_2 = r(r2)
		}
		else{
			forval l = 1/2 {
				local d_mvpf_`l' = .
			}
		}
	}
	*If too many draws in SW region expand CI to encompass everything
	else if `p_low_mvpf' <= 0 {
		local d_mvpf_1= - `inf_`i''
		local d_mvpf_2 = `inf_`i''
	}
	
	local l_mvpf_ef = `d_mvpf_1'
	local u_mvpf_ef = `d_mvpf_2'
	
	*Piece together results
	clear
	set obs 1
	g covered = inrange(`mvpf',`l_mvpf',`u_mvpf')
	g covered_ef = inrange(`mvpf',`l_mvpf_ef',`u_mvpf_ef')
	g covered_n_sw = inrange(`mvpf',`l_mvpf',`u_mvpf') if (`prop' < 0.05)
	g covered_ef_n_sw = inrange(`mvpf',`l_mvpf_ef',`u_mvpf_ef') if (`prop' < 0.05)
	g n_covered_u = `mvpf'>`u_mvpf'
	g n_covered_l = `mvpf'<`l_mvpf'
	g n_covered_u_ef = `mvpf'>`u_mvpf_ef'
	g n_covered_l_ef = `mvpf'<`l_mvpf_ef'
	
	g p_sw_hi = (`prop' >= 0.05)
	g p_sw = `prop'
	g p_low_mvpf = `p_low_mvpf'
	g wtp = `w'
	g cost = `c'

	append using `sims'
	save `sims', replace
}
