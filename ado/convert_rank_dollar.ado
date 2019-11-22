/*******************************************************************************
* Convert Ranks to Dollars
********************************************************************************
	DESCRIPTION: This program converts ranks into dollar values using the 
	crosswalk from the inside
	You can either just convert a single rank to a dollar amount
	
		(syntax: convert_rank_dollar XX, vartype [multiply100]
				 where XX = rank value for which you want to know the dollar amount)
	
	Or you can compute the difference in ranks from a given base to dollars 
	(e.g. how much is 1 SD in ranks for kir_black_male_p25) 
	
		(syntax: convert_rank_dollar XX YY, vartype
				 where XX = rank value for the base (e.g. mean)
				 and   YY = change (e.g. SD)) 
				 
	Or convert an entire variable to dollar values
	(syntax: convert_rank_dollar varname, vartype [multiply100] variable
				 where varname = name of the variable you want to convert and 
				 you must specify variable to signal you want to convert an entire
				 column)
				 
where 'vartype' refers to the type of variable you are converting, and can be either of
the following: kir, kfr, wagerank, kfr_26_e, kfr_26_l, kir_26_e, kir_26_l, par_inc.
Note:_e and _l refer to early (1978-1983) and late (1984-1989) birth cohorts.
*******************************************************************************/

* drop program
cap program drop convert_rank_dollar

