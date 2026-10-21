# Reproduction, verification and publication

## Requirements and reproduction

The production workflow requires Stata 17+ only. It estimates, collects, adjusts,
validates, saves and exports TeX entirely in Stata/Mata. Run with the skill folder
as working directory; each example can also run independently:

Extract the complete folder to a writable location on your computer. In Stata,
change the working directory to that extracted folder before running the commands
below. Paths are relative to the skill root, including the examples' optional
`archive/` or `_archive/` folders. Nothing is read from a surrounding project,
another skill installation or a particular user's home directory. The helper
does not require Codex, Claude, Python or a shell bridge to execute Stata code.
The automobile examples use `auto.dta` supplied with Stata (`sysuse auto`);
the other examples generate their own synthetic data. No external dataset,
SSC download or user-installed ado is needed for these examples or checks.

~~~stata
do examples/stata/run_all.do
do examples/stata/test_native.do
do verification/run_all.do
~~~

Regenerate examples on the target installation before comparison so the reference
and independent runs use the same Stata runtime. A precompiled PDF is provided for
every table. To regenerate PDFs, install a LaTeX distribution with `pdflatex` and
the wrapper packages: `geometry`, `fontenc` (T1), `lmodern`, `booktabs`, `array`,
`threeparttable`, `graphicx`, `float`, `rotating`, `pdflscape`, `longtable` and
`threeparttablex`. The automated PDF checker additionally needs `pdftotext`.
Put these executables on PATH or pass their locations with `--pdflatex` and
`--pdftotext`; no executable location is embedded in the skill.

Optional QA uses Python 3.10+ and the packages listed in
[requirements-qa.txt](../scripts/requirements-qa.txt). Install them into your
chosen Python environment with `python -m pip install -r scripts/requirements-qa.txt`.
On systems where the interpreter is named `python3` or `py`, use that command in
place of `python`. Packaging itself needs only Python's standard library.
`ritest` is an additional requirement only if an actual analysis calls for RI;
the bundled demonstrations do not run it. Public research links are citations,
not files downloaded during verification.

Results, TeX and preview wrappers go into examples/stata/output.
The shared data.do creates synthetic demonstration data. Grouped regression
examples use Stata's 1978 automobile data for observational associations, without
causal claims. Repeated synthetic rows are labeled layout stress fixtures.

| Complete estimation-to-TeX script | Demonstration |
|---|---|
| [standard.do](../examples/stata/standard.do) | Two treatments, three outcomes, equality-test row |
| [shared.do](../examples/stata/shared.do) | Identical samples; common headings and final-panel N |
| [different_samples.do](../examples/stata/different_samples.do) | Different membership; panel-specific N |
| [unknown_samples.do](../examples/stata/unknown_samples.do) | Equal N without membership evidence |
| [different_outcomes.do](../examples/stata/different_outcomes.do) | Panel-specific outcome headings |
| [summary.do](../examples/stata/summary.do) | Mean above (SD), variable-specific N |
| [long_labels.do](../examples/stata/long_labels.do) | Wider label column; wrapping and escaping |
| [multipage.do](../examples/stata/multipage.do) | Portrait multipage summary |
| [wide_multipage.do](../examples/stata/wide_multipage.do) | Landscape multipage summary |
| [panel_continuation.do](../examples/stata/panel_continuation.do) | Repeated regression panel context |
| [grouped_regression.do](../examples/stata/grouped_regression.do) | Categories spanning outcomes, outcomes spanning specifications; shared N |
| [grouped_regression_multipage.do](../examples/stata/grouped_regression_multipage.do) | Same models; complete hierarchy repeated on longtable pages |
| [auto_summary.do](../examples/stata/auto_summary.do) | Automobile means/SDs and variable-specific N by origin |
| [auto_summary_repair_panels.do](../examples/stata/auto_summary_repair_panels.do) | Five repair-category panels, including empty origin groups |
| [ordinary_regression.do](../examples/stata/ordinary_regression.do) | Three ordinary covariates, three outcomes, optional contrasts, strL sample collection |

