version 17
* Run the complete model collection, then export the same results in longtable.
do examples/stata/grouped_regression.do
use examples/stata/output/grouped_regression.dta, clear
char _dta[pt_table_id] "grouped_regression_multipage"
char _dta[pt_layout] "multipage"
tempfile stage
save `stage'
pt_export using `stage', saving("examples/stata/output/grouped_regression_multipage.tex") replace project(".")
pt_wrapper, table(grouped_regression_multipage)
