version 17
clear all
set more off
capture log close
log using examples/stata/output/test_native.log, text replace
capture erase examples/stata/output/TEST_PASS.txt
adopath ++ scripts
run scripts/pt_tables.do
* Formatting uses original magnitudes, extended missing, and strict p cutoffs.
mata: assert(pt_fmt(.99996,"number",-1)=="1.000")
mata: assert(pt_fmt(99.9996,"number",-1)=="100.00")
mata: assert(pt_fmt(100,"number",-1)=="100.0")
mata: assert(pt_fmt(6179.25,"number",-1)=="6179.3")
mata: assert(pt_fmt(-6179.25,"number",-1)=="-6179.3")
mata: assert(pt_fmt(-.00001,"number",-1)=="0.000")
mata: assert(pt_fmt(.a,"number",-1)==char(92)+"mbox{-{}-}")
mata: assert(pt_fmt(.z,"number",-1)==char(92)+"mbox{-{}-}")
mata: assert(pt_fmt(1,"probability",-1)=="1.000")
mata: assert(pt_fmt(120,"count",-1)=="120")
mata: assert(pt_stars(.10)=="")
mata: assert(pt_stars(.05)=="*")
mata: assert(pt_stars(.01)=="**")
mata: assert(pt_stars(.009999)=="***")
mata: assert(pt_stars(.a)=="")
mata: assert(pt_escape("a_&%"+char(36))=="a"+char(92)+"_"+char(92)+"&"+char(92)+"%"+char(92)+char(36))
* Re-estimate directly in Stata; no retired pipeline or frozen DTA dependency.
tempfile original stage
use examples/stata/output/standard.dta, clear
sort panel_id column_id row_id
save `original'
forvalues j=1/3 {
    forvalues t=1/2 {
        preserve
        do examples/stata/data.do
        quietly regress y`j' i.arm, vce(robust)
        scalar expected_n=e(N)
        generate byte sample=e(sample)
        quietly lincom `t'.arm
        scalar expected_b=r(estimate)
        scalar expected_se=r(se)
        scalar expected_p=r(p)
        quietly summarize y`j' if sample & arm==0, meanonly
        scalar expected_mean=r(mean)
        restore
        assert b==expected_b & se==expected_se & p==expected_p if column_id=="y`j'" & row_id=="arm`t'"
        assert n_obs==expected_n & control_mean==expected_mean if column_id=="y`j'"
    }
}
* Independently compare the Mata validator with the identified Stata ado.
clear
input double p
0
.001
.01
.01
.4
.8
1
.a
.z
end
fdr_sharpened_qvalues p, generate(q_reference)
mata: expected_q=pt_bky(st_data(.,"p")); reference_q=st_data(.,"q_reference")
mata: assert(all(missing(expected_q):==missing(reference_q)))
mata: valid_q=selectindex(expected_q:<.); assert(all(abs(expected_q[valid_q]-reference_q[valid_q]):<1e-12))
use examples/stata/output/summary.dta, clear
forvalues g=0/2 {
    forvalues j=1/3 {
        preserve
        do examples/stata/data.do
        quietly summarize y`j' if arm==`g'
        scalar expected_n=r(N)
        scalar expected_mean=r(mean)
        scalar expected_sd=r(sd)
        restore
        assert summary_n==expected_n if group_id=="g`g'" & row_id=="y`j'"
        assert value==expected_n if group_id=="g`g'" & row_id=="y`j'" & statistic=="n"
        assert value==expected_mean if group_id=="g`g'" & row_id=="y`j'" & statistic=="mean"
        assert value==expected_sd if group_id=="g`g'" & row_id=="y`j'" & statistic=="sd"
    }
}
assert summary_n==27 if group_id=="g0" & row_id=="y2"
assert summary_n==40 if group_id=="g0" & row_id=="y1"

