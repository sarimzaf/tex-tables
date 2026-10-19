version 17
clear all
set more off
capture mkdir verification/output
set linesize 120
capture log close _all
log using "verification/output/direct_regressions.log", text replace name(direct)
display "INDEPENDENT DIRECT STATA REGRESSIONS"
display "No publication-table programs or FDR packages are loaded."
about
sysuse auto, clear
generate long observation_id=_n
describe price mpg trunk foreign weight

* Twelve explicit regress commands; all displayed in the text log.
* Panel A: conventional OLS covariance.
regress price i.foreign
estimates store ols_price_basic
regress price i.foreign weight
estimates store ols_price_weight
regress mpg i.foreign
estimates store ols_mpg_basic
regress mpg i.foreign weight
estimates store ols_mpg_weight
regress trunk i.foreign
estimates store ols_trunk_basic
regress trunk i.foreign weight
estimates store ols_trunk_weight

* Panel B: heteroskedasticity-robust covariance.
regress price i.foreign, vce(robust)
estimates store robust_price_basic
regress price i.foreign weight, vce(robust)
estimates store robust_price_weight
regress mpg i.foreign, vce(robust)
estimates store robust_mpg_basic
regress mpg i.foreign weight, vce(robust)
estimates store robust_mpg_weight
regress trunk i.foreign, vce(robust)
estimates store robust_trunk_basic
regress trunk i.foreign weight, vce(robust)
estimates store robust_trunk_weight

* Collect directly from e(b), e(V) and e(sample), without lincom or a helper.
* The log also retains full output for all covariates and intercepts above.
tempname h
postfile `h' str2 panel_id str20 column_id str12 outcome_id str12 specification ///
    double(direct_b direct_se direct_p direct_mean direct_n direct_df direct_r2) ///
    str2045 direct_sample using "verification/output/direct_results.dta", replace
foreach covariance in ols robust {
    local panel=cond("`covariance'"=="ols","p1","p2")
    foreach outcome in price mpg trunk {
        foreach spec in basic weight {
            estimates restore `covariance'_`outcome'_`spec'
            local specification=cond("`spec'"=="basic","unadjusted","adjusted")
            local column "`outcome'_`specification'"
            scalar db=_b[1.foreign]
            scalar ds=_se[1.foreign]
            scalar dp=2*ttail(e(df_r),abs(db/ds))
            scalar dn=e(N)
            scalar df=e(df_r)
            scalar rsq=e(r2)
            quietly summarize `outcome' if e(sample) & foreign==0, meanonly
            scalar dm=r(mean)
            quietly levelsof observation_id if e(sample), local(ids)
            assert strlen("`ids'")<=2045
            post `h' ("`panel'") ("`column'") ("`outcome'") ("`specification'") ///
                (db) (ds) (dp) (dm) (dn) (df) (rsq) ("`ids'")
            display "FULL PRECISION: `panel' / `column'"
            display "Coefficient = " %24.17g db
            display "Standard error = " %24.17g ds
            display "Conventional p = " %24.17g dp
            display "Domestic mean = " %24.17g dm
            display "N = " %12.0f dn "  residual df = " %12.0f df "  R-squared = " %24.17g rsq
            * One parseable record per statistic, independently checked against the log.
            display "DIRECT|`panel'|`column'|b|" %24.17g db
            display "DIRECT|`panel'|`column'|se|" %24.17g ds
            display "DIRECT|`panel'|`column'|p|" %24.17g dp
            display "DIRECT|`panel'|`column'|control_mean|" %24.17g dm
            display "DIRECT|`panel'|`column'|n_obs|" %24.17g dn
        }
    }
}
postclose `h'

* Independent sharpened BKY grid calculation, in ordinary Stata commands.
* Families: each covariance panel x specification, all three outcome tests.
* This is additional calculation, not output returned by regress.
use "verification/output/direct_results.dta", clear
generate double direct_q=1
sort panel_id specification direct_p column_id
by panel_id specification: generate int rank=_n
by panel_id specification: generate int family_n=_N
assert family_n==3
assert !missing(direct_p)
quietly {
    forvalues step=1000(-1)1 {
        scalar level=`step'/1000
        scalar alpha=level/(1+level)
        foreach panel in p1 p2 {
            foreach spec in unadjusted adjusted {
                summarize rank if panel_id=="`panel'" & specification=="`spec'" & direct_p<=alpha*rank/family_n, meanonly
                local first=cond(r(N)==0,0,r(max))
                if `first'==3 {
                    replace direct_q=level if panel_id=="`panel'" & specification=="`spec'"
                }
                else {
                    summarize rank if panel_id=="`panel'" & specification=="`spec'" & direct_p<=alpha*rank/(family_n-`first'), meanonly
                    local second=cond(r(N)==0,0,r(max))
                    replace direct_q=level if panel_id=="`panel'" & specification=="`spec'" & rank<=`second'
                }
            }
        }
    }
}
sort panel_id column_id
isid panel_id column_id
save "verification/output/direct_results.dta", replace
format direct_b direct_se direct_p direct_mean direct_q %20.15g
list panel_id column_id direct_b direct_se direct_p direct_q direct_n, noobs abbreviate(24) separator(0)
display "DIRECT RUN COMPLETE: 12 regressions; four separate three-outcome q families."
log close direct
do "verification/compare_regressions.do"
