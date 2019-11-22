/*******************************************************************************
* Return Parameters for Earnings Forecast
*******************************************************************************

DESCRIPTION: Takes as inputs:
* type of intermediate outcome
* magnitude of intermediate outcome


EXAMPLE CALL:
int_outcome, outcome_type("test score") impact_magnitude(0.1) usd_year(2010)


*******************************************************************************/

* drop program
cap program drop int_outcome

* define program
program define int_outcome, rclass

* syntax
syntax , outcome_type(string) /// takes on "test score", "enrollment", "attainment", "ccattain", or "lbw"
	impact_magnitude(real) ///
	usd_year(real)


*-------------------------------------------------------------------------------
*	                		 IMPORT DEFLATOR DATA
*-------------------------------------------------------------------------------

*Use deflate_to function
deflate_to `usd_year', from(2005)
local deflator = r(deflator)

*-------------------------------------------------------------------------------
*	                 TEST SCORE INTERMEDIATE OUTCOME
*-------------------------------------------------------------------------------
if "`outcome_type'" == "test score" {
	*Calculate Earnings Impact
	local test_score_earn_effect = 0.1 // Assumption from Kline and Walters (2017)
	local prog_earn_effect = `test_score_earn_effect'*`impact_magnitude'

	*Earnings Gain start
	local earnings_gain_proj_start = 18

	*RETURN VARIABLES
	return scalar prog_earn_effect = `prog_earn_effect'
	return scalar earnings_gain_proj_start = `earnings_gain_proj_start'
	return scalar private_cost = 0
	return scalar total_cost = 0
}

