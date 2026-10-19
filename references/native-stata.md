# Native Stata workflow and results schema (version 2.4.0)

All statistical computation, validation, numerical formatting and TeX generation
run in Stata/Mata. No Python installation or Stata `python` integration is needed.
Run from the skill folder, or adapt relative helper/data/output paths to the
project. `examples/stata/NAME.do` is the complete workflow for table NAME; shared
`data.do` creates explicitly synthetic demonstration data; the grouped regression
examples use Stata's bundled `sysuse auto` data. Regression workflows
contain `regress`, `lincom`, control-mean extraction, result posting, q-adjustment,
validation, save and export. Summary files contain `summarize`, variable-specific
counts, posting and export. Statistical procedures are not hidden in Python.

## Commands

```stata
adopath ++ scripts
run scripts/pt_tables.do
* Estimate and post unrounded cells/provenance, then set dataset characteristics.
pt_adjust                         // COMPLETE intended regression families
pt_validate
tempfile stage
save `stage'
pt_export using `stage', saving("results/table.tex") replace project(".")
```

`pt_adjust` uses bundled `fdr_sharpened_qvalues.ado` at .001 resolution,
conventional p-values, and `panel_id` by `effect_id` families, independently of
display-row IDs. Use
`pt_adjust, family(planned_family)` for an explicitly specified string family
variable. Record its scientific definition in notes and
`char _dta[pt_q_family_definition]`. Adjust before display filtering.
`display=0` hides cells without removing hypotheses. Recompute if families change.
The identified ado uses integer ranks, so more than 32,740 nonmissing tests per
family are rejected. Other adjustment sources/methods need an explicit adapter.

`pt_export` requires `.tex`, distinct input and companion paths, and `replace`
for existing output. Stata tempfiles may end in `.tmp`; their contents must be
DTA format. Do not alias source and destination through symlinks/filesystem aliases.
The exporter validates and saves temporary results, reopens them, renders temporary
TeX, then copies that exact DTA to the matching destination. It never renders from
an unrelated in-memory estimation result. Create the output directory first.

Existing incomplete pairs are rejected. If `project()/archive` or
`project()/_archive` exists, old pairs receive unique timestamp-and-sequence names
there. New outputs are prepared first. Ordinary copy failures restore backups;
persistent `.recovery` copies are written on failure. Simultaneous writers and
power loss are outside the guarantee.

## One record per logical cell

One DTA represents one table: dataset characteristic `pt_table_id`. Unique key:
`panel_id column_id row_id`. IDs are stable strings, separate from labels/order.
Duplicate/conflicting cells are errors, never averaged.

| Fields | Meaning |
|---|---|
| `panel_id panel_order panel_title` | Panel identity, numeric order, heading |
| `column_id column_order column_label` | Model/statistic identity, order, heading |
| `row_id row_order row_label row_type` | Effect/variable identity, order, label; `coef` or `scalar` |
| `b se p q p_ri` | Unrounded coefficient/inference; missing for scalar cells |
| `value` | Unrounded scalar; missing for coefficient cells |
| `value_kind` | `number`, `probability`, or `count` |
| `control_mean n_obs mean_dec source` | Model metadata; `mean_dec=-1` for adaptive precision |
| `display` | Optional 0/1, default 1; never shrinks q families |
| `panel_title_raw column_label_raw row_label_raw` | Optional 0/1, default 0; deliberate raw TeX when 1 |

Use `double` for estimated statistics. Missing includes `.` through `.z`.
Probabilities are missing or [0,1], SEs missing or nonnegative, counts missing or
nonnegative integers. No q>=p constraint exists. Panel titles/order, within-panel
column label/order/source/control mean/N/mean precision, and within-panel row
label/order/type must be consistent. Display positions uniquely identify IDs.
Missing existing cells show `--`; absent cells are blank. Collectors must inspect
omitted/failed estimates and leave them missing, never estimated zero.