The canonical example list is [manifest.json](../examples/stata/manifest.json).
Check newly written PASS.txt and TEST_PASS.txt plus their logs, not just the
Stata process exit code. The supplied runners remove stale status first.
Tests re-estimate from the synthetic and Stata automobile data directly.

## Independent Stata checks

Run [verification/run_all.do](../verification/run_all.do) from the skill root
after generating the examples. It removes its old success marker, checks the
required companion files, runs the two independent calculations, and writes
`verification/output/INDEPENDENT_PASS.txt` only after both comparisons succeed.
Inspect freshly written logs and the marker; a Stata process exit code alone
does not establish success. None of these Stata scripts loads the table engine,
its validator, or its FDR ado. Each calculation starts with `clear all` and reads
the skill's saved results only after independent estimates have been saved.

- [regressions.do](../verification/regressions.do) executes 12 explicit automobile
  regressions: price, mileage and trunk space, without/with weight, using
  conventional/robust covariance. `direct_regressions.log` includes full native
  output and 60 full-precision records. Coefficients/SEs come directly from e(b)/e(V),
  and p-values use residual-df t inference. Ordinary Stata commands separately
  calculate sharpened BKY q-values on a .001 grid, using four complete
  panel-by-specification families of three outcomes; q is not returned by regress.
- [compare_regressions.do](../verification/compare_regressions.do) merges by
  model identity and records differences in `comparison.log`. It checks b, SE,
  p, q, control means, N, sample membership, family sizes, and agreement between
  the single-page and multipage saved results. Numerical tolerance is 1e-12;
  the bundled example has zero differences.
- [summaries.do](../verification/summaries.do) uses ordinary `summarize` and a
  separate nonmissing `count` for each variable/group/panel. `summary_check.log`
  contains native output and the comparison of all 360 mean/sample-SD/N cells.
  It checks 120 variable/group/panel counts, including repair-rating N=48/21
  versus 52/22 for complete variables, and 20 empty combinations with N=0 and
  40 missing means/SDs. Counts must not be replaced by a common complete-case N.

Logs, direct DTA results, comparison DTA/CSV files and optional reports are generated
under `verification/output`; they are not static release payloads. Optional Python
checks independently parse the log records and compare every displayed cell,
star and missing marker in its correct TeX column:

~~~sh
python verification/check_regression_log_and_tex.py
python verification/check_summary_log_and_tex.py
~~~

These write `COMPARISON.md` and `SUMMARY_COMPARISON.md` beside the logs. They use
the same optional pandas dependency as the PDF checker and import no renderer
or renderer QA code. They do not replace compilation and visual inspection.

For an actual analysis, adapt the direct commands and identifiers to its exact
data, samples, weights, estimator and inference; preserve full-precision logs
before comparing with the exported DTA and rounded TeX. This is an independent
execution/extraction check within Stata, not verification by a second statistical
software implementation. The bundled q check covers these four families; it does
not establish FDR assumptions for other analyses. RI is not executed here.

## Compilation and visual checks

Compile every NAME-preview.tex twice from the output folder using the document's
LaTeX installation. The [wrapper](../assets/wrapper.tex) declares dependencies.
Optional Python 3.10+ utilities verify already-generated TeX/PDFs; they do not
estimate or export tables. Their optional dependencies are in
[requirements-qa.txt](../scripts/requirements-qa.txt).

~~~sh
python scripts/compile_examples.py
python scripts/render_previews.py
~~~

The compiler accepts --pdflatex PATH, --pdftotext PATH, and repeatable
--table NAME for targeted checks. It rejects compilation errors, overfull boxes
and unresolved references, requires captions/continuation context on each page,
and checks visible numerical tokens against DTA values, including means and N.
Token presence is not proof of cell placement; visual inspection is still required.

The rasterizer writes page PNGs/contact sheets to output/visual-qa. It removes
only its own previous generated images, including pages that no longer exist.
Inspect every page at readable scale: wrapping, alignment, inference blocks,
control-mean rules, terminal rules, captions, repeated headings, notes, and clipping.
Correct problems and repeat affected checks. Repeat in the actual manuscript,
because geometry, fonts and surrounding floats can change pagination.

