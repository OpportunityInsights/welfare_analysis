/*******************************************************************************
						METAFILE FOR WELFARE PAPER 
********************************************************************************

	This file produces all estimates in Hendren & Sprung-Keyser (2019). It
	requires not only this code repository but also a separate set of files
	available at https://opportunityinsights.org/

********************************************************************************

To get started two file paths must be set.

First, set the welfare_git filepath below to the top-folder of this code 
repository.

Second, set the welfare_files filepath below to the top-folder of the separate
files folder.

********************************************************************************

Required software packages:
	- Stata
	- Matlab, including Global Optimization Toolbox
	
Capture statements have been added to allow the code to run without Matlab, in
which case the estimation of and correction for publication bias is omitted.

*******************************************************************************/

global welfare_git = "/welfare_analysis" //point to code root

global welfare_files = "/welfare_files" // point to files folder

global welfare_seed 1280 // Massachusetts Avenue

*-------------------------------------------------------------------------------
* 1 - Prepare causal estimates 
*-------------------------------------------------------------------------------

* 1a - prepare bootstrap draws of uncorrected causal estimates
do "${welfare_git}/wrapper/prepare_causal_estimates.do" ///
											all_programs // programs to run for

* 1b - estimate publication bias and correct causal estimates
* This file will pause to let the Matlab script run. Once that 
* has finished (the Matlab window closes), simply type "end" 
* into the Stata Window
cap do "${welfare_git}/wrapper/prepare_corrected_ests.do"

*-------------------------------------------------------------------------------
* 2 - Estimate MVPFs and other statistics, bootstrapping
*-------------------------------------------------------------------------------

* 2a - bootstrap MVPF estimates and components
do "${welfare_git}/wrapper/bootstrap_wrapper.do" ///
										all_programs /// programs to run for
										all // modes to run on
										
* 2b - run simulations for confidence interval coverage
do "${welfare_git}/ci_simulations/grid_w_c.do"
do "${welfare_git}/ci_simulations/vary_c_around_zero.do"

*-------------------------------------------------------------------------------
* 3 - Compile estimates
*-------------------------------------------------------------------------------

* 3a - Compile estimates with bootstrapped confidence intervals
do "${welfare_git}/wrapper/compile_results.do" ///
									all_modes // modes to run on

* 3b - Compile point estimates where we don't have confidence intervals
cap do "${welfare_git}/wrapper/compile_pe.do" ///
					"corrected_mode_1 corrected_mode_4" // modes to run on

*-------------------------------------------------------------------------------
* 4 - Estimate value of information experiments
*-------------------------------------------------------------------------------

qui do "${welfare_git}/wrapper/value_info.do"

*-------------------------------------------------------------------------------
* 5 - Produce figures
*-------------------------------------------------------------------------------

adopath + "${welfare_git}/ado"
cap mkdir "${welfare_files}/figtab"
cap mkdir "${welfare_files}/figtab/paper"
cap mkdir "${welfare_files}/figtab/slides"
do "${welfare_git}/figtab/figures_metafile.do"
