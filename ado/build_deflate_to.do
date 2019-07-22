*===============================================================================
* Purpose: output data for deflate_to.ado
*===============================================================================

*CPI-U
import excel "${welfare_files}/Data/inputs/deflate_to/cpi_u.xlsx", clear
ren A year
drop N O
drop in 1/12
ds year, not
destring year `r(varlist)', replace force
ds year, not
egen cpi_u = rowmean(`r(varlist)')
keep year cpi_u
tempfile cpi_u
save `cpi_u'
tostring year cpi_u, replace force
g locals = "local cpi_u_"+year+" = "+cpi_u
outfile locals using "${welfare_files}/Data/inputs/deflate_to/cpi_u_series_locals.txt", replace noquote


*CPI-U-RS
*https://www.bls.gov/cpi/research-series/home.htm
import excel "${welfare_files}/Data/inputs/deflate_to/cpi_u_rs.xlsx", clear cellrange(A7) first
renvars * , lower
keep year avg
ren avg cpi_u_rs
tempfile cpi_u_rs
save `cpi_u_rs'
tostring year cpi_u_rs, replace force
g locals = "local cpi_u_rs_"+year+" = "+cpi_u_rs
outfile locals using "${welfare_files}/Data/inputs/deflate_to/cpi_u_rs_series_locals.txt", replace noquote


*CPI-U-RS extended via CPI-U

use `cpi_u', clear
merge 1:1 year using `cpi_u_rs', nogen
tsset year
g g_cpi_u = cpi_u / L.cpi_u
g n_year = -year
tsset n_year
replace cpi_u_rs = L.cpi_u_rs / L.g_cpi_u if cpi_u_rs==.
g g_cpi_u_rs = cpi_u_rs / F.cpi_u_rs
assert g_cpi_u == g_cpi_u_rs if year <= 1978

keep year cpi_u_rs
ren cpi_u_rs cpi_u_rs_extended
tostring year cpi_u_rs_extended, replace force
g locals = "local cpi_u_rs_extended_"+year+" = "+cpi_u_rs_extended
outfile locals using "${welfare_files}/Data/inputs/deflate_to/cpi_u_rs_extended_series_locals.txt", replace noquote
