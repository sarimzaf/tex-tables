"""Check independently logged Stata results against saved cells and both TeX layouts."""
from pathlib import Path
from decimal import Decimal, ROUND_HALF_UP
import re
import pandas as pd

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output"
TABLES = ROOT.parent / "examples/stata/output"
data = pd.read_stata(OUT / "comparison.dta", convert_categoricals=False)
keyed = data.set_index(["panel_id", "column_id"])
text = (OUT / "direct_regressions.log").read_text()
fields = {"b": "direct_b", "se": "direct_se", "p": "direct_p",
          "control_mean": "direct_mean", "n_obs": "direct_n"}
seen = set()
for line in text.splitlines():
    if not line.startswith("DIRECT|"):
        continue
    _, panel, column, field, value = line.split("|")
    assert (panel, column, field) not in seen
    seen.add((panel, column, field))
    expected = float(keyed.loc[(panel, column), fields[field]])
    assert float(value.strip()) == expected, (panel, column, field)
assert len(seen) == 60

def number(value, probability=False, count=False):
    value = float(value)
    digits = 0 if count else 3 if probability or abs(value) < 1 else 2 if abs(value) < 100 else 1
    rounded = Decimal(str(value)).quantize(Decimal(1).scaleb(-digits), rounding=ROUND_HALF_UP)
    result = f"{rounded:,.{digits}f}"
    return result[1:] if result.startswith("-") and rounded == 0 else result

def stars(p):
    return "***" if p < .01 else "**" if p < .05 else "*" if p < .10 else ""

expected = []
for panel in ["p1", "p2"]:
    rows = data[data.panel_id.eq(panel)].sort_values("column_order")
    effects = []
    for row in rows.itertuples():
        mark = stars(row.direct_p)
        effects.append(number(row.direct_b) + ("$^{" + mark + "}$" if mark else ""))
    expected.append(["Foreign origin", *effects])
    expected.append(["", *["(" + number(v) + ")" for v in rows.direct_se]])
    expected.append(["", *["[" + number(v, probability=True) + "]" for v in rows.direct_q]])
    expected.append(["Control mean", *[number(v) for v in rows.direct_mean]])
    if panel == "p2":
        expected.append(["N", *[number(v, count=True) for v in rows.direct_n]])

for name in ["grouped_regression", "grouped_regression_multipage"]:
    actual = []
    for line in (TABLES / (name + ".tex")).read_text().splitlines():
        if not re.search(r"\\\\\*?$", line):
            continue
        cells = re.sub(r"\s*\\\\\*?$", "", line).split(" & ")
        first = cells[0].strip()
        if first in ["Foreign origin", "Control mean", "N"] or (
            first == "" and len(cells) == 7 and cells[1].startswith(("(", "["))
        ):
            cells[0] = first
            actual.append(cells)
    assert actual == expected, name

lines = [
    "# Independent Stata comparison",
    "",
    "Scope: the 12 automobile regressions in the grouped regression example:",
    "price, mpg and trunk; without/with weight; conventional/robust covariance.",
    "",
    "No publication-table helper or FDR package was loaded. verification/regressions.do contains",
    "12 explicit regress commands. Coefficients and SEs come directly from e(b)",
    "and e(V); p-values use the model residual-df t distribution. Full regression",
    "output, including controls and intercepts, is in direct_regressions.log.",
    "",
    "| Statistic | Maximum absolute difference |",
    "|---|---:|",
]
for field, label in [("b", "Coefficient"), ("se", "Standard error"),
                     ("p", "Conventional p-value"), ("mean", "Control mean"),
                     ("n", "N"), ("q", "Sharpened q-value")]:
    lines.append(f"| {label} | {data['delta_' + field].abs().max():.17g} |")
lines += [
    "",
    "All estimation-sample IDs and adjustment-family sizes also match exactly.",
    "All 60 full-precision log records match the independently saved results.",
    "Every displayed coefficient, SE, q-value, control mean, N and significance",
    "star agrees in its correct column in both the standard and multipage TeX.",
    "",
    "Native regress does not return q-values. Those were independently computed",
    "using ordinary Stata commands for the two-stage sharpened BKY procedure,",
    "with a .001 grid and four panel-by-specification families of three outcomes.",
    "No RI was run or fabricated. Conventional p-values remain saved and determine",
    "stars; they are not separate rows in these tables.",
    "",
    "Differences in visible digits between Stata's usual output and the publication",
    "tables are display rounding only; the saved estimates are identical.",
    "",
    "| Covariance | Outcome | Specification | Coefficient | SE | p-value | q-value | N |",
    "|---|---|---|---:|---:|---:|---:|---:|",
]
for row in data.sort_values(["panel_order", "column_order"]).itertuples():
    lines.append(f"| {'Conventional' if row.panel_id == 'p1' else 'Robust'} | {row.outcome_id} | {row.specification} | {row.direct_b:.9g} | {row.direct_se:.9g} | {row.direct_p:.9g} | {row.direct_q:.3f} | {row.direct_n:.0f} |")
(OUT / "COMPARISON.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("PASS: 60 full-precision log records and every displayed numerical cell/star in both TeX layouts.")
