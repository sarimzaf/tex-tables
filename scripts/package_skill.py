"""Build the publication ZIP from an explicit current-file list; Python stdlib only."""
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "examples" / "stata"
names = json.loads((EXAMPLES / "manifest.json").read_text(encoding="utf-8"))
if len(names) != len(set(names)) or not all(re.fullmatch(r"[a-z][a-z0-9_]*", n) for n in names):
    raise RuntimeError("Invalid or duplicated example names")
relative = [
    "README.md", ".gitignore", ".gitattributes",
    "SKILL.md", "agents/openai.yaml", "assets/wrapper.tex",
    "references/inference.md", "references/layout.md",
    "references/native-stata.md", "references/verification.md",
    "scripts/pt_tables.do", "scripts/fdr_sharpened_qvalues.ado",
    "scripts/compile_examples.py", "scripts/render_previews.py",
    "scripts/package_skill.py", "scripts/requirements-qa.txt",
    "examples/stata/manifest.json", "examples/stata/data.do",
    "examples/stata/run_all.do", "examples/stata/test_native.do",
    "examples/stata/test_regression_schema.do",
    "verification/run_all.do", "verification/regressions.do",
    "verification/compare_regressions.do", "verification/summaries.do",
    "verification/check_regression_log_and_tex.py",
    "verification/check_summary_log_and_tex.py",
]
if (ROOT / "LICENSE").is_file():
    relative.append("LICENSE")
for name in names:
    relative.append(f"examples/stata/{name}.do")
    relative += [f"examples/stata/output/{name}{s}" for s in
                 [".dta", ".tex", "-preview.pdf", "-preview.tex"]]
files = [ROOT / p for p in sorted(relative)]
for p in files:
    if not p.is_file():
        raise RuntimeError(f"Missing publication file: {p.relative_to(ROOT)}")
    if p.suffix in [".md", ".py", ".do", ".ado", ".json", ".yaml", ".tex", ".txt"]:
        content = p.read_text(encoding="utf-8")
        if re.search(r"(?<![A-Za-z0-9])(?:[A-Za-z]:[/\\]|/(?:Users|home|mnt|Volumes|opt|usr|tmp)/|\\\\[A-Za-z0-9_.-]+\\)", content):
            raise RuntimeError(f"Machine-specific path in {p.relative_to(ROOT)}")
    if p.suffix == ".md":
        for target in re.findall(r"\]\(([^)]+)\)", p.read_text(encoding="utf-8")):
            if "://" not in target:
                resolved = (p.parent / target.split("#")[0]).resolve()
                if not resolved.is_relative_to(ROOT) or not resolved.is_file():
                    raise RuntimeError(f"Broken or external reference in {p.relative_to(ROOT)}: {target}")
    if p.suffix == ".tex" and not p.stem.endswith("-preview") and p.name != "wrapper.tex":
        if not p.with_suffix(".dta").is_file():
            raise RuntimeError(f"Table lacks companion DTA: {p.name}")
ado = ROOT / "scripts/fdr_sharpened_qvalues.ado"
if hashlib.sha256(ado.read_bytes()).hexdigest() != "c77dc31b35165551ea21e8fd67e666628451e8f50ea6a56ff115f55a954c4184":
    raise RuntimeError("Bundled FDR implementation differs from documented provenance")
# Every source file must be intentionally included, not silently omitted as stale.
selected = set(files)
for p in ROOT.rglob("*"):
    if p.relative_to(ROOT).parts[0] in {"skills", "skill-tests", "data", "_archive", "archive"}:
        continue
    if any(part in {".git", "dist", ".venv", "__pycache__", ".codex", ".agents"}
           for part in p.relative_to(ROOT).parts):
        continue
    if p.is_file() and p.suffix in [".md", ".py", ".do", ".ado", ".yaml", ".json"]:
        generated_report = (p.parent == ROOT / "verification" / "output" and
                            p.name in {"COMPARISON.md", "SUMMARY_COMPARISON.md"})
        if p not in selected and "visual-qa" not in p.parts and not generated_report:
            raise RuntimeError(f"Unreviewed source file outside publication list: {p.relative_to(ROOT)}")
hashes = "\n".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(ROOT).as_posix()}"
                   for p in files) + "\n"
manifest = ROOT / "SHA256SUMS"
manifest.write_text(hashes, encoding="utf-8", newline="\n")
files.append(manifest)
dest = ROOT / "dist" / "tex-tables.zip"
dest.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in sorted(files):
        info = zipfile.ZipInfo((Path("tex-tables") / p.relative_to(ROOT)).as_posix(), (1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        z.writestr(info, p.read_bytes())
digest = hashlib.sha256(dest.read_bytes()).hexdigest()
dest.with_suffix(".zip.sha256").write_text(f"{digest}  {dest.name}\n", encoding="utf-8")
print(f"Packaged {len(files)} files: {dest}")
print(f"SHA-256: {digest}")
