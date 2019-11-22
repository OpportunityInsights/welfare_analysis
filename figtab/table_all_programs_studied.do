********************************************************************************
* 	Graph costs by age for all possible programs
********************************************************************************

*options
local corr = 1

* Set file paths
global output "${welfare_files}/figtab/tables"
cap mkdir "$output"

import excel "${welfare_files}/MVPF_Calculations/Further program details.xlsx", clear first
replace program = lower(program)
keep if prog_type !=""

merge 1:1 program using "${welfare_files}/data/derived/all_programs_extendeds_corr_1.dta", ///
		keepusing(age_benef year_implementation) assert(master match) keep(match) nogen

*Drop  non-sample MTO & taxes
drop if prog_type=="Top Taxes" & main_spec==0
drop if regexm(prog_type,"MTO") & main_spec==0		
		
g baseline = main_spec==1
g restricted = main_spec==1 & (earnings_type==""|earnings_type=="observed")
g extended = 1

replace prog_type="MTO" if regexm(prog_type,"MTO")

replace paper_cite_keys = subinstr(paper_cite_keys,",",", ",.)
gen papers = wordcount(paper_cite_keys)
replace paper_cite_keys = subinstr(paper_cite_keys," ","",.)
replace paper_cite_keys = subinstr(paper_cite_keys," ","",.)
replace paper_cite_keys = subinstr(paper_cite_keys," ","",.)
split paper_cite_keys, parse(",")
expand papers

bys program : g paper_num = _n
su paper_num
g papers_utilized = ""
forval i = 1/`=r(max)' {
	replace papers_utilized = paper_cite_keys`i' if paper_num==`i'
}
drop paper_cite* 

sort prog_type label_name paper_num
replace prog_type = "zOther" if prog_type=="Other"
sort prog_type label_name paper_num
replace prog_type = "Other" if prog_type=="zOther"


keep prog_type long_description small_label_name papers_utilized baseline restricted extended age_benef estimates_mvpf year_implementation

g group = ""
replace group = "Social Insurance" if inlist(prog_type, "Disability Ins.", "Health Adult", "Health Child", "Unemp. Ins.", "Supp. Sec. Inc.")
replace group = "In Kind Transfers" if inlist(prog_type, "Nutrition", "Housing Vouchers", "MTO")
replace group = "Education" if inlist(prog_type, "Child Education", "Job Training", "College Child", "College Adult")
replace group = "Taxes" if inlist(prog_type, "Top Taxes", "Cash Transfers")
replace group = "Welfare Reform" if inlist(prog_type, "Welfare Reform")
g group_order = 0
replace group_order = 1 if group=="Education"
replace group_order = 2 if group=="Social Insurance"
replace group_order = 3 if group=="In Kind Transfers"
replace group_order = 4 if group=="Taxes"
replace group_order = 5 if group=="Welfare Reform"
sort group_order prog_type long_description papers_utilized

* make some changes to long description (just for table 1)
replace long_description = "Top Taxes, Economic Recovery Tax Act 1981" if long_description == "Top Taxes, Economic Recovery Tax Act 1981 (Saez Estimates)"
replace long_description = "Top Taxes, Tax Reform Act 1986" if long_description == "Top Taxes, Tax Reform Act 1986 (Auten & Carroll Estimates)"
replace long_description = "Top taxes, Omnibus Budget Reconciliation Act 1993" if long_description == "Top taxes, Omnibus Budget Reconciliation Act 1993 (Carroll Estimates)"
replace long_description = "Top Taxes, Economic Growth And Tax Relief Reconciliation Act 2001" if long_description == "Top Taxes, Economic Growth And Tax Relief Reconciliation Act 2001 (Heim Estimates)"
replace long_description = "Top Taxes, Affordable Care Act" if long_description == "Top Taxes, Affordable Care Act (Kawano et al. Estimates)"

* drop zimmerman everywhere except fiu
drop if papers_utilized == "Zimmerman2014" & small_label_name != "FIU GPA"

* make longer category names
replace prog_type = "Disability Ins." if prog_type == "Disability Ins."
replace prog_type = "Supplemental Security Income" if prog_type == "Supp. Sec. Inc."
replace prog_type = "Unemployment Insurance" if prog_type == "Unemp. Ins."

*Format papers_utilized to be accessed from lyx
replace papers_utilized = "\cite{"+papers_utilized+"}" if papers_utilized!=""
replace papers_utilized = "." if papers_utilized==""
*Introduce panel breaks
g correct_order = _n

*remove excess data
bys small_label_name : egen min_temp = min(correct_order)
g first_row = correct_order==min_temp
drop min_temp
ds papers_utilized correct_order prog_type, not
sort correct_order
foreach g in `r(varlist)' {
	cap replace `g' = "" if first_row==0
	cap replace `g' = . if first_row==0
}

drop first_row
bys prog_type : egen min_temp = min(correct_order)
g first_row = correct_order==min_temp
drop min_temp
expand 1+first_row, gen(id)

gsort correct_order -id correct_order

ds prog_type id correct_order, not
foreach var in `r(varlist)' {
	cap replace `var' = "" if id==1
	cap replace `var' = . if id==1
}

replace long_description = prog_type if id==1
drop prog_type group correct_order first_row id

replace papers_utilized = "xx" if papers_utilized==""
replace papers_utilized = papers_utilized + " \newline"

order long_description small_label_name year_implementation age_benef  baseline restricted  ///
	 extended estimates_mvpf papers_utilized, first
	
replace age_benef = round(age_benef,1)
tostring *, replace force
ds 
foreach var in `r(varlist)' {
	replace `var' = "" if `var'=="."
}


foreach var in baseline restricted extended estimates_mvpf {
	replace `var' = "x" if `var'=="1"
	replace `var' = "" if `var'=="0"
}
* add blank lines between categories
cap drop correct_order
g correct_order = _n

expand 2 if small_label_name == "" & long_description != "", gen(id2)
gsort correct_order -id2

ds id2 correct_order id papers_utilized, not
foreach var in `r(varlist)' {
	cap replace `var' = "" if id2 == 1 
	cap replace `var' = . if id2 == 1 

}

drop correct_order id2 group_order
export excel "$output/update_table1.xlsx", sheetmodify sheet("RAW")