## Singleton-family validation, 2026-10-21

Domain-based grouping can produce families with one hypothesis. The Mata
validator handles singleton and all-missing families without empty-selection
dimension errors. Tests compare it with the unchanged bundled ado at p=0,
.001, .04, .5, .8, 1 and ordinary/extended missing values. The complete native
suite and independent regression/summary checks pass.

## Formatting update validation, 2026-10-20

The native tests cover comma grouping for positive/negative thousands and
millions, rounding across 1,000, and formatted note quantities. Single displayed
panels omit their titles in regression and summary tables, including longtable
continuation headers and a table whose other panel is hidden. Multiple-panel
headings remain present. All fifteen examples compile and pass PDF numerical
checks; all 32 rendered pages were visually reviewed. Independent checks pass
for all 420 regression and summary log records and their displayed cells.
Ad hoc runs belong under gitignored `skill-tests/`; generated artifacts must
not enter the package. Reusable test scripts and curated examples are retained.

## Validation record: version 2.4.0, 2026-10-18

- All fifteen examples and the native suite passed in Stata 17. The new ordinary
  regression example displays three real-data covariates without equality tests;
  its nine coefficients, SEs and finite-df p-values match direct re-estimation.
- [test_regression_schema.do](../examples/stata/test_regression_schema.do), called
  by the native suite, checks default/explicit optional contrasts, requested
  subsets, strict first-versus-rest coverage, unknown modes, missing coefficient
  references, self-comparisons, and duplicate/reversed comparison pairs.
- A deterministic 200,000-record stress test collects all 180,000 e(sample) IDs
  into a strL over one million characters long, verifies every ID, and round-trips
  the DTA. Collection preserves estimation results and is invariant to input
  ordering. Equal-N different membership stays distinct. Duplicate model keys,
  duplicate/missing/fractional/unsafe integer IDs, and truncated evidence fail.
- All regression collectors now use `pt_sample` and merge the complete sample
  evidence into posted results. The unknown-sample example deliberately blanks
  this evidence after collection, retaining its original purpose and behavior.
- The existing independent automobile regressions and summaries passed, including
  all 420 full-precision log records and their displayed TeX cells.
- All fifteen example PDFs compiled twice without overfull boxes or unresolved
  references (32 pages). The fourteen pre-existing examples preserve all saved
  result columns and have pixel-identical pages to the 2.3.1 supplied PDFs. The
  new ordinary-regression page was visually inspected.

## Prior validation record: version 2.3.1, 2026-10-18

- All fourteen current native workflows, native tests and independent checks passed in Stata 17.
- Saved coefficients, SEs, conventional p-values, model N, control means, summary
  means/SDs/counts and equality-test p-values were reconciled with direct Stata
  re-estimation/summarization. Equality-test p-values also agree with lincom.
- Tests cover original-magnitude precision boundaries, extended missing values,
  negative zero, strict star cutoffs, plain-text escaping, invalid/conflicting
  cells, changed FDR families, sample evidence, display filtering, replacement
  protection and unique archive names. A three-treatment schema fixture verifies
  that both 1=2 and 1=3 comparisons are required; it is never exported as estimates.
- The identified Stata FDR helper and independent Mata recomputation agree,
  including missing values, ties and p=1. The Mata check reproduces the ado's
  intermediate local-macro decimal precision at exact grid boundaries. The original validation used the ado with
  SHA-256 f762b092b7edfbe0352cd077af21e5895ac06b67b0c1c82299c7a1cb7da39b55.
- All fourteen examples compiled twice without overfull boxes or unresolved references.
  All 31 pages were rasterized and visually inspected. Portrait multipage summary:
  four pages; landscape summary: seven; multipage regression: four.
- The skill frontmatter/name validation, relative reference checks, portable-path
  checks, and publication file/hash checks passed.
