# tex-tables

A Codex skill for producing publication-quality economics regression and
summary-statistics tables in LaTeX, with estimation, collection, validation, and
export performed in Stata/Mata.

The skill supplies a native table engine, fifteen runnable examples, saved
results, PDF previews, and independent numerical checks. It supports ordinary
regressions and treatment comparisons, grouped headings, multipage layouts,
sharpened FDR q-values, and exact estimation-sample membership checks.

## Install

Clone this repository into the `tex-tables` directory under your Codex skills
folder (normally `~/.codex/skills`):

```sh
git clone https://github.com/sarimzaf/tex-tables.git ~/.codex/skills/tex-tables
```

On Windows PowerShell:

```powershell
git clone https://github.com/sarimzaf/tex-tables.git "$env:USERPROFILE/.codex/skills/tex-tables"
```

If that destination already exists, update or back up the existing installation
first. For an installation without Git, download the repository ZIP and place
its contents in a folder named `tex-tables` under your skills directory.

Invoke `$tex-tables` with your data, model specification, and desired table
layout. For example:

> Use $tex-tables to create a summary table by survey wave and a regression
> table from my Stata panel data. Save the do-files, result datasets, and LaTeX
> tables, and compile and inspect the PDFs.

The Stata helpers also run directly without an AI assistant. Start with
[SKILL.md](SKILL.md) and the [native command reference](references/native-stata.md).

## Requirements and quick start

- **Stata 17 or newer** for estimation and table export. Stata is separately
  licensed and is not included.
- **LaTeX** to compile the tables. The supplied wrapper's packages and setup are
  listed in [verification](references/verification.md#requirements-and-reproduction).
- **Python 3.10 or newer**, optionally, for PDF checks, rendering, and packaging.
  Table estimation and export do not require Python.

In Stata, change to this repository's root and run:

```stata
do examples/stata/ordinary_regression.do
do examples/stata/summary.do
```

Each example writes a matched `.dta` and `.tex` pair under
`examples/stata/output`. Precompiled previews are included:

| Example | Source | PDF preview |
| --- | --- | --- |
| Ordinary covariates, optional equality tests | [Do-file](examples/stata/ordinary_regression.do) | [PDF](examples/stata/output/ordinary_regression-preview.pdf) |
| Treatment comparisons | [Do-file](examples/stata/standard.do) | [PDF](examples/stata/output/standard-preview.pdf) |
| Summary statistics | [Do-file](examples/stata/summary.do) | [PDF](examples/stata/output/summary-preview.pdf) |
| Grouped regression columns | [Do-file](examples/stata/grouped_regression.do) | [PDF](examples/stata/output/grouped_regression-preview.pdf) |

See the [complete example guide](references/verification.md) for all fifteen
layouts. Examples use generated synthetic data or Stata's supplied automobile
dataset. No household-survey microdata are distributed in this repository.

## Validate and reproduce

Run from the repository root in Stata:

```stata
do examples/stata/run_all.do
do examples/stata/test_native.do
do verification/run_all.do
```

Optional PDF and displayed-value checks:

```sh
python -m pip install -r scripts/requirements-qa.txt
python verification/check_regression_log_and_tex.py
python verification/check_summary_log_and_tex.py
python scripts/compile_examples.py
python scripts/render_previews.py
```

Compiling requires `pdflatex` and `pdftotext` on PATH; the compiler script also
accepts explicit executable locations. Inspect every generated page, including
in the intended manuscript. The recorded execution checks used Windows and
Stata 17; other operating systems have not been execution-tested.

Equality tests are optional by default. Treatment analyses can explicitly
require first-arm comparisons. `pt_sample` collects exact sample IDs directly
into `strL`; validation includes a 180,000-observation selected-sample test.
See [inference](references/inference.md) for q-value families, reference
distributions, and randomization-inference requirements. The bundled examples
do not execute randomization inference. Other estimators and survey weights
require an appropriate collector and verification.

## Build the distributable skill

```sh
python scripts/package_skill.py
```

The standard-library-only packager checks the explicit publication file list,
relative documentation links, portable paths, and FDR source provenance. It
refreshes `SHA256SUMS` and writes `dist/tex-tables.zip` and its checksum.
Generated logs, caches, test artifacts, and local archives are ignored by Git.
Saved example results and their matching TeX/PDF previews are intentionally
versioned so users can inspect the output before running Stata.

## Attribution

The sharpened q-value implementation follows Benjamini, Krieger, and Yekutieli
(2006) and Anderson (2008); the Stata adaptation credits Sarim Zafar. Statistical
references and implementation provenance are documented in
[inference](references/inference.md) and [verification](references/verification.md).
Hess's `ritest` is referenced for applicable designs and is not bundled.

Original code and documentation are available under the [MIT license](LICENSE).
Stata, its datasets, and cited external software remain subject to their own
terms; they are not relicensed by this repository.
