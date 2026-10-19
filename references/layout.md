# Layout and notes

The helper uses booktabs top/bottom rules, `\midrule` between panels, and a
centered bold spanning panel heading followed by `\hline`. Outcome headings and
row labels use paragraph columns. Order comes from numeric order fields, never
alphabetic IDs. The default is `\small`, 4pt column separation and 1.12 row stretch.
Avoid solving overflow by shrinking the font. A user-requested different layout
can be implemented deliberately; preserve the saved-results and validation rules.

Regression cells: coefficient with stars, `(SE)`, `[q]`, visible `\{p_ri\}`.
Effect, treatment-equality test, control mean and N lines get labels. A rule precedes control means;
another follows means and precedes N. Star source defaults to unrounded p with
strict cutoffs .10/.05/.01; missing source means no stars. Source and cutoffs are
generated in notes without “Stars use” or “unrounded source” wording. Omit each
q-value or RI p-value line when all its values across that treatment effect's
displayed columns are missing. A partially available line retains `--` for missing
cells; an absent logical cell is blank. Do not delete saved inference values.

Do not display an individual coefficient's conventional p-value as a separate
row. This does not remove the requested q-value or RI lines. Ordinary regressions
need no equality-test rows. When `pt_contrasts` is `first_vs_rest`, for T non-control
treatment arms add T-1 labeled rows immediately above the control mean:
“p-value: Treatment 1 = Treatment 2”, ..., “p-value: Treatment 1 = Treatment T”.
These are separate pairwise equality tests, not a single omnibus test. Use the
fitted model's joint covariance and appropriate Wald/F/t/other reference
distribution; never derive them from two marginal SEs while ignoring covariance.
Store full-precision test p-values as scalar probability cells, displayed with
three decimals and no stars. Explain the actual test in the notes. Unavailable
tests remain missing with an explanation, not fabricated. Do not include these
tests in the outcome-by-treatment q families unless the analysis plan requests it.
In the default `optional` mode, include only explicitly planned comparisons,
possibly none; do not compare unrelated covariates solely because they are shown.
Each requested test is model-specific. In every
regression layout, `\hline` separates the last equality-test/effect row from the
control mean. Equality-test rows are the additional labeled-row exception.

Do not put `\hline` immediately before another `\hline`, `\midrule` or
`\bottomrule` within the table. In particular, when N is shared, omit the
otherwise trailing rule after a non-final panel's control mean. The one deliberate
exception is the final `\hline` followed by `\bottomrule`, immediately before
footnotes. This applies to the final multipage segment as well; continuation
pages use their normal continuation footer, not the terminal rule pair.
The multipage renderer keeps the terminal rules and single notes item in one
indivisible body row, together with the preceding result where possible.

