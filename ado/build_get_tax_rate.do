*===============================================================================
* Purpose: output data for get_tax_rate.ado
*===============================================================================

*Import poverty thresholds
import excel "${welfare_files}/Data/inputs/get_tax_rate/hstpov1.xls", clear cellrange(A4) first
ren A year
drop if year =="" | strlen(year)>10
replace year = substr(year,1,4)
destring year, replace force
ren E fpl_2
ren people fpl_3
ren I fpl_4
ren J fpl_5
ren K fpl_6
keep year fpl*
duplicates drop year, force

*cpi adjust
preserve
	use "${welfare_files}/Data/inputs/lifetime_forecasts/cpi_u.dta", clear
	tempfile cpi_u
	save `cpi_u'
restore

merge 1:1 year using `cpi_u', assert(2 3) keep(3) nogen

*Put all in 2015 USD
ds fpl*
foreach var in `r(varlist)' {
	replace `var' = `var' * deflator
}

*Output text file to store local
tostring year, replace
ds fpl*
foreach var in `r(varlist)' {
	tostring `var', replace force
	g locals_`var' = "local "+"`var'"+"_"+year+" = "+`var'
}

keep locals_fpl* year
ds locals_fpl*
reshape long locals_fpl_ , i(year) j(sam_size)
sort locals_fpl_
keep locals_fpl_
outfile locals_fpl_ using "${welfare_files}/Data/inputs/get_tax_rate/fpl_locals.txt", replace noquote



*get CPI-U deflators by year

use `cpi_u', clear
tostring year deflator, replace force
g locals = "local deflator_"+year+" = "+deflator
outfile locals using "${welfare_files}/Data/inputs/get_tax_rate/cpi_u_deflator_locals.txt", replace noquote

