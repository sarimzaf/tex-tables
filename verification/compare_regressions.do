version 17
set more off
capture mkdir verification/output
set linesize 120
capture log close comparison
log using "verification/output/comparison.log", text replace name(comparison)
use "verification/output/direct_results.dta", clear
* Read the delivered results only after independent estimation is finished.
merge 1:1 panel_id column_id using "examples/stata/output/grouped_regression.dta"
assert _merge==3
assert _N==12
drop _merge
assert row_id=="foreign" & row_type=="coef"
generate double delta_b=direct_b-b
generate double delta_se=direct_se-se
generate double delta_p=direct_p-p
generate double delta_mean=direct_mean-control_mean
generate double delta_n=direct_n-n_obs
generate double delta_q=direct_q-q
assert direct_sample==sample_ids
assert family_n==q_family_n & family_n==q_family_total
assert missing(p_ri)
foreach stat in b se p mean n q {
    quietly summarize delta_`stat', meanonly
    display "Maximum absolute difference, `stat': " %24.17g max(abs(r(min)),abs(r(max)))
    assert abs(delta_`stat')<1e-12
}
format direct_b b direct_se se direct_p p direct_q q %20.15g
list panel_id column_id direct_b b delta_b direct_se se delta_se, noobs abbreviate(24) separator(0)
list panel_id column_id direct_p p delta_p direct_q q delta_q, noobs abbreviate(24) separator(0)
list panel_id column_id direct_mean control_mean direct_n n_obs, noobs abbreviate(24) separator(0)
save "verification/output/comparison.dta", replace
export delimited using "verification/output/comparison.csv", replace

* The multipage layout must carry the same statistical values, keyed by model.
preserve
keep panel_id column_id b se p q control_mean n_obs sample_ids
rename (b se p q control_mean n_obs sample_ids) (single_b single_se single_p single_q single_mean single_n single_sample)
merge 1:1 panel_id column_id using "examples/stata/output/grouped_regression_multipage.dta"
assert _merge==3
assert b==single_b & se==single_se & p==single_p & q==single_q
assert control_mean==single_mean & n_obs==single_n & sample_ids==single_sample
restore
display "PASS: all 12 independently estimated models agree within 1e-12; sample IDs and family sizes agree exactly."
display "PASS: standard and multipage saved tables contain identical model statistics."
log close comparison
