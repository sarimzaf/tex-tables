---
name: tex-tables
description: Produce reproducible LaTeX regression and summary-statistics tables entirely in Stata/Mata, with validated long-format DTA files, Anderson/BKY q-values, documented randomization inference, and publication layout checks.
---

# tex-tables

Keep the complete estimation-to-TeX workflow in **Stata**. Do not use Python,
R, or a shell bridge to render tables. Provide a runnable `.do` file for each
table alongside its matching `.dta` and `.tex`. Use the bundled native helper.
This folder is portable between Codex and Claude; use project-relative paths.
For a new computer, follow [setup and dependencies](references/verification.md#requirements-and-reproduction).
Stata 17+ is required; LaTeX compilation is a separate document-build step.
User presentation choices override defaults; statistical validity and agreement
with saved results do not. All helpers, schemas and examples referenced below
are included in this skill.

1. Read [native schema and commands](references/native-stata.md). Collect full-precision
   results and model provenance from the analysis, with stable IDs separate from
   labels/order. Start from the complete [regression](examples/stata/standard.do)
   or [summary](examples/stata/summary.do) workflow, adapting the analysis explicitly.
   For ordinary covariates, use [ordinary regression](examples/stata/ordinary_regression.do).
   Collect exact model membership with `pt_sample` into a separate strL DTA and
   merge it into the posted results; never post ID lists into fixed-width strings.
   Reject duplicates, conflicting metadata, omitted estimates disguised as zero,
   and unsupported statistical assumptions.
2. For regression inference, read [inference and metadata](references/inference.md).
   Extract estimator-appropriate p-values. Adjust the complete intended family
   before display filtering. Define outcome families by a common substantive
   domain inferred from outcome definitions and study context: for example,
   GAD, PHQ and PSS belong to a mental-health domain. Panel or table placement
   does not define a family. Distinguish primary composite indices from secondary
   components: calculate component q-values within each domain separately from
   the indices. Define the indices' primary-outcome testing family from the
   analysis plan; do not automatically treat each index as a singleton. Ask before
   adjustment when their roles or the index-family membership are unclear.
   Keep treatment/effect families separate unless the
   analysis plan specifies pooling; document the domain membership and any
   planned time/specification boundaries. Ask when the context is ambiguous.
   Prefer Hess's `ritest` only with a documented assignment design. Ask for
   essential missing design information; keep unavailable RI missing in the data.
3. Save model provenance as columns and table metadata as dataset characteristics.
   Encode outcome roles, planned outcome groups and effects in an explicit string family ID;
   run `pt_adjust, family(planned_family)` on complete regression families,
   record their scientific definition, then run `pt_validate`.
   For summaries use variables as rows and each group name once as a centered
   spanning heading above its Mean (SD) and N columns, with a `\cmidrule` beneath
   the span. Stack SD below mean and preserve each variable-specific count.
   For grouped regression columns, use explicit header tiers for shared outcomes
   or categories; see the [grouped regression workflow](examples/stata/grouped_regression.do).
4. Validate, then export **from the staged DTA**. Export creates a matching
   `.tex`/`.dta` pair. Never overwrite the old companion DTA during collection.
   Use `pt_export using ..., saving(...) replace project(...)` for replacement
   and archival. Do not overwrite the old companion before staging new results.
5. Read [layout and notes](references/layout.md), compile in the target document
   or [wrapper](assets/wrapper.tex), inspect **every page**, and reconcile visible
   values with saved results. Fix and repeat affected checks. If compilation or
   visual inspection is unavailable, explicitly report incomplete verification;
   do not call that output publication-ready.
   Run the [independent Stata checks](references/verification.md#independent-stata-checks)
   as a separate verification step; retain their logs and reconcile variable-specific N.

Run from this skill's folder; each file executes estimation through TeX:

```stata
do examples/stata/standard.do
do examples/stata/summary.do
* All fifteen layouts, native tests, then independent calculations:
do examples/stata/run_all.do
do examples/stata/test_native.do
do verification/run_all.do
```

Default coefficients: coefficient/stars, (SE), [sharpened q], and visible {RI p},
with informative regressor labels. Never add individual coefficient p-value rows;
keep p in the saved data for stars and adjustment. Equality tests are optional
by default; ordinary covariates do not imply treatment-arm comparisons. When a
treatment analysis calls for all first-arm comparisons, set
`char _dta[pt_contrasts] "first_vs_rest"` and include T-1 labeled tests of
treatment 1 = treatment i, for i=2,...,T, immediately before the control mean.
The default `optional` mode permits no tests or an explicitly planned subset.
Compute supplied tests with the fitted model's covariance and
appropriate reference distribution. Always put `\hline` above the control mean,
then a rule before N when shown. Existing unavailable
statistics are `--`; nonexistent cells are blank. Omit a q-value or RI p-value line
when it has no available values across that effect's displayed columns. Finish
with `\hline` then `\bottomrule`, followed by one footnote item beginning “Notes:”.
Avoid adjacent rules elsewhere. Give two- or three-column tables adequate width
(widen the row/outcome-label column as well as all result/outcome-heading columns)
(default minimum 85% of available width, without scaling text). Numeric precision uses the
original magnitude: 3 decimals below 1, 2 below 100, otherwise 1. Probabilities
always have 3 decimals; counts are integers. Use comma thousands separators for
every reported number whose absolute displayed value is at least 1,000, including
negative values and numbers in footnotes (for example, `1,234`, `-1,234.5`,
and “10,000 replications”). Apply this to authored notes as well as table cells;
never round or insert formatting into the saved numeric results.
When exactly one panel is displayed, omit its panel heading, including on
continuation pages. Retain the table caption and column/group headings.

Keep ad hoc tests, comparison exercises, and their generated files under the
gitignored `skill-tests/` directory. Do not add private analysis inputs or test
artifacts to the skill package or Git; reusable test scripts and curated public
examples remain versioned.

For reproducible examples, tests, dependencies, and known limits, read
[verification](references/verification.md). Do not silently extend the statistical
coverage of a helper. Adapt an estimator or requested presentation explicitly,
then test the resulting implementation and document the departure.
Optional Python utilities only compile, check, rasterize or package existing
outputs; they do not estimate or export tables. Production has no Python dependency.
