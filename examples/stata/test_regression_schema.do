version 17
* Called by test_native.do; schema-only fixtures are never reported as estimates.
use examples/stata/output/unknown_samples.dta, clear
assert sample_ids==""
pt_validate
* Actual multi-covariate example must validate without any equality rows.
use examples/stata/output/ordinary_regression.dta, clear
assert row_type=="coef" & _N==9
char _dta[pt_contrasts]
pt_validate // Missing mode defaults to optional.
tempfile ordinary
save `ordinary'
foreach outcome in price trunk turn {
    preserve
    sysuse auto, clear
    quietly regress `outcome' i.foreign c.weight c.length, vce(robust)
    foreach term in foreign weight length {
        local coef "`term'"
        if "`term'"=="foreign" local coef "1.foreign"
        scalar expected_b_`term'=_b[`coef']
        scalar expected_se_`term'=_se[`coef']
        scalar expected_p_`term'=2*ttail(e(df_r),abs(_b[`coef']/_se[`coef']))
    }
    restore
    foreach term in foreign weight length {
        assert b==expected_b_`term' & se==expected_se_`term' & abs(p-expected_p_`term')<1e-12 if column_id=="`outcome'" & effect_id=="`term'"
    }
}
* Explicit required mode still rejects a missing comparison set.
char _dta[pt_contrasts] "first_vs_rest"
capture pt_validate
assert _rc!=0
char _dta[pt_contrasts] "typo"
capture pt_validate
assert _rc!=0

* Optional mode permits the real supplied tests or no tests at all.
use examples/stata/output/standard.dta, clear
char _dta[pt_contrasts] "optional"
pt_validate
drop if row_type=="scalar" & column_id!="y1"
pt_validate
drop if row_type=="scalar"
pt_validate
* Supplied tests remain checked, including reversed duplicate pairs.
foreach fault in self unknown duplicate reverse {
    use examples/stata/output/standard.dta, clear
    char _dta[pt_contrasts] "optional"
    if "`fault'"=="self" replace test_rhs=test_lhs if row_type=="scalar"
    if "`fault'"=="unknown" replace test_rhs="missing_effect" if row_type=="scalar"
    if inlist("`fault'","duplicate","reverse") {
        expand 2 if row_type=="scalar"
        bysort panel_id column_id row_id: generate byte copied=_n==2
        replace row_id="second_test" if copied
        replace row_order=2000 if copied
        if "`fault'"=="reverse" {
            replace test_lhs="arm2" if copied
            replace test_rhs="arm1" if copied
        }
    }
    capture pt_validate
    assert _rc!=0
}

* Large exact membership: beyond fixed-width fields and default macro limits.
clear
set obs 200000
generate long observation_id=_n
generate double x=mod(_n,97)
generate double y=.3*x+sin(_n)
replace y=. if mod(_n,10)==0
tempfile large_samples reordered changed
quietly regress y x
scalar expected_n=e(N)
scalar expected_coef=_b[x]
pt_sample using `large_samples', id(observation_id) panel("ordinary") column("price")
assert e(N)==expected_n & _b[x]==expected_coef
count if e(sample)
assert r(N)==expected_n
gsort -observation_id
pt_sample using `reordered', id(observation_id) panel("ordinary") column("price")
* Duplicate model keys are rejected without overwriting the saved membership.
capture pt_sample using `large_samples', id(observation_id) panel("ordinary") column("price")
assert _rc!=0
* Different ID set, same N, must remain different evidence.
replace observation_id=200001 if observation_id==1
pt_sample using `changed', id(observation_id) panel("ordinary") column("price")
* Invalid IDs must be rejected, even with no fixed-width field involved.
foreach fault in duplicate missing fraction unsafe_integer {
    preserve
    if "`fault'"=="duplicate" replace observation_id=2 if observation_id==3
    if "`fault'"=="missing" replace observation_id=. if observation_id==3
    if "`fault'"=="fraction" {
        recast double observation_id
        replace observation_id=3.5 if observation_id==3
    }
    if "`fault'"=="unsafe_integer" {
        recast double observation_id
        replace observation_id=2^53 if observation_id==3
    }
    capture pt_sample using `reordered', id(observation_id) panel("other") column("price")
    assert _rc!=0
    restore
}
use `large_samples', clear
assert strlen(sample_ids)>1000000
assert wordcount(sample_ids)==180000
assert substr(sample_ids,1,17)=="1 2 3 4 5 6 7 8 9"
assert substr(sample_ids,-6,6)=="199999"
mata: expected_ids=1::200000; expected_ids=select(expected_ids,mod(expected_ids,10):!=0)
mata: assert(all(strtoreal(tokens(st_sdata(1,"sample_ids")))':==expected_ids))
cf sample_ids using `reordered'
rename sample_ids original_ids
merge 1:1 panel_id column_id using `changed', assert(match) nogen
assert original_ids!=sample_ids & wordcount(original_ids)==wordcount(sample_ids)
use `ordinary', clear
keep if column_id=="price"
drop sample_ids
merge m:1 panel_id column_id using `large_samples', assert(match) nogen
replace n_obs=180000
* Restrict the q family honestly for this schema-only fixture.
replace q=.
char _dta[pt_q_method]
pt_validate
tempfile large_roundtrip
save `large_roundtrip'
use `large_roundtrip', clear
pt_validate
assert strlen(sample_ids)>1000000 & wordcount(sample_ids)==180000
replace sample_ids=substr(sample_ids,1,2045)
capture pt_validate
assert _rc!=0
display "PASS: ordinary covariates, optional/required contrasts, and large exact sample membership."
