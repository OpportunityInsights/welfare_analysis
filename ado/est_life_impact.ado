/*******************************************************************************
* Estimate lifetime earnings impacts from short run impacts
*******************************************************************************

	DESCRIPTION: Takes as inputs:
		* an estimate of a policy's level (or %) earnings impact in a given year
		* an estimated parent income, parent income rank or direct counterfactual income
		* dates of policy and impact as well as age when policy enacted

	See "build_est_life_impact.do" for derivation of data that is input here
	from .dta files

*******************************************************************************/

cap program drop est_life_impact

program define est_life_impact, rclass
qui {
* syntax
syntax anything(name=earn_impact id="Earnings impact") , ///
	impact_age(real) /// age at which income is measured - and age for which counterfactual income is returned
	project_age(real) /// age at which projection starts
	end_project_age(real) /// age at which projection ends
	project_year(real) /// year in which projection starts
	usd_year(real) /// all dollar values given in this usd_year
	income_info(real) /// counterfactual income or parent rank or parent income depending on the input to income_info_type
	income_info_type(string) /// "counterfactual_income" or "parent_rank" or "parent_income" or "none"
	earn_method(string) /// "multiplicative" or "fixed" or "observed"
	[percentage(string) /// allows earnings impact to be in % form - "yes", else "no" assumed
	parent_age(integer 200) /// age of parents when their income is measured (if income info type is parent income)
	parent_income_year(integer 200) /// additional info only required when income_info_type is "parent_income"
	earn_series(string) /// all is default, uses population averages by age, "HS" option uses those with HS but no college
	max_age_obs(integer -1) /// max age at which incomes are observed, for observed earn_method
	tax_method(string) /// doesn't do anything, only one setting: off
	transfer_method(string) /// doesn't do anything, only one setting: off
	]

local impact_year = `project_year' + `impact_age' - `project_age'

*	asserts/error statements for correct option specification
cap assert "$earn_method"!=""
if _rc>0 {
	di in red "earn_method not set in global. Note that the option in the program is defunct"
	pause on
	pause
}
else local earn_method $earn_method


if `project_age' > `end_project_age' {
	di in red "Projection start age after projection end age"
	exit
}

if "`income_info_type'" == "parent_rank" {
	if `income_info' > 100 {
		di as err "Parent rank may not exceed 100, perhaps you want the counterfactual_income option for income_info_type()"
		exit
	}
	else local parent_rank `income_info'
}

if "`income_info_type'" == "counterfactual_income" {
	if `income_info' <= 100 {
		di as err "It looks like you want the parent_rank option for income_info_type()"
		exit
	}
	else local cfactual_income `income_info'
}

if "`income_info_type'" == "parent_income" {
	cap assert "`parent_income_year'" != "200"
	if _rc > 0 {
		di "year in which parent income measured not specified, assuming the same as impact_year"
		local parent_income_year = `impact_year'
	}
}

cap assert inlist("`income_info_type'","counterfactual_income","parent_rank","parent_income","none")
if _rc > 0 {
	di as err "income_info_type() must be either none, parent_rank, or counterfactual_income"
}

*Set up modifier to get right earnings series
if "`earn_series'"=="HS" local wag_mod = "_HS"
else local wag_mod = ""

if "`earn_method'"=="observed" {
	if `max_age_obs'==-1 {
		di in red "No max age at which income is observed specified"
		local earn_impact = 0 // force zeros to be returned
	}
	else {
		if inrange(`max_age_obs',`project_age',`end_project_age') {
			local end_project_age = `max_age_obs' // reduce forecast length to observed period
		}
		else if `max_age_obs' < `project_age' local earn_impact = 0 // force zeros to be returned
	}
	local earn_method = "multiplicative" 			// return to normal operation
}

*-------------------------------------------------------------------------------
*			   	    DEFINE LOCALS FOR OPERATION FROM GLOBALS
*-------------------------------------------------------------------------------

local project_end_year = `project_year' + `end_project_age' - `project_age'

