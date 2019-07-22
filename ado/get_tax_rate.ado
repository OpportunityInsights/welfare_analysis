/*******************************************************************************
* Get tax rates from CBO
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
cap program drop get_tax_rate

* define program
program define get_tax_rate, rclass

* syntax
syntax anything(name=provided_info), ///
	include_transfers(string) /// "yes" or "no"
	forecast_income(string) /// "yes" or "no"
	usd_year(integer) /// USD year of income
	inc_year(integer) /// year of income measurement
	earnings_type(string) /// "individual" or "household"
	[ /// optional options, relevant if forecast_income = yes
	include_payroll(string) /// "yes" or "no"
	program_age(integer -70) /// age of income measurement
	kids(integer 2) /// not used currently -- default is 2 kids
	]

*-------------------------------------------------------------------------------
* Check inputs/error messages
*-------------------------------------------------------------------------------

cap assert inlist("`include_transfers'","yes","no")
if _rc> 0 {
	di as err `"include_transfers must be set to "yes" or "no""'
	exit
}
if "`forecast_income'"== "yes" & `program_age'==-70 {
	di as err "Please provide information of the age of program recipients to forecast income"
}
local inc_year = round(`inc_year')
if "`include_transfers'"== "yes" & `inc_year' < 1978 {
	di as err "Program cannot handle years before 1978"
}
if "`include_payroll'" == "" {
	di in red "Excluding payroll"
	local include_payroll = "no" // our baseline assumption everywhere
}

*-------------------------------------------------------------------------------
* Import data
*-------------------------------------------------------------------------------

*Data from CBO:
*https://www.cbo.gov/publication/50923
*"Data Underlying Figures"
/*
The marginal tax rates include the combined effects of federal and state
individual income taxes, federal payroll taxes, and benefits from the
Supplemental Nutrition Assistance Program and cost-sharing subsidies for
health insurance, generally on the basis of 2016 law. State income taxes
were calculated using state tax laws in place in 2013. The marginal tax
rates are based on taxpayers’ compensation before their employers’ share of
payroll taxes is deducted.
*/

local median_rate_0 = 0.142 // 0-49 % of the FPL
local median_rate_50 = 0.235 // 50-99 of the FPL
local median_rate_100 = 0.338 // etc.
local median_rate_150 = 0.339
local median_rate_200 = 0.328
local median_rate_250 = 0.325
local median_rate_300 = 0.326
local median_rate_350 = 0.327
local median_rate_400 = 0.335 // this is 400-450 

*https://www.cbo.gov/system/files/2019-01/54911-MTRchartbook.pdf (Exhibit 12)
/*
The marginal rate here is defined as the change in taxes divided by the change in
earnings that follows from a 1 percent increase in earnings for each tax return.
Each quintile contains an equal number of filing units; nonfilers are not included
*/

local mtr_q1_2015 -2.1
local mtr_q1_2016 -1.9
local mtr_q2_2015 9.8
local mtr_q2_2016 10.3
local mtr_q3_2015 19.3
local mtr_q3_2016 19.5
local mtr_q4_2015 19.9
local mtr_q4_2016 20.1
local mtr_q5_2015 25.8
local mtr_q5_2016 26

*Get the average state taxes: Table 1
local state_mtr_2016 2.6

*Get average payroll taxes by: Table 1
local payroll_mtr_2016 13.9

*Get the federal poverty guidelines (nominal dollars)
*see https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-poverty-thresholds.html
*format fpl_h[hh size]_c[children]_[year]