Regression columns also contain `outcome_id outcome_definition time estimator
controls fixed_effects weights sample_restrictions se_method control_group
control_sample sample_ids sample_namespace`, consistent within panel/model.
Describe absent controls/weights as `none`, not blanks. The example collector
supports unweighted OLS; other estimators/weights require appropriate extraction,
reference distributions and weighted mean/count conventions. Never silently
substitute unweighted calculations.

Regression rows include `effect_id test_lhs test_rhs test_method`. For coefficient
rows, `effect_id` is a stable coefficient identity (ordinary covariate or treatment);
test fields are empty. Repeated layout copies retain that effect ID. Equality tests
are optional by default: omit `pt_contrasts` or set it to `optional` to permit zero
tests or a planned subset. Do not infer hypotheses from the number of displayed
covariates. See [ordinary_regression.do](../examples/stata/ordinary_regression.do).

For treatment analyses that require all first-arm comparisons, explicitly set
`char _dta[pt_contrasts] "first_vs_rest"`. Each model then requires exactly T-1
scalar probability cells, comparing the first effect by row order with every other
effect. The treatment examples opt into this mode. Existing saved tables without
this characteristic now use optional mode; set it explicitly when migrating an
older table whose scientific design requires complete comparisons.

Every supplied comparison, in either mode, must identify two distinct effects
present in that model through `test_lhs` and `test_rhs`, and record its actual
estimator-supported `test_method`. Duplicate unordered pairs (including reversed
pairs) and invalid references are rejected. Store the p-value in `value`, with
`b se p q p_ri` missing. These rows render after all coefficients and before the
control mean. `pt_adjust` excludes them from coefficient outcome families.
Individual coefficient p-values stay saved for inference, without display rows.

`sample_ids` is a strL containing sorted unique integer observation IDs actually
extracted from `e(sample)`; `sample_namespace` identifies the original observation
universe. Use the native collector immediately after estimating each model:

```stata
tempfile samples results
* In the estimation loop, with the original analysis data still loaded:
regress y x
pt_sample using `samples', id(observation_id) panel("p1") column("m1")
* Post numerical results, without a sample_ids field, to `results'.
* After postclose:
use `results', clear
merge m:1 panel_id column_id using `samples', assert(match) nogen
generate str80 sample_namespace="my-common-observation-universe"
```

`pt_sample` creates or appends one row per panel/model in the membership DTA. It
preserves the analysis data and estimation results. Duplicate model keys fail;
`replace` explicitly starts a new membership file. ID lists are constructed and
stored directly in Mata/strL, without `levelsof`, macro expansion, or `postfile`
strings. Thus neither the 2,045-character fixed-string limit nor Stata's macro
length limits bound collection. The complete membership is embedded in the final
companion DTA; the temporary file is not an external runtime dependency.

IDs must be nonmissing, unique integers within e(sample), with absolute value at
most 2^53-1. For household panels use a unique household-wave observation ID, not
the repeated household ID. String/composite IDs need one verified shared numeric
mapping before estimation; never independently renumber samples. Empty evidence
still forces panel-specific N. Equal N alone never establishes equality. Validation
checks sorted uniqueness and agreement with unweighted N, but analysts must extract
the correct sample. Storage remains bounded by available memory and Stata's strL
capacity; the bundled stress test covers 180,000 selected IDs from 200,000 records,
not an unlimited dataset size. Never truncate evidence to fit a macro or field.

`pt_adjust` adds `q_source q_family q_family_n q_family_total`: source p, family ID,
nonmissing count and total records. Validation compares sources, membership counts
and recomputed BKY values across complete saved families. These checks catch stale
or deleted tests but cannot establish the analyst's intended scientific universe.

## Regression column groups

Optional string fields `header1_id header1_label` define the top group tier;
`header2_id header2_label` define a second tier beneath it. Optional numeric
`header1_label_raw header2_label_raw` are 0/1, default 0, for deliberate raw TeX.
Omitted fields default to empty strings/zero and retain the ordinary flat header.
Keep `column_label` for the lowest tier, such as specification or follow-up time.

