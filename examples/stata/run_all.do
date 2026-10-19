version 17
clear all
set more off
capture mkdir examples/stata/output
capture log close
log using examples/stata/output/run_all.log, text replace
capture erase examples/stata/output/PASS.txt
foreach table in standard shared different_samples unknown_samples different_outcomes summary long_labels multipage wide_multipage panel_continuation grouped_regression grouped_regression_multipage auto_summary auto_summary_repair_panels ordinary_regression {
    do examples/stata/`table'.do
}
file open status using examples/stata/output/PASS.txt, write text replace
file write status "All fifteen native Stata table workflows completed." _n
file close status
log close
