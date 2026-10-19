version 17
clear all
set more off
capture mkdir verification/output
set linesize 140
capture log close _all
log using "verification/output/summary_check.log", text replace name(summarycheck)
display "INDEPENDENT SUMMARY-STATISTICS CHECK"
display "Ordinary Stata summarize and count only; no table skill or helper loaded."
about
sysuse auto, clear
describe price mpg rep78 headroom trunk weight length turn displacement gear_ratio
tabulate foreign, missing
tabulate rep78 foreign, missing

* Each summarize uses that variable's available observations, not complete cases.
tempname h
postfile `h' str32 table_id str3 panel_id str2 group_id str32 row_id ///
    double(direct_n direct_mean direct_sd checked_count) ///
    using "verification/output/direct_summary_results.dta", replace
local variables "price mpg rep78 headroom trunk weight length turn displacement gear_ratio"
forvalues category=0/5 {
    local table=cond(`category'==0,"auto_summary","auto_summary_repair_panels")
    local restriction "1"
    if `category'>0 local restriction "rep78==`category'"
    forvalues origin=0/1 {
        local label=cond(`origin'==0,"Domestic","Foreign")
        foreach variable of local variables {
            display "TABLE=`table'; PANEL=p`category'; GROUP=`label'; VARIABLE=`variable'"
            summarize `variable' if foreign==`origin' & (`restriction')
            scalar dn=r(N)
            scalar dm=r(mean)
            scalar ds=r(sd)
            * Independent count of available records must agree with summarize.
            quietly count if foreign==`origin' & (`restriction') & !missing(`variable')
            scalar cn=r(N)
            assert cn==dn
            if dn==0 assert missing(dm) & missing(ds)
            post `h' ("`table'") ("p`category'") ("g`origin'") ("`variable'") (dn) (dm) (ds) (cn)
            display "SUMMARY|`table'|p`category'|g`origin'|`variable'|n|" %24.17g dn
            display "SUMMARY|`table'|p`category'|g`origin'|`variable'|mean|" %24.17g dm
            display "SUMMARY|`table'|p`category'|g`origin'|`variable'|sd|" %24.17g ds
        }
    }
}
postclose `h'
use "verification/output/direct_summary_results.dta", clear
assert _N==120
isid table_id panel_id group_id row_id
assert direct_n==checked_count
display "Direct calculations complete: 120 variable/group/panel combinations, each with mean, sample SD and variable-specific N."

* Load delivered skill results only after direct calculations are saved.
tempfile reference
use "examples/stata/output/auto_summary.dta", clear
generate str32 table_id="auto_summary"
save `reference'
use "examples/stata/output/auto_summary_repair_panels.dta", clear
generate str32 table_id="auto_summary_repair_panels"
append using `reference'
keep table_id panel_id group_id row_id statistic value summary_n panel_order row_order group_order row_label
isid table_id panel_id group_id row_id statistic
save `reference', replace

use "verification/output/direct_summary_results.dta", clear
generate double variable_n=direct_n
reshape long direct_, i(table_id panel_id group_id row_id) j(statistic) string
rename direct_ direct_value
merge 1:1 table_id panel_id group_id row_id statistic using `reference'
assert _merge==3
assert _N==360
drop _merge
assert missing(direct_value)==missing(value)
assert variable_n==summary_n
generate double difference=direct_value-value
foreach statistic in n mean sd {
    quietly summarize difference if statistic=="`statistic'", meanonly
    display "Maximum absolute difference for `statistic': " %24.17g max(abs(r(min)),abs(r(max)))
    assert difference==0 if statistic=="`statistic'" & !missing(direct_value)
}
assert value==0 if statistic=="n" & variable_n==0
assert missing(value) if inlist(statistic,"mean","sd") & variable_n==0
quietly count if missing(value)
display "Matching unavailable statistics: " r(N)
assert r(N)==40
quietly count if statistic=="n" & variable_n==0
display "Matching empty variable/group/panel combinations: " r(N)
assert r(N)==20

display "OVERALL TABLE: DIRECT VERSUS SKILL"
format direct_value value %20.15g
sort table_id panel_order row_order group_order statistic
list row_id group_id statistic direct_value value difference if table_id=="auto_summary", noobs abbreviate(24) separator(0)

display "VARIABLE-SPECIFIC N: DIRECT VERSUS SKILL, ALL PANELS"
list table_id panel_id row_id group_id direct_value value if statistic=="n", noobs abbreviate(24) separator(0)

* Explicit missingness checks from the original data, not inferred from a footer.
assert direct_value==52 if table_id=="auto_summary" & row_id=="price" & group_id=="g0" & statistic=="n"
assert direct_value==22 if table_id=="auto_summary" & row_id=="price" & group_id=="g1" & statistic=="n"
assert direct_value==48 if table_id=="auto_summary" & row_id=="rep78" & group_id=="g0" & statistic=="n"
assert direct_value==21 if table_id=="auto_summary" & row_id=="rep78" & group_id=="g1" & statistic=="n"
save "verification/output/summary_comparison.dta", replace
export delimited using "verification/output/summary_comparison.csv", replace
display "PASS: all 360 mean/SD/N cells match exactly, including 40 unavailable values; all variable-specific counts agree."
display "PASS: the overall table uses 52/22 cars for complete variables and 48/21 for repair ratings, domestic/foreign."
display "PASS: repair-category panels preserve empty foreign groups as N=0 with unavailable means and SDs."
log close summarycheck
