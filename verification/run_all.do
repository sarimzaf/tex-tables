version 17
* Run from the skill root after examples/stata/run_all.do.
* Each independent calculation starts with clear all and loads no table helper.
set more off
capture mkdir verification/output
capture erase verification/output/INDEPENDENT_PASS.txt
foreach table in grouped_regression grouped_regression_multipage auto_summary auto_summary_repair_panels {
    confirm file "examples/stata/output/`table'.dta"
}
do verification/regressions.do
do verification/summaries.do
file open status using verification/output/INDEPENDENT_PASS.txt, write text replace
file write status "PASS: independent regression and summary calculations and saved-result comparisons completed." _n
file close status