* define program
program define convert_rank_dollar, rclass 

	* syntax
	syntax anything[, kir kfr kfr_26_e kir_26_e kfr_26_l kir_26_l par_inc ///
		wagerank sd multiply100 variable reverse] 
	tokenize `anything' 

	* set household or individual income
       if "`kfr'" != ""			local inc kid_hh_income
       if "`kir'" != ""			local inc kid_indiv_income
	   if "`wagerank'" != ""	local inc kid_wageflex
	   if "`kfr_26_e'" != ""	local inc kid_hh_income_age26_e
	   if "`kir_26_e'" != ""	local inc kid_indiv_income_age26_e
	   if "`kfr_26_l'" != ""	local inc kid_hh_income_age26_l
	   if "`kir_26_l'" != ""	local inc kid_indiv_income_age26_l
	   if "`par_inc'" != ""		local inc parent_hh_income

	* a couple of error messages
	if "`kfr'"=="" & "`kir'"=="" & "`wagerank'" =="" & "`kfr_26_e'" =="" ///
		& "`kir_26_e'" =="" & "`kfr_26_l'" =="" & "`kir_26_l'" =="" & "`par_inc'" =="" {
		di in red "rank (e.g. kfr or kir) must be specified"
		exit
		}
	if "`2'" != "" & "`sd'" == "" {
		di in red "please specify option sd if that's what you want to do"
		exit
		}
	if "`3'" !="" {
		di in red "only one or two inputs allowed" 
		exit
		}
	if `1' > 101 & "`reverse'"=="" {
		di in red "please specify option reverse if that's what you want to do" 
		exit
		}
	if "`reverse'"!="" & ("`sd'"!=""|"`variable'"!=""|"`multiply100'"!="") {
		di in red "reverse option is not compatible with sd, variable or multiply100 options" 
		exit
		}
	if "`sd'" !="" & "`variable'"!= "" {
	di in red "the option sd is not compatible with the variable option, will be written shortly"
	}
	if "`variable'" == "" {
	quietly {

	*******
	* build temp data
	*******

	qui: count 
	local N = `r(N)' 
	if `N' < 101	 			set obs 101

	tempvar temp_percentile
	gen `temp_percentile' = _n-1 in 1/101

	* kfr 
	if "`kfr'" != ""  {
		tempvar temp_`inc'
		gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = 0 if _n ==4
		replace `temp_`inc'' = 0 if _n ==5
		replace `temp_`inc'' = 0 if _n ==6
		replace `temp_`inc'' = 0 if _n ==7
		replace `temp_`inc'' = 0 if _n ==8
		replace `temp_`inc'' = 0 if _n ==9
		replace `temp_`inc'' = 0 if _n ==10
		replace `temp_`inc'' = 25.38736343383789 if _n ==11
		replace `temp_`inc'' = 224.5708618164063 if _n ==12
		replace `temp_`inc'' = 820.9931640625 if _n ==13
		replace `temp_`inc'' = 1794.332275390625 if _n ==14
		replace `temp_`inc'' = 2992.315185546875 if _n ==15
		replace `temp_`inc'' = 4288.796875 if _n ==16
		replace `temp_`inc'' = 5574 if _n ==17
		replace `temp_`inc'' = 6846.81396484375 if _n ==18
		replace `temp_`inc'' = 8111.70166015625 if _n ==19
		replace `temp_`inc'' = 9335.6953125 if _n ==20
		replace `temp_`inc'' = 10493.0908203125 if _n ==21
		replace `temp_`inc'' = 11603.517578125 if _n ==22
		replace `temp_`inc'' = 12666.310546875 if _n ==23
		replace `temp_`inc'' = 13661.3984375 if _n ==24
		replace `temp_`inc'' = 14610.5078125 if _n ==25
		replace `temp_`inc'' = 15551.20703125 if _n ==26
		replace `temp_`inc'' = 16512.912109375 if _n ==27
		replace `temp_`inc'' = 17499.8046875 if _n ==28
		replace `temp_`inc'' = 18506.26171875 if _n ==29
		replace `temp_`inc'' = 19529.1171875 if _n ==30
		replace `temp_`inc'' = 20562.421875 if _n ==31
		replace `temp_`inc'' = 21599.33203125 if _n ==32
		replace `temp_`inc'' = 22637.14453125 if _n ==33
		replace `temp_`inc'' = 23677.515625 if _n ==34
		replace `temp_`inc'' = 24718.87109375 if _n ==35
		replace `temp_`inc'' = 25759.546875 if _n ==36
		replace `temp_`inc'' = 26802.69921875 if _n ==37
		replace `temp_`inc'' = 27849.96875 if _n ==38
		replace `temp_`inc'' = 28898.875 if _n ==39
		replace `temp_`inc'' = 29953.294921875 if _n ==40
		replace `temp_`inc'' = 31015.8359375 if _n ==41
		replace `temp_`inc'' = 32086.60546875 if _n ==42
		replace `temp_`inc'' = 33166.28125 if _n ==43
		replace `temp_`inc'' = 34255.6171875 if _n ==44
		replace `temp_`inc'' = 35359.57421875 if _n ==45
		replace `temp_`inc'' = 36477.6875 if _n ==46
		replace `temp_`inc'' = 37610.703125 if _n ==47
		replace `temp_`inc'' = 38758.625 if _n ==48
		replace `temp_`inc'' = 39923.79296875 if _n ==49
		replace `temp_`inc'' = 41110.23828125 if _n ==50
		replace `temp_`inc'' = 42317.11328125 if _n ==51
		replace `temp_`inc'' = 43547.8828125 if _n ==52
		replace `temp_`inc'' = 44805.18359375 if _n ==53
		replace `temp_`inc'' = 46089.65625 if _n ==54
		replace `temp_`inc'' = 47402.171875 if _n ==55
		replace `temp_`inc'' = 48748.55078125 if _n ==56
		replace `temp_`inc'' = 50124.84765625 if _n ==57
		replace `temp_`inc'' = 51530.5234375 if _n ==58
		replace `temp_`inc'' = 52975.515625 if _n ==59
		replace `temp_`inc'' = 54457.0859375 if _n ==60
		replace `temp_`inc'' = 55974.578125 if _n ==61
		replace `temp_`inc'' = 57533.19921875 if _n ==62
		replace `temp_`inc'' = 59127.79296875 if _n ==63
		replace `temp_`inc'' = 60756.7421875 if _n ==64
		replace `temp_`inc'' = 62428.453125 if _n ==65
		replace `temp_`inc'' = 64138.84375 if _n ==66
		replace `temp_`inc'' = 65881.40625 if _n ==67
		replace `temp_`inc'' = 67656.796875 if _n ==68
		replace `temp_`inc'' = 69466.7421875 if _n ==69
		replace `temp_`inc'' = 71314.28125 if _n ==70
		replace `temp_`inc'' = 73205.3515625 if _n ==71
		replace `temp_`inc'' = 75139.1328125 if _n ==72
		replace `temp_`inc'' = 77111.859375 if _n ==73
		replace `temp_`inc'' = 79127.640625 if _n ==74
		replace `temp_`inc'' = 81193.2890625 if _n ==75
		replace `temp_`inc'' = 83317.234375 if _n ==76
		replace `temp_`inc'' = 85503.203125 if _n ==77
		replace `temp_`inc'' = 87754.328125 if _n ==78
		replace `temp_`inc'' = 90081.5234375 if _n ==79
		replace `temp_`inc'' = 92497.375 if _n ==80
		replace `temp_`inc'' = 95015.28125 if _n ==81
		replace `temp_`inc'' = 97646.671875 if _n ==82
		replace `temp_`inc'' = 100403.640625 if _n ==83
		replace `temp_`inc'' = 103331.59375 if _n ==84
		replace `temp_`inc'' = 106440.0234375 if _n ==85
		replace `temp_`inc'' = 109755.875 if _n ==86
		replace `temp_`inc'' = 113343.265625 if _n ==87
		replace `temp_`inc'' = 117251 if _n ==88
		replace `temp_`inc'' = 121544.21875 if _n ==89
		replace `temp_`inc'' = 126315.8203125 if _n ==90
		replace `temp_`inc'' = 131680.71875 if _n ==91
		replace `temp_`inc'' = 137814.015625 if _n ==92
		replace `temp_`inc'' = 144962.78125 if _n ==93
		replace `temp_`inc'' = 153447.546875 if _n ==94
		replace `temp_`inc'' = 163754.4375 if _n ==95
		replace `temp_`inc'' = 176792.6875 if _n ==96
		replace `temp_`inc'' = 194357.890625 if _n ==97
		replace `temp_`inc'' = 220492.234375 if _n ==98
		replace `temp_`inc'' = 267373.3125 if _n ==99
		replace `temp_`inc'' = 552989.75 if _n ==100
		replace `temp_`inc'' = 1062313.625 if _n ==101
		}

	* kir	
	if "`kir'" != "" {
		tempvar temp_`inc'
		qui: gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = 0 if _n ==4
		replace `temp_`inc'' = 0 if _n ==5
		replace `temp_`inc'' = 0 if _n ==6
		replace `temp_`inc'' = 0 if _n ==7
		replace `temp_`inc'' = 0 if _n ==8
		replace `temp_`inc'' = 0 if _n ==9
		replace `temp_`inc'' = 0 if _n ==10
		replace `temp_`inc'' = 0 if _n ==11
		replace `temp_`inc'' = 0 if _n ==12
		replace `temp_`inc'' = 1.959543585777283 if _n ==13
		replace `temp_`inc'' = 54.61543655395508 if _n ==14
		replace `temp_`inc'' = 260.6127014160156 if _n ==15
		replace `temp_`inc'' = 645.2803344726563 if _n ==16
		replace `temp_`inc'' = 1160.642822265625 if _n ==17
		replace `temp_`inc'' = 1778.0810546875 if _n ==18
		replace `temp_`inc'' = 2473.636962890625 if _n ==19
		replace `temp_`inc'' = 3228.634033203125 if _n ==20
		replace `temp_`inc'' = 4027.28271484375 if _n ==21
		replace `temp_`inc'' = 4835.591796875 if _n ==22
		replace `temp_`inc'' = 5654.08984375 if _n ==23
		replace `temp_`inc'' = 6492.943359375 if _n ==24
		replace `temp_`inc'' = 7330.845703125 if _n ==25
		replace `temp_`inc'' = 8175.978515625 if _n ==26
		replace `temp_`inc'' = 9030.634765625 if _n ==27
		replace `temp_`inc'' = 9868.5673828125 if _n ==28
		replace `temp_`inc'' = 10698.6826171875 if _n ==29
		replace `temp_`inc'' = 11536.9658203125 if _n ==30
		replace `temp_`inc'' = 12372.7451171875 if _n ==31
		replace `temp_`inc'' = 13193.091796875 if _n ==32
		replace `temp_`inc'' = 13990.8671875 if _n ==33
		replace `temp_`inc'' = 14779.931640625 if _n ==34
		replace `temp_`inc'' = 15582.3984375 if _n ==35
		replace `temp_`inc'' = 16406.51953125 if _n ==36
		replace `temp_`inc'' = 17249.04296875 if _n ==37
		replace `temp_`inc'' = 18103.4921875 if _n ==38
		replace `temp_`inc'' = 18964.798828125 if _n ==39
		replace `temp_`inc'' = 19829.322265625 if _n ==40
		replace `temp_`inc'' = 20695.72265625 if _n ==41
		replace `temp_`inc'' = 21562.34765625 if _n ==42
		replace `temp_`inc'' = 22428.171875 if _n ==43
		replace `temp_`inc'' = 23294.09765625 if _n ==44
		replace `temp_`inc'' = 24158.337890625 if _n ==45
		replace `temp_`inc'' = 25018.458984375 if _n ==46
		replace `temp_`inc'' = 25877.841796875 if _n ==47
		replace `temp_`inc'' = 26735.54296875 if _n ==48
		replace `temp_`inc'' = 27591.63671875 if _n ==49
		replace `temp_`inc'' = 28449.5546875 if _n ==50
		replace `temp_`inc'' = 29304.96875 if _n ==51
		replace `temp_`inc'' = 30158.71875 if _n ==52
		replace `temp_`inc'' = 31015.5390625 if _n ==53
		replace `temp_`inc'' = 31874.662109375 if _n ==54
		replace `temp_`inc'' = 32733.984375 if _n ==55
		replace `temp_`inc'' = 33595.85546875 if _n ==56
		replace `temp_`inc'' = 34462.609375 if _n ==57
		replace `temp_`inc'' = 35336.78125 if _n ==58
		replace `temp_`inc'' = 36217.546875 if _n ==59
		replace `temp_`inc'' = 37103.1015625 if _n ==60
		replace `temp_`inc'' = 37996.90625 if _n ==61
		replace `temp_`inc'' = 38898.1484375 if _n ==62
		replace `temp_`inc'' = 39807.6484375 if _n ==63
		replace `temp_`inc'' = 40729.7890625 if _n ==64
		replace `temp_`inc'' = 41667.5703125 if _n ==65
		replace `temp_`inc'' = 42622.44140625 if _n ==66
		replace `temp_`inc'' = 43594.5546875 if _n ==67
		replace `temp_`inc'' = 44585.6328125 if _n ==68
		replace `temp_`inc'' = 45602.23828125 if _n ==69
		replace `temp_`inc'' = 46648.6328125 if _n ==70
		replace `temp_`inc'' = 47723.27734375 if _n ==71
		replace `temp_`inc'' = 48832.54296875 if _n ==72
		replace `temp_`inc'' = 49983.9375 if _n ==73
		replace `temp_`inc'' = 51176.8671875 if _n ==74
		replace `temp_`inc'' = 52417.1015625 if _n ==75
		replace `temp_`inc'' = 53712 if _n ==76
		replace `temp_`inc'' = 55058.9296875 if _n ==77
		replace `temp_`inc'' = 56466.38671875 if _n ==78
		replace `temp_`inc'' = 57946.0234375 if _n ==79
		replace `temp_`inc'' = 59504.28125 if _n ==80
		replace `temp_`inc'' = 61147.96875 if _n ==81
		replace `temp_`inc'' = 62889.3046875 if _n ==82
		replace `temp_`inc'' = 64738.359375 if _n ==83
		replace `temp_`inc'' = 66702.234375 if _n ==84
		replace `temp_`inc'' = 68797.5 if _n ==85
		replace `temp_`inc'' = 71042.03125 if _n ==86
		replace `temp_`inc'' = 73454.34375 if _n ==87
		replace `temp_`inc'' = 76062.5390625 if _n ==88
		replace `temp_`inc'' = 78911.5703125 if _n ==89
		replace `temp_`inc'' = 82050.4921875 if _n ==90
		replace `temp_`inc'' = 85545.046875 if _n ==91
		replace `temp_`inc'' = 89492.71875 if _n ==92
		replace `temp_`inc'' = 94025.53125 if _n ==93
		replace `temp_`inc'' = 99346.59375 if _n ==94
		replace `temp_`inc'' = 105778.578125 if _n ==95
		replace `temp_`inc'' = 113885.90625 if _n ==96
		replace `temp_`inc'' = 124790.109375 if _n ==97
		replace `temp_`inc'' = 140984.75 if _n ==98
		replace `temp_`inc'' = 170080.5 if _n ==99
		replace `temp_`inc'' = 342853.59375 if _n ==100
		replace `temp_`inc'' = 649917.375 if _n ==101
		}

	* wagerank	
	if "`wagerank'" != "" {
		tempvar temp_`inc'
		qui: gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = .3768180012702942 if _n ==4
		replace `temp_`inc'' = 1.229456543922424 if _n ==5
		replace `temp_`inc'' = 2.275061130523682 if _n ==6
		replace `temp_`inc'' = 3.334434032440186 if _n ==7
		replace `temp_`inc'' = 4.233735084533691 if _n ==8
		replace `temp_`inc'' = 4.960264205932617 if _n ==9
		replace `temp_`inc'' = 5.56895637512207 if _n ==10
		replace `temp_`inc'' = 6.10356330871582 if _n ==11
		replace `temp_`inc'' = 6.589410781860352 if _n ==12
		replace `temp_`inc'' = 7.039019584655762 if _n ==13
		replace `temp_`inc'' = 7.426365852355957 if _n ==14
		replace `temp_`inc'' = 7.77796745300293 if _n ==15
		replace `temp_`inc'' = 8.132393836975098 if _n ==16
		replace `temp_`inc'' = 8.48442268371582 if _n ==17
		replace `temp_`inc'' = 8.84661865234375 if _n ==18
		replace `temp_`inc'' = 9.171550750732422 if _n ==19
		replace `temp_`inc'' = 9.478237152099609 if _n ==20
		replace `temp_`inc'' = 9.781427383422852 if _n ==21
		replace `temp_`inc'' = 10.04850006103516 if _n ==22
		replace `temp_`inc'' = 10.34133625030518 if _n ==23
		replace `temp_`inc'' = 10.61537170410156 if _n ==24
		replace `temp_`inc'' = 10.8923511505127 if _n ==25
		replace `temp_`inc'' = 11.19074153900146 if _n ==26
		replace `temp_`inc'' = 11.47911357879639 if _n ==27
		replace `temp_`inc'' = 11.75453090667725 if _n ==28
		replace `temp_`inc'' = 12.01596069335938 if _n ==29
		replace `temp_`inc'' = 12.25808238983154 if _n ==30
		replace `temp_`inc'' = 12.53433990478516 if _n ==31
		replace `temp_`inc'' = 12.78624248504639 if _n ==32
		replace `temp_`inc'' = 13.03161525726318 if _n ==33
		replace `temp_`inc'' = 13.34050846099854 if _n ==34
		replace `temp_`inc'' = 13.56288909912109 if _n ==35
		replace `temp_`inc'' = 13.81352043151855 if _n ==36
		replace `temp_`inc'' = 14.11510372161865 if _n ==37
		replace `temp_`inc'' = 14.3646411895752 if _n ==38
		replace `temp_`inc'' = 14.62566184997559 if _n ==39
		replace `temp_`inc'' = 14.8328104019165 if _n ==40
		replace `temp_`inc'' = 15.09752178192139 if _n ==41
		replace `temp_`inc'' = 15.36635589599609 if _n ==42
		replace `temp_`inc'' = 15.61414527893066 if _n ==43
		replace `temp_`inc'' = 15.84145259857178 if _n ==44
		replace `temp_`inc'' = 16.05544281005859 if _n ==45
		replace `temp_`inc'' = 16.40364265441895 if _n ==46
		replace `temp_`inc'' = 16.59676361083984 if _n ==47
		replace `temp_`inc'' = 16.87729454040527 if _n ==48
		replace `temp_`inc'' = 17.21010780334473 if _n ==49
		replace `temp_`inc'' = 17.31548690795898 if _n ==50
		replace `temp_`inc'' = 17.67184448242188 if _n ==51
		replace `temp_`inc'' = 17.99073791503906 if _n ==52
		replace `temp_`inc'' = 18.17182922363281 if _n ==53
		replace `temp_`inc'' = 18.47319412231445 if _n ==54
		replace `temp_`inc'' = 18.81318283081055 if _n ==55
		replace `temp_`inc'' = 19.05522727966309 if _n ==56
		replace `temp_`inc'' = 19.32637786865234 if _n ==57
		replace `temp_`inc'' = 19.70912933349609 if _n ==58
		replace `temp_`inc'' = 19.98567390441895 if _n ==59
		replace `temp_`inc'' = 20.30573654174805 if _n ==60
		replace `temp_`inc'' = 20.72717666625977 if _n ==61
		replace `temp_`inc'' = 20.89284133911133 if _n ==62
		replace `temp_`inc'' = 21.28796195983887 if _n ==63
		replace `temp_`inc'' = 21.76218223571777 if _n ==64
		replace `temp_`inc'' = 21.95437622070313 if _n ==65
		replace `temp_`inc'' = 22.37472724914551 if _n ==66
		replace `temp_`inc'' = 22.75466156005859 if _n ==67
		replace `temp_`inc'' = 23.04935264587402 if _n ==68
		replace `temp_`inc'' = 23.46121215820313 if _n ==69
		replace `temp_`inc'' = 23.89336776733398 if _n ==70
		replace `temp_`inc'' = 24.24256134033203 if _n ==71
		replace `temp_`inc'' = 24.6153507232666 if _n ==72
		replace `temp_`inc'' = 25.17168617248535 if _n ==73
		replace `temp_`inc'' = 25.66484642028809 if _n ==74
		replace `temp_`inc'' = 26.14102935791016 if _n ==75
		replace `temp_`inc'' = 26.59385681152344 if _n ==76
		replace `temp_`inc'' = 27.01068496704102 if _n ==77
		replace `temp_`inc'' = 27.73875427246094 if _n ==78
		replace `temp_`inc'' = 28.39067840576172 if _n ==79
		replace `temp_`inc'' = 28.85550117492676 if _n ==80
		replace `temp_`inc'' = 29.40035820007324 if _n ==81
		replace `temp_`inc'' = 30.12445640563965 if _n ==82
		replace `temp_`inc'' = 30.84361267089844 if _n ==83
		replace `temp_`inc'' = 31.54028511047363 if _n ==84
		replace `temp_`inc'' = 32.40198516845703 if _n ==85
		replace `temp_`inc'' = 33.28947448730469 if _n ==86
		replace `temp_`inc'' = 34.18220901489258 if _n ==87
		replace `temp_`inc'' = 35.01460266113281 if _n ==88
		replace `temp_`inc'' = 36.18698120117188 if _n ==89
		replace `temp_`inc'' = 37.42079162597656 if _n ==90
		replace `temp_`inc'' = 38.62483978271484 if _n ==91
		replace `temp_`inc'' = 40.10430145263672 if _n ==92
		replace `temp_`inc'' = 41.71204376220703 if _n ==93
		replace `temp_`inc'' = 43.67465972900391 if _n ==94
		replace `temp_`inc'' = 45.86504364013672 if _n ==95
		replace `temp_`inc'' = 48.6933708190918 if _n ==96
		replace `temp_`inc'' = 52.56130599975586 if _n ==97
		replace `temp_`inc'' = 58.20485687255859 if _n ==98
		replace `temp_`inc'' = 68.77986145019531 if _n ==99
		replace `temp_`inc'' = 133.6757507324219 if _n ==100
		replace `temp_`inc'' = 249.2462158203125 if _n ==101
		}

	* kfr_26 early	
	if "`kfr_26_e'" != ""  {
		tempvar temp_`inc'
		gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = 0 if _n ==4
		replace `temp_`inc'' = 0 if _n ==5
		replace `temp_`inc'' = 0 if _n ==6
		replace `temp_`inc'' = 0 if _n ==7
		replace `temp_`inc'' = 0 if _n ==8
		replace `temp_`inc'' = 0 if _n ==9
		replace `temp_`inc'' = 0 if _n ==10
		replace `temp_`inc'' = 5.286441326141357 if _n ==11
		replace `temp_`inc'' = 72.92526245117188 if _n ==12
		replace `temp_`inc'' = 293.3884887695313 if _n ==13
		replace `temp_`inc'' = 679.9441528320313 if _n ==14
		replace `temp_`inc'' = 1191.502197265625 if _n ==15
		replace `temp_`inc'' = 1799.588134765625 if _n ==16
		replace `temp_`inc'' = 2466.419677734375 if _n ==17
		replace `temp_`inc'' = 3163.585205078125 if _n ==18
		replace `temp_`inc'' = 3965.829345703125 if _n ==19
		replace `temp_`inc'' = 4892.150390625 if _n ==20
		replace `temp_`inc'' = 5823.83251953125 if _n ==21
		replace `temp_`inc'' = 6713.1923828125 if _n ==22
		replace `temp_`inc'' = 7569.955078125 if _n ==23
		replace `temp_`inc'' = 8382.376953125 if _n ==24
		replace `temp_`inc'' = 9160.46484375 if _n ==25
		replace `temp_`inc'' = 9943.15625 if _n ==26
		replace `temp_`inc'' = 10727.89453125 if _n ==27
		replace `temp_`inc'' = 11497.3125 if _n ==28
		replace `temp_`inc'' = 12251.23828125 if _n ==29
		replace `temp_`inc'' = 12985.244140625 if _n ==30
		replace `temp_`inc'' = 13708.03125 if _n ==31
		replace `temp_`inc'' = 14427.228515625 if _n ==32
		replace `temp_`inc'' = 15141.5595703125 if _n ==33
		replace `temp_`inc'' = 15847.21875 if _n ==34
		replace `temp_`inc'' = 16542.02734375 if _n ==35
		replace `temp_`inc'' = 17229.58984375 if _n ==36
		replace `temp_`inc'' = 17915.92578125 if _n ==37
		replace `temp_`inc'' = 18600.171875 if _n ==38
		replace `temp_`inc'' = 19282.078125 if _n ==39
		replace `temp_`inc'' = 19963.994140625 if _n ==40
		replace `temp_`inc'' = 20645.138671875 if _n ==41
		replace `temp_`inc'' = 21323.892578125 if _n ==42
		replace `temp_`inc'' = 21999.267578125 if _n ==43
		replace `temp_`inc'' = 22673.951171875 if _n ==44
		replace `temp_`inc'' = 23347.158203125 if _n ==45
		replace `temp_`inc'' = 24021.248046875 if _n ==46
		replace `temp_`inc'' = 24696.33203125 if _n ==47
		replace `temp_`inc'' = 25371.5234375 if _n ==48
		replace `temp_`inc'' = 26050.08203125 if _n ==49
		replace `temp_`inc'' = 26730.16796875 if _n ==50
		replace `temp_`inc'' = 27413.44921875 if _n ==51
		replace `temp_`inc'' = 28102.732421875 if _n ==52
		replace `temp_`inc'' = 28795.44140625 if _n ==53
		replace `temp_`inc'' = 29493.251953125 if _n ==54
		replace `temp_`inc'' = 30199.44140625 if _n ==55
		replace `temp_`inc'' = 30909.94140625 if _n ==56
		replace `temp_`inc'' = 31626.46484375 if _n ==57
		replace `temp_`inc'' = 32353.578125 if _n ==58
		replace `temp_`inc'' = 33091.34375 if _n ==59
		replace `temp_`inc'' = 33839.9921875 if _n ==60
		replace `temp_`inc'' = 34602.75 if _n ==61
		replace `temp_`inc'' = 35379.578125 if _n ==62
		replace `temp_`inc'' = 36170.3984375 if _n ==63
		replace `temp_`inc'' = 36979.5234375 if _n ==64
		replace `temp_`inc'' = 37808.85546875 if _n ==65
		replace `temp_`inc'' = 38659.734375 if _n ==66
		replace `temp_`inc'' = 39531.3984375 if _n ==67
		replace `temp_`inc'' = 40427.3828125 if _n ==68
		replace `temp_`inc'' = 41350.8828125 if _n ==69
		replace `temp_`inc'' = 42302.7265625 if _n ==70
		replace `temp_`inc'' = 43283.8046875 if _n ==71
		replace `temp_`inc'' = 44293.21875 if _n ==72
		replace `temp_`inc'' = 45334.2421875 if _n ==73
		replace `temp_`inc'' = 46417.5078125 if _n ==74
		replace `temp_`inc'' = 47547.36328125 if _n ==75
		replace `temp_`inc'' = 48727.484375 if _n ==76
		replace `temp_`inc'' = 49960.671875 if _n ==77
		replace `temp_`inc'' = 51247.96875 if _n ==78
		replace `temp_`inc'' = 52594.7109375 if _n ==79
		replace `temp_`inc'' = 54004.8125 if _n ==80
		replace `temp_`inc'' = 55480.3984375 if _n ==81
		replace `temp_`inc'' = 57029.0234375 if _n ==82
		replace `temp_`inc'' = 58663.8515625 if _n ==83
		replace `temp_`inc'' = 60395.3515625 if _n ==84
		replace `temp_`inc'' = 62229.109375 if _n ==85
		replace `temp_`inc'' = 64168.52734375 if _n ==86
		replace `temp_`inc'' = 66224.8671875 if _n ==87
		replace `temp_`inc'' = 68413.3125 if _n ==88
		replace `temp_`inc'' = 70757.28125 if _n ==89
		replace `temp_`inc'' = 73284.796875 if _n ==90
		replace `temp_`inc'' = 76015.296875 if _n ==91
		replace `temp_`inc'' = 78990.6640625 if _n ==92
		replace `temp_`inc'' = 82288.296875 if _n ==93
		replace `temp_`inc'' = 86003.0390625 if _n ==94
		replace `temp_`inc'' = 90257.75 if _n ==95
		replace `temp_`inc'' = 95283.53125 if _n ==96
		replace `temp_`inc'' = 101521.578125 if _n ==97
		replace `temp_`inc'' = 109846.3515625 if _n ==98
		replace `temp_`inc'' = 122937.7421875 if _n ==99
		replace `temp_`inc'' = 198553.0625 if _n ==100
		replace `temp_`inc'' = 333266.0625 if _n ==101
		}

	* kir_26 early	
	if "`kir_26_e'" != ""  {
		tempvar temp_`inc'	
		gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = 0 if _n ==4
		replace `temp_`inc'' = 0 if _n ==5
		replace `temp_`inc'' = 0 if _n ==6
		replace `temp_`inc'' = 0 if _n ==7
		replace `temp_`inc'' = 0 if _n ==8
		replace `temp_`inc'' = 0 if _n ==9
		replace `temp_`inc'' = 0 if _n ==10
		replace `temp_`inc'' = 0 if _n ==11
		replace `temp_`inc'' = 0 if _n ==12
		replace `temp_`inc'' = 0 if _n ==13
		replace `temp_`inc'' = 2.857035398483276 if _n ==14
		replace `temp_`inc'' = 49.26974105834961 if _n ==15
		replace `temp_`inc'' = 217.3881988525391 if _n ==16
		replace `temp_`inc'' = 521.85400390625 if _n ==17
		replace `temp_`inc'' = 931.5637817382813 if _n ==18
		replace `temp_`inc'' = 1432.639404296875 if _n ==19
		replace `temp_`inc'' = 1998.25830078125 if _n ==20
		replace `temp_`inc'' = 2601.294921875 if _n ==21
		replace `temp_`inc'' = 3226.907470703125 if _n ==22
		replace `temp_`inc'' = 3866.342529296875 if _n ==23
		replace `temp_`inc'' = 4516.79296875 if _n ==24
		replace `temp_`inc'' = 5177.919921875 if _n ==25
		replace `temp_`inc'' = 5842.177734375 if _n ==26
		replace `temp_`inc'' = 6504.0419921875 if _n ==27
		replace `temp_`inc'' = 7167.4482421875 if _n ==28
		replace `temp_`inc'' = 7829.5556640625 if _n ==29
		replace `temp_`inc'' = 8481.7431640625 if _n ==30
		replace `temp_`inc'' = 9117.0576171875 if _n ==31
		replace `temp_`inc'' = 9753.275390625 if _n ==32
		replace `temp_`inc'' = 10409.787109375 if _n ==33
		replace `temp_`inc'' = 11073.6171875 if _n ==34
		replace `temp_`inc'' = 11731.3916015625 if _n ==35
		replace `temp_`inc'' = 12384.83203125 if _n ==36
		replace `temp_`inc'' = 13031.12109375 if _n ==37
		replace `temp_`inc'' = 13672.4296875 if _n ==38
		replace `temp_`inc'' = 14314.6328125 if _n ==39
		replace `temp_`inc'' = 14953.861328125 if _n ==40
		replace `temp_`inc'' = 15589.0751953125 if _n ==41
		replace `temp_`inc'' = 16220.236328125 if _n ==42
		replace `temp_`inc'' = 16848.5 if _n ==43
		replace `temp_`inc'' = 17475.83984375 if _n ==44
		replace `temp_`inc'' = 18102.255859375 if _n ==45
		replace `temp_`inc'' = 18725.849609375 if _n ==46
		replace `temp_`inc'' = 19346.5703125 if _n ==47
		replace `temp_`inc'' = 19965.25390625 if _n ==48
		replace `temp_`inc'' = 20578.9296875 if _n ==49
		replace `temp_`inc'' = 21187.7734375 if _n ==50
		replace `temp_`inc'' = 21796.615234375 if _n ==51
		replace `temp_`inc'' = 22403.408203125 if _n ==52
		replace `temp_`inc'' = 23006.19140625 if _n ==53
		replace `temp_`inc'' = 23609.94140625 if _n ==54
		replace `temp_`inc'' = 24212.82421875 if _n ==55
		replace `temp_`inc'' = 24813.748046875 if _n ==56
		replace `temp_`inc'' = 25418.626953125 if _n ==57
		replace `temp_`inc'' = 26026.521484375 if _n ==58
		replace `temp_`inc'' = 26635.4609375 if _n ==59
		replace `temp_`inc'' = 27249.37890625 if _n ==60
		replace `temp_`inc'' = 27867.283203125 if _n ==61
		replace `temp_`inc'' = 28488.2265625 if _n ==62
		replace `temp_`inc'' = 29114.263671875 if _n ==63
		replace `temp_`inc'' = 29745.421875 if _n ==64
		replace `temp_`inc'' = 30381.51171875 if _n ==65
		replace `temp_`inc'' = 31021.5859375 if _n ==66
		replace `temp_`inc'' = 31665.841796875 if _n ==67
		replace `temp_`inc'' = 32317.109375 if _n ==68
		replace `temp_`inc'' = 32981.14453125 if _n ==69
		replace `temp_`inc'' = 33659.1484375 if _n ==70
		replace `temp_`inc'' = 34347.34375 if _n ==71
		replace `temp_`inc'' = 35045.44140625 if _n ==72
		replace `temp_`inc'' = 35756.453125 if _n ==73
		replace `temp_`inc'' = 36487.57421875 if _n ==74
		replace `temp_`inc'' = 37241.6953125 if _n ==75
		replace `temp_`inc'' = 38013.890625 if _n ==76
		replace `temp_`inc'' = 38808.078125 if _n ==77
		replace `temp_`inc'' = 39630.2421875 if _n ==78
		replace `temp_`inc'' = 40482.4609375 if _n ==79
		replace `temp_`inc'' = 41364.66796875 if _n ==80
		replace `temp_`inc'' = 42278.90234375 if _n ==81
		replace `temp_`inc'' = 43235.1875 if _n ==82
		replace `temp_`inc'' = 44236.4609375 if _n ==83
		replace `temp_`inc'' = 45281.78125 if _n ==84
		replace `temp_`inc'' = 46386.015625 if _n ==85
		replace `temp_`inc'' = 47568.2734375 if _n ==86
		replace `temp_`inc'' = 48836.625 if _n ==87
		replace `temp_`inc'' = 50199.0234375 if _n ==88
		replace `temp_`inc'' = 51675.4296875 if _n ==89
		replace `temp_`inc'' = 53288.8984375 if _n ==90
		replace `temp_`inc'' = 55059.15625 if _n ==91
		replace `temp_`inc'' = 57026.9765625 if _n ==92
		replace `temp_`inc'' = 59250.5625 if _n ==93
		replace `temp_`inc'' = 61805.6640625 if _n ==94
		replace `temp_`inc'' = 64805.2109375 if _n ==95
		replace `temp_`inc'' = 68435.6796875 if _n ==96
		replace `temp_`inc'' = 73011.375 if _n ==97
		replace `temp_`inc'' = 79210.6796875 if _n ==98
		replace `temp_`inc'' = 89327.703125 if _n ==99
		replace `temp_`inc'' = 148860.140625 if _n ==100
		replace `temp_`inc'' = 254944.765625 if _n ==101
		}


	* kfr_26 late	
	if "`kfr_26_l'" != ""  {
		tempvar temp_`inc'
		gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = 0 if _n ==4
		replace `temp_`inc'' = 0 if _n ==5
		replace `temp_`inc'' = 0 if _n ==6
		replace `temp_`inc'' = 0 if _n ==7
		replace `temp_`inc'' = 0 if _n ==8
		replace `temp_`inc'' = 0 if _n ==9
		replace `temp_`inc'' = 0 if _n ==10
		replace `temp_`inc'' = 0 if _n ==11
		replace `temp_`inc'' = 0 if _n ==12
		replace `temp_`inc'' = 2.103335380554199 if _n ==13
		replace `temp_`inc'' = 47.94550704956055 if _n ==14
		replace `temp_`inc'' = 252.3904266357422 if _n ==15
		replace `temp_`inc'' = 697.20361328125 if _n ==16
		replace `temp_`inc'' = 1318.369995117188 if _n ==17
		replace `temp_`inc'' = 2032.260986328125 if _n ==18
		replace `temp_`inc'' = 2811.860107421875 if _n ==19
		replace `temp_`inc'' = 3626.113037109375 if _n ==20
		replace `temp_`inc'' = 4450.96484375 if _n ==21
		replace `temp_`inc'' = 5274.4697265625 if _n ==22
		replace `temp_`inc'' = 6083.7470703125 if _n ==23
		replace `temp_`inc'' = 6866.5322265625 if _n ==24
		replace `temp_`inc'' = 7621.173828125 if _n ==25
		replace `temp_`inc'' = 8347.451171875 if _n ==26
		replace `temp_`inc'' = 9033.0126953125 if _n ==27
		replace `temp_`inc'' = 9649.60546875 if _n ==28
		replace `temp_`inc'' = 10214.3046875 if _n ==29
		replace `temp_`inc'' = 10804.474609375 if _n ==30
		replace `temp_`inc'' = 11433.775390625 if _n ==31
		replace `temp_`inc'' = 12065.4228515625 if _n ==32
		replace `temp_`inc'' = 12685.404296875 if _n ==33
		replace `temp_`inc'' = 13278.6669921875 if _n ==34
		replace `temp_`inc'' = 13838.396484375 if _n ==35
		replace `temp_`inc'' = 14386.41015625 if _n ==36
		replace `temp_`inc'' = 14942.8583984375 if _n ==37
		replace `temp_`inc'' = 15506.923828125 if _n ==38
		replace `temp_`inc'' = 16071.080078125 if _n ==39
		replace `temp_`inc'' = 16635.298828125 if _n ==40
		replace `temp_`inc'' = 17196.287109375 if _n ==41
		replace `temp_`inc'' = 17756.509765625 if _n ==42
		replace `temp_`inc'' = 18329.0546875 if _n ==43
		replace `temp_`inc'' = 18914.80859375 if _n ==44
		replace `temp_`inc'' = 19505.5703125 if _n ==45
		replace `temp_`inc'' = 20098.806640625 if _n ==46
		replace `temp_`inc'' = 20695.42578125 if _n ==47
		replace `temp_`inc'' = 21290.41015625 if _n ==48
		replace `temp_`inc'' = 21886.2734375 if _n ==49
		replace `temp_`inc'' = 22486.28515625 if _n ==50
		replace `temp_`inc'' = 23090.38671875 if _n ==51
		replace `temp_`inc'' = 23700.23828125 if _n ==52
		replace `temp_`inc'' = 24315.810546875 if _n ==53
		replace `temp_`inc'' = 24937.279296875 if _n ==54
		replace `temp_`inc'' = 25567.91796875 if _n ==55
		replace `temp_`inc'' = 26205.98046875 if _n ==56
		replace `temp_`inc'' = 26850.734375 if _n ==57
		replace `temp_`inc'' = 27504.59375 if _n ==58
		replace `temp_`inc'' = 28168.44140625 if _n ==59
		replace `temp_`inc'' = 28841.5078125 if _n ==60
		replace `temp_`inc'' = 29526.22265625 if _n ==61
		replace `temp_`inc'' = 30223.359375 if _n ==62
		replace `temp_`inc'' = 30932.1484375 if _n ==63
		replace `temp_`inc'' = 31654.3828125 if _n ==64
		replace `temp_`inc'' = 32386.62890625 if _n ==65
		replace `temp_`inc'' = 33130.48828125 if _n ==66
		replace `temp_`inc'' = 33893.546875 if _n ==67
		replace `temp_`inc'' = 34684.984375 if _n ==68
		replace `temp_`inc'' = 35508.8515625 if _n ==69
		replace `temp_`inc'' = 36361.0078125 if _n ==70
		replace `temp_`inc'' = 37244.8984375 if _n ==71
		replace `temp_`inc'' = 38161.30078125 if _n ==72
		replace `temp_`inc'' = 39110.1484375 if _n ==73
		replace `temp_`inc'' = 40099.80078125 if _n ==74
		replace `temp_`inc'' = 41131.15234375 if _n ==75
		replace `temp_`inc'' = 42206.6640625 if _n ==76
		replace `temp_`inc'' = 43333.86328125 if _n ==77
		replace `temp_`inc'' = 44513.5859375 if _n ==78
		replace `temp_`inc'' = 45748.3046875 if _n ==79
		replace `temp_`inc'' = 47042.1171875 if _n ==80
		replace `temp_`inc'' = 48402.515625 if _n ==81
		replace `temp_`inc'' = 49844.59375 if _n ==82
		replace `temp_`inc'' = 51372.42578125 if _n ==83
		replace `temp_`inc'' = 52983.7734375 if _n ==84
		replace `temp_`inc'' = 54688.609375 if _n ==85
		replace `temp_`inc'' = 56497.5234375 if _n ==86
		replace `temp_`inc'' = 58418.90234375 if _n ==87
		replace `temp_`inc'' = 60482.8203125 if _n ==88
		replace `temp_`inc'' = 62726.30078125 if _n ==89
		replace `temp_`inc'' = 65170.7421875 if _n ==90
		replace `temp_`inc'' = 67841.265625 if _n ==91
		replace `temp_`inc'' = 70777.28125 if _n ==92
		replace `temp_`inc'' = 74036.0625 if _n ==93
		replace `temp_`inc'' = 77718.6875 if _n ==94
		replace `temp_`inc'' = 81978.2578125 if _n ==95
		replace `temp_`inc'' = 87040.09375 if _n ==96
		replace `temp_`inc'' = 93294.8125 if _n ==97
		replace `temp_`inc'' = 101606.96875 if _n ==98
		replace `temp_`inc'' = 114343.828125 if _n ==99
		replace `temp_`inc'' = 185099.03125 if _n ==100
		replace `temp_`inc'' = 310782.3125 if _n ==101
		}

	* kir_26 late	
	if "`kir_26_l'" != ""  {
		tempvar temp_`inc'	
		gen `temp_`inc'' = .
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 0 if _n ==2
		replace `temp_`inc'' = 0 if _n ==3
		replace `temp_`inc'' = 0 if _n ==4
		replace `temp_`inc'' = 0 if _n ==5
		replace `temp_`inc'' = 0 if _n ==6
		replace `temp_`inc'' = 0 if _n ==7
		replace `temp_`inc'' = 0 if _n ==8
		replace `temp_`inc'' = 0 if _n ==9
		replace `temp_`inc'' = 0 if _n ==10
		replace `temp_`inc'' = 0 if _n ==11
		replace `temp_`inc'' = 0 if _n ==12
		replace `temp_`inc'' = 0 if _n ==13
		replace `temp_`inc'' = 0 if _n ==14
		replace `temp_`inc'' = 0 if _n ==15
		replace `temp_`inc'' = 3.759856700897217 if _n ==16
		replace `temp_`inc'' = 42.84579849243164 if _n ==17
		replace `temp_`inc'' = 195.5519256591797 if _n ==18
		replace `temp_`inc'' = 523.8770141601563 if _n ==19
		replace `temp_`inc'' = 992.0201416015625 if _n ==20
		replace `temp_`inc'' = 1534.356201171875 if _n ==21
		replace `temp_`inc'' = 2123.441162109375 if _n ==22
		replace `temp_`inc'' = 2743.2490234375 if _n ==23
		replace `temp_`inc'' = 3382.964599609375 if _n ==24
		replace `temp_`inc'' = 4033.105224609375 if _n ==25
		replace `temp_`inc'' = 4687.7236328125 if _n ==26
		replace `temp_`inc'' = 5342.318359375 if _n ==27
		replace `temp_`inc'' = 5993.5087890625 if _n ==28
		replace `temp_`inc'' = 6640.1650390625 if _n ==29
		replace `temp_`inc'' = 7278.77880859375 if _n ==30
		replace `temp_`inc'' = 7906.9189453125 if _n ==31
		replace `temp_`inc'' = 8518.71484375 if _n ==32
		replace `temp_`inc'' = 9111.6123046875 if _n ==33
		replace `temp_`inc'' = 9685.990234375 if _n ==34
		replace `temp_`inc'' = 10240.4765625 if _n ==35
		replace `temp_`inc'' = 10797.40234375 if _n ==36
		replace `temp_`inc'' = 11374.4501953125 if _n ==37
		replace `temp_`inc'' = 11957.1005859375 if _n ==38
		replace `temp_`inc'' = 12533.6875 if _n ==39
		replace `temp_`inc'' = 13101.6748046875 if _n ==40
		replace `temp_`inc'' = 13656.3828125 if _n ==41
		replace `temp_`inc'' = 14198.8447265625 if _n ==42
		replace `temp_`inc'' = 14740.65625 if _n ==43
		replace `temp_`inc'' = 15287.541015625 if _n ==44
		replace `temp_`inc'' = 15837.74609375 if _n ==45
		replace `temp_`inc'' = 16387.115234375 if _n ==46
		replace `temp_`inc'' = 16936.484375 if _n ==47
		replace `temp_`inc'' = 17488.30859375 if _n ==48
		replace `temp_`inc'' = 18041.796875 if _n ==49
		replace `temp_`inc'' = 18597.7109375 if _n ==50
		replace `temp_`inc'' = 19158.513671875 if _n ==51
		replace `temp_`inc'' = 19722.6796875 if _n ==52
		replace `temp_`inc'' = 20287.74609375 if _n ==53
		replace `temp_`inc'' = 20851.92578125 if _n ==54
		replace `temp_`inc'' = 21416.10546875 if _n ==55
		replace `temp_`inc'' = 21982.8671875 if _n ==56
		replace `temp_`inc'' = 22549.6015625 if _n ==57
		replace `temp_`inc'' = 23118.8046875 if _n ==58
		replace `temp_`inc'' = 23695.525390625 if _n ==59
		replace `temp_`inc'' = 24276.29296875 if _n ==60
		replace `temp_`inc'' = 24858.69921875 if _n ==61
		replace `temp_`inc'' = 25448.68359375 if _n ==62
		replace `temp_`inc'' = 26048.6484375 if _n ==63
		replace `temp_`inc'' = 26653.537109375 if _n ==64
		replace `temp_`inc'' = 27265.09375 if _n ==65
		replace `temp_`inc'' = 27888.369140625 if _n ==66
		replace `temp_`inc'' = 28517.5546875 if _n ==67
		replace `temp_`inc'' = 29153.41796875 if _n ==68
		replace `temp_`inc'' = 29799.208984375 if _n ==69
		replace `temp_`inc'' = 30458.28515625 if _n ==70
		replace `temp_`inc'' = 31130.72265625 if _n ==71
		replace `temp_`inc'' = 31812.359375 if _n ==72
		replace `temp_`inc'' = 32506.54296875 if _n ==73
		replace `temp_`inc'' = 33215.171875 if _n ==74
		replace `temp_`inc'' = 33941.50390625 if _n ==75
		replace `temp_`inc'' = 34696.171875 if _n ==76
		replace `temp_`inc'' = 35485.015625 if _n ==77
		replace `temp_`inc'' = 36305.5390625 if _n ==78
		replace `temp_`inc'' = 37160.2578125 if _n ==79
		replace `temp_`inc'' = 38053.3046875 if _n ==80
		replace `temp_`inc'' = 38985.6328125 if _n ==81
		replace `temp_`inc'' = 39961.453125 if _n ==82
		replace `temp_`inc'' = 40988.98046875 if _n ==83
		replace `temp_`inc'' = 42075.75390625 if _n ==84
		replace `temp_`inc'' = 43227.609375 if _n ==85
		replace `temp_`inc'' = 44454.34765625 if _n ==86
		replace `temp_`inc'' = 45762.80078125 if _n ==87
		replace `temp_`inc'' = 47161.53125 if _n ==88
		replace `temp_`inc'' = 48672.74609375 if _n ==89
		replace `temp_`inc'' = 50325.5625 if _n ==90
		replace `temp_`inc'' = 52143.50390625 if _n ==91
		replace `temp_`inc'' = 54151.5625 if _n ==92
		replace `temp_`inc'' = 56391.44921875 if _n ==93
		replace `temp_`inc'' = 58946.0859375 if _n ==94
		replace `temp_`inc'' = 61947.4453125 if _n ==95
		replace `temp_`inc'' = 65593.7109375 if _n ==96
		replace `temp_`inc'' = 70194.3984375 if _n ==97
		replace `temp_`inc'' = 76428.625 if _n ==98
		replace `temp_`inc'' = 86527.671875 if _n ==99
		replace `temp_`inc'' = 144102.125 if _n ==100
		replace `temp_`inc'' = 246350.71875 if _n ==101
		}

	* parent income
	if "`par_inc'" != ""  {
		tempvar temp_`inc'	
		gen `temp_`inc'' = .	
		replace `temp_`inc'' = 0 if _n ==1
		replace `temp_`inc'' = 2192.091552734375 if _n ==2
		replace `temp_`inc'' = 3919.33203125 if _n ==3
		replace `temp_`inc'' = 5401.69482421875 if _n ==4
		replace `temp_`inc'' = 6733.67578125 if _n ==5
		replace `temp_`inc'' = 7957.9833984375 if _n ==6
		replace `temp_`inc'' = 9100.5341796875 if _n ==7
		replace `temp_`inc'' = 10185.0625 if _n ==8
		replace `temp_`inc'' = 11224.6396484375 if _n ==9
		replace `temp_`inc'' = 12226.478515625 if _n ==10
		replace `temp_`inc'' = 13201.619140625 if _n ==11
		replace `temp_`inc'' = 14154.4716796875 if _n ==12
		replace `temp_`inc'' = 15088.0751953125 if _n ==13
		replace `temp_`inc'' = 16010.927734375 if _n ==14
		replace `temp_`inc'' = 16924.625 if _n ==15
		replace `temp_`inc'' = 17833.322265625 if _n ==16
		replace `temp_`inc'' = 18738.9453125 if _n ==17
		replace `temp_`inc'' = 19640.3046875 if _n ==18
		replace `temp_`inc'' = 20542.4296875 if _n ==19
		replace `temp_`inc'' = 21449.56640625 if _n ==20
		replace `temp_`inc'' = 22365.85546875 if _n ==21
		replace `temp_`inc'' = 23286.396484375 if _n ==22
		replace `temp_`inc'' = 24210.986328125 if _n ==23
		replace `temp_`inc'' = 25145.798828125 if _n ==24
		replace `temp_`inc'' = 26089.71875 if _n ==25
		replace `temp_`inc'' = 27044.203125 if _n ==26
		replace `temp_`inc'' = 28011.162109375 if _n ==27
		replace `temp_`inc'' = 28992.98046875 if _n ==28
		replace `temp_`inc'' = 29993.12109375 if _n ==29
		replace `temp_`inc'' = 31005.703125 if _n ==30
		replace `temp_`inc'' = 32029.9765625 if _n ==31
		replace `temp_`inc'' = 33071.06640625 if _n ==32
		replace `temp_`inc'' = 34130.64453125 if _n ==33
		replace `temp_`inc'' = 35206.703125 if _n ==34
		replace `temp_`inc'' = 36299.4921875 if _n ==35
		replace `temp_`inc'' = 37410.9609375 if _n ==36
		replace `temp_`inc'' = 38539.0703125 if _n ==37
		replace `temp_`inc'' = 39682.83984375 if _n ==38
		replace `temp_`inc'' = 40842.53515625 if _n ==39
		replace `temp_`inc'' = 42015.09375 if _n ==40
		replace `temp_`inc'' = 43201.7578125 if _n ==41
		replace `temp_`inc'' = 44407.74609375 if _n ==42
		replace `temp_`inc'' = 45629.0859375 if _n ==43
		replace `temp_`inc'' = 46861.1875 if _n ==44
		replace `temp_`inc'' = 48104.98828125 if _n ==45
		replace `temp_`inc'' = 49361.6328125 if _n ==46
		replace `temp_`inc'' = 50628.59375 if _n ==47
		replace `temp_`inc'' = 51904.84765625 if _n ==48
		replace `temp_`inc'' = 53193.71875 if _n ==49
		replace `temp_`inc'' = 54493.4296875 if _n ==50
		replace `temp_`inc'' = 55802.23046875 if _n ==51
		replace `temp_`inc'' = 57122.125 if _n ==52
		replace `temp_`inc'' = 58452.93359375 if _n ==53
		replace `temp_`inc'' = 59792.015625 if _n ==54
		replace `temp_`inc'' = 61140.55078125 if _n ==55
		replace `temp_`inc'' = 62499.234375 if _n ==56
		replace `temp_`inc'' = 63868.6640625 if _n ==57
		replace `temp_`inc'' = 65251.359375 if _n ==58
		replace `temp_`inc'' = 66645.734375 if _n ==59
		replace `temp_`inc'' = 68057.390625 if _n ==60
		replace `temp_`inc'' = 69488.828125 if _n ==61
		replace `temp_`inc'' = 70937.046875 if _n ==62
		replace `temp_`inc'' = 72405.453125 if _n ==63
		replace `temp_`inc'' = 73894.703125 if _n ==64
		replace `temp_`inc'' = 75404.703125 if _n ==65
		replace `temp_`inc'' = 76940.578125 if _n ==66
		replace `temp_`inc'' = 78502.9921875 if _n ==67
		replace `temp_`inc'' = 80093.515625 if _n ==68
		replace `temp_`inc'' = 81715.859375 if _n ==69
		replace `temp_`inc'' = 83369.96875 if _n ==70
		replace `temp_`inc'' = 85060.5625 if _n ==71
		replace `temp_`inc'' = 86795.34375 if _n ==72
		replace `temp_`inc'' = 88578.5703125 if _n ==73
		replace `temp_`inc'' = 90411.625 if _n ==74
		replace `temp_`inc'' = 92298.5546875 if _n ==75
		replace `temp_`inc'' = 94251.8984375 if _n ==76
		replace `temp_`inc'' = 96275.953125 if _n ==77
		replace `temp_`inc'' = 98383.796875 if _n ==78
		replace `temp_`inc'' = 100578.9375 if _n ==79
		replace `temp_`inc'' = 102877.5234375 if _n ==80
		replace `temp_`inc'' = 105283.921875 if _n ==81
		replace `temp_`inc'' = 107799.1796875 if _n ==82
		replace `temp_`inc'' = 110480.28125 if _n ==83
		replace `temp_`inc'' = 113345.0703125 if _n ==84
		replace `temp_`inc'' = 116394.015625 if _n ==85
		replace `temp_`inc'' = 119683.1015625 if _n ==86
		replace `temp_`inc'' = 123248.359375 if _n ==87
		replace `temp_`inc'' = 127137.328125 if _n ==88
		replace `temp_`inc'' = 131432.15625 if _n ==89
		replace `temp_`inc'' = 136236.96875 if _n ==90
		replace `temp_`inc'' = 141708.5625 if _n ==91
		replace `temp_`inc'' = 148020.53125 if _n ==92
		replace `temp_`inc'' = 155465.71875 if _n ==93
		replace `temp_`inc'' = 164577.21875 if _n ==94
		replace `temp_`inc'' = 176179.34375 if _n ==95
		replace `temp_`inc'' = 191772.53125 if _n ==96
		replace `temp_`inc'' = 214489.671875 if _n ==97
		replace `temp_`inc'' = 251413.265625 if _n ==98
		replace `temp_`inc'' = 323974.53125 if _n ==99
		replace `temp_`inc'' = 749596.6875 if _n ==100
		replace `temp_`inc'' = 1502224.75 if _n ==101
		}


	*******
	* if option SD not specified --> simply convert rank to dollar
	*******

	if "`sd'" == ""  {
		if "`reverse'"=="" {
		* multiply by 100 if option specified
		if "`multiply100'" !=""			local 1 = `1'*100

		* summarize floor 
		summ `temp_`inc'' if `temp_percentile' == floor(`1')
		local dollar_amount_floor = `r(mean)'

		* summarize ceiling
		summ `temp_`inc'' if `temp_percentile' == ceil(`1')
		local dollar_amount_ceil = `r(mean)'

		* dollar amount 
		local dollar_amount = `dollar_amount_floor' + ((`1' - floor(`1')) * ///
		(`dollar_amount_ceil' - `dollar_amount_floor'))
		}

		*REVERSE!
		if "`reverse'"!="" {
			tempvar my_n
			g `my_n'=_n if inrange(_n,1,101)
			if `1' <= 0 {
				su `my_n' if `temp_`inc''==0
				local rank = r(mean)
			}
			else {
				su `my_n' if `temp_`inc''<=`1'
				local rank_floor = r(max)
				su `my_n' if `temp_`inc''>=`1'
				local rank_ceil = r(min)
				su `temp_`inc'' if `my_n'==`rank_floor'
				local int_floor =r(mean)
				su `temp_`inc'' if `my_n'==`rank_ceil'
				local int_ceil =r(mean)
				local rank = `rank_floor' + (`1'-`int_floor')/(`int_ceil'-`int_floor')
			}
			drop `my_n'
		}
	}

	*******
	* if option SD specified --> it all becomes more tricky now...
	*******

	if "`sd'" != ""  {
		if "`2'" =="" {
			di in red "Please specify both the SD and the mean"
			exit
			}

		* multiply by 100 if option specified
		if "`multiply100'" !=""	{
			local 1 = `1'*100
			local 2 = `2'*100
			}			

		* summarize floor: mean MINUS SD
		summ `temp_`inc'' if `temp_percentile' == floor(`1'-`2')
		local dollar_amount_floor_lower = `r(mean)'

		* summarize floor: mean PLUS SD
		summ `temp_`inc'' if `temp_percentile' == floor(`1'+`2')
		local dollar_amount_floor_upper = `r(mean)'

		* summarize ceiling: mean MINUS SD
		summ `temp_`inc'' if `temp_percentile' == ceil(`1'-`2')
		local dollar_amount_ceil_lower = `r(mean)'

		* summarize ceiling: mean PLUS SD
		summ `temp_`inc'' if `temp_percentile' == ceil(`1'+`2')
		local dollar_amount_ceil_upper = `r(mean)'

		* dollar amount: mean MINUS SD
		local dollar_amount_lower = `dollar_amount_floor_lower' + ///
			(((`1' -`2') - floor(`1'-`2')) * ///
			(`dollar_amount_ceil_lower' - `dollar_amount_floor_lower'))

		* dollar amount: mean PLUS SD
		local dollar_amount_upper = `dollar_amount_floor_upper' + ///
			(((`1' +`2') - floor(`1'+`2')) * ///
			(`dollar_amount_ceil_upper' - `dollar_amount_floor_upper'))	

		* dollar amount
		local dollar_amount = (`dollar_amount_upper' - `dollar_amount_lower')/2
	}

	}
	if "`reverse'"=="" {
		return scalar dollar_amount = `dollar_amount'
		di as result "Dollar amount: `dollar_amount'"
	}
	else if "`variable'" == "" {
		return scalar rank = `rank'
		di as result "Rank: `rank'"
	}
	drop `temp_percentile' `temp_`inc''
	}

	if "`variable'" != ""  {
	quietly {
	* multiply by 100 if option specified
	g rank =`1'
	if "`multiply100'" !=""  	replace rank = rank*100

	* generate floor and ceiling variables
	g rank_low = floor(rank)
	g rank_high = ceil(rank)
	* merge dollar amount corresponding to floor
	ren rank_low percentile
	merge m:1 percentile using "${dropbox}/outside/finer_geo/data/raw/crosswalks/rank_dollar_ado_file.dta", nogen keepusing(`inc') keep(master matched)
	ren percentile rank_low
	ren `inc' dollar_floor
	* merge dollar amount corresponding to ceiling
	ren rank_high percentile
	merge m:1 percentile using "${dropbox}/outside/finer_geo/data/raw/crosswalks/rank_dollar_ado_file.dta", nogen keepusing(`inc') keep(master matched)
	ren percentile rank_high
	ren `inc' dollar_ceiling
	gen dollar_amount = dollar_floor + ((rank - rank_low) * ///
		(dollar_ceiling - dollar_floor))
	drop rank_low rank_high rank dollar_floor dollar_ceiling	

	}
	}
end


/*
*** CREATE CROSSWALK FILE 
import delimited "${dropbox}/outside/finer_geo/interactive_tract_maps/output/pctile_to_dollar_cw.csv", clear
	
save  "${dropbox}/outside/finer_geo/data/raw/crosswalks/rank_dollar_ado_file.dta", replace
use "${dropbox}/outside/finer_geo/data/raw/crosswalks/rank_dollar_ado_file.dta", clear
qui: gen temp_kid_wageflex = .
qui: gen temp_percentile = _n-1 in 1/101
forval i= 1/101 {
	qui: su kid_wageflex if _n == `i'
	di "replace temp_inc = `r(mean)' if _n ==`i'"  
	}
assert temp_kid_wageflex[_n] >= temp_kid_wageflex[_n-1]
*/
