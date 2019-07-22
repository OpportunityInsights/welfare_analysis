*! NJC 1.0.0 20 August 2002
* values of -values-, or its value labels, to be labels of -varname-
program def labmask, sortpreserve 
	version 7 
	syntax varname(numeric) [if] [in], /* 
	*/ VALues(varname) [ LBLname(str) decode ]

	* observations to use 
	marksample touse 
	qui count if `touse' 
	if r(N) == 0 { 
		error 2000 
	}	
	
	* integers only! 
	capture assert `varlist' == int(`varlist') if `touse' 
	if _rc { 
		di as err "may not label non-integers" 
		exit 198 
	}
	
	tempvar diff decoded group example 
	
	* do putative labels differ? 
	bysort `touse' `varlist' (`values'): /* 
		*/ gen byte `diff' = (`values'[1] != `values'[_N]) * `touse' 
	su `diff', meanonly 
	if r(max) == 1 { 
		di as err "`values' not constant within groups of `varlist'" 
		exit 198 
	} 

	* decode? i.e. use value labels (will exit if value labels not assigned) 
	if "`decode'" != "" { 
		decode `values', gen(`decoded') 
		local values "`decoded'" 
	} 	

	* we're in business 
	if "`lblname'" == "" { 
		local lblname "`varlist'" 
	} 
	
	* groups of values of -varlist-; assign labels 
	
	by `touse' `varlist' : /*
		*/ gen byte `group' = (_n == 1) & `touse' 
	qui replace `group' = sum(`group') 

	gen long `example' = _n 
	local max = `group'[_N]  
	
	forval i = 1 / `max' { 
		su `example' if `group' == `i', meanonly 
		local label = `values'[`r(min)'] 
		local value = `varlist'[`r(min)'] 
		label def `lblname' `value' `"`label'"', modify 	
	} 

	label val `varlist' `lblname' 
end 

