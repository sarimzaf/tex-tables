version 17
* Ordinary covariates with different units: no treatment-arm equality tests.
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
    str12 column_id int column_order str100 column_label ///
    str32 row_id int row_order str100 row_label str8 row_type ///
    double(b se p q p_ri value control_mean n_obs) ///
    int mean_dec str12 value_kind str100 source using `results'
local j=0
foreach outcome in price trunk turn {
    local ++j
    use `analysis', clear
    quietly regress `outcome' i.foreign c.weight c.length, vce(robust)
    scalar model_n=e(N)
    pt_sample using `samples', id(observation_id) panel("ordinary") column("`outcome'")
    quietly summarize `outcome' if e(sample) & foreign==0, meanonly
    scalar model_mean=r(mean)
    local heading : variable label `outcome'
    tempname omitted
    _ms_omit_info e(b)
    matrix `omitted'=r(omit)
    local k=0
    foreach term in 1.foreign weight length {
        local ++k
        local effect : word `k' of foreign weight length
        local label "Foreign origin"
        if `k'==2 local label "Weight (lb.)"
        if `k'==3 local label "Length (inches)"
        assert `omitted'[1,colnumb(e(b),"`term'")]==0
        quietly lincom `term'
        post `h' ("ordinary") (1) ("OLS with heteroskedasticity-robust standard errors") ///
            ("`outcome'") (`j') ("`heading'") ///
            ("`effect'") (`k') ("`label'") ("coef") ///
            (r(estimate)) (r(se)) (r(p)) (.) (.) (.) ///
            (model_mean) (model_n) (-1) ("number") ("Stata sysuse auto; 1978 automobile data")
    }
}
postclose `h'
use `results', clear
merge m:1 panel_id column_id using `samples', assert(match) nogen
generate str32 effect_id=row_id
foreach field in test_lhs test_rhs test_method {
    generate str1 `field'=""
}
generate str80 sample_namespace="stata-auto-original-observation-order"
generate str12 outcome_id=column_id
generate str100 outcome_definition=cond(column_id=="price","Price in USD",cond(column_id=="trunk","Trunk space in cubic feet","Turning circle in feet"))
generate str12 time="1978"
generate str100 estimator="Stata regress OLS; lincom finite-df t inference"
generate str100 controls="foreign origin, weight in pounds, length in inches; all slopes displayed"
generate str12 fixed_effects="none"
generate str12 weights="none"
generate str100 sample_restrictions="Nonmissing outcome, foreign, weight and length"
generate str100 se_method="Heteroskedasticity-robust: vce(robust)"
generate str100 control_group="foreign==0: domestic cars"
generate str100 control_sample="Domestic-car mean in the model estimation sample"
char _dta[pt_table_id] "ordinary_regression"
char _dta[pt_kind] "regression"
char _dta[pt_contrasts] "optional"
char _dta[pt_caption] "Ordinary regression with multiple displayed covariates"
char _dta[pt_notes] "Stata's 1978 automobile data. Each outcome is regressed on foreign origin, weight and length; all slopes are displayed. These covariates are not treatment arms, and no equality tests are requested. Standard errors are heteroskedasticity-robust with finite-df t inference. No weights or fixed effects. Control mean denotes the domestic-car outcome mean within each model's estimation sample. N counts cars. Observational associations, not causal estimates. Anderson/BKY sharpened q-values use the .001 grid across all three outcomes separately for each covariate. RI is inapplicable."
pt_adjust
char _dta[pt_q_family_definition] "All three outcomes separately for each displayed covariate"
pt_validate
save `stage'
pt_export using `stage', saving("examples/stata/output/ordinary_regression.tex") replace project(".")
pt_wrapper, table(ordinary_regression)
