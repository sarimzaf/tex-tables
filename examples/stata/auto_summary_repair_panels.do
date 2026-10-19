version 17
* Run from the skill folder. Complete automobile summary-to-TeX workflow.
set more off
run scripts/pt_tables.do
capture mkdir examples/stata/output
sysuse auto, clear
tempfile results stage
tempname h
postfile `h' str12 panel_id int panel_order str80 panel_title ///
    str12 column_id int column_order str100 column_label ///
    str32 row_id int row_order str244 row_label str8 row_type ///
    double(b se p q p_ri value control_mean n_obs summary_n) ///
    int mean_dec str12 value_kind str100 source ///
    str12 group_id int group_order str120 group_label str8 statistic using `results'
local variables "price mpg rep78 headroom trunk weight length turn displacement gear_ratio"
forvalues panel=1/5 {
    local restriction "1"
    local panel_title "Vehicle characteristics by origin"
    if `panel'>0 {
        local restriction "rep78==`panel'"
        local panel_title "Repair record category `panel' (1978)"
    }
    forvalues g=0/1 {
        local group_label=cond(`g'==0,"Domestic","Foreign")
        local j=0
        foreach outcome of local variables {
            local ++j
            local row_label : variable label `outcome'
            quietly summarize `outcome' if foreign==`g' & (`restriction')
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
                post `h' ("p`panel'") (`panel'+1) ("`panel_title'") ///
                    ("g`g'_s`k'") (`c') ("`group_label': `stat'") ///
                    ("`outcome'") (`j') ("`row_label'") ("scalar") ///
                    (.) (.) (.) (.) (.) (val) (.) (.) (sn) (-1) ("`kind'") ///
                    ("Stata sysuse auto; variable-specific summarize") ///
                    ("g`g'") (`g'+1) ("`group_label'") ("`stat'")
            }
        }
    }
}
postclose `h'
use `results', clear
char _dta[pt_table_id] "auto_summary_repair_panels"
char _dta[pt_kind] "summary"
char _dta[pt_caption] "Car characteristics by repair record"
char _dta[pt_notes] "Stata's 1978 automobile data. Price is in dollars and mileage in miles per gallon. Arithmetic means with sample SDs in parentheses and variable-specific N; no weights or inferential comparisons. Domestic means foreign=0; foreign means foreign=1. Panels use observed rep78 categories 1 through 5; five cars with missing ratings are excluded. Empty origin groups retain N=0 and unavailable means/SDs. Missing observations are excluded separately for each variable and group. Repair record is the stored ordinal 1978 rating; its mean and SD describe the numeric coding. Labels retain the dataset's units: headroom in inches, trunk volume in cubic feet, weight in pounds, length in inches, turning circle in feet, displacement in cubic inches, and gear ratio as a ratio."
char _dta[pt_sample_convention] "Variable-specific available observations"
char _dta[pt_groups] "foreign=0 domestic, then foreign=1 foreign"
char _dta[pt_weights] "none"
char _dta[pt_n_definition] "Number of observed records for each variable within each group and panel"
char _dta[pt_missing_handling] "Exclude missing outcome separately for each variable and group"
char _dta[pt_sample_restrictions] "Restrict panels to rep78 categories 1 through 5; omit five missing ratings"
char _dta[pt_orientation] "portrait"
char _dta[pt_layout] "multipage"
char _dta[pt_row_width_cm] "5.0"
pt_validate
save `stage'
pt_export using `stage', saving("examples/stata/output/auto_summary_repair_panels.tex") replace project(".")
pt_wrapper, table(auto_summary_repair_panels)