*-------------------------------------------------------------------------------
*		       COLLEGE ENROLLMENT INTERMEDIATE OUTCOME
*-------------------------------------------------------------------------------
if "`outcome_type'" == "enrollment" {
	local earnings_gain_proj_start = 22
	/* For each effect the % effect is estimated by normalising the observed earnings
	effect in Zimmerman (2014) by the control mean earnings. The se is then estimated
	by assuming control earnings are known, so the % effect shares a t-stat with the
	observed earnings effect.*/
	local earnings_level_8_14_quarterly = 7241 // Zimmerman Table 5
	local total_earn_1_7 = 94368 // Zimmerman Table 7B

	local enrollment_earn_effect_pos = 1593 / `earnings_level_8_14_quarterly' // 0.22 - Zimmerman 2014 table 5
	local enrollment_earn_effect_neg = -12294 / `total_earn_1_7' // Zimmerman 2014 table 7B

	if "${draw_number}" != "" & "${draw_number}" != "0" {
		if "${bootstrap_enrollment_effects}" == "yes" {
			preserve
				use "${input_data}/causal_estimates/uncorrected/draws/FIU.dta", replace
				local enrollment_earn_effect_pos = earnings_8_14_change[${draw_number}] ///
					/ `earnings_level_8_14_quarterly'
				local enrollment_earn_effect_neg = earning_reduction_1_7[${draw_number}] ///
					/ `total_earn_1_7'
			restore
		}
	}

	local prog_earn_effect_pos = `enrollment_earn_effect_pos' * ///
								 `impact_magnitude'
	local prog_earn_effect_neg = `enrollment_earn_effect_neg' * ///
								 `impact_magnitude'

	*Additional Government + Private Expenditure on School
	local private_expenditure = 2979  * `deflator' // Zimmerman 2014, Table 7a, Expenditure by individuals due to college enrollment
	local total_expenditure = 5713  * `deflator'  // Zimmerman 2014, Table 7a, Total due to college enrollment

	local private_expenditure_sum = `impact_magnitude' * `private_expenditure'
	local total_expenditure_sum = `impact_magnitude' * `total_expenditure'

	*RETURN VARIABLES
	return scalar prog_earn_effect_pos = `prog_earn_effect_pos'
	return scalar prog_earn_effect_neg = `prog_earn_effect_neg'
	return scalar earnings_gain_proj_start = `earnings_gain_proj_start'
	return scalar private_cost = `private_expenditure_sum'
	return scalar total_cost = `total_expenditure_sum'
}

*-------------------------------------------------------------------------------
*.              COLLEGE ATTAINMENT INTERMEDIATE OUTCOME
*-------------------------------------------------------------------------------

if "`outcome_type'" == "attainment" {
	/* For the positive effect the % effect is estimated by normalising the observed earnings
	effect in Zimmerman (2014) by the control mean earnings. The se is then estimated
	by assuming control earnings are known, so the % effect shares a t-stat with the
	observed earnings effect.*/
	local total_earn_1_7 = 94368 // Zimmerman Table 7B

	local attainment_earn_effect_pos = 815 / 7241 // Zimmerman 2014
	local attainment_earn_effect_pos_se = abs( ///
		`attainment_earn_effect_pos' / (815 / 276)) // Zimmerman 2014

	local attainment_earn_effect_neg = (-12294 / `total_earn_1_7') / ///
									   (0.457 / 0.234) // ratio of years to admittance effect in table 4

	if "${draw_number}" != "" & "${draw_number}" != "0" {
		if "${bootstrap_enrollment_effects}" == "yes" {
			/*Use draws for enrollment effect as both enrollment and attainment effects
			are estimated from zimmerman on same sample, so we want them correlated */
			matrix temp = college_effects["${draw_number}", "enrollment_earn_effect_pos"]
			local attainment_earn_effect_pos_draw = temp[1,1] //the line above doesn't return a scalar
			/* Positive effect need not be correlated with FIU draws because
			   we don't use it in that program. */
			local attainment_earn_effect_pos = `attainment_earn_effect_pos' + ///
				`attainment_earn_effect_pos_se' * ///
				invnormal(`attainment_earn_effect_pos_draw')
			preserve
				use "${input_data}/causal_estimates/uncorrected/draws/FIU.dta", replace
				local attainment_earn_effect_neg = earning_reduction_1_7[${draw_number}] ///
					/ `total_earn_1_7' / (0.457 / 0.234)
			restore
		}
	}

	local prog_earn_effect_pos = `attainment_earn_effect_pos' * `impact_magnitude'
	local prog_earn_effect_neg = `attainment_earn_effect_neg' * `impact_magnitude'

	*Additional Government + Private Expenditure on School
	local private_expenditure_term = 1166 * `deflator'
	//Zimmerman 2014, Table 7a, Expenditure by individuals due to college enrollment

	local total_expenditure_term =  4904 * `deflator'
	//Zimmerman 2014, Table 7a, Total expenditure due to college enrollment

	*Per Term Costs are multiplied by 2 to get per year costs and then multiplied by numbers of years of enrollment
	local private_expenditure_sum = `impact_magnitude' * `private_expenditure_term' * 2
	local total_expenditure_sum = `impact_magnitude' * `total_expenditure_term' * 2

	*RETURN VARIABLES
	return scalar prog_earn_effect_pos = `prog_earn_effect_pos'
	return scalar prog_earn_effect_neg = `prog_earn_effect_neg'
	return scalar private_cost = `private_expenditure_sum'
	return scalar total_cost = `total_expenditure_sum'
}

*-------------------------------------------------------------------------------
*.             COMMUNITY COLLEGE ATTAINMENT INTERMEDIATE OUTCOME
*-------------------------------------------------------------------------------

if "`outcome_type'" == "ccattain" {

	local community_earn_effect_pos = (1337/6141)/1.72 // Mountjoy (2018) table 5, page 41
	local community_earn_effect_pos_se = abs(`community_earn_effect_pos' / ///
										(1337/731)) // Mountjoy (2018) table 5, page 41
	//This result comes from the earnings effect in Table 5, divided by the total earnings level on page 41
	//We assume the years of schooling effect is fixed, and scale the point estimate and standard error based
	//on that figure. We use the estimate of going to two-year school instead of no

	local community_earn_effect_neg = 0
	local community_earn_effect_neg_se = 0
	//This result comes from a rough visual inspection of Figure 8 in Mountjoy 2018. The earnings pooled
	//earnings effects are not reported, but the earnings decline in years 22-24 appears matched by the
	//gains in 25-27. We assume as a result that there are no net earnings changes before age 27

	if "${draw_number}" != "" & "${draw_number}" !="0" {
	if "${bootstrap_enrollment_effects}"== "yes" {
		matrix temp= college_effects["${draw_number}", "community_earn_effect_pos"]
		local community_earn_effect_pos_draw = temp[1,1] //the line above doesn't return a scalar
		matrix temp = college_effects["${draw_number}", "community_earn_effect_neg"]
		local community_earn_effect_neg_draw = temp[1,1]
		local community_earn_effect_pos = `community_earn_effect_pos' + `community_earn_effect_pos_se' * invnormal(`community_earn_effect_pos_draw')
		local community_earn_effect_neg = `community_earn_effect_neg' + `community_earn_effect_neg_se' * invnormal(`community_earn_effect_neg_draw')
		}
	}

	local prog_earn_effect_pos = `community_earn_effect_pos'*`impact_magnitude'
	local prog_earn_effect_neg = `community_earn_effect_neg'*`impact_magnitude'

	*RETURN VARIABLES
	return scalar prog_earn_effect_pos = `prog_earn_effect_pos'
	return scalar prog_earn_effect_neg = `prog_earn_effect_neg'
}


*-------------------------------------------------------------------------------
*.                 LOW BIRTHWEIGHT INTERMEDIATE OUTCOME
*-------------------------------------------------------------------------------

if "`outcome_type'" == "lbw" {
	local earnings_gain_proj_start = 18
	* from Black Devereux and Salvanes "The effect of Birth weight on adult outcomes" QJE 2007
	local bw_earn_effect = 0.12 //Black 2007 table III
	local bw_earn_effect_se = 0.06 //Black 2007 table III

	if "${draw_number}" != "" & "${draw_number}" !="0" {
		if "${bootstrap_bw_effects}"== "yes" {
			matrix temp= bw_effects["${draw_number}", "bw_earn_effect"]
			local bw_earn_effect_draw = temp[1,1] //the line above doesn't return a scalar
			local bw_earn_effect = `bw_earn_effect' + `bw_earn_effect_se' * invnormal(`bw_earn_effect_draw')

		}
	}

	local prog_earn_effect = `bw_earn_effect'*`impact_magnitude'

	*RETURN VARIABLES
	return scalar prog_earn_effect = `prog_earn_effect'
	return scalar earnings_gain_proj_start = `earnings_gain_proj_start'
	return scalar private_cost = 0
	return scalar total_cost = 0
}

end
