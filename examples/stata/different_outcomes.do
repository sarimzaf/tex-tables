version 17
* Complete native Stata workflow. Run from the skill folder:
* do examples/stata/different_outcomes.do
set more off
adopath ++ scripts
run scripts/pt_tables.do
do examples/stata/data.do
capture mkdir examples/stata/output
tempfile analysis results stage samples
save `analysis'
tempname h
postfile `h' str12 panel_id int panel_order str80 panel_title ///
    str12 column_id int column_order str100 column_label ///
    str32 row_id int row_order str100 row_label str8 row_type ///
    double(b se p q p_ri value control_mean n_obs) ///
    int mean_dec str12 value_kind str80 source ///
    using `results'
foreach s in 1 2 {
    forvalues j=1/3 {
        if `s'==2 & `j'!=3 continue
        use `analysis', clear
        local rhs ""
        if `s'==2 local rhs "x"
        if `s'==3 local rhs "xmiss"
        quietly regress y`j' i.arm `rhs', vce(robust)
        scalar model_n=e(N)
        generate byte estimation_sample=e(sample)
        * Collect exact sample IDs directly into strL; no fixed-width or macro bottleneck.
        pt_sample using `samples', id(id) panel("s`s'") column("y`j'")

        quietly summarize y`j' if estimation_sample & arm==0, meanonly
        scalar model_mean=r(mean)
        tempname omitted
        _ms_omit_info e(b)
        matrix `omitted'=r(omit)
        forvalues t=1/2 {
            local k=colnumb(e(b),"`t'.arm")
            assert !missing(`k')
            assert `omitted'[1,`k']==0
            quietly lincom `t'.arm
            assert !missing(r(estimate),r(se),r(p))
            assert abs(r(p)-2*ttail(e(df_r),abs(r(estimate)/r(se))))<1e-12
            post `h' ("s`s'") (`s') ("Panel `s': Specification `s'") ///
                ("y`j'") (`j') ("Synthetic endline outcome `j'") ///
                ("arm`t'") (`t') ("Treatment arm `t'") ("coef") ///
                (r(estimate)) (r(se)) (r(p)) (.) (.) (.) ///
                (model_mean) (model_n) (-1) ("number") ///
                ("Synthetic Stata example, seed 20261018")
        }
        * Equality tests use the fitted model's joint covariance and F reference.
        * Extend this loop through the number of non-control treatment arms.
        forvalues t=2/2 {
            quietly test 1.arm = `t'.arm
            scalar equality_p=r(p)
            assert !missing(equality_p)
            post `h' ("s`s'") (`s') ("Panel `s': Specification `s'") ///
                ("y`j'") (`j') ("Synthetic endline outcome `j'") ///
                ("eq1_`t'") (1000+`t') ("p-value: Treatment 1 = Treatment `t'") ("scalar") ///
                (.) (.) (.) (.) (.) (equality_p) ///
                (model_mean) (model_n) (-1) ("probability") ///
                ("Synthetic Stata example, seed 20261018")
        }
    }
}
postclose `h'
use `results', clear
merge m:1 panel_id column_id using `samples', assert(match) nogen
generate str12 effect_id=cond(row_type=="coef",row_id,"")
generate str12 test_lhs=cond(row_type=="scalar","arm1","")
generate str12 test_rhs=cond(row_type=="scalar","arm"+substr(row_id,5,.),"")
generate str100 test_method=cond(row_type=="scalar","Stata test: equality of coefficients, robust Wald F using model residual df","")
generate str40 sample_namespace="synthetic-20261018-v1"
generate str12 outcome_id=column_id
generate str244 outcome_definition=""
replace outcome_definition=".2*(arm==1)+.5*(arm==2)+.2*x+normal noise" if column_id=="y1"
replace outcome_definition="40+2*(arm==1)+3*(arm==2)+4*x+8*normal noise; missing at id multiples of 9" if column_id=="y2"
replace outcome_definition="200+80*(arm==1)+110*(arm==2)+20*x+50*normal noise" if column_id=="y3"
generate str12 time="endline"
generate str80 estimator="Stata regress OLS; lincom finite-df t inference"
generate str12 controls=cond(panel_id=="s1","none",cond(panel_id=="s2","x","xmiss"))
generate str12 fixed_effects="none"
generate str12 weights="none"
generate str100 sample_restrictions="Nonmissing model outcome and regressors"
generate str80 se_method="Heteroskedasticity-robust: vce(robust)"
generate str40 control_group="arm==0"
generate str100 control_sample="Endline outcome among arm==0 within corresponding e(sample)"
char _dta[pt_table_id] "different_outcomes"
char _dta[pt_kind] "regression"
char _dta[pt_contrasts] "first_vs_rest"
char _dta[pt_caption] "Synthetic treatment-effect demonstration"
char _dta[pt_notes] "Synthetic examples, not empirical findings. Outcome definitions and data generation are in examples/stata/data.do. OLS with heteroskedasticity-robust standard errors; specification 1 has no additional controls; specification 2 controls for x. No fixed effects or weights. Sharpened q-values use Anderson (2008) and BKY (2006), conventional p-values, a .001 grid and a complete outcome family for each panel and treatment effect. No RI was run. Control means use arm=0 at endline in each model's estimation sample; missing model variables are excluded model by model."
local notes : char _dta[pt_notes]
char _dta[pt_notes] "`notes' Equality-test rows report unadjusted robust Wald F p-values for treatment 1 versus each other treatment, using the model covariance and residual degrees of freedom."
* Compute adjustment BEFORE any display filtering or layout copies.
pt_adjust

pt_validate
save `stage'
pt_export using `stage', saving("examples/stata/output/different_outcomes.tex") replace project(".")
pt_wrapper, table(different_outcomes)
