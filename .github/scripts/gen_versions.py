#!/usr/bin/env python3
"""Build a deployed-content manifest from Jekyll's _site (no source HTML changes)."""
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "_site")
BLOCK = re.compile(r"<!--[\s\S]*?-->|/\*[\s\S]*?\*/")
DECL = re.compile(r"^\s*(?:const|let|var)\s+APP_VERSION\s*=\s*['\"]?v?(\d+)['\"]?(?=[\s;,)]|$)", re.M)
TITLE = re.compile(r"<title\b[^>]*>([\s\S]*?)</title>", re.I)
TITLE_VERSION = re.compile(r"\bv(\d{1,4})\b", re.I)

def parse(raw):
    source = BLOCK.sub("", raw.decode("utf-8", "replace"))
    # Remove full-line comments and inline JS comments without changing declarations.
    source = "\n".join(line for line in source.splitlines() if not line.lstrip().startswith("//"))
    candidates = sorted(set(int(x) for x in DECL.findall(source)))
    tm = TITLE.search(source)
    tv = TITLE_VERSION.search(tm.group(1)) if tm else None
    title_number = int(tv.group(1)) if tv else None
    if len(candidates) > 1:
        return {"version": None, "source": "conflict", "candidates": candidates}
    if candidates:
        entry = {"version": candidates[0], "source": "app_version"}
        if title_number is not None and title_number != candidates[0]:
            entry["title_mismatch"] = True
            entry["title_version"] = title_number
        return entry
    if title_number is not None:
        return {"version": title_number, "source": "title"}
    return {"version": None, "source": "none"}

def main():
    if not ROOT.is_dir():
        raise SystemExit(f"Missing build directory: {ROOT}")
    files = {}
    for path in sorted(ROOT.rglob("*.html")):
        if path.name.lower() == "index.html":
            continue
        data = path.read_bytes()
        obj = parse(data)
        obj.update(sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
        files[path.relative_to(ROOT).as_posix()] = obj
    output = {
        "schema": 1,
        "repo": os.environ.get("GITHUB_REPOSITORY", "local"),
        "commit": os.environ.get("GITHUB_SHA", "local"),
        "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "files": files,
    }
    dest = ROOT / "versions.json"
    dest.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    assert json.loads(dest.read_text(encoding="utf-8"))["files"] == files
    print(f"Manifest: {len(files)} HTML files; conflicts: {sum(e['source']=='conflict' for e in files.values())}")

if __name__ == "__main__":
    main()
