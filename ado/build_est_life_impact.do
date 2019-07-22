*===============================================================================
* Purpose: output .dtas to store locals within the est_life_impact 
* .ado file
*===============================================================================

*-------------------------------------------------------------------------------
*	GET NATIONAL PARENT RANK - > CHILD RANK FUNCTION
*-------------------------------------------------------------------------------

use "${welfare_files}/Data/inputs/mobility_estimates/nat_pct_kfr_kir_kid_jail_78_83.dta", clear

keep par_pctile s_kir_pooled_pooled

save "${welfare_files}/Data/inputs/lifetime_forecasts/national_parent_child_rank.dta", replace

*-------------------------------------------------------------------------------
*	GET MEAN EARNINGS BY AGE
*-------------------------------------------------------------------------------

*Get ACS mean earnings by age in 2015
use "${welfare_files}/data/inputs/acs_2015/usa_00006.dta", clear
ren incwage wag
keep if age >= 18
collapse (mean) wag [w=perwt], by(age)
tsset age
tsfill
replace wag = 0 if wag == .
save "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", replace

*-------------------------------------------------------------------------------
*	GET MEAN EARNINGS BY AGE BY EDUCATIONAL ATTAINMENT
*-------------------------------------------------------------------------------

use "${welfare_files}/data/inputs/acs_2015/usa_00006.dta", clear
ren incwage wag
keep if age >= 18
collapse (mean) wag [w=perwt], by(age educ)
xtset educ age
tsfill
*Keep only those who have completed HS but not attended college
keep if educ==6
save "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age_HS_only.dta", replace


*-------------------------------------------------------------------------------
*	GET MEAN AGE OF MOTHER BY COHORT
*-------------------------------------------------------------------------------

*Import CDC data
import excel "${welfare_files}\Data\inputs\mother_ages\birth_rates_by_age_by_cohort.xlsx", clear cellrange(A6:L1710)
ren A birth_cohort 
ren B mother_age
ren C mother_birth_cohort
ren D total_rate
destring birth_cohort mother_age mother_birth_cohort total_rate, replace force
replace total_rate = total_rate / 1000
drop if birth_cohort==.

collapse (mean) mother_age [w=total_rate], by(birth_cohort)

tostring *, replace force
g locals = "global mother_age_"+birth_cohort+" = "+mother_age

save "${welfare_files}/Data/inputs/mother_ages/mother_ages.dta", replace
outfile locals using "${welfare_files}/Data/inputs/mother_ages/mother_ages.txt", replace noquote
