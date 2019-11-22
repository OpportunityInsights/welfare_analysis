# Change Log

## [2.0](https://github.com/Opportunitylab/welfare_analysis/tree/v2.0)

**Implemented Changes**
- Added program `head_start` studying the introduction of head start using estimates from Jackson et al (2016). This work initially was omitted because it was not included in the survey articles used to form our sample frame, and it was missed in our review of prominent literature in this space after this survey. We greatly appreciate the researchers who have pointed out this omission.
- Removed program `snap_imm`. This research does not observe impacts on earnings, and instead only observes impacts on program participation. Upon review, we realized this does not meet the standards of our sample frame for other policies, and have therefore omitted it from our sample.
- Added a "set seed" for the causal effect college draws that ensures bootstrapped confidence intervals are fully replicable in the replication files.
- Implemented an alternative specification with a calculation using an exponential rather than a percentage approximation of income effects in the `mc_preg_women` program. In addition, we removed a double counting of incomes at age 37 when counting the benefits.
- Set `payroll_assumption` for the `get_tax_rate` function to a default 'no'. This ensures that we use a tax rate that excludes payroll taxes in our alternative specifications and did not affect the baseline estimates.
- For NIT, we updated to the latest version of the causal estimates from [(Price and Song 2018)](https://www.davidjonathanprice.com/docs/djprice_jsong_simedime_WP621.pdf). Since the release of our original results, the revised paper has been published with slightly revised estimates.


**Additional minor coding adjustments**
-  `afdc_max_ben.do`: Fixed an issue that prevented `tax_rate_assumption` to be loaded properly.
- `EITC_Obra93.do`: For alternative specifications, we fixed an issue that adds costs of college to the calculations that use college outcomes.
- `FIU.do`: Fixed an issue with the standard errors. In the bootstrap iterations, we now correlate college causal effect draws with the observed effects, as drawn for the FIU program, which renders more appropriate conservative standard errors. In addition, we also changed the conservative WTP specification to be $1. We thank a referee for pointing out that tuition payments are not reflective of WTP for the policy, since the policy under consideration is admitting a student into FIU and requiring them to pay tuition. Hence, the conservative WTP should be $1 not the tuition payments.
- `hous_vou_afdc.do`: We have removed a behavioral response from the program cost, and the impacts on kids are no longer included in the baseline specification. We also fixed a coding issue for an alternative specification that prevented a 'no kids' alternative to be run if a different local was set to a specific value.
- `HS_RD.do`: Fixed a deflation issue where college costs were included for 1987 but the program deflated to 1984.
- `kalamazoo.do`: Fixed an issue that prevented the `college_cost` assumption to be loaded properly.
- `pell_tn.do`: We fixed a miscalculation in the fraction of enrollees switching from community colleges.
- `ss_benefit.do`: We now correctly incorporate the private cost of college. To do so, we now set the parameter `private_costs_gov` to 'yes'. Before, code reliant on this assumption was skipped in the calculation.
- `tuition_s_pe.do`: We fixed an issue that prevented the `omit_edu_cost` assumption to be loaded properly. This does not affect our baseline estimates as the assumption was loaded from another `tuition_*` program when running the bootstrap wrapper.
- `TN_Hope.do`: Fixed a minor double counting issue in enrollment.
- `WIC.do`: Fixed an issue in the conservative WTP measurements in which a code block did not run. This does not affect the MVPF but affects the size of the program cost.
- `wrapper/bootstrap_wrapper.do` and `wrapper/compile_results.do`: Fixed an issue where the Efron correction used the number of draws rather than the number of draws where the MVPF is non-missing.