For repeated outcome columns, use header1 for outcome and column_label for the
specification/time. For categories spanning several outcomes, use header1 for
category, header2 for outcome, then column_label for specification/time. A category
above distinct outcomes needs only header1, with outcomes in column_label.
These are presentation identities, separate from `outcome_id` and model identity;
never infer a group from equal labels or change the hypothesis family to fit it.

Each group ID must occupy contiguous columns in the saved column order, with
one consistent label/raw flag per panel. Metadata must be consistent across all
rows of a model. A second-tier group belongs to exactly one nonempty first-tier
group. Group IDs may differ across panels. Empty ID/label pairs leave individual
columns ungrouped; a singleton group is allowed. Validation rejects conflicting,
disjoint or crossing groups before rendering. Display filtering reduces spans
to visible columns without changing saved groups or adjustment families.

The renderer centers and wraps each label over its actual span and adds a
`\cmidrule(lr)` below it. Identical full header hierarchies can be shared across
panels; a change in tier IDs, labels or raw flags forces panel-specific headings.
Verified common N is decided separately. Longtable continuation headers repeat
all tiers, specification labels and panel context. See
[grouped_regression.do](../examples/stata/grouped_regression.do) and its
[multipage variant](../examples/stata/grouped_regression_multipage.do).

## Summary cells

Additional fields: `group_id group_order group_label statistic summary_n`.
`statistic` is `n`, `mean` or `sd`, with a distinct saved column for each statistic.
`summary_n` is each variable/group's available count, consistent across its cells.
N matches its scalar count; SD is nonnegative. Each group displays mean with (SD)
below and adjacent N, under one centered heading spanning the two columns.
The second header tier is Mean (SD), N; group labels are not repeated there.
There is no common N footer. Additional requested statistics
require an explicit collector/renderer extension. Do not disguise another
statistic as mean/SD. Comparisons are absent unless specified and implemented.

## Dataset characteristics

Use `char _dta[pt_NAME] "..."`; inspect with `char list`. Characteristics are saved
inside the DTA. Required: `table_id kind caption notes`, where kind is `regression`
or `summary`. Plain-text notes combine with generated star/delimiter explanations
in one item. `notes_raw=1` and `caption_raw=1` separately enable deliberate raw TeX.
Never pre-escape plain text. Raw citations require the manuscript's bibliography.
Stata expands macros in source strings; construct literal dollar signs with
`char(36)` or read literal text safely from a file.

Required summary characteristics: `sample_convention groups weights n_definition
missing_handling sample_restrictions`. Defaults are variable-specific available
observations; weighted N conventions must be explicit.

Nonmissing RI requires characteristics `pt_ri_implementation`, `pt_ri_version`,
`pt_ri_assignment_variable`, `pt_ri_assignment_unit`, `pt_ri_restrictions`,
`pt_ri_null`, `pt_ri_statistic`, `pt_ri_tail`, `pt_ri_repetitions`, `pt_ri_seed`,
`pt_ri_ties`, `pt_ri_mc_formula`. These describe the table; varying procedures need
model/effect-specific additional variables, notes and adapted validation. The
renderer never runs RI itself.

Optional characteristics: `stars` (`p`, `q`, `p_ri`, `none`), `label` (safe LaTeX
reference label), `share_headings`/`share_n` (0 disables sharing), `layout`
(`multipage`, `standard`, otherwise auto), `orientation` (`landscape`/`portrait`),
`row_width_cm` (3.2), `data_width_cm` (2.1), `portrait_width_cm` (16),
`landscape_width_cm` (23), `small_table_width_fraction` (.85 for 2–3 columns),
`page_lines` (48 portrait, 32 landscape). Set widths for the actual document.
Pagination is heuristic: compile and inspect every page.

This is the current saved-results schema. There is no external JSON metadata
file: model provenance is in columns and table metadata in dataset characteristics.