local fpl_h1_c0_2018 13064
local fpl_h2_c0_2018 16815
local fpl_h2_c1_2018 17308
local fpl_h3_c0_2018 19642
local fpl_h3_c1_2018 20212
local fpl_h3_c2_2018 20231
local fpl_h4_c0_2018 25900
local fpl_h4_c1_2018 26324
local fpl_h4_c2_2018 25465
local fpl_h4_c3_2018 25554
local fpl_h1_c0_2017 12752
local fpl_h2_c0_2017 16414
local fpl_h2_c1_2017 16895
local fpl_h3_c0_2017 19173
local fpl_h3_c1_2017 19730
local fpl_h3_c2_2017 19749
local fpl_h4_c0_2017 25283
local fpl_h4_c1_2017 25696
local fpl_h4_c2_2017 24858
local fpl_h4_c3_2017 24944
local fpl_h1_c0_2016 12486
local fpl_h2_c0_2016 16072
local fpl_h2_c1_2016 16543
local fpl_h3_c0_2016 18774
local fpl_h3_c1_2016 19318
local fpl_h3_c2_2016 19337
local fpl_h4_c0_2016 24755
local fpl_h4_c1_2016 25160
local fpl_h4_c2_2016 24339
local fpl_h4_c3_2016 24424
local fpl_h1_c0_2015 12331
local fpl_h2_c0_2015 15871
local fpl_h2_c1_2015 16337
local fpl_h3_c0_2015 18540
local fpl_h3_c1_2015 19078
local fpl_h3_c2_2015 19096
local fpl_h4_c0_2015 24447
local fpl_h4_c1_2015 24847
local fpl_h4_c2_2015 24036
local fpl_h4_c3_2015 24120
local fpl_h1_c0_2014 12316
local fpl_h2_c0_2014 15853
local fpl_h2_c1_2014 16317
local fpl_h3_c0_2014 18518
local fpl_h3_c1_2014 19055
local fpl_h3_c2_2014 19073
local fpl_h4_c0_2014 24418
local fpl_h4_c1_2014 24817
local fpl_h4_c2_2014 24008
local fpl_h4_c3_2014 24091
local fpl_h1_c0_2013 12119
local fpl_h2_c0_2013 15600
local fpl_h2_c1_2013 16057
local fpl_h3_c0_2013 18222
local fpl_h3_c1_2013 18751
local fpl_h3_c2_2013 18769
local fpl_h4_c0_2013 24028
local fpl_h4_c1_2013 24421
local fpl_h4_c2_2013 23624
local fpl_h4_c3_2013 23707
local fpl_h1_c0_2012 11945
local fpl_h2_c0_2012 15374
local fpl_h2_c1_2012 15825
local fpl_h3_c0_2012 17959
local fpl_h3_c1_2012 18480
local fpl_h3_c2_2012 18498
local fpl_h4_c0_2012 23681
local fpl_h4_c1_2012 24069
local fpl_h4_c2_2012 23283
local fpl_h4_c3_2012 23364
local fpl_h1_c0_2011 11702
local fpl_h2_c0_2011 15063
local fpl_h2_c1_2011 15504
local fpl_h3_c0_2011 17595
local fpl_h3_c1_2011 18106
local fpl_h3_c2_2011 18123
local fpl_h4_c0_2011 23201
local fpl_h4_c1_2011 23581
local fpl_h4_c2_2011 22811
local fpl_h4_c3_2011 22891
local fpl_h1_c0_2010 11344
local fpl_h2_c0_2010 14602
local fpl_h2_c1_2010 15030
local fpl_h3_c0_2010 17057
local fpl_h3_c1_2010 17552
local fpl_h3_c2_2010 17568
local fpl_h4_c0_2010 22491
local fpl_h4_c1_2010 22859
local fpl_h4_c2_2010 22113
local fpl_h4_c3_2010 22190
local fpl_h1_c0_2009 11161
local fpl_h2_c0_2009 14366
local fpl_h2_c1_2009 14787
local fpl_h3_c0_2009 16781
local fpl_h3_c1_2009 17268
local fpl_h3_c2_2009 17285
local fpl_h4_c0_2009 22128
local fpl_h4_c1_2009 22490
local fpl_h4_c2_2009 21756
local fpl_h4_c3_2009 21832
local fpl_h1_c0_2008 11201
local fpl_h2_c0_2008 14417
local fpl_h2_c1_2008 14840
local fpl_h3_c0_2008 16841
local fpl_h3_c1_2008 17330
local fpl_h3_c2_2008 17346
local fpl_h4_c0_2008 22207
local fpl_h4_c1_2008 22570
local fpl_h4_c2_2008 21834
local fpl_h4_c3_2008 21910
local fpl_h1_c0_2007 10787
local fpl_h2_c0_2007 13884
local fpl_h2_c1_2007 14291
local fpl_h3_c0_2007 16218
local fpl_h3_c1_2007 16689
local fpl_h3_c2_2007 16705
local fpl_h4_c0_2007 21386
local fpl_h4_c1_2007 21736
local fpl_h4_c2_2007 21027
local fpl_h4_c3_2007 21100
local fpl_h1_c0_2006 10488
local fpl_h2_c0_2006 13500
local fpl_h2_c1_2006 13896
local fpl_h3_c0_2006 15769
local fpl_h3_c1_2006 16227
local fpl_h3_c2_2006 16242
local fpl_h4_c0_2006 20794
local fpl_h4_c1_2006 21134
local fpl_h4_c2_2006 20444
local fpl_h4_c3_2006 20516
local fpl_h1_c0_2005 10160
local fpl_h2_c0_2005 13078
local fpl_h2_c1_2005 13461
local fpl_h3_c0_2005 15277
local fpl_h3_c1_2005 15720
local fpl_h3_c2_2005 15735
local fpl_h4_c0_2005 20144
local fpl_h4_c1_2005 20474
local fpl_h4_c2_2005 19806
local fpl_h4_c3_2005 19874
local fpl_h1_c0_2004 9827
local fpl_h2_c0_2004 12649
local fpl_h2_c1_2004 13020
local fpl_h3_c0_2004 14776
local fpl_h3_c1_2004 15205
local fpl_h3_c2_2004 15219
local fpl_h4_c0_2004 19484
local fpl_h4_c1_2004 19803
local fpl_h4_c2_2004 19157
local fpl_h4_c3_2004 19223
local fpl_h1_c0_2003 9573
local fpl_h2_c0_2003 12321
local fpl_h2_c1_2003 12682
local fpl_h3_c0_2003 14393
local fpl_h3_c1_2003 14810
local fpl_h3_c2_2003 14824
local fpl_h4_c0_2003 18979
local fpl_h4_c1_2003 19289
local fpl_h4_c2_2003 18660
local fpl_h4_c3_2003 18725
local fpl_h1_c0_2002 9359
local fpl_h2_c0_2002 12047
local fpl_h2_c1_2002 12400
local fpl_h3_c0_2002 14072
local fpl_h3_c1_2002 14480
local fpl_h3_c2_2002 14494
local fpl_h4_c0_2002 18556
local fpl_h4_c1_2002 18859
local fpl_h4_c2_2002 18244
local fpl_h4_c3_2002 18307
local fpl_h1_c0_2001 9214
local fpl_h2_c0_2001 11859
local fpl_h2_c1_2001 12207
local fpl_h3_c0_2001 13853
local fpl_h3_c1_2001 14255
local fpl_h3_c2_2001 14269
local fpl_h4_c0_2001 18267
local fpl_h4_c1_2001 18566
local fpl_h4_c2_2001 17960
local fpl_h4_c3_2001 18022
local fpl_h1_c0_2000 8959
local fpl_h2_c0_2000 11531
local fpl_h2_c1_2000 11869
local fpl_h3_c0_2000 13470
local fpl_h3_c1_2000 13861
local fpl_h3_c2_2000 13874
local fpl_h4_c0_2000 17761
local fpl_h4_c1_2000 18052
local fpl_h4_c2_2000 17463
local fpl_h4_c3_2000 17524
local fpl_h1_c0_1999 8667
local fpl_h2_c0_1999 11156
local fpl_h2_c1_1999 11483
local fpl_h3_c0_1999 13032
local fpl_h3_c1_1999 13410
local fpl_h3_c2_1999 13423
local fpl_h4_c0_1999 17184
local fpl_h4_c1_1999 17465
local fpl_h4_c2_1999 16895
local fpl_h4_c3_1999 16954
local fpl_h1_c0_1998 8480
local fpl_h2_c0_1998 10915
local fpl_h2_c1_1998 11235
local fpl_h3_c0_1998 12750
local fpl_h3_c1_1998 13120
local fpl_h3_c2_1998 13133
local fpl_h4_c0_1998 16813
local fpl_h4_c1_1998 17088
local fpl_h4_c2_1998 16530
local fpl_h4_c3_1998 16588
local fpl_h1_c0_1997 8350
local fpl_h2_c0_1997 10748
local fpl_h2_c1_1997 11063
local fpl_h3_c0_1997 12554
local fpl_h3_c1_1997 12919
local fpl_h3_c2_1997 12931
local fpl_h4_c0_1997 16555
local fpl_h4_c1_1997 16825
local fpl_h4_c2_1997 16276
local fpl_h4_c3_1997 16333
local fpl_h1_c0_1996 8163
local fpl_h2_c0_1996 10507
local fpl_h2_c1_1996 10815
local fpl_h3_c0_1996 12273
local fpl_h3_c1_1996 12629
local fpl_h3_c2_1996 12641
local fpl_h4_c0_1996 16183
local fpl_h4_c1_1996 16448
local fpl_h4_c2_1996 15911
local fpl_h4_c3_1996 15967
local fpl_h1_c0_1995 7929
local fpl_h2_c0_1995 10205
local fpl_h2_c1_1995 10504
local fpl_h3_c0_1995 11921
local fpl_h3_c1_1995 12267
local fpl_h3_c2_1995 12278
local fpl_h4_c0_1995 15719
local fpl_h4_c1_1995 15976
local fpl_h4_c2_1995 15455
local fpl_h4_c3_1995 15509
local fpl_h1_c0_1994 7710
local fpl_h2_c0_1994 9924
local fpl_h2_c1_1994 10215
local fpl_h3_c0_1994 11592
local fpl_h3_c1_1994 11929
local fpl_h3_c2_1994 11940
local fpl_h4_c0_1994 15286
local fpl_h4_c1_1994 15536
local fpl_h4_c2_1994 15029
local fpl_h4_c3_1994 15081
local fpl_h1_c0_1993 7518
local fpl_h2_c0_1993 9676
local fpl_h2_c1_1993 9960
local fpl_h3_c0_1993 11303
local fpl_h3_c1_1993 11631
local fpl_h3_c2_1993 11642
local fpl_h4_c0_1993 14904
local fpl_h4_c1_1993 15148
local fpl_h4_c2_1993 14654
local fpl_h4_c3_1993 14705
local fpl_h1_c0_1992 7299
local fpl_h2_c0_1992 9395
local fpl_h2_c1_1992 9670
local fpl_h3_c0_1992 10974
local fpl_h3_c1_1992 11293
local fpl_h3_c2_1992 11304
local fpl_h4_c0_1992 14471
local fpl_h4_c1_1992 14708
local fpl_h4_c2_1992 14228
local fpl_h4_c3_1992 14277
local fpl_h1_c0_1991 7086
local fpl_h2_c0_1991 9120
local fpl_h2_c1_1991 9388
local fpl_h3_c0_1991 10654
local fpl_h3_c1_1991 10963
local fpl_h3_c2_1991 10973
local fpl_h4_c0_1991 14048
local fpl_h4_c1_1991 14278
local fpl_h4_c2_1991 13812
local fpl_h4_c3_1991 13860
local fpl_h1_c0_1990 6800
local fpl_h2_c0_1990 8752
local fpl_h2_c1_1990 9009
local fpl_h3_c0_1990 10223
local fpl_h3_c1_1990 10520
local fpl_h3_c2_1990 10530
local fpl_h4_c0_1990 13481
local fpl_h4_c1_1990 13701
local fpl_h4_c2_1990 13254
local fpl_h4_c3_1990 13301
local fpl_h1_c0_1989 6451
local fpl_h2_c0_1989 8303
local fpl_h2_c1_1989 8547
local fpl_h3_c0_1989 9699
local fpl_h3_c1_1989 9981
local fpl_h3_c2_1989 9990
local fpl_h4_c0_1989 12790
local fpl_h4_c1_1989 12999
local fpl_h4_c2_1989 12575
local fpl_h4_c3_1989 12619
local fpl_h1_c0_1988 6155
local fpl_h2_c0_1988 7922
local fpl_h2_c1_1988 8154
local fpl_h3_c0_1988 9254
local fpl_h3_c1_1988 9522
local fpl_h3_c2_1988 9531
local fpl_h4_c0_1988 12202
local fpl_h4_c1_1988 12402
local fpl_h4_c2_1988 11997
local fpl_h4_c3_1988 12039
local fpl_h1_c0_1987 5909
local fpl_h2_c0_1987 7606
local fpl_h2_c1_1987 7829
local fpl_h3_c0_1987 8885
local fpl_h3_c1_1987 9142
local fpl_h3_c2_1987 9151
local fpl_h4_c0_1987 11715
local fpl_h4_c1_1987 11907
local fpl_h4_c2_1987 11519
local fpl_h4_c3_1987 11559
local fpl_h1_c0_1986 5701
local fpl_h2_c0_1986 7338
local fpl_h2_c1_1986 7553
local fpl_h3_c0_1986 8571
local fpl_h3_c1_1986 8820
local fpl_h3_c2_1986 8829
local fpl_h4_c0_1986 11302
local fpl_h4_c1_1986 11487
local fpl_h4_c2_1986 11113
local fpl_h4_c3_1986 11151
local fpl_h1_c0_1985 5593
local fpl_h2_c0_1985 7199
local fpl_h2_c1_1985 7410
local fpl_h3_c0_1985 8410
local fpl_h3_c1_1985 8654
local fpl_h3_c2_1985 8662
local fpl_h4_c0_1985 11089
local fpl_h4_c1_1985 11270
local fpl_h4_c2_1985 10903
local fpl_h4_c3_1985 10941
local fpl_h1_c0_1984 5400
local fpl_h2_c0_1984 6951
local fpl_h2_c1_1984 7155
local fpl_h3_c0_1984 8120
local fpl_h3_c1_1984 8355
local fpl_h3_c2_1984 8363
local fpl_h4_c0_1984 10707
local fpl_h4_c1_1984 10882
local fpl_h4_c2_1984 10527
local fpl_h4_c3_1984 10564
local fpl_h1_c0_1983 5180
local fpl_h2_c0_1983 6667
local fpl_h2_c1_1983 6863
local fpl_h3_c0_1983 7789
local fpl_h3_c1_1983 8015
local fpl_h3_c2_1983 8022
local fpl_h4_c0_1983 10270
local fpl_h4_c1_1983 10437
local fpl_h4_c2_1983 10098
local fpl_h4_c3_1983 10133
local fpl_h1_c0_1982 5019
local fpl_h2_c0_1982 6459
local fpl_h2_c1_1982 6649
local fpl_h3_c0_1982 7546
local fpl_h3_c1_1982 7765
local fpl_h3_c2_1982 7772
local fpl_h4_c0_1982 9950
local fpl_h4_c1_1982 10112
local fpl_h4_c2_1982 9783
local fpl_h4_c3_1982 9817
local fpl_h1_c0_1981 4729
local fpl_h2_c0_1981 6086
local fpl_h2_c1_1981 6265
local fpl_h3_c0_1981 7110
local fpl_h3_c1_1981 7316
local fpl_h3_c2_1981 7323
local fpl_h4_c0_1981 9375
local fpl_h4_c1_1981 9528
local fpl_h4_c2_1981 9218
local fpl_h4_c3_1981 9250
local fpl_h1_c0_1980 4284
local fpl_h2_c0_1980 5514
local fpl_h2_c1_1980 5676
local fpl_h3_c0_1980 6442
local fpl_h3_c1_1980 6628
local fpl_h3_c2_1980 6635
local fpl_h4_c0_1980 8494
local fpl_h4_c1_1980 8633
local fpl_h4_c2_1980 8351
local fpl_h4_c3_1980 8380
local fpl_h1_c0_1978 3392
local fpl_h2_c0_1978 4366
local fpl_h2_c1_1978 4494
local fpl_h3_c0_1978 5100
local fpl_h3_c1_1978 5248
local fpl_h3_c2_1978 5253
local fpl_h4_c0_1978 6725
local fpl_h4_c1_1978 6835
local fpl_h4_c2_1978 6612
local fpl_h4_c3_1978 6635


