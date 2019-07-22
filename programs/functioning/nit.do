/****************************************************************************************
0. Program: Negative income tax. 

This analysis is based off The Long-Term Effects of Cash Assistance, by Price & Song.
https://www.davidjonathanprice.com/docs/djprice_jsong_simedime_WP621.pdf
https://www.davidjonathanprice.com/docs/djprice_jsong_simedime_appendix.pdf
Unless specified, all page, figure and table references are from that paper.

We also use some supplementary estimates from:
https://www.ssa.gov/policy/docs/statcomps/supplement/2017/6c.pdf (age receiving SSI)
https://assets.aeaweb.org/asset-server/articles-attachments/aer/data/dec2011/20081333_app.pdf (cost of SSI)
https://aspe.hhs.gov/report/overview-final-report-seattle-denver-income-maintenance-experiment (treatment and control transfers)
https://taxfoundation.org/us-federal-individual-income-tax-rates-history-1913-2013-nominal-and-inflation-adjusted-brackets/ (baseline ATR) 

We consider a hypothetical policy which replaces all pre-existing benefits with a
lump-sum payment for a set number of years. A family receiving the payment faces a
fixed per-dollar clawback rate in lieu of any income taxes; after the lump-sum has been
entirely clawed back the family pays whatever tax rate they would have paid in the
absense of the policy.

We include effects on transfers (including SSDI) and on earnings, for both recipients
and their children. We ignore health effects, effects on marriage/divorce, and effects
on SSI claims.

We include all reduced-form effects on childrens' income (earnings and SSDI) in WTP.
We include only mechanical effects on parents' income (i.e. assuming no behavioural
respone) in WTP.
We include all reduced-form effects in the fiscal externality.

****************************************************************************************/

tempfile initial all_estimates baselineParentEarnings baselineChildEarnings
save `initial', replace emptyok

/****************************************************************************************
1. Pull Global Assumptions (except for tax rates, which vary over the age).
****************************************************************************************/

* Only use locals in calculations, pull necessary globals into locals:
local program_folder "${input_data}/causal_estimates/uncorrected/nit"
local discount_rate = $discount_rate
local discount_factor = 1/(1+`discount_rate')
local proj_age = $proj_age // Final age for which earnings effects are included.
local correlation = $correlation // Sampling correlation between estimates
local payroll_assumption "$payroll_assumption"   // Include payroll taxes in average tax rates.
local tax_rate_assumption "$tax_rate_assumption" // 'continuous' if we assume a constant rate
                                                 // (equal to $tax_rate_cont) or 'cbo' if we
                                                 // try to calculate average income-year
                                                 // specific tax rates using data from the
                                                 // CBO.
if "`tax_rate_assumption'" ==  "continuous" local tax_rate_cont = $tax_rate_cont // set assumed tax rate
local existing_ATR "$existing_ATR" // 'married' if we use the "Married filing jointly"
								   // tax schedule to calculate the pre-policy average
								   // tax rate or 'single' if we use the "Head of
								   // household" schedule.
								   // doesn't matter if tax_rate_assumption == continuous.
local wtp_age = "$wtp_age" // Whether to include children, adults or both in WTP.
assert inlist("`wtp_age'", "child", "adult", "both")
local cost_age = "$cost_age" // Whether to include adults, parents or both in cost.
                             // Note that program_cost is always included.
assert inlist("`cost_age'", "child", "adult", "both")
local DI_in_WTP = "$DI_in_WTP" // Include effects on kid DI receipts in WTP (adult receipts
                               // are never included).
