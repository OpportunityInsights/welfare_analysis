/*******************************************************************************
	Get expected mother age in a given year from child age and child year of birth

	Source: CDC data, see build_est_life_impact.do

*******************************************************************************/

* drop program
cap program drop get_mother_age

* define program
program define get_mother_age, rclass 

* syntax
syntax anything(name=year id="Year") , yob(real)
	
*Mean mother ages by birth cohort 1960-2005
global mother_age_1960 = 25.85998726
global mother_age_1961 = 25.93366623
global mother_age_1962 = 25.93479347
global mother_age_1963 = 25.96970367
global mother_age_1964 = 26.03688431
global mother_age_1965 = 26.04781151
global mother_age_1966 = 25.92436218
global mother_age_1967 = 25.83920479
global mother_age_1968 = 25.74608803
global mother_age_1969 = 25.66665268
global mother_age_1970 = 25.55743027
global mother_age_1971 = 25.50759506
global mother_age_1972 = 25.41373253
global mother_age_1973 = 25.3343811
global mother_age_1974 = 25.27130508
global mother_age_1975 = 25.28398514
global mother_age_1976 = 25.36966896
global mother_age_1977 = 25.39791107
global mother_age_1978 = 25.44277382
global mother_age_1979 = 25.47469139
global mother_age_1980 = 25.50602722
global mother_age_1981 = 25.57194328
global mother_age_1982 = 25.64364243
global mother_age_1983 = 25.7168293
global mother_age_1984 = 25.8150425
global mother_age_1985 = 25.87001419
global mother_age_1986 = 25.93109512
global mother_age_1987 = 26.01826668
global mother_age_1988 = 26.0676403
global mother_age_1989 = 26.05931664
global mother_age_1990 = 26.09706306
global mother_age_1991 = 26.03761101
global mother_age_1992 = 26.09503746
global mother_age_1993 = 26.15459824
global mother_age_1994 = 26.22550011
global mother_age_1995 = 26.32520294
global mother_age_1996 = 26.44292641
global mother_age_1997 = 26.54706573
global mother_age_1998 = 26.65357208
global mother_age_1999 = 26.75517464
global mother_age_2000 = 26.88107109
global mother_age_2001 = 27.01959038
global mother_age_2002 = 27.138937
global mother_age_2003 = 27.30438042
global mother_age_2004 = 27.37801361
global mother_age_2005 = 27.40863037

if inrange(`yob',1960,2005)==0 {
	*Fill in elsewhere
	forval y = 1900/1959 {
		global mother_age_`y' = ${mother_age_1960}
	}
	forval y = 2006/2020 {
		global mother_age_`y' = ${mother_age_2005}
	}
}	
*Estimate age in requested year
return scalar mother_age = round(${mother_age_`yob'}+(`year'-`yob'))
di "Mother age in `year': `=round(${mother_age_`yob'}+(`year'-`yob'))'"
end



	


	
	