- Single-effect models without equality-test rows and empty selections are covered
  by native tests. Decimal half-value checks reconcile display rounding with Stata.
- Grouped summary headers show each group once above Mean (SD) and N, with
  spanning rules. Standard, long-label, portrait/landscape multipage and
  real-data examples were recompiled and inspected with both header tiers
  repeated on continuation pages. Saved statistical values were unchanged.
- Regression headers support outcome spans, category spans and both nested tiers.
  The automobile example and two-page variant were reconciled with independent
  Stata estimation; three-outcome adjustment families remain separate by panel
  and specification. Tests reject disjoint, inconsistent, crossing and orphan
  groups, exercise single-tier/filtered columns, and verify that changing panel
  group headings repeats the headings while retaining a separately verified
  common N. Existing flat-header examples remain supported.
- Default adjustment families use panel and treatment-effect IDs, independently
  of display-row IDs. A sparse-row fixture verifies that separate rows for the
  same treatment effect retain their complete outcome family.
- The independent workflow matched all 12 regression models and all 360 summary
  cells, with zero numerical differences and exact missing-value agreement.
  All 420 full-precision log records and displayed TeX cells passed the independent
  checks. The workflow was also run from an extracted publication ZIP.
- Portability was tested by extracting the ZIP into a different writable folder
  whose name contains spaces and pointing Stata's SITE, PERSONAL, PLUS and OLDPLACE
  ado directories at an empty folder. All fourteen examples, native tests and
  independent comparisons passed. All regenerated DTA values and TeX sources
  matched the supplied examples exactly. Six representative single-page,
  shared-N, grouped and multipage examples compiled there successfully (11 pages).
  This execution test used Windows and Stata 17; macOS and Linux execution has
  not been tested. No operating-system-specific command is required by the
  bundled Stata workflow.

## Public distribution provenance

The public copy changes only the FDR ado's project-name comment to `tex-tables`;
its executable Stata code is unchanged from the version used in the validation
records above. The public file's SHA-256 is
`c77dc31b35165551ea21e8fd67e666628451e8f50ea6a56ff115f55a954c4184`. The saved
`Anderson-BKY-grid001-ado-f762b092` method tag continues to identify the original
validated implementation; the current source file is checked independently by
the packager and `SHA256SUMS`. Author credit and statistical references are retained.

## Publication contents

The publication folder contains the current Stata engine, identified
FDR ado, fifteen runnable table scripts and shared data/runner/tests, one current schema,
linked inference/layout/verification guidance, document wrapper, UI metadata,
a public README and Git configuration, independent Stata verification scripts
and log/TeX comparators, optional PDF QA/package
tools, and each example's matched DTA/TeX/preview source/PDF.

Run `python scripts/package_skill.py` to build `dist/tex-tables.zip`
from an explicit file list. It checks references, provenance and portable paths,
writes per-file `SHA256SUMS`, and creates `dist/tex-tables.zip.sha256`. ZIP metadata
is fixed so repeated packaging of identical files produces an identical archive.
Stata/PDF regeneration can change embedded timestamps; verify hashes after every
regeneration. The same archive folder works for Codex and Claude.

Build logs, temporary stages, test artifacts and raster previews are excluded
from the publication bundle. Reproduction may generate logs, aux files and QA
images; these are not publication source files. Retain author and provenance
notices in the bundled FDR source.

## Explicit limits

The collector examples are unweighted OLS and unweighted summaries. Other
estimators, weights, statistics and RI need a correct Stata adapter and accurate
metadata; the renderer must not silently change the analysis. No RI execution was
part of this validation. Require assignment-design checks and saved-draw
reconciliation before reporting RI. The identified FDR helper is limited to
32,740 nonmissing tests per family.

Sample membership comparisons establish equality of supplied ID sets, not that
the correct samples were extracted. Pagination is heuristic and always requires
compilation/visual review. Ordinary export/archival checks were run; crash/power-loss
or simultaneous-writer recovery is not claimed tested. Do not describe an actual
research table as publication-ready until it passes checks in its intended document.