*Get household income cut-offs (in 2017 dollars) (https://www.census.gov/data/tables/time-series/demo/income-poverty/historical-income-households.html -- Table H1)
*format hhinc_q[quintile]_[year]

local hhinc_q1_2017 24638
local hhinc_q1_2016 24518
local hhinc_q1_2015 23591
local hhinc_q1_2014 22213
local hhinc_q1_2013 22134
local hhinc_q1_2013 22029
local hhinc_q1_2012 22033
local hhinc_q1_2011 22132
local hhinc_q1_2010 22534
local hhinc_q1_2009 23425
local hhinc_q1_2008 23639
local hhinc_q1_2007 24048
local hhinc_q1_2006 24418
local hhinc_q1_2005 24131
local hhinc_q1_2004 24048
local hhinc_q1_2003 24027
local hhinc_q1_2002 24480
local hhinc_q1_2001 24941
local hhinc_q1_2000 25580
local hhinc_q1_1999 25291
local hhinc_q1_1998 24292
local hhinc_q1_1997 23527
local hhinc_q1_1996 23049
local hhinc_q1_1995 23073
local hhinc_q1_1994 22031
local hhinc_q1_1993 21722
local hhinc_q1_1992 21639
local hhinc_q1_1991 22162
local hhinc_q1_1990 22802
local hhinc_q1_1989 23153
local hhinc_q1_1988 22739
local hhinc_q1_1987 22356
local hhinc_q1_1986 21940
local hhinc_q1_1985 21658
local hhinc_q1_1984 21408
local hhinc_q1_1983 21005
local hhinc_q1_1982 20559
local hhinc_q1_1981 20824
local hhinc_q1_1980 21240
local hhinc_q1_1979 22108
local hhinc_q1_1978 21847
local hhinc_q1_1977 21187
local hhinc_q1_1976 21232
local hhinc_q1_1975 20771
local hhinc_q1_1974 21849
local hhinc_q1_1973 21744
local hhinc_q1_1972 21282
local hhinc_q1_1971 20567
local hhinc_q1_1970 20835
local hhinc_q1_1969 21192
local hhinc_q1_1968 20576
local hhinc_q1_1967 19305
local hhinc_q2_2017 47110
local hhinc_q2_2016 46581
local hhinc_q2_2015 45020
local hhinc_q2_2014 42688
local hhinc_q2_2013 43251
local hhinc_q2_2013 42358
local hhinc_q2_2012 42533
local hhinc_q2_2011 42075
local hhinc_q2_2010 42815
local hhinc_q2_2009 44151
local hhinc_q2_2008 44512
local hhinc_q2_2007 46340
local hhinc_q2_2006 46038
local hhinc_q2_2005 45298
local hhinc_q2_2004 45109
local hhinc_q2_2003 45426
local hhinc_q2_2002 45606
local hhinc_q2_2001 46237
local hhinc_q2_2000 47106
local hhinc_q2_1999 47110
local hhinc_q2_1998 45834
local hhinc_q2_1997 44609
local hhinc_q2_1996 43326
local hhinc_q2_1995 43125
local hhinc_q2_1994 41351
local hhinc_q2_1993 41342
local hhinc_q2_1992 41458
local hhinc_q2_1991 42243
local hhinc_q2_1990 43163
local hhinc_q2_1989 44024
local hhinc_q2_1988 42952
local hhinc_q2_1987 42434
local hhinc_q2_1986 41967
local hhinc_q2_1985 40749
local hhinc_q2_1984 40066
local hhinc_q2_1983 39057
local hhinc_q2_1982 39101
local hhinc_q2_1981 38929
local hhinc_q2_1980 39832
local hhinc_q2_1979 41059
local hhinc_q2_1978 41308
local hhinc_q2_1977 39906
local hhinc_q2_1976 39557
local hhinc_q2_1975 38983
local hhinc_q2_1974 40528
local hhinc_q2_1973 41812
local hhinc_q2_1972 40987
local hhinc_q2_1971 39207
local hhinc_q2_1970 39913
local hhinc_q2_1969 40664
local hhinc_q2_1968 39010
local hhinc_q2_1967 37644
local hhinc_q3_2017 77552
local hhinc_q3_2016 76479
local hhinc_q3_2015 74498
local hhinc_q3_2014 70699
local hhinc_q3_2013 70830
local hhinc_q3_2013 69039
local hhinc_q3_2012 69079
local hhinc_q3_2011 68196
local hhinc_q3_2010 69293
local hhinc_q3_2009 70781
local hhinc_q3_2008 71589
local hhinc_q3_2007 73480
local hhinc_q3_2006 73126
local hhinc_q3_2005 72552
local hhinc_q3_2004 71849
local hhinc_q3_2003 72752
local hhinc_q3_2002 72640
local hhinc_q3_2001 73560
local hhinc_q3_2000 74475
local hhinc_q3_1999 74361
local hhinc_q3_1998 72859
local hhinc_q3_1997 70275
local hhinc_q3_1996 68682
local hhinc_q3_1995 67300
local hhinc_q3_1994 65800
local hhinc_q3_1993 64985
local hhinc_q3_1992 65090
local hhinc_q3_1991 65248
local hhinc_q3_1990 66034
local hhinc_q3_1989 67664
local hhinc_q3_1988 66938
local hhinc_q3_1987 66239
local hhinc_q3_1986 65132
local hhinc_q3_1985 63126
local hhinc_q3_1984 61728
local hhinc_q3_1983 59945
local hhinc_q3_1982 59742
local hhinc_q3_1981 60210
local hhinc_q3_1980 61066
local hhinc_q3_1979 63170
local hhinc_q3_1978 62501
local hhinc_q3_1977 60827
local hhinc_q3_1976 60258
local hhinc_q3_1975 58907
local hhinc_q3_1974 59886
local hhinc_q3_1973 61865
local hhinc_q3_1972 60577
local hhinc_q3_1971 57695
local hhinc_q3_1970 58054
local hhinc_q3_1969 58809
local hhinc_q3_1968 55915
local hhinc_q3_1967 53429
local hhinc_q4_2017 126855
local hhinc_q4_2016 123621
local hhinc_q4_2015 121060
local hhinc_q4_2014 116355
local hhinc_q4_2013 116186
local hhinc_q4_2013 111631
local hhinc_q4_2012 111344
local hhinc_q4_2011 110956
local hhinc_q4_2010 112704
local hhinc_q4_2009 114530
local hhinc_q4_2008 114406
local hhinc_q4_2007 118516
local hhinc_q4_2006 118260
local hhinc_q4_2005 115390
local hhinc_q4_2004 114482
local hhinc_q4_2003 116058
local hhinc_q4_2002 114799
local hhinc_q4_2001 115892
local hhinc_q4_2000 116716
local hhinc_q4_1999 116937
local hhinc_q4_1998 113048
local hhinc_q4_1997 109232
local hhinc_q4_1996 106154
local hhinc_q4_1995 104349
local hhinc_q4_1994 103116
local hhinc_q4_1993 101013
local hhinc_q4_1992 99622
local hhinc_q4_1991 99902
local hhinc_q4_1990 100702
local hhinc_q4_1989 102807
local hhinc_q4_1988 101074
local hhinc_q4_1987 100109
local hhinc_q4_1986 98455
local hhinc_q4_1985 94941
local hhinc_q4_1984 93247
local hhinc_q4_1983 90593
local hhinc_q4_1982 89087
local hhinc_q4_1981 89017
local hhinc_q4_1980 89412
local hhinc_q4_1979 91592
local hhinc_q4_1978 90900
local hhinc_q4_1977 88680
local hhinc_q4_1976 86695
local hhinc_q4_1975 84580
local hhinc_q4_1974 86914
local hhinc_q4_1973 89073
local hhinc_q4_1972 86703
local hhinc_q4_1971 82267
local hhinc_q4_1970 82827
local hhinc_q4_1969 82396
local hhinc_q4_1968 78565
local hhinc_q4_1967 76190


*Import 2015 ACS mean household income by age (see "${welfare_files}/Data/inputs/lifetime_forecasts/ACS_2015_mean_wages_by_age.dta")
local mean_acs_a18_2015 2801.652281
local mean_acs_a19_2015 5000.228459
local mean_acs_a20_2015 7701.40967
local mean_acs_a21_2015 9630.165886
local mean_acs_a22_2015 11699.53147
local mean_acs_a23_2015 15121.6937
local mean_acs_a24_2015 18122.19242
local mean_acs_a25_2015 22930.3305
local mean_acs_a26_2015 24591.14679
local mean_acs_a27_2015 26929.40886
local mean_acs_a28_2015 28520.38775
local mean_acs_a29_2015 30416.68249
local mean_acs_a30_2015 31739.4884
local mean_acs_a31_2015 33043.50363
local mean_acs_a32_2015 34801.7591
local mean_acs_a33_2015 35694.66543
local mean_acs_a34_2015 36458.62584
local mean_acs_a35_2015 38242.02511
local mean_acs_a36_2015 40283.7839099999
local mean_acs_a37_2015 41136.80886
local mean_acs_a38_2015 42467.42464
local mean_acs_a39_2015 43039.76066
local mean_acs_a40_2015 42525.30597
local mean_acs_a41_2015 44820.14439
local mean_acs_a42_2015 43966.69753
local mean_acs_a43_2015 44721.23813
local mean_acs_a44_2015 45938.49769
local mean_acs_a45_2015 46569.42194
local mean_acs_a46_2015 46444.03082
local mean_acs_a47_2015 45539.96398
local mean_acs_a48_2015 45997.56494
local mean_acs_a49_2015 45430.43317
local mean_acs_a50_2015 44845.44248
local mean_acs_a51_2015 44811.55371
local mean_acs_a52_2015 44382.44032
local mean_acs_a53_2015 43832.08326
local mean_acs_a54_2015 43451.99702
local mean_acs_a55_2015 41746.37106
local mean_acs_a56_2015 41779.50566
local mean_acs_a57_2015 40128.0104
local mean_acs_a58_2015 39332.87696
local mean_acs_a59_2015 38452.05651
local mean_acs_a60_2015 35476.1684499999
local mean_acs_a61_2015 33595.4452
local mean_acs_a62_2015 30722.98986
local mean_acs_a63_2015 26715.88208
local mean_acs_a64_2015 24448.28764
local mean_acs_a65_2015 20436.39282
local mean_acs_a66_2015 16889.25078
local mean_acs_a67_2015 14048.40786
local mean_acs_a68_2015 13054.5858
local mean_acs_a69_2015 10877.02114
local mean_acs_a70_2015 8651.779203
local mean_acs_a71_2015 7568.56553
local mean_acs_a72_2015 6831.35879399999
local mean_acs_a73_2015 5804.155339
local mean_acs_a74_2015 5400.701773
local mean_acs_a75_2015 4246.049592
local mean_acs_a76_2015 4011.179618
local mean_acs_a77_2015 3216.218856
local mean_acs_a78_2015 2951.410209
local mean_acs_a79_2015 2557.358299
local mean_acs_a80_2015 2143.866608
local mean_acs_a81_2015 2158.597476
local mean_acs_a82_2015 1642.504748
local mean_acs_a83_2015 1924.421167
local mean_acs_a84_2015 1197.231271
local mean_acs_a85_2015 1151.188717
local mean_acs_a86_2015 1047.829759
local mean_acs_a87_2015 899.1749371
local mean_acs_a88_2015 957.3759801
local mean_acs_a89_2015 470.2011679
local mean_acs_a90_2015 721.2896421
local mean_acs_a91_2015 896.7432765
local mean_acs_a92_2015 633.9770431
local mean_acs_a93_2015 420.3558006
local mean_acs_a94_2015 505.08938
local mean_acs_a95_2015 337.2004431
local mean_acs_a96_2015 0
local mean_acs_a97_2015 111.9296162

*Set a default wage growth rate
local wage_g = 0.005

*Set the base year
local base_year 2015

*Set the inc year of hhic
local hhinc_base_year 2017

*Set default number of children
local c 2

*-------------------------------------------------------------------------------
* Calculations
*-------------------------------------------------------------------------------

*Step 1: Is income to be forecasted?
qui deflate_to 2015, from(`usd_year')
local income = `provided_info' * r(deflator)

if "`forecast_income'" == "yes" {
	* Translate to age 40 - note since we do not have FPL past 2018, if the program participants
	* turn 40 after 2018 we treat them as though they turn 40 in 2018.
	local income = `income'*(1+`wage_g')^(min(2018 - (`inc_year' + 40 - `program_age'), 0)) // shift income back if inc_year will end up being after 2018
	local income = `income'*(1+`wage_g')^(max(1978 - (`inc_year' + 40 - `program_age'), 0)) // shift income forward if inc_year will end up being before 1978
	
	local inc_ratio = `mean_acs_a40_2015' *((1+`wage_g')^(40-`program_age')) / `mean_acs_a`program_age'_2015'
	local income = `income' * `inc_ratio'
	local inc_year = max(min(round(`inc_year'+(40-`program_age')), 2018), 1978)
}

local inc_year = max(min(`inc_year', 2018), 1978)
local hhinc_base_year = max(min(`hhinc_base_year', 2018), 1978)

if `inc_year' == 1979 local inc_year = 1980 // 1979 fpl data is missing (but we have 1978 & 1980)

*Import relevant deflators to 2015 for FPLs and income quartiles
foreach year in inc_year hhinc_base_year {
	qui deflate_to 2015, from(``year'')
	local deflator_``year'' = r(deflator)
}

*Step 2: Tax rate or Tax + Transfer Rate
if "`include_transfers'" == "yes" {
	*Get percentage of FPL
	if "`earnings_type'" == "individual" local h 3 // 1 adult + 2 kids
	else if "`earnings_type'" == "household" local h 4 // 2 adults + 2 kids
	di `inc_year'
	local fpl = `fpl_h`h'_c`c'_`inc_year'' * `deflator_`inc_year''
	local pfpl = 100 * `income' / `fpl'

	*Categorise
	local fpl_bin = floor(`pfpl'/50) // counts from 0
	if `fpl_bin'> 8 {
		local fpl_bin = 8 //assume tax rates above 450% of the FPL are the same as at 400-450%
	}

	*Get CBO tax + transfer rate
	local tax_rate = `median_rate_`=`fpl_bin'*50''
}
else if "`include_transfers'" == "no" {
	*Get the relevant cut-offs
	if `income' <= `hhinc_q1_`inc_year'' * `deflator_`hhinc_base_year''  local q 1 // hhinc thresholds in different dollars (2017)
	else if `income' > `hhinc_q1_`inc_year'' * `deflator_`hhinc_base_year'' & `income' <= `hhinc_q2_`inc_year'' * `deflator_`hhinc_base_year'' local q 2
	else if `income' > `hhinc_q2_`inc_year'' * `deflator_`hhinc_base_year'' & `income' <= `hhinc_q3_`inc_year'' * `deflator_`hhinc_base_year'' local q 3
	else if `income' > `hhinc_q3_`inc_year'' * `deflator_`hhinc_base_year'' & `income' <= `hhinc_q4_`inc_year'' * `deflator_`hhinc_base_year'' local q 4
	else local q 5

	*get quintile tax rate
	local inc_tax = `mtr_q`q'_2016' / 100
	local state_tax = `state_mtr_2016' / 100
	local tax_rate = `inc_tax' + `state_tax' + (`payroll_mtr_2016'/100)
}

*Step 3: Net out payroll taxes
if "`include_payroll'" == "no" {
	local payroll = `payroll_mtr_2016' / 100
	local tax_rate = (`tax_rate' - `payroll')
}

di "Tax rate: `tax_rate'"

return scalar tax_rate = `tax_rate'
if "`include_transfers'" == "yes" return scalar pfpl = `pfpl'
if "`include_transfers'" == "no" return scalar quintile = `q'

end

/* Example Entry:
get_tax_rate 1280 , ///
	include_transfers(yes) ///
	include_payroll(no) /// "yes" or "no"
	forecast_income(no) /// "yes" or "no"
	usd_year(2010) /// USD year of income
	inc_year(2002) /// year of income measurement
	earnings_type(individual) ///
	program_age(28) /// age of income measurement
	kids(3) // number of kids in family
*/
