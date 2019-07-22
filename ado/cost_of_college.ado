
/*
* Define a program that calculates the cost of college based on the 
Delta Cost Project Database 1987–2015 

for reference, see: 
https://www.deltacostproject.org/sites/default/files/database/DCP_Database_Documentation_1987-2015.pdf
https://www.deltacostproject.org/delta-cost-project-database

Note: Returns the cost as nominal in the year requested
*/


cap program drop cost_of_college
program define cost_of_college, rclass

syntax, year(integer) /// year for which cost of college should be calculated
	/// optional options
	[name(string) /// name of college you want to estimate cost for 
	state(string) /// state for which cost of college should be calculated
	type_of_uni(string) /// type of university - this can be: research, masters, bachelors, community, any, rmb (research, masters, bachelors, i.e. all except community)
	list_all_colleges /// option that simply shows list of all colleges (for specified state, year, etc.)
	]
	
	quietly {
	
	* save dataset that is currently being used and return to it later
	tempfile temp_save
	save `temp_save' , emptyok
	
	* load data to calculate cost of college
	* this is based on data from 
	* https://www.deltacostproject.org/delta-cost-project-database
	* and is cleaned in 'clean_data_for_cost_of_college.do'
	use "${welfare_files}/Data/inputs/cost_of_college/cost_of_college_data.dta", clear
	
	* year must be between 2015 and 1987 because we don't observe data before or after in the delta project
	if `year' > 2015 | `year' < 1987 {
		di in red "year must be between 1987 and 2015" 
		}
	if `year' < 1987 {
		di in red "program instead calculates the cost of college in 1987"
		local year = 1987
		}
		
	* restrict to universities observed in specified year
	keep if year == `year'
	
	* check if option state correctly specified
	* if it is, then restrict to universities in that state
	if "`state'" != "" {
		keep if state =="`state'"
		count
		if `r(N)' == 0 {
			di in red "state `state' does not exist in year `year'"
			if strlen("`state'") != 2 {
				di in red "use two letter state abbreviations (e.g. 'CA' for California)"
				}
			exit 
			}
		}
	
	* check if option type_of_uni correctly specified
	* if it is, then restrict to universities of specified type
	if "`type_of_uni'" != "" {
		if "`type_of_uni'" != "research" & "`type_of_uni'" != "masters" & ///
			"`type_of_uni'" != "bachelors" & "`type_of_uni'" != "community" &  ///
			"`type_of_uni'" != "any" & "`type_of_uni'" != "rmb" {
			di in red "type_of_uni incorrectly specified. type_of_uni must be one of research, masters, bachelors, community, any, rmb"
			exit
			}
		* depending on the year for which we want to calculate the cost of college
		* we should use definitions from different years to categorize universities
		* possible years for classification are 2000, 2005, 2010, so we use whatever is closest
		if inrange(year, 1987, 2002) 				local classification_year = 2000
		if inrange(year, 2003, 2007) 				local classification_year = 2005
		if inrange(year, 2008, 2015) 				local classification_year = 2010
		
		if "`type_of_uni'"	== "research" 			local type_of_uni_num = 1
		if "`type_of_uni'"	== "masters" 			local type_of_uni_num = 2
		if "`type_of_uni'"	== "bachelors" 			local type_of_uni_num = 3
		if "`type_of_uni'"	== "community" 			local type_of_uni_num = 4
		if "`type_of_uni'"	== "any" 				local type_of_uni_num = 5
		if "`type_of_uni'"	== "rmb" 				local type_of_uni_num = 6
		if inrange(`type_of_uni_num', 1, 4) {
			keep if type_of_uni`classification_year' == `type_of_uni_num'
			}
		if "`type_of_uni'" == "rmb"	{
			keep if inrange(type_of_uni`classification_year',1, 3)
			}
		count
		if `r(N)' == 0 {
			if "`state'" == ""	di in red "no universities of type `type_of_uni' exist in year `year'"
			else 				di in red "no universities of type `type_of_uni' exist in year `year' in state `state'"
			exit
			}
		}
	}
	
	* if option list_all_colleges is specified, program does not calculate
	* cost of college. instead it simply lists all colleges in a given state
	if "`list_all_colleges'" !="" {
		sort year state name
		list state name type_of_uni*
		exit
		}
	
	* if option name is specified, restrict to university with specific name 
	* to get the name right, it's helpful to use option 'list_all_colleges' first
	* to see how universities are spelled
	quietly {
	if "`name'" != ""{
		keep if name == "`name'"
		count
		if `r(N)' == 0 {
			if "`state'" == "" 	di in red "`name' does not exist in year `year'"
			else 				di in red "`name' does not exist in year `year' in state `state'"
			if "`type_of_uni'" != "" 	di in red "no need to specify option type_of_uni when option name is specified"
			exit
			}
		}
	
	* now compute the cost of college per full time equivalent student
	* we do this by taking the sum of tuition and the average subsidy
	* and dividing this by the number of full time equivalent students
	* save a local with the cost of college (=r(cost_of_college))
	collapse (rawsum) eandr net_student_tuition fte_count tuitionfee02_tf tuitionfee03_tf
	gen cost_of_college_per_fte = eandr / fte_count
	su cost_of_college_per_fte
	assert `r(N)' == 1
	local cost_of_college = `r(mean)'
	local cost_of_college_rounded = round(`cost_of_college', .01)
	return scalar cost_of_college = `cost_of_college' 
	gen tuition_per_fte = net_student_tuition / fte_count
	su tuition_per_fte
	assert `r(N)' == 1
	local tuition = `r(mean)'
	local tuition_rounded = round(`tuition', .01)
	return scalar tuition = `tuition' 
	su fte_count 
	local fte_count = `r(mean)' 
	return scalar fte_count = `fte_count'
	su tuitionfee02_tf
   	local in_state = `r(mean)'
    return scalar in_state = `in_state'
	su tuitionfee03_tf
   	local out_state = `r(mean)'
	return scalar out_state = `out_state'
	gen in_rat = cost_of_college_per_fte/ tuitionfee02_tf
	su in_rat
	local in_ratio = `r(mean)'
	return scalar in_ratio = `in_ratio'
	gen out_rat = cost_of_college_per_fte/ tuitionfee03_tf
	su out_rat
	local out_ratio = `r(mean)'
	return scalar out_ratio = `out_ratio'

			
	use `temp_save', clear	
	}
	di "calculated cost of college is USD`cost_of_college_rounded' per full-time equivalent student"
	di "average net tuition is USD `tuition_rounded' per full-time equivalent student"
end

