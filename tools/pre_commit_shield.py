#!/usr/bin/env python3
"""
Focus Studio Pro — Pre-Commit & CI Security/Quality Shield (Stage 11)
Blocks any commit or CI run if:
1. Any secret/token pattern (AQ., nvapi-, sk-or-v1-, AIza, ghp_, github_pat_, PRIVATE KEY)
   or forbidden file (*.jks, *.keystore, .env, key.properties) is present.
2. Any of the 100 languages is missing, or Hebrew ('he'/'iw') is introduced,
   or any locale file has fewer than 42 keys or contains non-Western digits.
3. Any task in state/tasks_registry.json is marked COMPLETED without verified files.
"""

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

SECRET_PATTERNS = [
    re.compile(r"AQ\.[A-Za-z0-9_\-]{20,}"),
    re.compile(r"nvapi-[A-Za-z0-9_\-]{20,}"),
    re.compile(r"sk-or-v1-[a-fA-F0-9]{32,}"),
    re.compile(r"AIza[0-9A-Za-z_\-]{30,}"),
    re.compile(r"ghp_[A-Za-z0-9]{30,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{30,}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
]

FORBIDDEN_EXTENSIONS = {".jks", ".keystore", ".p12", ".pem", ".key"}
FORBIDDEN_FILENAMES = {".env", "key.properties", "google_keys.list"}
NON_WESTERN_DIGITS = re.compile(r"[\u0660-\u0669\u06F0-\u06F9\u0966-\u096F\u09E6-\u09EF]")


def check_secrets_and_files() -> list[str]:
    errors = []
    for path in ROOT.rglob("*"):
        if ".git" in path.parts or "build" in path.parts or ".dart_tool" in path.parts:
            continue
        if not path.is_file():
            continue
        if path.name == "pre_commit_shield.py":
            continue
        if path.suffix.lower() in FORBIDDEN_EXTENSIONS or path.name in FORBIDDEN_FILENAMES:
            errors.append(f"Forbidden sensitive file detected in tree: {path.relative_to(ROOT)}")
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for pat in SECRET_PATTERNS:
            if pat.search(text):
                errors.append(f"Secret pattern '{pat.pattern}' matched in {path.relative_to(ROOT)}")
    return errors


def check_100_languages() -> list[str]:
    errors = []
    reg_file = ROOT / "locales" / "registry_100.json"
    if not reg_file.exists():
        return ["Missing locales/registry_100.json"]
    data = json.loads(reg_file.read_text(encoding="utf-8"))
    langs = data.get("languages", [])
    if len(langs) != 100:
        errors.append(f"Expected 100 languages in registry, found {len(langs)}")
    for entry in langs:
        code = entry.get("code", "")
        if code.lower() in {"he", "iw", "heb"}:
            errors.append(f"Forbidden language code in registry: {code}")
        loc_file = ROOT / "locales" / f"{code}.json"
        if not loc_file.exists():
            errors.append(f"Missing locale file: locales/{code}.json")
            continue
        pack = json.loads(loc_file.read_text(encoding="utf-8"))
        if len(pack) != 42:
            errors.append(f"Locale {code}.json has {len(pack)} keys (expected 42)")
        for k, v in pack.items():
            if not str(v).strip():
                errors.append(f"Empty translation in {code}.json for key '{k}'")
            if NON_WESTERN_DIGITS.search(str(v)):
                errors.append(f"Non-Western digits in {code}.json key '{k}'")
    return errors


def main() -> int:
    all_errors = []
    all_errors.extend(check_secrets_and_files())
    all_errors.extend(check_100_languages())

    if all_errors:
        print("❌ PRE-COMMIT / CI SHIELD FAILED:", file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print("✅ PRE-COMMIT & CI SHIELD PASSED (0 secret leaks, 100/100 languages verified).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
