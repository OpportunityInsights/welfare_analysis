/*
clean data from 'Delta Cost Project Database 1987–2015' to write ado-file
to calculate the cost of college in a consistent way
for reference, see: 
https://www.deltacostproject.org/sites/default/files/database/DCP_Database_Documentation_1987-2015.pdf
https://www.deltacostproject.org/delta-cost-project-database
*/

cd "${welfare_files}/Data/inputs/cost_of_college"

use delta_public_release_87_99, clear
append using delta_public_release_00_15 

* generate public / private indicator
gen public_private = . 
replace public = 1 if inlist(sector, 1, 4, 7) // public 
replace public = 2 if inlist(sector, 2, 3, 5, 6, 8, 9) // private 

* restrict to public universities
keep if public_private == 1

* use Carnegie classifications from different years to classify universities into
* research, masters, bachelors, community
foreach year in 2005 2010 {
	gen type_of_uni`year' = .
	replace type_of_uni`year' = 1 if inlist(carnegie`year', 15, 16, 17) // research
	replace type_of_uni`year' = 2 if inlist(carnegie`year', 18, 19, 20) // masters
	replace type_of_uni`year' = 3 if inlist(carnegie`year', 21, 22, 23) // bachelors
	replace type_of_uni`year' = 4 if inrange(carnegie`year', 1, 8) | inlist(carnegie`year', 11, 12) // community (associates)
	}

local year 2000 
gen type_of_uni`year' = .
replace type_of_uni`year' = 1 if inlist(carnegie`year', 15, 16) // research
replace type_of_uni`year' = 2 if inlist(carnegie`year', 21, 22) // masters
replace type_of_uni`year' = 3 if inlist(carnegie`year', 31, 32) // bachelors
replace type_of_uni`year' = 4 if inlist(carnegie`year', 33, 40) // community (associates)	

label def type_of_uni 1 "research" 2 "masters" 3 "bachelors" 4 "community"
label val type_of_uni* type_of_uni

* restrict to research, masters or bachelors universities as well as community colleges
keep if type_of_uni2010 != . | type_of_uni2005 != . | type_of_uni2000 != .

* drop military universities
drop if strpos(lower(instname), "air force")!=0
drop if strpos(lower(instname), "military")!=0
drop if strpos(lower(instname), "army")!=0

* keep key variables only and clean up 
keep state academicyear instname type_of_uni* eandr net_student_tuition fte_count tuitionfee02_tf tuitionfee03_tf
order state academicyear instname type_of_uni* eandr net_student_tuition fte_count tuitionfee02_tf tuitionfee03_tf
ren (academicyear instname) (year name)
replace name = lower(name)

sort state name year
isid state name year 

* save
save cost_of_college_data.dta, replace