Summary means appear above their SDs in round brackets, with a separate adjacent
N column for each group. Show the group label once, centered in a `\multicolumn`
heading spanning those two columns, followed by `\cmidrule(lr)` across that span.
The next header row contains only `Mean (SD)` and `N`; do not repeat the group name
in each subcolumn. Wrap long group names within the combined column width.
Repeat both header tiers and their spanning rules on multipage continuations,
preserving the requested group order. The same shared-label principle applies
to regression columns through the optional `header1_*` and `header2_*` fields
in the [native schema](native-stata.md#regression-column-groups). They support
an outcome spanning specifications/times, a category spanning distinct outcomes,
or both tiers together. Every populated group gets a centered wrapping span and
its own `\cmidrule`; the full hierarchy repeats on multipage continuations.
Do not infer grouping from matching text alone. Changing a group heading across
panels prevents header sharing, independently of verified sample equality for N.
Keep the mean/SD lines together. No regression inference
lines, control means or common N footer are added. The underlying saved results
still contain separate mean, SD and N cells; native `group_id`, `group_order`,
`group_label`, and `statistic` map them explicitly to presentation groups. Other
statistics or a requested flat layout require an explicit native renderer extension.

## Width and pagination

Natural width is 3.2cm for labels plus 2.1cm per data column, capped at available
width. For two or three displayed data columns, allocate at least 85% of the
available width, using wider columns rather than resizing text. Configure the fraction
with `small_table_width_fraction` (0 restores natural width). Paragraph columns wrap
outcomes. The TeX width is capped by `\linewidth` in the chosen orientation;
no resizebox is used. Defaults assume 16cm portrait/23cm landscape text area.
Set `portrait_width_cm` and `landscape_width_cm` from the actual document geometry.
Use `row_width_cm` and `data_width_cm` to allocate more natural width for unusually
long labels or numbers; defaults are 3.2 and 2.1. Recompile after changes.
When widening a small table, preserve the natural width proportions so the
row/outcome-label column grows together with the numerical columns and their
outcome headings. Do not leave a cramped label column at a fixed 3.2cm while
allocating all added space to results. This also applies to summary tables.
More than seven model/data columns selects landscape; fewer also select it when
natural width exceeds the portrait limit. An explicit orientation overrides this
heuristic, but legibility must still be checked. Tables with less than 1.25cm
per numeric column are rejected for splitting or a larger paper format.

Layout `auto` chooses multipage when estimated rows exceed 48 portrait or 32
landscape; `page_lines` allows a conservative document-specific limit. This is a
heuristic, not a guarantee: long labels/notes may require
`char _dta[pt_layout] "multipage"`
even with fewer rows. Inspect the compiled page, then revise configuration.
For extreme notes that themselves exceed a page, move detailed definitions to a
referenced definition table or manuscript section with the user's agreement;
retain an accurate concise table note. Do not silently clip notes.

Multipage uses `longtable` with `threeparttablex`; wide and tall tables also use
`pdflscape`. It is never wrapped in a float or resizebox. A panel starts on its
own page/longtable segment; subsequent segments retain the table number. This
explicit page boundary makes repeated headers unambiguous. Every continuation
repeats the original caption with “(continued)”, outcome headings and the panel
heading. Adjacent inference lines use `\\*` to keep effect blocks together;
headings are kept with following rows. A block taller than a page must be split
manually into intelligible pieces, with inference clearly associated.

When outcomes differ, each panel has its own headings and N. For unchanged
outcomes in the same order across specification panels, semantic outcome
metadata must also match before headings are shared. N may be shared only when
corresponding models have verified identical observation-ID sets and equal N;
then only the final panel displays N. These decisions are independent. On new
pages, relevant headings repeat even if otherwise shareable. To request more
repetition, set `char _dta[pt_share_headings] "0"` or
`char _dta[pt_share_n] "0"`; layout settings use `pt_` dataset characteristics
as documented in [native schema](native-stata.md).

## Notes checklist

Combine all note points into exactly one `\item`, beginning `\textit{Notes:}`.
Use continuous prose. For example: “Notes: * p<0.10, ** p<0.05, *** p<0.01,
using conventional p-values. Standard errors appear in round brackets. ...”
Identify an alternative star source explicitly, but do not add “unrounded source”.
Only explain square/curly delimiters when those inference lines actually appear.
Do not prefix each metadata paragraph with another “Notes:” or create extra items.

Read analysis code/documentation; ask for missing essential facts. Do not invent:

- Outcome definitions, or the existing outcome-definition table reference.
- Controls and fixed effects; panel-specific differences.
- Estimator and departures from ordinary Stata regress/OLS.
- SE calculation and cluster level; parentheses convention.
- Square brackets: Anderson (2008)/BKY (2006) sharpened q-values, source p-values,
  family definition (including all outcomes and treatment grouping), grid.
- Curly brackets: RI method actually run, design restrictions, statistic, tail,
  draws/seed and tie/Monte Carlo conventions; cite Hess (2017) only for ritest.
  Explain unavailability when retained lines contain missing RI.
- Control group, endline/time, model estimation sample and weighting.
- Sample restrictions, variable-specific missingness, count and weight conventions.

The renderer supplies star and delimiter notes only; substantive notes remain
the analyst's responsibility and must be checked against embedded provenance.
Use plain author-year text when no bibliography exists. Use raw citation commands
only with corresponding bibliography entries and the parent document setup.

Standard dependencies: `booktabs`, `array`, `threeparttable`. Add `graphicx` if a
custom layout uses resizing; `float` for `[H]`. Landscape here uses `pdflscape`;
`sidewaystable` alternatives require `rotating`. Multipage requires `longtable`
and `threeparttablex` (loaded after `threeparttable`). See the bundled wrapper.