assert inlist(`DI_in_WTP', 1, 0)
local behavior_value = "$behavior_value" // Incomes change partially due to behaviour
                                         // change. This is the proportion of that change
										 // which is valued.
local add_tax_effect = $add_tax_effect // Does Figure 1a net out taxes? It isn't clear.
                                       // If this macro = 1, we add the effect of the
									   // tax cut to our estimate of program cost and
									   // WTP. If it's 0 we assume that that effect
									   // is already included in the figures calculated
									   // in 4.b.

/****************************************************************************************
2. Estimated Inputs from Paper.
Load anything that has standard errors we can then use in simulations. Note that they are
in a dta, rather than in locals, as there are so many estimates.
****************************************************************************************/

/* Details of how dataset is constructed:

local program_folder "${input_data}/causal_estimates/uncorrected/nit"
tempfile all_estimates
* Short-run effects on parents' earnings and transfers from Figure 1.
import delimited "`program_folder'/nit_parentShortRunEffects.csv", clear
rename effect_*_se se*
rename effect_*    estimate*
reshape long se estimate, i(relative_year duration) j(specification) string
replace specification = "parent short-run " + specification
save "`all_estimates'"

* Long-run effects on parents' earnings from Figure 3.
import delimited "`program_folder'/nit_parentLongRunEffects.csv", clear // From Figure 1.
rename (effect_earnings effect_earnings_se) (estimate se)
generate specification = "parent long-run earnings"
append using  "`all_estimates'"
save "`all_estimates'", replace

* Effects on childrens' earnings from Figure C.6.
import delimited "`program_folder'/nit_childEffects.csv", clear // From Figure 1.
rename (effect_earnings effect_earnings_se) (estimate se)
generate specification = "child earnings"
append using  "`all_estimates'"
save "`all_estimates'", replace

* Manually enter effects on SSDI, from tables C.1 (a)(3) and C.4 (a)(3).
set obs `=_N+2'
replace specification = "parent SSDI" if _n == _N - 1
replace specification = "child SSDI"  if _n == _N
replace estimate = 0.0335  if _n == _N - 1
replace estimate = 0.00729 if _n == _N
replace se = 0.0178  if _n == _N - 1
replace se = 0.00853 if _n == _N
save "`all_estimates'", replace

* If bootstrapping replace estimates with their random draw.
if "`bootstrap'" == "yes" {
	* Transfer and earnings effects are negatively correlated.
	generate transfer_effect = !strpos(specification, "earnings")
    * This redraws the estimates with the appropriate correlation.
    generate idiosyncratic_noise = rnormal()
    generate common_component    = `=rnormal()'*(-1)^transfer_effect
    replace estimate = estimate                                              ///
                     + sqrt(`correlation'*se^2)*common_component             ///
                     + sqrt(se^2 - `correlation'*se^2)*idiosyncratic_noise
    drop idiosyncratic_noise common_component transfer_effect
	
}
save "`all_estimates'", replace
*/

*Import preprocessed datasets, with bootstrapping option when run externally
if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
		if ${draw_number} == 1 {
			use "${input_data}/causal_estimates/${folder_name}/draws/${name}.dta", clear
			cap drop *_pe
			qui ds draw_number, not 
			global estimates_${name} = r(varlist)
			local ests ${estimates_${name}}
			renvars `ests', prefix(pe)
			reshape long pe, i(draw_number) j(estimate) string
			g est_num = .
			local j = 0
			foreach est in `ests' {
				local ++j
				replace est_num = `j' if estimate == "`est'"
				global est_`j' = "`est'"
			}
			global max_j = `j'
			drop estimate
			forval draw = 1/$replications {
			preserve
				keep if draw_number == `draw'
				mkmat pe draw_number est_num, matrix(draws_`draw'_${name})
			restore
			}
	}

	clear
	svmat draws_${draw_number}_${name}, names(col)
	g estimate = ""
	forval j = 1/$max_j {
		replace estimate = "${est_`j'}" if est_num == `j'
	}
	keep pe estimate		
}
if "`bootstrap'" != "yes" {
	import delimited "${input_data}/causal_estimates/${folder_name}/${name}.csv", clear
	keep pe estimate		
}

* change format to fit with original code
replace estimate = regexr(estimate, "^par_", "parent_")
g specification = ""
local specs child_earnings parent_long_run_earnings parent_short_run_earnings ///
	parent_short_run_transfers parent_SSDI child_SSDI
foreach spec in `specs' {
	replace specification = "`spec'" if regexm(estimate, "^`spec'")
}
replace estimate = subinstr(estimate, specification , "",.)
replace specification = subinstr(subinstr(subinstr(specification, "_", " ",.), "short run", "short-run",.), "long run", "long-run",.)

g age = regexr(regexr(estimate, "_d(([0-9])+)", ""),"_y(([0-9])+)", "")
replace age = subinstr(age, "_a", "",.)
destring age, replace

g relative_year = regexr(regexr(estimate, "_d(([0-9])+)", ""),"_a(([0-9])+)", "")
replace relative_year = subinstr(relative_year, "_y", "",.)
destring relative_year, replace

g duration = regexr(regexr(estimate, "_y(([0-9])+)", ""),"_a(([0-9])+)", "")
replace duration = subinstr(duration, "_d", "",.)
destring duration, replace
drop estimate
ren pe estimate

save "`all_estimates'", replace

/****************************************************************************************
3. Exact Inputs from Paper and parameters.
Load exact inputs from the paper and set parameters governing recipient demographics
and policy details.
****************************************************************************************/

* Counterfactual earnings are in nit_childBaselineEarnings and
*  nit_parentBaselineEarnings.csv.
import delimited "`program_folder'/nit_childBaselineEarnings.csv", clear
save "`baselineChildEarnings'"
import delimited "`program_folder'/nit_parentBaselineEarnings.csv", clear
save "`baselineParentEarnings'"

* Set parameters governing policy details.
local year_implemented           1971    // Year policy is implemented. This local shouldn't affect results.
local duration                   5       // The number of years for which the policy was implemented. Should be 3 or 5.
local clawback_rate              0.65    // The rate at which the lump-sum payment is attenuated per dollar earnt. See discussion at top of p 6. Actual was between 50% and 80%.

* Set parameters governing recipient demographics.
local initial_age_of_adult 35       // Initial age of the representative adult. 35 is the first age we have counterfactual income (from C.4).
local num_adults           1.525    // Families average 5185/3400 = 1.525 adults on the basis of Table A.1.
local num_children         2.893    // Families average 9676/3345 = 2.9 children on the basis of Table A.1
local initial_age_of_child 7        // Initial age of the representative child.
local age_of_SSDI 50 // Age at which a person starts to receive SSDI, if they ever do (see https://www.ssa.gov/policy/docs/statcomps/supplement/2017/6c.pdf).
                     // Note that we don't explicitly allow for crowd-out of other transfers from DI, which will be important if this is high.

* Average tax rate on baseline earnings, assuming a 1971 tax schedule (regardless
* of year_implemented) and that the person earns less than 8000 1970 dollars.
* See https://taxfoundation.org/us-federal-individual-income-tax-rates-history-1913-2013-nominal-and-inflation-adjusted-brackets/
* Note this is only used if "$tax_rate_assumption" != "continuous".
deflate_to 1971, from(2013)
local deflator = r(deflator)
if "`tax_rate_assumption'" != "continuous" {
	use "`baselineParentEarnings'", clear
	keep if age == `initial_age_of_adult'
	assert _N == 1
	generate earnings_1971 = earnings*`deflator'
	assert earnings_1971 <= 8000
	if "`existing_ATR'" == "single" { // Head of Household tax brackets.
		generate tax_paid = min(earnings_1971, 1000)*0.14
		if earnings_1971 > 1000 replace tax_paid = tax_paid + min(earnings_1971-1000, 1000)*0.16
		if earnings_1971 > 2000 replace tax_paid = tax_paid + min(earnings_1971-2000, 2000)*0.18
		if earnings_1971 > 4000 replace tax_paid = tax_paid + min(earnings_1971-4000, 2000)*0.19
		if earnings_1971 > 6000 replace tax_paid = tax_paid +    (earnings_1971-6000)      *0.22
	}
	if "`existing_ATR'" == "married" { // Married filing jointly tax brackets.
		generate tax_paid = min(earnings_1971, 1000)*0.14
		if earnings_1971 > 1000 replace tax_paid = tax_paid + min(earnings_1971-1000, 1000)*0.15
		if earnings_1971 > 2000 replace tax_paid = tax_paid + min(earnings_1971-2000, 1000)*0.16
		if earnings_1971 > 3000 replace tax_paid = tax_paid + min(earnings_1971-3000, 1000)*0.17
		if earnings_1971 > 4000 replace tax_paid = tax_paid +    (earnings_1971-4000)      *0.19
	}
	generate baseline_atr = tax_paid/earnings_1971
	local baseline_atr = baseline_atr[1]
}


/****************************************************************************************
4. Intermediate Calculations:
    a) Tax avoided.
	b  Effect on parents' transfers.
    c) Effect on childrens' earnings and taxes.
    d) Effect on DI receipts.
****************************************************************************************/

/* 4.a Tax avoided.

Calculate the taxes that our person now no longer has to pay because the policy essentially
zero-rates income under lump_sum_size/clawback_rate. This affects WTP and cost.

We assume that a family's earnings are always lower than lump_sum_size/clawback_rate,
which allows us to avoid specifying lump_sum_size. This is true for lump_sum_size = 22000,
clawback_rate = 0.65, and our baseline income measure.

This is only used if `add_tax_effect' == 1. Otherwise we assume this effect is
included in the statistic in 4.b

*/
if `add_tax_effect' == 1 {
	* Make each year an observation.
	clear
	set obs `duration'
	generate age = `initial_age_of_adult' + _n - 1
	generate year = `year_implemented' + _n - 1
	* Load in baseline earnings in those years.
	merge 1:1 age using "`baselineParentEarnings'", assert(match using) keep(match) nogen
	* Load in tax rates in those years.
	if "`tax_rate_assumption'" ==  "continuous" generate baseline_tax = `tax_rate_cont'
	if "`tax_rate_assumption'" ==  "cbo"        generate baseline_tax = `baseline_atr'
	* Calculate old tax paid.
	generate tax_decrease_discounted = `discount_factor'^(_n-1)*(earnings*baseline_tax)
	collapse (sum) tax_decrease
	local tax_decrease = tax_decrease[1]
}
else local tax_decrease 0


/* 4.b Effect on parents' transfers.
We have a reduced-form estimate of the effect on transfers. This includes both
the mechanical increase in transfers and the increase induced by the negative
labor supply effect. Both parts go into the fiscal externality, but only the
former goes into WTP. 
The WTP = Δ transfers given fixed income
        = total Δ transfers - Δ transfers due to income change
        = total Δ transfers - clawback_rate x Δ earnings
*/
clear
set obs `duration'
generate relative_year = _n
generate duration = `duration'
* Load transfer effects.
generate specification = "parent short-run transfers"
merge 1:n relative_year duration specification using "`all_estimates'",  nogen ///
										keep(match) assert(match using) keepusing(estimate)
	
isid relative_year // to make sure the 1:n merge doesn't cause errors.										
rename estimate change_transfers
* Load earnings effects.
replace specification = "parent short-run earnings"
merge 1:n relative_year duration specification using "`all_estimates'", nogen ///
										keep(match master) keepusing(estimate)
isid relative_year // to make sure the 1:n merge doesn't cause errors.										
rename estimate change_earnings
drop specification
* Take the net present value of transfer changes and earnings changes, and use
* the above formulate to find the WTP.
generate change_earnings_discounted  = change_earnings*`discount_factor'^(_n-1)
generate change_transfers_discounted = change_transfers*`discount_factor'^(_n-1)
collapse (sum) change*discounted
local adult_earnings_effect_sr = change_earnings_discounted[1]
local transfer_cost = change_transfers_discounted[1]
local transfer_WTP  = change_transfers_discounted[1] ///
                    + (1-`behavior_value')*`adult_earnings_effect_sr'*`clawback_rate'

di `adult_earnings_effect_sr'

/* 4.c Effect on childrens' earnings and taxes.
This is a fairly mechanical use of the estmates in Figure C.6.
As in other programs, we assume Δtax = Δearnings x old marginal tax rate
*/
* Load a representative child.
use "`baselineChildEarnings'", clear
generate specification = "child earnings"
merge 1:n age specification using "`all_estimates'", ///
			nogen assert(match using) keep(match) keepusing(estimate)
isid age // to make sure the 1:n merge doesn't cause errors.
rename estimate effect_earnings
* Calculate marginal tax rate.
if "`tax_rate_assumption'" ==  "continuous" generate marginal_tax_rate = `tax_rate_cont'
if "`tax_rate_assumption'" ==  "cbo" {
	generate marginal_tax_rate = .
	forvalues i = 1/`=_N' {
		local inc_year = age[`i']+`year_implemented'-`initial_age_of_child'
		get_tax_rate `=earnings[`i']', ///
			inc_year(`=min(`inc_year', 2018)') /// 
			program_age(`=age[`i']') ///
			usd_year(2013) ///
			include_payroll("`payroll_assumption'") ///
			include_transfers(yes) ///
			earnings_type(household) ///
			forecast_income(no)
		replace marginal_tax_rate = r(tax_rate) if _n == `i'
	}
}
* The effect on tax is positive if we increased the tax take:
generate effect_tax = marginal_tax_rate*effect_earnings
* Project and effect on earnings, taxes and transfers for ages beyond what we have data for.
set obs `=_N+1'

est_life_impact `=effect_earnings[`=_N-1']', ///
	impact_age(55) project_age(56) end_project_age(`proj_age') ///
	project_year(`=56-`initial_age_of_child'+`year_implemented'') usd_year(2013) ///
	income_info(`=earnings[`=_N-1']') income_info_type(counterfactual_income) ///
	earn_method($earn_method) tax_method($tax_method) transfer_method($transfer_method) ///
	max_age_obs(55)

*Add to earnings series
replace effect_earnings = r(tot_earn_impact_d)                              if _n == _N

* use last tax rate in the observed range and apply it to the projected earnings
replace effect_tax      =  effect_earnings*`=marginal_tax_rate[`=_N -1']'   if _n == _N

* Discount each year's earnings and tax effects, and collapse over all years.
generate effect_earnings_discounted = effect_earnings*`discount_factor'^(age-`initial_age_of_child')
generate effect_tax_discounted      = effect_tax*`discount_factor'^(age-`initial_age_of_child')
local earnings_children_a55 = earnings[`=_N-1']
local earnings_children_age = age[`=_N - 1']
collapse (sum) effect_tax_discounted effect_earnings_discounted
* Multiply by the number of children and save.
local tax_loss_child        = -effect_tax_discounted[1]
local child_earnings_effect = effect_earnings_discounted[1]
local earnings_children_year = `earnings_children_age'+`year_implemented'-`initial_age_of_child'

/* 4.d Effect on DI receipts.

First, we take the gender-specific discounted total costs from von Wachter, Song & Manchester tables G.3 and G.4.
We then inflate these to get an annual cost using the discount rate provided by Von Wachter et al (0.03)
the average years on SSDI program (row 1) and the 'PDV of Annual Benefits Including Medicare Benefits' (row 7),
assuming a constant annual cost. We match observed age distribution. E.g. for women we solve:
sum_{t=0}^10 [(1/(1+0.03))^t*X] + (1/(1+0.03))^11*0.7*X = 168242 for X.

We then reinflate these annual costs into a total lifetime cost, using our preferred discount rate.

Use a 50-50 gender split

We finally deflate costs using estimated effects on SSDI claims.
*/

* Calculate annual DI cost for men and women from
* get inflation adjustment
deflate_to 2013, from(1997)
local deflate_from_1997 = r(deflator)
* https://assets.aeaweb.org/asset-server/articles-attachments/aer/data/dec2011/20081333_app.pdf
local total_cost_women  = 168242     // Table G4 column 3 row 7
local num_years_women   = 11.7       // Table G4 column 3 row 1
local total_cost_men    = 178570     // Table G3 column 3 row 7
local num_years_men     = 10.0       // Table G3 column 3 row 1
foreach gender in men women {
    * Set constants.
    local temp_discount_rate = 0.03 // discount rate assumed by von Wachter et al
    local d          = 1/(1+`temp_discount_rate') // discount factor
    local full_years = floor(`num_years_`gender'')
    local part_year  =  `num_years_`gender'' -`full_years'

	
    * Calculation of: 
    *    total_cost/(sum_{t=0}^(full_years-1) [d^t] + d^full_years*part_year)
    local divisor = `d'^`full_years'*`part_year'
    forvalues t = 0/`=`full_years'-1' {
        local divisor = `divisor' + `d'^`t'
    }
    local annual_cost_`gender' = `total_cost_`gender''/`divisor'
    * Transform to 2013 $ from 1997 $.
    local annual_cost_`gender' = `annual_cost_`gender'' *`deflate_from_1997'
}

* Calculate total discounted DI cost for each child, assuming 50/50 gender split. This goes into
* both WTP and the fiscal externality.
clear
* Create an observation for each gender.
set obs 2
generate female = _n - 1
generate annual_cost = cond(female, `annual_cost_women', `annual_cost_men')
* Create observations for each year that each gender would be on SSDI.
generate num_years   = cond(female, `num_years_women',   `num_years_men')
expand ceil(num_years)
sort female, stable
by female: generate year = `year_implemented' + `age_of_SSDI' - `initial_age_of_child' + _n - 1
* Discount the final year by the proportion they would spend on DI.
by female: generate partial_year_discounter = cond(_n > floor(num_years), num_years - floor(num_years), 1)
* Calculate discounted cost, and sum over the years spend on DI.
generate discounted_cost = partial_year_discounter*`discount_factor'^(year - `year_implemented')*annual_cost
collapse (sum)  discounted_cost, by(female)
* Take the average over the two genders.
collapse (mean) discounted_cost
* And deflate with the effect on claiming DI.
generate specification = "child SSDI"
merge 1:n specification using "`all_estimates'", nogen keepusing(estimate) assert(match using) keep(match)
local DI_cost_child = discounted_cost[1]*estimate[1]

* Calculate DI cost for the adult. This only goes into the fiscal externality.
clear
set obs 2
generate female = _n - 1
generate initial_age_of_adult = `initial_age_of_adult'
generate annual_cost = cond(female, `annual_cost_women', `annual_cost_men')
* Create observations for each year that each gender would be on SSDI.
generate num_years   = cond(female, `num_years_women',   `num_years_men')
expand ceil(num_years)
sort female, stable
by female: generate year = `year_implemented' + `age_of_SSDI' - initial_age_of_adult + _n - 1
* Discount the final year by the proportion they would spend on DI.
by female: generate partial_year_discounter = cond(_n > floor(num_years), num_years - floor(num_years), 1)
* Calculate discounted cost, and sum over the years spend on DI.
generate discounted_cost = partial_year_discounter*`discount_factor'^(year - `year_implemented')*annual_cost
collapse (sum)  discounted_cost, by(female)
* Average over the two genders.
collapse (mean)  discounted_cost
* Deflate with the effect on claiming DI.
generate specification = "parent SSDI"
merge 1:n specification using "`all_estimates'", nogen keepusing(estimate) assert(match using) keep(match)
local DI_cost_adult = discounted_cost[1]*estimate[1]



/* 4.e Changing tax income as a result of changing parent earnings.
As discussed in 4.a, we assume that a person's earnings are below lump_sum_size/claw_back_rate
and thus they face 0 tax rate while the policy is in place. As such we ignore
earnings effects while the policy is in prace.
We use the age-specific effects on earnings from Figure 3 after.
As in other programs, we assume Δtax = Δearnings x old marginal tax rate
*/
clear
* Create an annual dataset starting when the policy was implemented and ending the year
* the parent turns `proj_age' years old.
set obs `=`proj_age'-`initial_age_of_adult' + 1 - `duration''
generate age = `initial_age_of_adult' + _n - 1 + `duration'
generate year = `year_implemented' + _n - 1 + `duration'
* Load baseline earnings.
merge 1:1 age using "`baselineParentEarnings'", assert(match using) keep(match) nogen
rename earnings earnings_old
* Load age-specific effects on earnings.
generate specification = "parent long-run earnings"
merge 1:n age specification using "`all_estimates'", nogen ///
                                        keep(match master) keepusing(estimate)
isid age // to make sure the 1:n merge doesn't cause errors.
drop specification
* Load marginal tax rates on pre-policy income.
if "`tax_rate_assumption'" ==  "continuous" generate marginal_tax_rate = `tax_rate_cont'
if "`tax_rate_assumption'" ==  "cbo" {
    generate marginal_tax_rate = .
    forvalues y = 1/`=_N' {
			di "`=earnings_old[`y']'"
			di "`=max(min(`y'+`year_implemented'-1, 2018), 1980)'"
			di "`=age[`y']'"
		get_tax_rate `=earnings_old[`y']' , ///
            inc_year(`=max(min(`y'+`year_implemented'-1, 2018), 1980)') /// 
            usd_year(2013) ///
			program_age(`=age[`y']') ///
            include_payroll("`payroll_assumption'") ///
            include_transfers("yes") ///
			earnings_type(household) /// 
			forecast_income(no)
        replace marginal_tax_rate = r(tax_rate) if _n == `y'
    }
}
qui su earnings_old if age == 55 // age chosen for reporting of parental income
local earnings_parents_a55 = r(mean)
qui su year if age == 55
local earnings_parents_year = r(mean)

* Calcuate tax take, and sum its discounted change.
generate effect_earnings_discounted =                    estimate*`discount_factor'^(year - `year_implemented')
generate effect_tax_discounted      = -marginal_tax_rate*estimate*`discount_factor'^(year - `year_implemented')
collapse (sum) effect_tax_discounted effect_earnings_discounted
local tax_loss_adult        = effect_tax_discounted[1]
local adult_earnings_effect = effect_earnings_discounted[1]


/****************************************************************************************
5. Cost calculations.
In this section we calculate the cost of changing parent earnings due to changing
earnings. To find the cost of the policy we add those to some statistics calculated
in S4: the cost of the transfers, the mechanical effects of the tax change, the
effects on childrens' tax payments and the effects on DI claims.
****************************************************************************************/

/* 5.a Sum to find the total cost.
*/
* The program cost includes only the direct cost of increased transfers and decreased taxes.
local program_cost_per_parent = `transfer_cost' + `tax_decrease'
local program_cost = `num_adults' * `program_cost_per_parent'

* The total cost can also include the effect on tax & transfers due to changed earnings of
* both the child (calculated in S 4.b) and the parent, and the effect on SSDI receipts.
* Sometimes we include only one age group.
local total_cost = `program_cost'                                                    ///
    + `num_adults' *  (`tax_loss_adult'+`DI_cost_adult')*("`cost_age'" != "child")   ///
    + `num_children'* (`tax_loss_child'+`DI_cost_child')*("`cost_age'" != "adult")
* get 2015 deflator for income
deflate_to 2015, from(2013)
local deflator = r(deflator)

global adult_tax_impact = `tax_loss_adult'
global child_tax_impact =  `tax_loss_child'
global adult_DI_cost = `DI_cost_adult'
global child_DI_cost = `DI_cost_child'

/****************************************************************************************
6. WTP Calculations.
Our parent will be willing to pay the mechanical increase in transfers (assuming no
behavior change) + the decrase in tax liability. We assume the child will be willing
to pay for the full increase in their income (earnings + SSI).
****************************************************************************************/

local WTP_per_adult = `transfer_WTP' + `tax_decrease' + `behavior_value'*(`tax_loss_adult'+`DI_cost_adult')

** Kid WTP is the new DI income + the increase in earnings + their tax savings.
local child_net_earnings_effect = `child_earnings_effect' + `tax_loss_child'
local WTP_per_child = `DI_cost_child'*`DI_in_WTP' + `child_net_earnings_effect'

* Total WTP generally sums over WTP for parents and kids.
if "`wtp_age'" == "child"  local WTP =                                `num_children'*`WTP_per_child'
if "`wtp_age'" == "adult"  local WTP = `num_adults'*`WTP_per_adult'
if "`wtp_age'" == "both"   local WTP = `num_adults'*`WTP_per_adult' + `num_children'*`WTP_per_child'


/****************************************************************************************
7. MVPF Calculations.
****************************************************************************************/

local MVPF = `WTP'/`total_cost'

* Determine beneficiary age and determine whther the three children benefited (on average)
* more than the parent, to determine age_benef. If we don't "$wtp_age" == "both" this is mechanical.
if (`num_adults'*`WTP_per_adult')<(`num_children'*`WTP_per_child')  | "`wtp_age'" == "child" local age_benef = `initial_age_of_child'
if (`num_adults'*`WTP_per_adult')>=(`num_children'*`WTP_per_child') | "`wtp_age'" == "adult" local age_benef = `initial_age_of_adult'


/****************************************************************************************
8. Outputs.
****************************************************************************************/

* Store outputs in globals for the wrapper.
di `MVPF'
di `total_cost'
di `program_cost'

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global WTP_`1' = `WTP'
global age_stat_`1'  = `initial_age_of_adult'  // Age of statutory beneficiaries.
global age_benef_`1' = `age_benef'             // Age of economic beneficiaries - those with highest WTP.

* income globals
global inc_stat_`1' = `earnings_parents_a55'*`deflator'
global inc_type_stat_`1' = "household"
global inc_year_stat_`1' = `earnings_parents_year'
global inc_age_stat_`1' = 55

if `age_benef' == `initial_age_of_adult' {
	global inc_benef_`1' = `earnings_parents_a55'*`deflator'
	global inc_type_benef_`1' = "household"
	global inc_year_benef_`1' = `earnings_parents_year'
	global inc_age_benef_`1' = 55
}
else {
	global inc_benef_`1' = `earnings_children_a55'*`deflator'
	global inc_type_benef_`1' = "individual"
	global inc_year_benef_`1' = `earnings_children_year'
	global inc_age_benef_`1' = `earnings_children_age'
}

use `initial', clear
