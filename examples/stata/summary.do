version 17
* Complete native Stata workflow. Run from the skill folder:
* do examples/stata/summary.do
set more off
run scripts/pt_tables.do
do examples/stata/data.do
capture mkdir examples/stata/output
tempfile analysis results stage
save `analysis'
tempname h
postfile `h' str12 panel_id int panel_order str80 panel_title ///
    str12 column_id int column_order str100 column_label ///
    str32 row_id int row_order str244 row_label str8 row_type ///
    double(b se p q p_ri value control_mean n_obs summary_n) ///
    int mean_dec str12 value_kind str100 source ///
    str12 group_id int group_order str120 group_label str8 statistic using `results'
forvalues g=0/2 {
    forvalues j=1/3 {
        quietly summarize y`j' if arm==`g'
        scalar sn=r(N)
        scalar sm=r(mean)
        scalar ss=r(sd)
        forvalues k=1/3 {
            local stat "n"
            local kind "count"
            scalar val=sn
            if `k'==2 {
                local stat "mean"
                local kind "number"
                scalar val=sm
            }
            if `k'==3 {
                local stat "sd"
                local kind "number"
                scalar val=ss
            }
            local c=`g'*3+`k'
            post `h' ("summary") (1) ("Summary by assigned group") ///
                ("g`g'_s`k'") (`c') ("Group `g': `stat'") ///
                ("y`j'") (`j') ("Endline outcome `j'") ("scalar") ///
                (.) (.) (.) (.) (.) (val) (.) (.) (sn) (-1) ("`kind'") ///
                ("Synthetic Stata summarize; variable-specific available observations") ///
                ("g`g'") (`g'+1) ("Group `g'") ("`stat'")
        }
    }
}
postclose `h'
use `results', clear
char _dta[pt_table_id] "summary"
char _dta[pt_kind] "summary"
char _dta[pt_caption] "Summary statistics with variable-specific N"
char _dta[pt_notes] "Synthetic endline outcomes defined in examples/stata/data.do; arm 0 is control. Unweighted N, arithmetic mean and sample SD from Stata summarize. Counts are variable-specific available observations; y2 has missing values. No inferential comparisons."
char _dta[pt_sample_convention] "variable-specific available observations"
char _dta[pt_groups] "arm 0, 1, 2 in that order"
char _dta[pt_weights] "none"
char _dta[pt_n_definition] "Unweighted nonmissing observed records per variable and group"
char _dta[pt_missing_handling] "Exclude missing outcome separately for each variable and group"
char _dta[pt_sample_restrictions] "none"

pt_validate
save `stage'
pt_export using `stage', saving("examples/stata/output/summary.tex") replace project(".")
pt_wrapper, table(summary)
