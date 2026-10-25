#!/usr/bin/env python3
"""Summarize one or more case result.json files for meltano/sdk #3520 verification."""
from __future__ import annotations

import json
import sys

for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        d = json.load(fh)
    p = d["packages"]
    m = d["meta"]
    print(f"### {path}")
    print(
        f"singer-sdk={p['singer_sdk']['version']} simpleeval={p['simpleeval']['version']} "
        f"python={m['python_version']} all_pass={d['all_pass']}"
    )
    for r in d["results"]:
        print(f"- {r['key']}: {r['status']}  expr={r['expr']}")
        if r["error"]:
            print(f"    error: {r['error']}")
            for c in r["error_chain"]:
                print(f"    caused by: {c}")
        if r["check_error"]:
            print(f"    check: {r['check_error']}")
        elif r["output_field"] is not None:
            print(f"    output: {r['output_field']!r}")
        if r["schema_error"]:
            print(f"    schema_error: {r['schema_error']}")
        for w in r["warnings"]:
            print(f"    warning: {w}")
    print()
