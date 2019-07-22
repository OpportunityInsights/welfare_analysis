# A Unified Welfare Analysis of Government Policies - Replication Code
In order to replicate the results in Hendren & Sprung-Keyser (2019), files detailing causal estimates from papers and sets of assumptions must also be downloaded from [Opportunity Insights](https://opportunityinsights.org/data/).The Stata global ${welfare_git} should be set to point to the code folder, and the global ${welfare_files} should point to the folder downlowded from [Opportunity Insights](https://opportunityinsights.org/data/). All results in the paper can then be replicated by running ${welfare_git}/metafile.do in the top folder of the repository, after setting the appropriate filepaths.

### Outline of Program File Stucture
Each policy analysed has a corresponding .do file which serves to provide the logic necessary to translate causal effect estimates and assumptions into MVPFs and confidence intervals. These files can be found in “${welfare_git}/programs/functioning”. The correspondences between file names and policy descriptions can be found in “${welfare_files}/MVPF_Calculations/Further program details.xlsx”. The causal effect estimates and sources for each policy can be found in “${welfare_files}/Data/inputs/causal_estimates/uncorrected”. The sets of assumptions used in estimating the MVPF can be found in “${welfare_files}/MVPF_Calculations/program_assumptions”.

Each .do file begins in section 1 by loading assumptions set via globals into memory as locals. These globals are set externally, either through “bootstrap_wrapper.do” when batch running programs, or by the ado command “run_program”, which can be used to load the baseline assumptions and then run a program's do file by issuing Stata the command “run_program [policy]”.

After loading assumptions each file loads causal effect estimates from the relevant papers in section 2. When run directly via run_program the effects loaded will be point estimates, but when run externally via bootstrap_wrapper these may be bootstrap draws or publication bias corrected estimates.

In section 3 exact inputs and program specific information, such as the year of implementation or income of recipients, is laid out. Section 4 conducts intermediate calculations with the inputs now loaded, often using the ado files included in this repository. The most frequently used two of these, “get_tax_rate” and “est_life_impact”, are described in detail in appendices G and I.

Section 5 determines the program and net costs of the policy, then section 6 determines the WTP. Section 7 then brings these together to form the MVPF, which is then exported in section 8 to be aggregated by bootstrap_wrapper.

### I Prepare Causal Estimates
#### I.A Preparing Draws of Uncorrected Causal Estimates
Before estimating MVPFs and bootstrapping them, we prepare bootstrap draws of the causal estimates which go into each MVPF calculation. The file ${welfare_git}/wrapper/prepare_causal_estimates.do does this, looping over all the policies in our sample. For each policy it finds the corresponding causal estimates file in ${welfare_files}/Data/inputs/causal_estimates/uncorrected which details point estimates and standard errors. (In cases where standard errors are not available we use t-statistics or p-values in order to back them out. Where only significance levels are reported we draw uniformly over the range of possible associated p-values). The file also details the assumed correlational structure between estimates in the column "corr_direction". This variable defines blocks in the correlation matrix between estimates: blocks are indicated by different base numbers and the sign determines the correlation direction. E.g., if we have four variables with corr_directions 1, -1, 2, 2 respectively, then 1 and 2 are perfectly negatively correlated, 3 and 4 are perfectly positively correlated, and 1 and 2 are uncorrelated with 3 and 4. We set these correlations in order to maximise the width of our confidence intervals where estimates are from the same sample. Given point estimates, standard errors and a correlation matrix, we draw from the implied joint normal distribution 1000 times, generating the 1000 sets of estimates that correspond to our 1000 bootstrap estimates of the MVPF.

#### I.B Estimate Publication Bias and Corrected Causal Estimates
Using the methodology of Andrews and Kasy (Forthcoming), we estimate the degree of publication bias present in the causal estimates used as inputs into our analysis. The file ${welfare_git}/wrapper/prepare_corrected.do does this, first estimating the degree of publication bias, then obtaining publication bias-corrected point estimates for the causal effects by maximum likelihood. This procedure relies on files taken from Andrews and Kasy (Forthcoming)'s replication code, available from the authors' websites (downloaded from [here](https://scholar.harvard.edu/files/iandrews/files/code_and_data_2019.zip), accessed April 10th 2019). We present results using 4 different specifications:
1. Skip the estimation of publication bias, and assume that significant results showing positive impacts for children are 35 times more
likely to be published than other results.
2. Estimate publication bias allowing for breaks in publication probability at +/- 1.64
3. Estimate publication bias allowing for breaks in publication probability at +/- 1.96
4. Estimate publication bias allowing for breaks in publication probability at +/-1.64 and +/-
1.96

### II Estimate and Bootstrap MVPFs and Other Statistics
#### II.A Estimate and Bootstrap MVPF and Components
Once the draws for the causal estimates have been made, we estimate our MVPFs and bootstrap them in order to get confidence intervals in the file ${welfare_git}/wrapper/prepare_causal_estimates.do. This file loops over all programs, and estimates the MVPF under a number of different specifications. These specifications correspond to distinct sets of assumptions and are:
+ *baselines*: Estimates the MVPF under our baseline assumptions.
+ *lower_bound_wtp*: Estimates the MVPF under a set of assumptions corresponding to a lower bound for the WTP for the policy.
+ *fixed_forecast*: Estimates the MVPF as in the baseline but when projecting earnings forwards holds them constant at their observed level, not allowing them to grow with population earnings by age.
+ *observed_forecast*: Estimates the MVPF as in the baseline but does not project earnings forwards past the oldest age at which earnings are observed.
+ *corrected_mode_k*: Estimates the point estimate for the MVPF based on corrected causal estimates from corrected mode *k* in [1; 4] as detailed above.
+ *costs_by_age*: Estimates the cumulative cost of the policy over the life cycle of the policy's beneficiaries. This is not available for all policies.
+ *robustness*: Estimates the MVPF as in baselines but varying the interest and tax rates in order to assess robustness.
+ *robustness_pe*: Estimates the MVPF as in baselines but varying the interest and tax rates in order to assess robustness, but skips the estimation of confidence intervals for speed.
+ *normal*: Estimates the MVPF across all specifications included in each programs assumptions file, i.e., estimates the baseline and all alternative specifications. 

This file also generates draws for causal effects common across files, such as estimates of the returns to college attendance from Zimmerman (2014). The draws for these causal effects used in our paperwere generated without a set seed, so we include them in files available for download for replicability. These effects can be redrawn in bootstrap_wrapper.do by modifying the assumptions in sections 1.b and 1.c.

#### II.B Monte Carlo Simulations for Bootstrap Coverage
In order to assess the validity of our confidence intervals, we conduct a monte carlo exercise to estimate coverage ratios across the space of WTP and cost. These exercises are detailed in appendix H and are conducted in the files ${welfare_git}/ci_simulations/grid_w_c.do and ${welfare_git}/ci_simulations/vary_c_around_zero.do

### III Compile Estimates and Estimate Group Averages
#### III.A Compile Estimates with Confidence Intervals
Once we have estimated our MVPFs we draw together these estimates using the file ${welfare_git}/wrapper/compile_results.do. This file also estimates group averages for policies across program types and a range of other groupings. Programs are only included in averages if they have standard errors on at least one of their inputs and none of these standard errors are derived from ranges of p-values. The file also defines a number of groupings and variables that are useful for producing graphs later. This program exports datasets of both bounded estimates, used to produce figures, and unbounded estimates, used to produce tables and the numbers in the paper.

#### III.B Compile Estimates without Confidence Intervals
In some cases we estimate MVPFs without producing confidence intervals (in particular, MVPFs estimates that use publication bias corrected causal inputs), for these cases the file ${welfare_git}/wrapper/compile_pe.do
serves a very similar purpose to compile_results above.

### IV Estimate Value of Information Experiments
We estimate the value of information experiments detailed in section VI.A in the file ${welfare_git}/estimate_statistics/value_info.do. This file outlines the methodology for these experiments in the comments at the top, then produces a number of datasets giving values of information across policies.

### V Produce Figures for Paper
Once all data files have been produced, all figures included in the paper can be produced by running ${welfare_git}/figtab/figures_metafile.do, ensuring that the global "version" is set to "paper" at the top of the file. However, note that most of the final figures require some form of manual editing.

### References
Andrews, I. and M. Kasy (Forthcoming). Identification of and correction for publication bias.
American Economic Review.
Zimmerman, S. D. (2014). The returns to college admission for academically marginal students.
Journal of Labor Economics 32 (4), 711-754.
