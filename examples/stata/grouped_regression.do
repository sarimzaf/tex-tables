version 17
* Complete estimation-to-TeX example using Stata's bundled automobile data.
set more off
adopath ++ scripts
run scripts/pt_tables.do
sysuse auto, clear
generate long observation_id=_n
tempfile analysis results stage samples
save `analysis'
capture mkdir examples/stata/output
tempname h
postfile `h' str12 panel_id int panel_order str80 panel_title ///
    str20 column_id int column_order str100 column_label ///
    str32 row_id int row_order str100 row_label str8 row_type ///
    double(b se p q p_ri value control_mean n_obs) ///
    int mean_dec str12 value_kind str80 source ///
    str12 outcome_id str12 specification using `results'
forvalues panel=1/2 {
    local vce ""
    local title "Panel A: Conventional standard errors"
    if `panel'==2 {
        local vce ", vce(robust)"
        local title "Panel B: Heteroskedasticity-robust standard errors"
    }
    local col=0
    foreach outcome in price mpg trunk {
        foreach spec in unadjusted adjusted {
            use `analysis', clear
            local controls ""
            local subheading "No controls"
            if "`spec'"=="adjusted" {
                local controls "weight"
                local subheading "Weight adjusted"
            }
            quietly regress `outcome' i.foreign `controls' `vce'
            scalar model_n=e(N)
            generate byte estimation_sample=e(sample)
            pt_sample using `samples', id(observation_id) panel("p`panel'") column("`outcome'_`spec'")
            quietly summarize `outcome' if estimation_sample & foreign==0, meanonly
            scalar comparison_mean=r(mean)
            tempname omitted
            _ms_omit_info e(b)
            matrix `omitted'=r(omit)
            assert `omitted'[1,colnumb(e(b),"1.foreign")]==0
            quietly lincom 1.foreign
            assert !missing(r(estimate),r(se),r(p))
            assert abs(r(p)-2*ttail(e(df_r),abs(r(estimate)/r(se))))<1e-12
            local ++col
            post `h' ("p`panel'") (`panel') ("`title'") ///
                ("`outcome'_`spec'") (`col') ("`subheading'") ///
                ("foreign") (1) ("Foreign origin") ("coef") ///
                (r(estimate)) (r(se)) (r(p)) (.) (.) (.) ///
                (comparison_mean) (model_n) (-1) ("number") ///
                ("Stata sysuse auto; 1978 automobile data") ///
                ("`outcome'") ("`spec'")
        }
    }
}
postclose `h'
use `results', clear
merge m:1 panel_id column_id using `samples', assert(match) nogen
generate str12 effect_id="foreign"
foreach field in test_lhs test_rhs test_method {
    generate str1 `field'=""
}
generate str40 sample_namespace="stata-auto-original-observation-order"
generate str100 outcome_definition=cond(outcome_id=="price","Vehicle price in US dollars",cond(outcome_id=="mpg","Mileage in miles per gallon","Trunk space in cubic feet"))
generate str12 time="1978"
generate str80 estimator="Stata regress OLS; lincom finite-df t inference"
generate str12 controls=cond(specification=="adjusted","weight","none")
generate str12 fixed_effects="none"
generate str12 weights="none"
generate str100 sample_restrictions="Available outcome, origin and any included weight covariate"
generate str80 se_method=cond(panel_id=="p1","Conventional OLS covariance","Heteroskedasticity-robust: vce(robust)")
generate str40 control_group="foreign==0: domestic cars"
generate str100 control_sample="1978 outcome among domestic cars within model e(sample)"
* Two explicit tiers: categories, then outcomes. Final labels describe specifications.
generate str20 header1_id=cond(outcome_id=="price","market","characteristics")
generate str80 header1_label=cond(outcome_id=="price","Market value","Vehicle characteristics")
generate str12 header2_id=outcome_id
generate str80 header2_label=cond(outcome_id=="price","Price (USD)",cond(outcome_id=="mpg","Mileage (mpg)","Trunk space (cu. ft.)"))
char _dta[pt_table_id] "grouped_regression"
char _dta[pt_kind] "regression"
char _dta[pt_caption] "Automobile regressions with category and outcome headings"
char _dta[pt_notes] "Stata's 1978 automobile data; observational associations, not causal treatment effects. Price is in US dollars, mileage in miles per gallon and trunk space in cubic feet. Each column regresses its outcome on foreign origin, with vehicle weight (lb.) added in adjusted models. Panels use conventional and heteroskedasticity-robust OLS covariance, respectively, with residual-df t inference. No fixed effects or weights. Sharpened q-values use Anderson (2008) and BKY (2006), conventional p-values and a .001 grid; each panel and specification has a separate complete three-outcome family for the foreign-origin coefficient. RI is not applicable. Control means are domestic-car means in each model's estimation sample at the 1978 observation, not endline. All models use the same 74 cars, verified by observation IDs; N is shown in the final panel. Missing model variables are excluded."
* Prespecified families across all three outcomes, separately by specification.
generate str60 planned_family=panel_id+":"+effect_id+":"+specification
pt_adjust, family(planned_family)
char _dta[pt_q_family_definition] "Panel x foreign-origin effect x specification; all three outcomes"
pt_validate
assert q_family_n==3 & q_family_total==3
save `stage'
pt_export using `stage', saving("examples/stata/output/grouped_regression.tex") replace project(".")
pt_wrapper, table(grouped_regression)
