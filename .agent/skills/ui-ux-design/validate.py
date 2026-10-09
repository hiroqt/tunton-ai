#!/usr/bin/env python3
"""Validate the Design Motion reference catalog and its files."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
EXPECTED=76
CATEGORIES={"content","feedback","forms","interaction","motion","navigation","visual"}
data=json.loads((ROOT/"patterns.json").read_text(encoding="utf-8"))
assert len(data)==EXPECTED, f"Expected {EXPECTED} catalog entries, found {len(data)}"
assert len({x["slug"] for x in data})==EXPECTED, "Duplicate slugs found"
assert {x["category"] for x in data}==CATEGORIES, "Category set mismatch"
for item in data:
 p=ROOT/"patterns"/"design-motion"/item["category"]/f"{item['slug']}.md"
 assert p.is_file(), f"Missing pattern file: {p}"
 t=p.read_text(encoding="utf-8")
 assert f"# {item['title']}" in t, f"Title mismatch: {p}"
 assert item["source"] in t, f"Source missing: {p}"
files=list((ROOT/"patterns"/"design-motion").glob("*/*.md"))
assert len(files)==EXPECTED, f"Expected {EXPECTED} Design Motion files, found {len(files)}"
for name in ["SKILL.md","README.md","PATTERN-INDEX.md","SOURCES.md","patterns.json"]: assert (ROOT/name).is_file(), f"Missing package file: {name}"
for name in ["SKILL.md","README.md","PATTERN-INDEX.md","SOURCES.md"]: assert "76" in (ROOT/name).read_text(encoding="utf-8"), f"Updated count not found in {name}"
print(f"PASS: {EXPECTED}/{EXPECTED} Design Motion catalog entries have matching files.")
print("PASS: all 7 categories present; slugs unique; source/title mappings valid.")
print("PASS: package indexes and provenance files reference the updated count.")
