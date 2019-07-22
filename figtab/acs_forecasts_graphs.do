********************************************************************************
* 	Graph costs by age for Miller-Wherry and FIU
********************************************************************************

* Set file paths
global output "${output_root}/scatter"
cap mkdir "$output"

*Import ACS data
use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear
label variable age "Age"

*Medicaid Miller-Wherry
*Import ACS data
use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear
label variable age "Age"

*Get relevant numbers from MW do file file
run_program mc_preg_women

local usd_year = 2011
local proj_year = 2009

deflate_to 2015, from(`usd_year')
local earn_effect_2011 = ${mw_inc_effect} * r(deflator)
local median_income_09 = ${mw_cfactual_inc} * r(deflator)
local avg_age_earn = ${mw_impact_age}

gen proj_start_age = 37
gen earnings_start = 24
gen match_earnings = inrange(age,24,36)



*get wage growth inflated path
gen wag_11 = wag * (1.005^(`proj_year'-2015))
gen wag_adj = wag * (1.005^(age-30-(2015-`proj_year')))

cap gen cfactual_ratio = `median_income_09' / wag_adj if age == `avg_age_earn'
su cfactual_ratio
cap drop temp
egen temp = min(cfactual_ratio)
replace cfactual_ratio = temp
gen cfactual_wage = cfactual_ratio * wag_adj 
gen effect_wage = cfactual_wage * (1+(`earn_effect_2011'/`median_income_09')) if age >= 37
replace effect_wage = cfactual_wage + `earn_effect_2011' if inrange(age,24,36)

di (1+(`earn_effect_2011'/`median_income_09'))

keep if inrange(age,24,65)

*1a: ACS earnings in 2015
tw 	(scatter wag_adj age if 0, connect(l) msize(small)) /// population
	(scatter cfactual_wage age if 0 , connect(l) msize(small)) /// control
	(scatter effect_wage age if 0, connect(l) msize(small)) /// observed effect
	(scatter effect_wage age if 0 & age >= proj_start_age, connect(l) msize(small)) /// predicted effect
	(scatter wag age if 0, connect(l) msize(small) mcolor(black) lcolor(black)) /// ACS 2015
	, legend( cols(4) order(1 2 3 4) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(20(10)70) ylabel(10000(10000)50000)
	
graph export "${output}/acs_forecasts_mc_preg_women_1a.${img}", replace

*2: Adjusted for wage growth
tw 	(scatter wag_adj age if 0, connect(l) msize(small)) /// population
	(scatter cfactual_wage age if 0, connect(l) msize(small)) /// control
	(scatter effect_wage age if 0, connect(l) msize(small)) /// observed effect
	(scatter effect_wage age if 0 & age >= proj_start_age, connect(l) msize(small)) /// predicted effect
	(scatter wag age if 0, connect(l) msize(small) mcolor(black) lcolor(black)) /// ACS 2015
	(scatter wag_11 age if 0, connect(l) msize(small) mcolor(gs8) lcolor(gs8)) /// hypothetical ACS 2011
	(scatter wag_adj age, connect(l) msize(small) mstyle(p1) lstyle(p1)) /// population
	, legend( cols(4) order(1 2 3 4 ) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	ytitle("Wage") ///
	title(" ", size(vhuge)) ///
	xlabel(20(10)70) ylabel(10000(10000)50000)
	
graph export "${output}/acs_forecasts_mc_preg_women_2.${img}", replace


*3: Show observed control period
tw 	(scatter wag_adj age , connect(l) msize(small)) /// population
	(scatter cfactual_wage age if match_earnings, connect(l) msize(small)) /// control
	(scatter effect_wage age if 0, connect(l) msize(small)) /// observed effect
	(scatter effect_wage age if 0 & age >= proj_start_age, connect(l) msize(small)) /// predicted effect
	, legend( cols(4) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(20(10)70) ylabel(10000(10000)50000)
	
graph export "${output}/acs_forecasts_mc_preg_women_3.${img}", replace

*4: Forecast control forwards
tw 	(scatter wag_adj age , connect(l) msize(small)) /// population
	(scatter cfactual_wage age , connect(l) msize(small)) /// control
	(scatter effect_wage age if 0, connect(l) msize(small)) /// observed effect
	(scatter effect_wage age if 0 & age >= proj_start_age, connect(l) msize(small)) /// predicted effect
	, legend( cols(4) order(1 2 3 4) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(20(10)70) ylabel(10000(10000)50000)
	
graph export "${output}/acs_forecasts_mc_preg_women_4.${img}", replace

*5: Show observed treatment period
tw 	(scatter wag_adj age , connect(l) msize(small)) /// population
	(scatter cfactual_wage age , connect(l) msize(small)) /// control
	(scatter effect_wage age if age <= proj_start_age, connect(l) msize(small)) /// observed effect
	(scatter effect_wage age if 0 & age >= proj_start_age, connect(l) msize(small)) /// predicted effect
	, legend( cols(4) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(20(10)70) ylabel(10000(10000)50000)
	
	
graph export "${output}/acs_forecasts_mc_preg_women_5.${img}", replace

*6: Forecast treatment forewards
tw 	(scatter wag_adj age , connect(l) msize(small)) /// population
	(scatter cfactual_wage age , connect(l) msize(small)) /// control
	(scatter effect_wage age if age <= proj_start_age, connect(l) msize(small)) /// observed effect
	(scatter effect_wage age if age >= proj_start_age, connect(l) msize(small)) /// predicted effect
	, legend( cols(4) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	$title ///
	ytitle("Wage") ///
	xlabel(0(10)70) ylabel(10000(10000)50000)
	
graph export "${output}/acs_forecasts_mc_preg_women_6.${img}", replace





* Import costs by age for FIU 
use "${data_derived}/fiu_costs_by_age_1000_replications.dta", clear
keep if round(discount_rate, 0.01) == .03
*Import ACS data
merge 1:1 age using "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", nogen

label variable age "Age"

*Get relevant numbers from FIU file
run_program fiu
local cfactual_income = $fiu_cfactual_inc
local earn_loss_1_7 = $fiu_earn_loss_year
local earn_gain_8_14 = $fiu_earn_gain_year

*Process
local pct_earn_impact_pos = `earn_gain_8_14' / `cfactual_income'
local cfactual_age = 29
local usd_year = 2005
local proj_year = 2015
deflate_to 2015, from(2005)
local cpi_05_to_15 = r(deflator)
gen proj_start_age = 33
local age_2015 = 33
*get wage growth inflated path
gen wag_04 = wag * (1.005^(`proj_year'-2015))
gen wag_adj = wag * (1.005^(age-`age_2015'))

gen cfactual_ratio = `cfactual_income' / wag_adj if age == `cfactual_age'
egen temp = min(cfactual_ratio)
replace cfactual_ratio = temp
gen cfactual_wage = cfactual_ratio * wag_adj

gen effect_neg_wage = cfactual_wage + `earn_loss_1_7' if inrange(age,18,18+7)
gen effect_mid_wage = cfactual_wage + `earn_gain_8_14' if inrange(age,18+7+1,18+7+7)
gen effect_pos_wage = cfactual_wage * (1+`pct_earn_impact_pos') if age >= 32

gen effect_obs_wage = effect_neg_wage if inrange(age,18,18+7)
replace effect_obs_wage = effect_mid_wage if inrange(age,18+7+1,18+7+7)
replace effect_pos_wage=effect_obs_wage if age ==32

keep if age<=65


* 0. Costs on their own
tw 	(line cost age if age<=proj_start_age & cost >=0 , yaxis(2) ls(p1) lc(maroon%20) ) ///
 	(line cost age if age<=proj_start_age & cost <0 , yaxis(2) ls(p1) lc(dkgreen%20) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(navy) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(navy)) ///
	(line u_cost age if  age>=proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(navy))  ///
	(line l_cost age if  age>=proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(navy) ) ///
	(line cost age if age>=proj_start_age & cost>=0, lp(dash) yaxis(2) ls(p1) lc(maroon%20) ) ///
	(line cost age if age>=proj_start_age & cost<0, lp(dash) yaxis(2) ls(p1) lc(dkgreen%20) ) ///
	(scatter wag_adj age if 0, yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age if 0 , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0 , yaxis(1) connect(l) msize(vsmall) mcolor(black) lcolor(black)) ///
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg")  ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small))  legend(off) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

graph export "${output}/acs_forecasts_fiu_just_w_costs_forecast.${img}", replace
	
tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(navy%20) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(navy%20) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(navy%20)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age if 0, yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age if 0 , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0 , yaxis(1) connect(l) msize(vsmall) mcolor(black) lcolor(black)) ///
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg")  ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small))  legend(off) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

graph export "${output}/acs_forecasts_fiu_just_w_costs.${img}", replace
	



*1a: ACS earnings in 2015
tw 	(scatter wag_adj age if 0, connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age if 0 , connect(l) msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, connect(l) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age,  mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0, connect(l) msize(vsmall) mcolor(black) lcolor(black)) /// ACS 2015
	, legend( ring(0) pos(10)  cols(1)  order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	$title ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1))

	
graph export "${output}/acs_forecasts_fiu_1a.${img}", replace

* Graph combined with costs by age
tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(navy%30) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(navy%30) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(navy%30)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age if 0, yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age if 0 , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0, yaxis(1) connect(l) msize(vsmall) mcolor(black) lcolor(black)) ///
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small)) legend(off) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(10000)10000  -40000 "-40k" -30000 "-30k"  -20000 "-20k" -10000 "-10k"   10000 "10k" , axis(2)) ytitle("Cumulative Govt Cost", axis(2))

graph export "${output}/acs_forecasts_fiu_1a_w_costs.${img}", replace
	

*2: Adjusted for wage growth
tw 	(scatter wag_adj age if 0, connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age if 0, connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age if 0, connect(l) msize(vsmall)) /// observed effect
	(scatter effect_mid_wage age if 0, connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age,  mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	///
	(scatter wag age if 0, connect(l) msize(vsmall) mcolor(black) lcolor(black)) /// ACS 2015
	(scatter wag_adj age, connect(l) msize(vsmall) mstyle(p1) lstyle(p1)) /// population
	, legend( ring(0) pos(10)  cols(1) order(1 2 3 4 ) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(4 "Predicted") size(small)) ///
	ytitle("Wage") ///
	title(" ", size(vhuge)) ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1))
	
graph export "${output}/acs_forecasts_fiu_2.${img}", replace

* Graph combined with costs by age
tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white%0) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white%0) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white%0)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age , yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age if 0 , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0, yaxis(1) connect(l) msize(vsmall) mcolor(black) lcolor(black)) ///
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small)) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))
graph export "${output}/acs_forecasts_fiu_2_w_costs.${img}", replace



*3a: Show observed control earnings
tw 	(scatter wag_adj age , connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age if age <=32, connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age if 0, connect(l) msize(vsmall)) /// observed effect
	(scatter effect_mid_wage age if 0, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age  if 0, mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// forecast effect
	, legend( ring(0) pos(10)  cols(1) order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1))
	
graph export "${output}/acs_forecasts_fiu_3a.${img}", replace
* add costs
tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white%0) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white%0) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white%0)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age , yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age if age <=32 , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0, yaxis(1) connect(l) msize(vsmall) mcolor(black) lcolor(black)) ///
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small)) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

	
graph export "${output}/acs_forecasts_fiu_3a_w_costs.${img}", replace

*3b: Show predicted control earnings
tw 	(scatter wag_adj age , connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age, connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age if 0, connect(l) msize(vsmall)) /// observed effect
	(scatter effect_mid_wage age if 0, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age  if 0, mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// forecast effect
	, legend(  ring(0) pos(10)  cols(1)  order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1)) ///

	
graph export "${output}/acs_forecasts_fiu_3b.${img}", replace

* add costs
tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white%0) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white%0) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white%0)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age , yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age  , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	(scatter wag age if 0, yaxis(1) connect(l) msize(vsmall) mcolor(black) lcolor(black)) ///
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small)) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

	
graph export "${output}/acs_forecasts_fiu_3b_w_costs.${img}", replace

*4: Add observed negative earnings
tw 	(scatter wag_adj age , connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age , connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age, mstyle(p3) connect(l)  lstyle(p3) msize(vsmall)) /// observed effect
	(scatter effect_mid_wage age if 0, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age if 0, mstyle(p4) lstyle(p4) connect(l) msize(vsmall)) /// observed effect
	, legend( ring(0) pos(10)  cols(1)  order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1))
	
graph export "${output}/acs_forecasts_fiu_4.${img}", replace

*4: Add observed negative earnings

	tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white%0) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white%0) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white%0)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age , yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age  , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_neg_wage age , yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small)) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

	
graph export "${output}/acs_forecasts_fiu_4_w_costs.${img}", replace

*5: Add observed middle positive earnings
tw 	(scatter wag_adj age , connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age , connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age if 0, mstyle(p3) lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_obs_wage age, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age if 0, mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// forecast effect
	, legend( ring(0) pos(10)  cols(1)  order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	title(" ", size(vhuge)) ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1))
	
graph export "${output}/acs_forecasts_fiu_5.${img}", replace


tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white%0) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white%0) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white%0)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age , yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age  , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_obs_wage age  , yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_mid_wage age if 0, yaxis(1) connect(l) msize(vsmall) mstyle(p4)  lstyle(p4) ) /// observed effect
	(scatter effect_pos_wage age if 0 & age >= proj_start_age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 10) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(10 "Predicted") size(small)) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

graph export "${output}/acs_forecasts_fiu_5_w_costs.${img}", replace

*6: Add forecast positive earnings impact
tw 	(scatter wag_adj age , connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age , connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age if 0, mstyle(p3) lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_obs_wage age if 0, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age, mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// forecast effect
	(scatter effect_obs_wage age, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	, legend(   ring(0) pos(10)  cols(1)  order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	$title ///
	ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1))
	
graph export "${output}/acs_forecasts_fiu_6.${img}", replace

tw 	(scatter wag_adj age , connect(l) msize(vsmall)) /// population
	(scatter cfactual_wage age , connect(l) msize(vsmall)) /// control
	(scatter effect_neg_wage age if 0, mstyle(p3) lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_obs_wage age if 0, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(scatter effect_pos_wage age, mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// forecast effect
	(scatter effect_obs_wage age, mstyle(p3)  lstyle(p3) connect(l) msize(vsmall)) /// observed effect
	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	, legend(   ring(0) pos(10)  cols(1)  order(1 2 3 5) label(1 "Pop Avg") ///
	label(2 "Control Forecast") label(3 "Treatment") label(5 "Predicted") size(small)) ///
	$title ///
	ytitle("Wage") ///
	xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 60000 "60k", axis(1)) ///
	ylabel(-60000(20000)50000 -60000 "-60k" -40000 "-40k" -20000 "-20k" 20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

tw 	(line cost age if age<=proj_start_age, yaxis(2) ls(p1) lc(white%0) ) ///
	(line u_cost age  if age<=proj_start_age , yaxis(2) lp(dot)  ls(p1) lc(white%0) ) ///
	(line l_cost age  if age<=proj_start_age ,yaxis(2) lp(dot)  ls(p1) lc(white%0)) ///
	(line u_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15) ) ///
	(line l_cost age if  age>proj_start_age ,yaxis(2) lp(dot) ls(p1) lc(white%15)) ///
	(scatter wag_adj age , yaxis(1) mstyle(p1)  lstyle(p1) connect(1) msize(vsmall)) /// population
	(scatter cfactual_wage age  , yaxis(1) connect(l) mstyle(p2)  lstyle(p2)  msize(vsmall)) /// control
	(scatter effect_obs_wage age  , yaxis(1) connect(l) mstyle(p3)  lstyle(p3) msize(vsmall)) /// positive effect
	(scatter effect_pos_wage age, yaxis(1) mstyle(p4)  lstyle(p4) connect(l) msize(vsmall)) /// predicted effect
	, legend( ring(0) pos(10)  cols(1)  order(6 7 8 9) label(6 "Pop Avg") ///
	label(7 "Control Forecast") label(8 "Treatment") label(9 "Predicted") size(small)) ///
	$title ytitle("Wage")  xlabel(0(10)70) ylabel(0(10000)60000 10000 "10k" 20000 "20k" 30000 "30k" 40000 "40k" 50000 "50k" 60000 "60k", axis(1)) ///
	 ylabel(-40000(20000)40000  -40000 "-40k"  -20000 "-20k"   20000 "20k" 40000 "40k", axis(2)) ytitle("Cumulative Govt Cost", axis(2))

graph export "${output}/acs_forecasts_fiu_6_w_costs.${img}", replace
