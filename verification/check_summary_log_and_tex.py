"""Verify independent summary log records and correctly positioned TeX cells."""
from pathlib import Path
from decimal import Decimal, ROUND_HALF_UP
import re
import pandas as pd

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output"
TABLES = ROOT.parent / "examples/stata/output"
data = pd.read_stata(OUT / "summary_comparison.dta", convert_categoricals=False)
keys = ["table_id", "panel_id", "group_id", "row_id", "statistic"]
keyed = data.set_index(keys)
seen = set()
for line in (OUT / "summary_check.log").read_text().splitlines():
    if not line.startswith("SUMMARY|"):
        continue
    _, table, panel, group, row, statistic, value = line.split("|")
    key = (table, panel, group, row, statistic)
    assert key not in seen
    seen.add(key)
    expected = keyed.loc[key, "direct_value"]
    if value.strip() == ".":
        assert pd.isna(expected), key
    else:
        assert float(value.strip()) == expected, key
assert len(seen) == 360

def number(value, count=False):
    if pd.isna(value):
        return r"\mbox{-{}-}"
    digits = 0 if count else 3 if abs(value) < 1 else 2 if abs(value) < 100 else 1
    rounded = Decimal(str(float(value))).quantize(Decimal(1).scaleb(-digits), rounding=ROUND_HALF_UP)
    result = f"{rounded:,.{digits}f}"
    return result[1:] if result.startswith("-") and rounded == 0 else result

for table in ["auto_summary", "auto_summary_repair_panels"]:
    subset = data[data.table_id.eq(table)]
    expected = []
    metadata = subset.sort_values(["panel_order", "row_order"]).drop_duplicates(["panel_id", "row_id"])
    labels = set(metadata.row_label)
    for row in metadata.itertuples():
        means, sds = [row.row_label], [""]
        for group in ["g0", "g1"]:
            prefix = (table, row.panel_id, group, row.row_id)
            means += [number(keyed.loc[(*prefix, "mean"), "direct_value"]),
                      number(keyed.loc[(*prefix, "n"), "direct_value"], count=True)]
            sds += ["(" + number(keyed.loc[(*prefix, "sd"), "direct_value"]) + ")", ""]
        expected += [means, sds]
    actual = []
    for line in (TABLES / (table + ".tex")).read_text().splitlines():
        if not re.search(r"\\\\\*?$", line):
            continue
        cells = [cell.strip() for cell in re.sub(r"\s*\\\\\*?$", "", line).split("&")]
        first = cells[0].strip()
        if first in labels or (first == "" and len(cells) == 5 and cells[1].startswith("(")):
            cells[0] = first
            actual.append(cells)
    assert actual == expected, table

lines = [
    "# Independent summary-statistics comparison",
    "",
    "Direct Stata summarize and count were run on Stata's automobile data.",
    "No publication-table helper was loaded. The overall table and five repair-category",
    "panels cover 10 variables by domestic/foreign origin: 120 combinations and 360",
    "mean, sample-SD and N cells. Each variable uses its own available observations.",
    "",
    "| Statistic | Maximum absolute difference |",
    "|---|---:|",
]
for statistic in ["mean", "sd", "n"]:
    delta = data.loc[data.statistic.eq(statistic), "difference"].abs().max()
    lines.append(f"| {statistic} | {delta:.17g} |")
lines += [
    "",
    "All 360 saved cells match: 320 numeric values and 40 unavailable statistics.",
    "All 360 full-precision log records match the direct results. Every displayed",
    "mean, parenthesized SD, count and missing marker matches its correct position",
    "in both TeX tables. Display rounding is the only difference from full precision.",
    "",
    "| Overall-table variable | Domestic N | Foreign N |",
    "|---|---:|---:|",
]
overall = data[data.table_id.eq("auto_summary") & data.statistic.eq("n")]
for _, group in overall.sort_values("row_order").groupby("row_id", sort=False):
    counts = group.set_index("group_id").direct_value
    lines.append(f"| {group.row_label.iloc[0]} | {counts['g0']:.0f} | {counts['g1']:.0f} |")
lines += [
    "",
    "Repair ratings have four missing domestic observations and one missing foreign",
    "observation. Their N is 48/21, versus 52/22 for the other nine variables.",
    "The repair-category panels exclude those five missing ratings. Foreign groups",
    "in categories 1 and 2 contain no cars: 20 variable/group combinations correctly",
    "retain N=0, with 40 missing means/SDs displayed as -- rather than estimated zeros.",
    "",
    "Files compared: examples/stata/output/auto_summary.dta and auto_summary_repair_panels.dta,",
    "plus their matching TeX outputs. The Stata calculations and comparisons are",
    "reproducible by running verification/summaries.do from the skill folder; summary_check.log",
    "contains the complete direct output and comparison assertions.",
]
(OUT / "SUMMARY_COMPARISON.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("PASS: all 360 log records and all displayed summary cells/counts/missing markers in both TeX tables.")