* Reject duplicate cells, invalid values, inconsistent metadata, changed families.
* Single-effect models legitimately have no scalar equality-test rows.
use `original', clear
keep if row_id=="arm1"
pt_adjust
pt_validate
mata: assert(rows(pt_select((1::st_nobs()),"row_type","scalar"))==0)
mata: assert(cols(pt_select((1::st_nobs()),"row_type","scalar"))==1)
mata: assert(rows(pt_unique(J(0,1,.),"row_id","row_order"))==0)
mata: assert(rows(pt_body((1::st_nobs()),3,1))>0)
foreach fault in duplicate negative_se bad_probability count column row panel position missing_family changed_source bad_sample {
    use `original', clear
    if "`fault'"=="duplicate" expand 2
    if "`fault'"=="negative_se" replace se=-1 in 1
    if "`fault'"=="bad_probability" replace p=1.01 in 1
    if "`fault'"=="count" replace n_obs=120.5 in 1
    if "`fault'"=="column" replace column_label="conflict" in 1
    if "`fault'"=="row" replace row_label="conflict" in 1
    if "`fault'"=="panel" replace panel_title="conflict" in 1
    if "`fault'"=="position" replace column_order=1
    if "`fault'"=="missing_family" drop in 1
    if "`fault'"=="changed_source" replace p=p/2 in 1
    if "`fault'"=="bad_sample" replace sample_ids="1 2 3" in 1
    capture pt_validate
    assert _rc!=0
}
use `original', clear
replace display=0 in 1
pt_validate // Hiding a hypothesis does not alter its adjustment family.
use `original', clear
replace q=. in 1
capture pt_validate
assert _rc!=0
* All-missing inference can be stored explicitly if it was never calculated.
use `original', clear
replace q=.
char _dta[pt_q_method]
pt_validate
mata: assert(pt_cell(.,"b")=="")
replace b=.a in 1
pt_validate
mata: assert(pt_cell(1,"b")==char(92)+"mbox{-{}-}")

* Missing source p-values stay missing and are excluded from family size.
use `original', clear
replace p=.a in 1
pt_adjust
pt_validate
assert missing(q) if missing(p)
assert q_family_n==2 if effect_id=="arm1"
* Display-row identity does not split a treatment effect's outcome family.
use `original', clear
keep if effect_id=="arm1"
replace row_id="arm1_separate_row" if column_id=="y3"
replace row_order=3 if column_id=="y3"
pt_adjust
pt_validate
assert q_family_n==3 & q_family_total==3
* Equality rows must match actual model-based tests, including covariance.
use `original', clear
forvalues j=1/3 {
    preserve
    do examples/stata/data.do
    quietly regress y`j' i.arm, vce(robust)
    quietly test 1.arm=2.arm
    scalar expected_equality=r(p)
    quietly lincom 1.arm-2.arm
    assert abs(r(p)-expected_equality)<1e-12
    restore
    assert value==expected_equality if column_id=="y`j'" & row_type=="scalar"
}
drop if row_type=="scalar"
capture pt_validate
assert _rc!=0 // Multi-treatment tables require the pairwise equality rows.
* Schema-only three-treatment fixture: copied numbers are NOT new estimates.
* Never export this fixture; verify that BOTH 1=2 and 1=3 cells are required.
use `original', clear
expand 2 if inlist(row_id,"arm2","eq1_2")
bysort panel_id column_id row_id: generate byte duplicate=_n==2
replace effect_id="arm3" if duplicate & row_type=="coef"
replace row_order=3 if duplicate & row_type=="coef"
replace row_label="Treatment arm 3" if duplicate & row_type=="coef"
replace test_rhs="arm3" if duplicate & row_type=="scalar"
replace row_order=1003 if duplicate & row_type=="scalar"
replace row_label="p-value: Treatment 1 = Treatment 3" if duplicate & row_type=="scalar"
replace row_id=cond(row_type=="coef","arm3","eq1_3") if duplicate
pt_adjust
pt_validate
drop if row_id=="eq1_3"
capture pt_validate
assert _rc!=0
* Reconcile the grouped real-data example against independent model estimates.
use examples/stata/output/grouped_regression.dta, clear
tempfile grouped
save `grouped'
forvalues panel=1/2 {
    foreach outcome in price mpg trunk {
        foreach spec in unadjusted adjusted {
            preserve
            sysuse auto, clear
            local rhs ""
            local vce ""
            if "`spec'"=="adjusted" local rhs "weight"
            if `panel'==2 local vce ", vce(robust)"
            quietly regress `outcome' i.foreign `rhs' `vce'
            scalar expected_b=_b[1.foreign]
            scalar expected_se=_se[1.foreign]
            scalar expected_p=2*ttail(e(df_r),abs(expected_b/expected_se))
            scalar expected_n=e(N)
            quietly summarize `outcome' if e(sample) & foreign==0, meanonly
            scalar expected_mean=r(mean)
            restore
            assert b==expected_b & se==expected_se & abs(p-expected_p)<1e-12 & n_obs==expected_n & control_mean==expected_mean if panel_id=="p`panel'" & column_id=="`outcome'_`spec'"
        }
    }
}
assert q_family_n==3 & q_family_total==3
foreach fault in disjoint inconsistent crossing orphan {
    use `grouped', clear
    if "`fault'"=="disjoint" replace column_order=cond(column_order==2,5,cond(column_order==5,2,column_order))
    if "`fault'"=="inconsistent" replace header1_label="Conflicting label" if column_order==2
    if "`fault'"=="crossing" {
        replace header2_id="price" if column_order==3
        replace header2_label="Price (USD)" if column_order==3
    }
    if "`fault'"=="orphan" {
        replace header1_id="" if column_order<=2
        replace header1_label="" if column_order<=2
    }
    capture pt_validate
    assert _rc!=0
}
* A single outcome tier, singleton spans, and hidden columns are supported.
use `grouped', clear
replace header1_id=header2_id
replace header1_label=header2_label
replace header2_id=""
replace header2_label=""
replace display=0 if column_order==2
pt_validate
mata: assert(rows(pt_head(selectindex(st_data(.,"display"):==1),5,1,1))>0)
* Export rejects wrong extension, same source/companion, implicit replacement.
capture mkdir examples/stata/output/test_artifacts
capture mkdir examples/stata/output/test_artifacts/archive
* Changed panel headings repeat independently of a verified common N.
use `grouped', clear
replace header1_label="Vehicle dimensions" if panel_id=="p2" & header1_id=="characteristics"
tempfile headerstage
save `headerstage'
pt_export using `headerstage', saving("examples/stata/output/test_artifacts/header_sharing.tex") replace project("examples/stata/output/test_artifacts")
tempname headercheck
file open `headercheck' using examples/stata/output/test_artifacts/header_sharing.tex, read text
local nrows=0
local headingrows=0
file read `headercheck' line
while r(eof)==0 {
    if substr(`"`line'"',1,3)=="N &" local ++nrows
    if strpos(`"`line'"',"Market value") local ++headingrows
    file read `headercheck' line
}
file close `headercheck'
assert `nrows'==1 & `headingrows'==2
use `original', clear
save `stage'
capture pt_export using `stage', saving("examples/stata/output/test_artifacts/bad.txt")
assert _rc!=0
capture pt_export using "examples/stata/output/standard.dta", saving("examples/stata/output/standard.tex") replace
assert _rc!=0
pt_export using `stage', saving("examples/stata/output/test_artifacts/test.tex") replace project("examples/stata/output/test_artifacts")
capture pt_export using `stage', saving("examples/stata/output/test_artifacts/test.tex")
assert _rc==602
pt_export using `stage', saving("examples/stata/output/test_artifacts/test.tex") replace project("examples/stata/output/test_artifacts")
pt_export using `stage', saving("examples/stata/output/test_artifacts/test.tex") replace project("examples/stata/output/test_artifacts")
local archives : dir "examples/stata/output/test_artifacts/archive" files "*.dta"
local n : word count `archives'
assert `n'>=2
use examples/stata/output/test_artifacts/test.dta, clear
sort panel_id column_id row_id
cf b se p q control_mean n_obs using `original', all
do examples/stata/test_regression_schema.do
file open status using examples/stata/output/TEST_PASS.txt, write text replace
file write status "PASS: native formatting, statistical reconciliation, schema and family rejection, export and archival checks." _n
file close status
log close