local base_year = `project_year'

local max_age = 97

if "$discount_rate" != "" {
	local discount = $discount_rate
}
else {
	di in red "No discount rate global found, assuming 0.03"
	local discount 0.03
}

if "$wage_growth_rate" != "" {
	local wage_g = $wage_growth_rate
}
else {
	di in red "No wage growth global found, assuming 0.005"
	local wage_g = 0.005
}

*-------------------------------------------------------------------------------
*					  	 IMPORT DATA AND PUT IN LOCALS
*-------------------------------------------------------------------------------

*Try to store data in globals to improve speed where possible
if "$data_in_mem" != "yes" {
	preserve
		* Parent and child rank relation
		use "${welfare_files}/Data/inputs/lifetime_forecasts/national_parent_child_rank.dta", clear

		sort par_pctile
		forvalues i = 1/100 {
			global c_rank_p_rank_`i' = s_kir_pooled_pooled[`i']
		}

		*Get inflation indices from deflate_to function (CPI-U-RS)
		local cpi_early = 1945
		local cpi_late = 2018
		forval i = `cpi_early'/`cpi_late' {
			deflate_to `i', index
			global cpi_u_`i' = r(index)
		}

		*ACS mean wages by age in 2015
		use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta", clear
		su age
		global acs_youngest = r(min)
		global acs_oldest = r(max)
		forvalues age = ${acs_youngest}/${acs_oldest} {
			local index = `age' - (${acs_youngest} - 1)
			global mean_wage_a`age'_2015 = wag[`index']
		}

		*ACS mean wages by age in 2015
		use "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age_HS_only.dta", clear
		su age
		global acs_HS_youngest = r(min)
		global acs_HS_oldest = r(max)
		forvalues age = ${acs_HS_youngest}/${acs_HS_oldest} {
			local index = `age' - (${acs_youngest} - 1)
			global mean_wage_HS_a`age'_2015 = wag[`index']
		}

	restore

	global data_in_mem yes
}
forval a = ${acs`wag_mod'_youngest}/${acs`wag_mod'_oldest} {
	*Adjust 2015 mean wages to relevant USD year and adjust by wage growth to fit sample
	local mean_wage`wag_mod'_a`a' = ${mean_wage`wag_mod'_a`a'_2015} * ///
		(${cpi_u_`usd_year'}/${cpi_u_2015}) * ///
		((1 + `wage_g')^(`impact_year' - 2015 + `a'-`impact_age'))
}

*Get parent age if required, using get_mother_age ado
if "`income_info_type'" == "parent_income" & "`parent_age'" == "200" {  // 200 is default value
	local birth_year = `impact_year' - `impact_age'
	get_mother_age `parent_income_year' , yob(`birth_year')
	local parent_age = r(mother_age)
}

*-------------------------------------------------------------------------------
*							PRODUCE REQUIRED INPUTS
*-------------------------------------------------------------------------------

/*
FG facts:
	* Child income measured 2014-15 : 2014 (Chetty et al., 2018)
	* Average child age at measurement: 34 (Chetty et al., 2018)
	* Parent income measured 1994,1995,1998-2000: 1997 (Chetty et al., 2018)
	* Average parent age at measurement: 42.1: 42 (Chetty et al., 2014)
	* Conver
Chetty et al. (2014) uses a slightly different sample but generally very similar.
*/

local ch_inc_base_year = 2014
local ch_inc_base_age = 34
local par_inc_base_year = 1997
local par_inc_base_age = 42
local fg_usd_year = 2015

if "`income_info_type'" == "parent_income" {
	*Convert income by inflation/wage growth to equivalent in `par_inc_base_year'
	local par_inc_base_year = (${cpi_u_`fg_usd_year'}/${cpi_u_`usd_year'}) * ///
		((1+`wage_g')^(`par_inc_base_year'- `parent_income_year')) * `income_info'

	*Convert via ACS mean ratios to predicted parent income at `par_inc_base_age'
	*Assume parents earnings follow ACS lifecycle path too
	local par_inc_base_year_age = `par_inc_base_year' * ///
		(${mean_wage_a`par_inc_base_age'_2015}/${mean_wage_a`parent_age'_2015})

	*Convert from parent income to ranks using convert_rank_dollar command, see
	*in ado in same folder as this file for more details
	convert_rank_dollar `par_inc_base_year_age', par_inc reverse
	local income_info = r(rank)
	local income_info_type = "parent_rank"
}

if "`income_info_type'" == "parent_rank" {
	*Predict child rank via national rank-rank (+ interpolation)
	local f_p_rank=floor(`income_info')
	local c_p_rank=`f_p_rank'+1

	local child_rank = ${c_rank_p_rank_`f_p_rank'} + ///
		(((`income_info'-`f_p_rank')/(`c_p_rank' - `f_p_rank')) * ///
		(${c_rank_p_rank_`c_p_rank'}-${c_rank_p_rank_`f_p_rank'}))



	*Predict child individual income at 34 via convert_rank_dollar
	qui convert_rank_dollar `child_rank', kir multiply100
	local child_inc_34 = r(dollar_amount)

	*Convert from age 34 income to requested year via ACS mean ratios, wage growth, and CPI
	local cfactual_income = `child_inc_34' * ///
		(${mean_wage_a`impact_age'_2015}/${mean_wage_a34_2015}) * ///
		((1 + `wage_g')^(`impact_year' - `ch_inc_base_year')) * ///
		(${cpi_u_`usd_year'}/${cpi_u_`fg_usd_year'})

	local income_info_type = "counterfactual_income"
}
if "`income_info_type'" == "none" {
	local cfactual_income = ${mean_wage`wag_mod'_a`impact_age'_2015} * ///
		(${cpi_u_`usd_year'}/${cpi_u_2015}) * ///
		((1 + `wage_g')^(`impact_year' - 2015))
	local income_info_type "counterfactual_income"
}

*-------------------------------------------------------------------------------
*							GENERATE EARNINGS ESTIMATES
*-------------------------------------------------------------------------------

if inlist("`earn_method'","multiplicative","fixed") {
	cap assert "`income_info_type'" == "counterfactual_income"
	if _rc>0 {
		di as err `"income_info_type should be "counterfactual_income" at this point - debugging needed"'
		exit
	}

	*Find earnings impact
	if "`percentage'" == "yes" local pct_increase = `earn_impact'
	else local pct_increase = `earn_impact' / `cfactual_income'

	*Find counterfactual % of average
	local cfactual_fraction = `cfactual_income' / `mean_wage`wag_mod'_a`impact_age''

	macro drop aggt_earn_impact*
	forvalues year = `project_year'/`project_end_year' {
		local age = `project_age' + `year' - `project_year'
		*apply % increase to constant fraction of population average in each year earnings impacts
		if "`earn_method'"=="multiplicative" {
			local earn_impact_a`age' = `pct_increase' * `cfactual_fraction' * `mean_wage`wag_mod'_a`age''
		}
		if "`earn_method'"=="fixed" { //project backwards but carry a fixed effect forwards
			if `age'>`impact_age' 	local earn_impact_a`age' = `pct_increase' * `cfactual_fraction' * `mean_wage`wag_mod'_a`impact_age''
			else 					local earn_impact_a`age' = `pct_increase' * `cfactual_fraction' * `mean_wage`wag_mod'_a`age''
		}

		local t = `year' - `project_year'
		local earn_impact_t`t' = `earn_impact_a`age''

		assert `earn_impact_a`age''!=.

		*discounted figures`
		local earn_impact_a`age'_d = `earn_impact_a`age'' * (1/(1+`discount'))^(`year'-`base_year')
		local earn_impact_t`t'_d = `earn_impact_a`age'_d'

		if `year' == `project_year' global aggt_earn_impact_a`age' = `earn_impact_a`age'_d'
		else if `year' > `project_year' {
			global aggt_earn_impact_a`age' = ${aggt_earn_impact_a`=`age'-1'} + `earn_impact_a`age'_d'
		}
	}
}


*-------------------------------------------------------------------------------
*						  		RETURN OUTPUTS
*-------------------------------------------------------------------------------

*Sum over projected years
local outcomes earn
forvalues year = `project_year'/`project_end_year' {
	local age = `project_age' + `year' - `project_year'
	foreach outcome in `outcomes' {
		if `year' == `project_year' {
				local tot_`outcome'_impact = ``outcome'_impact_a`age''
				local tot_`outcome'_impact_d = ``outcome'_impact_a`age'_d'
			}
		else if `year' > `project_year' {
				local tot_`outcome'_impact = `tot_`outcome'_impact' + ``outcome'_impact_a`age''
				local tot_`outcome'_impact_d = `tot_`outcome'_impact_d' + ``outcome'_impact_a`age'_d'
		}
	}
}

foreach outcome in `outcomes' {
	return scalar tot_`outcome'_impact = `tot_`outcome'_impact'
	return scalar tot_`outcome'_impact_d = `tot_`outcome'_impact_d'
}

di as result "Total earnings impact: `tot_earn_impact'"
di as result "Discounted total earnings impact: `tot_earn_impact_d'"
di as result "pct_increase: `pct_increase'"
di as result "cfactual_fraction: `cfactual_fraction'"
di as result "cfactual_income at impact age: `cfactual_income'"
di as result "mean_wage_aimpact_age : `mean_wage_a`impact_age''"
di as result "impact_age : `impact_age'"

return scalar cfactual_income = `cfactual_income'
return scalar parent_age = `parent_age'
return scalar cfactual_fraction = `cfactual_fraction'
return scalar pct_increase = `pct_increase'
}
end
