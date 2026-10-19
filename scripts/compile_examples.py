"""Compile existing Stata-produced TeX and check PDF values; never export tables."""
import argparse
from decimal import Decimal, ROUND_HALF_UP
import json
import math
from pathlib import Path
import re
import subprocess

import pandas as pd
from pandas.io.stata import StataMissingValue

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "examples" / "stata"


def display_number(value, kind="number", decimals=-1):
    """Independent PDF-check expectation; native Stata tests check rounding boundaries."""
    if isinstance(value, StataMissingValue) or pd.isna(value):
        return None
    x = float(value)
    if not math.isfinite(x):
        raise ValueError("Infinite statistic")
    if kind == "count":
        if x < 0 or x != int(x):
            raise ValueError("Invalid count")
        return str(int(x))
    places = (3 if kind == "probability" else decimals if decimals >= 0 else
              3 if abs(x) < 1 else 2 if abs(x) < 100 else 1)
    # Match Stata's decimal half-away-from-zero display, not Python's tie-to-even.
    rounded = Decimal(str(x)).quantize(Decimal(1).scaleb(-places), rounding=ROUND_HALF_UP)
    result = f"{rounded:.{places}f}"
    return result[1:] if result.startswith("-") and float(result) == 0 else result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdflatex", default="pdflatex")
    parser.add_argument("--pdftotext", default="pdftotext")
    parser.add_argument("--table", action="append", help="Check named examples only; repeatable")
    args = parser.parse_args()
    names = json.loads((EXAMPLES / "manifest.json").read_text(encoding="utf-8"))
    if args.table:
        if set(args.table) - set(names):
            parser.error("Unknown table name")
        names = args.table
    out = EXAMPLES / "output"
    for name in names:
        for _ in range(2):
            run = subprocess.run([args.pdflatex, "-interaction=nonstopmode", "-halt-on-error",
                                  name + "-preview.tex"], cwd=out, capture_output=True, text=True)
            if run.returncode:
                raise RuntimeError(name + " compilation failed:\n" + run.stdout[-3000:])
        log = (out / f"{name}-preview.log").read_text(errors="replace")
        bad = re.findall(r"(?:Overfull \\[hv]box|LaTeX Warning:.*(?:undefined|multiply defined|too large)).*", log)
        if bad:
            raise RuntimeError(name + ": " + "\n".join(bad))
        subprocess.run([args.pdftotext, "-layout", name + "-preview.pdf",
                        name + "-preview.txt"], cwd=out, check=True)
        rendered = (out / f"{name}-preview.txt").read_text(encoding="utf-8")
        pages = [p for p in rendered.split("\f") if p.strip()]
        for i, page in enumerate(pages):
            if "Table 1:" not in page or (i and "(continued)" not in page):
                raise AssertionError(f"{name}: page {i+1} lacks caption/continuation context")
        d = pd.read_stata(out / (name + ".dta"), convert_missing=True, convert_categoricals=False)
        if "display" in d:
            d = d[d.display.eq(1)]
        normalized = re.sub(r"\s+", "", rendered).replace("−", "-")
        for _, row in d.iterrows():
            fields = ["b", "se", "q", "p_ri"] if row.row_type == "coef" else ["value"]
            for field in fields:
                kind = row.value_kind if field == "value" else "probability" if field in ["q", "p_ri"] else "number"
                val = display_number(row[field], kind)
                if val is not None and val not in normalized:
                    raise AssertionError(f"{name}: {field}={val} absent from PDF text")
            if row.row_type == "coef":
                for field, kind, dec in [("n_obs", "count", 0), ("control_mean", "number", int(row.mean_dec))]:
                    val = display_number(row[field], kind, dec)
                    if val is not None and val not in normalized:
                        raise AssertionError(f"{name}: {field}={val} absent from PDF text")
        print(f"Compiled and numerically checked: {name} ({len(pages)} pages)", flush=True)


if __name__ == "__main__":
    main()
