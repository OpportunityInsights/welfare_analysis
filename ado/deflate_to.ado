/*******************************************************************************
* Get correct deflator
*******************************************************************************

	DESCRIPTION: Takes as inputs:
		* Income (specifiy USD year and income year)
		* Whether transfers are to be included
		* Whether payroll tax is to be included 
		* Whether income is to be forecasted (for child programs)
		* Age when income is measured  (if forecasting income)
		* Individual or household earnings (number of children optional)
		* Number of kids in family 
		
*Based on:
Congressional Budget Office, November 2015
"Effective Marginal Tax Rates for Low- and Moderate-Income Workers in 2016"
https://www.cbo.gov/sites/default/files/114th-congress-2015-2016/reports/50923-marginaltaxrates.pdf

*******************************************************************************/

* drop program
cap program drop deflate_to

* define program
program define deflate_to, rclass 

* syntax
syntax anything(name=to), ///
	[ /// 
	from(real 0) /// year to convert from
	index /// return the index in the specified year
	] 
	
*-------------------------------------------------------------------------------
* Check inputs/error messages
*-------------------------------------------------------------------------------

cap assert "`index'"=="index" | "`from'"!="" 
if _rc> 0 {
	di as err "Either specify you want an index or a year to convert from"
	exit
}
if "`index'"=="index" {
	cap assert `from'==0
	if _rc> 0 {
		di as err "from year cannot be specified with index option"
		exit
	}
}
cap confirm integer `to'
if _rc>0 cap confirm number `to'
if _rc==0 local to = round(`to')
else {
	di as err "Year to convert to incorrectly specified"
	exit
}
cap confirm integer `from'
if _rc>0 local from = round(`from')

*Default to a series
local series = "cpi_u_rs_extended"

*-------------------------------------------------------------------------------
* Import data
*-------------------------------------------------------------------------------

*See build_deflate_to.do for details, normalised by 2015 value

*CPI-U
local cpi_u_1945 = 17.99166679
local cpi_u_1946 = 19.51666641
local cpi_u_1947 = 22.32500076
local cpi_u_1948 = 24.04166603
local cpi_u_1949 = 23.80833244
local cpi_u_1950 = 24.06666756
local cpi_u_1951 = 25.95833397
local cpi_u_1952 = 26.54999924
local cpi_u_1953 = 26.76666641
local cpi_u_1954 = 26.85000038
local cpi_u_1955 = 26.77499962
local cpi_u_1956 = 27.18333244
local cpi_u_1957 = 28.09166718
local cpi_u_1958 = 28.85833359
local cpi_u_1959 = 29.14999962
local cpi_u_1960 = 29.57500076
local cpi_u_1961 = 29.89166641
local cpi_u_1962 = 30.25
local cpi_u_1963 = 30.625
local cpi_u_1964 = 31.01666641
local cpi_u_1965 = 31.50833321
local cpi_u_1966 = 32.45833206
local cpi_u_1967 = 33.35833359
local cpi_u_1968 = 34.78333282
local cpi_u_1969 = 36.68333435
local cpi_u_1970 = 38.82500076
local cpi_u_1971 = 40.49166489
local cpi_u_1972 = 41.81666565
local cpi_u_1973 = 44.40000153
local cpi_u_1974 = 49.30833435
local cpi_u_1975 = 53.81666565
local cpi_u_1976 = 56.90833282
local cpi_u_1977 = 60.60833359
local cpi_u_1978 = 65.23332977
local cpi_u_1979 = 72.57499695
local cpi_u_1980 = 82.40833282
local cpi_u_1981 = 90.92500305
local cpi_u_1982 = 96.5
local cpi_u_1983 = 99.59999847
local cpi_u_1984 = 103.8833313
local cpi_u_1985 = 107.5666656
local cpi_u_1986 = 109.6083298
local cpi_u_1987 = 113.625
local cpi_u_1988 = 118.2583313
local cpi_u_1989 = 123.9666672
local cpi_u_1990 = 130.6583405
local cpi_u_1991 = 136.1916656
local cpi_u_1992 = 140.3166656
local cpi_u_1993 = 144.4583282
local cpi_u_1994 = 148.2250061
local cpi_u_1995 = 152.3833313
local cpi_u_1996 = 156.8500061
local cpi_u_1997 = 160.5166626
local cpi_u_1998 = 163.0083313
local cpi_u_1999 = 166.5749969
local cpi_u_2000 = 172.1999969
local cpi_u_2001 = 177.0666656
local cpi_u_2002 = 179.875
local cpi_u_2003 = 183.9583282
local cpi_u_2004 = 188.8833313
local cpi_u_2005 = 195.2916718
local cpi_u_2006 = 201.5916595
local cpi_u_2007 = 207.3424225
local cpi_u_2008 = 215.3025055
local cpi_u_2009 = 214.5370026
local cpi_u_2010 = 218.0554962
local cpi_u_2011 = 224.9391632
local cpi_u_2012 = 229.5939178
local cpi_u_2013 = 232.957077
local cpi_u_2014 = 236.7361603
local cpi_u_2015 = 237.0169983
local cpi_u_2016 = 240.0071716
local cpi_u_2017 = 245.1195831
local cpi_u_2018 = 250.7917786

*CPI-U-RS
local cpi_u_rs_1977 = .
local cpi_u_rs_1978 = 104.4
local cpi_u_rs_1979 = 114.3
local cpi_u_rs_1980 = 127.1
local cpi_u_rs_1981 = 139.1
local cpi_u_rs_1982 = 147.5
local cpi_u_rs_1983 = 153.8
local cpi_u_rs_1984 = 160.2
local cpi_u_rs_1985 = 165.7
local cpi_u_rs_1986 = 168.6
local cpi_u_rs_1987 = 174.4
local cpi_u_rs_1988 = 180.7
local cpi_u_rs_1989 = 188.6
local cpi_u_rs_1990 = 197.9
local cpi_u_rs_1991 = 205.1
local cpi_u_rs_1992 = 210.2
local cpi_u_rs_1993 = 215.5
local cpi_u_rs_1994 = 220
local cpi_u_rs_1995 = 225.3
local cpi_u_rs_1996 = 231.3
local cpi_u_rs_1997 = 236.3
local cpi_u_rs_1998 = 239.5
local cpi_u_rs_1999 = 244.6
local cpi_u_rs_2000 = 252.9
local cpi_u_rs_2001 = 260.1
local cpi_u_rs_2002 = 264.2
local cpi_u_rs_2003 = 270.2
local cpi_u_rs_2004 = 277.5
local cpi_u_rs_2005 = 286.9
local cpi_u_rs_2006 = 296.2
local cpi_u_rs_2007 = 304.6
local cpi_u_rs_2008 = 316.3
local cpi_u_rs_2009 = 315.2
local cpi_u_rs_2010 = 320.4
local cpi_u_rs_2011 = 330.5
local cpi_u_rs_2012 = 337.5
local cpi_u_rs_2013 = 342.5
local cpi_u_rs_2014 = 348.3
local cpi_u_rs_2015 = 348.9
local cpi_u_rs_2016 = 353.4
local cpi_u_rs_2017 = 361
local cpi_u_rs_2018 = 369.8

*CPI-U-RS extended back to 1945 by growth rate of CPI-U
local cpi_u_rs_extended_2018 = 369.8
local cpi_u_rs_extended_2017 = 361
local cpi_u_rs_extended_2016 = 353.4
local cpi_u_rs_extended_2015 = 348.9
local cpi_u_rs_extended_2014 = 348.3
local cpi_u_rs_extended_2013 = 342.5
local cpi_u_rs_extended_2012 = 337.5
local cpi_u_rs_extended_2011 = 330.5
local cpi_u_rs_extended_2010 = 320.4
local cpi_u_rs_extended_2009 = 315.2
local cpi_u_rs_extended_2008 = 316.3
local cpi_u_rs_extended_2007 = 304.6
local cpi_u_rs_extended_2006 = 296.2
local cpi_u_rs_extended_2005 = 286.9
local cpi_u_rs_extended_2004 = 277.5
local cpi_u_rs_extended_2003 = 270.2
local cpi_u_rs_extended_2002 = 264.2
local cpi_u_rs_extended_2001 = 260.1
local cpi_u_rs_extended_2000 = 252.9
local cpi_u_rs_extended_1999 = 244.6
local cpi_u_rs_extended_1998 = 239.5
local cpi_u_rs_extended_1997 = 236.3
local cpi_u_rs_extended_1996 = 231.3
local cpi_u_rs_extended_1995 = 225.3
local cpi_u_rs_extended_1994 = 220
local cpi_u_rs_extended_1993 = 215.5
local cpi_u_rs_extended_1992 = 210.2
local cpi_u_rs_extended_1991 = 205.1
local cpi_u_rs_extended_1990 = 197.9
local cpi_u_rs_extended_1989 = 188.6
local cpi_u_rs_extended_1988 = 180.7
local cpi_u_rs_extended_1987 = 174.4
local cpi_u_rs_extended_1986 = 168.6
local cpi_u_rs_extended_1985 = 165.7
local cpi_u_rs_extended_1984 = 160.2
local cpi_u_rs_extended_1983 = 153.8
local cpi_u_rs_extended_1982 = 147.5
local cpi_u_rs_extended_1981 = 139.1
local cpi_u_rs_extended_1980 = 127.1
local cpi_u_rs_extended_1979 = 114.3
local cpi_u_rs_extended_1978 = 104.4
local cpi_u_rs_extended_1977 = 96.99811626
local cpi_u_rs_extended_1976 = 91.07660111
local cpi_u_rs_extended_1975 = 86.12866855
local cpi_u_rs_extended_1974 = 78.91349854
local cpi_u_rs_extended_1973 = 71.05815972
local cpi_u_rs_extended_1972 = 66.92376284
local cpi_u_rs_extended_1971 = 64.8032181
local cpi_u_rs_extended_1970 = 62.13587279
local cpi_u_rs_extended_1969 = 58.70833289
local cpi_u_rs_extended_1968 = 55.66755075
local cpi_u_rs_extended_1967 = 53.38696972
local cpi_u_rs_extended_1966 = 51.94659649
local cpi_u_rs_extended_1965 = 50.42620745
local cpi_u_rs_extended_1964 = 49.63933777
local cpi_u_rs_extended_1963 = 49.01251039
local cpi_u_rs_extended_1962 = 48.41235725
local cpi_u_rs_extended_1961 = 47.83887977
local cpi_u_rs_extended_1960 = 47.33208289
local cpi_u_rs_extended_1959 = 46.65190866
local cpi_u_rs_extended_1958 = 46.18512475
local cpi_u_rs_extended_1957 = 44.95814782
local cpi_u_rs_extended_1956 = 43.5044434
local cpi_u_rs_extended_1955 = 42.85094238
local cpi_u_rs_extended_1954 = 42.97097372
local cpi_u_rs_extended_1953 = 42.8376036
local cpi_u_rs_extended_1952 = 42.49084809
local cpi_u_rs_extended_1951 = 41.54393976
local cpi_u_rs_extended_1950 = 38.51649967
local cpi_u_rs_extended_1949 = 38.10305606
local cpi_u_rs_extended_1948 = 38.47648438
local cpi_u_rs_extended_1947 = 35.72911935
local cpi_u_rs_extended_1946 = 31.23463646
local cpi_u_rs_extended_1945 = 28.79401274

*-------------------------------------------------------------------------------
* Return deflator/index
*-------------------------------------------------------------------------------

if "`index'"=="" {
	local deflator = ``series'_`to''/``series'_`from''

	di "Deflator: `deflator'"

	return scalar deflator = `deflator'
}

if "`index'"=="index" {
	local inf_index = ``series'_`to''
	
	di "Index `to': `inf_index'"
	
	return scalar index = `inf_index'
}

end

/*Example entries

deflate_to 1996 , from(1992)
deflate_to 1990 , index




	

	
	
