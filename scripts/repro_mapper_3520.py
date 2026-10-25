#!/usr/bin/env python3
"""Minimal reproduction script for meltano/sdk issue #3520.

Evaluates stream map expressions through the SDK's real mapping pipeline
(PluginMapper -> CustomStreamMap -> _eval -> simpleeval), one expression per
stream map, and records per-expression results, warnings, errors and the
inferred output schema type.

Compatible with singer-sdk v0.53.x and current (same API surface as
tests/core/test_mapper.py::_run_transform in both).

Exit codes:
  0 = all expressions evaluated and passed their checks
  1 = at least one expression failed (evaluation error or check failure)
"""
from __future__ import annotations

import argparse
import datetime as dt
import importlib.metadata
import json
import logging
import os
import platform
import sys
import time
import warnings

STREAM_NAME = "issue_stream"

INPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": "integer"},
        "create_date": {"type": "string"},
        "owner_email": {"type": ["string", "null"]},
        "user": {"type": "object"},
    },
}

INPUT_RECORD = {
    "id": 1,
    "create_date": "2026-04-01",
    "owner_email": "a@example.com",
    "user": {"name": "Alice", "age": 30},
}

# (key, expression, validator name) -- validators are defined below.
EXPRESSIONS = [
    ("issue_original_utcnow", "datetime.datetime.utcnow().isoformat()", "iso_datetime_string"),
    ("issue_example_year", "int(datetime.date.fromisoformat(create_date).year)", "equals_2026"),
    ("control_field_ref", "id", "equals_1"),
    ("control_string_method", "owner_email.split('@')[1]", "equals_example_com"),
    ("helper_json_dumps", "json.dumps(user, default=str)", "equals_expected_json"),
]

EXPECTED_JSON = json.dumps(INPUT_RECORD["user"], default=str)


def enable_shadow_datetime_field() -> None:
    """Add a record field named ``datetime`` so the bare name in expressions
    resolves to the record value instead of the SDK-provided module.

    Tests the name-shadowing hypothesis for the exact exception quoted in
    issue #3520 (``AttributeDoesNotExist: Attribute 'datetime' does not
    exist``), which simpleeval's module rejection cannot produce.
    """
    INPUT_RECORD["datetime"] = "2026-04-01"
    INPUT_SCHEMA["properties"]["datetime"] = {"type": "string"}


def dist_version(dist_name: str) -> str | None:
    try:
        return importlib.metadata.version(dist_name)
    except importlib.metadata.PackageNotFoundError:
        return None


def validate_iso_datetime(value: object) -> None:
    if not isinstance(value, str):
        raise AssertionError(f"expected ISO datetime string, got {type(value).__name__}: {value!r}")
    parsed = dt.datetime.fromisoformat(value)
    if not (2020 <= parsed.year <= 2030):
        raise AssertionError(f"parsed year out of plausible range: {parsed!r}")


def validate_equals(value: object, expected: object) -> None:
    if value != expected:
        raise AssertionError(f"expected {expected!r}, got {value!r}")


VALIDATORS = {
    "iso_datetime_string": validate_iso_datetime,
    "equals_2026": lambda v: validate_equals(v, 2026),
    "equals_1": lambda v: validate_equals(v, 1),
    "equals_example_com": lambda v: validate_equals(v, "example.com"),
    "equals_expected_json": lambda v: validate_equals(v, EXPECTED_JSON),
}


def fmt_warning(w: warnings.WarningMessage) -> str:
    return f"{w.category.__name__}: {w.message}"


def run_expression(expr_key: str, expr: str, validator_name: str) -> dict:
    """Evaluate one expression through a dedicated PluginMapper/stream map."""
    import singer_sdk.mapper as sm

    result = {
        "key": expr_key,
        "expr": expr,
        "status": None,
        "error": None,
        "error_chain": [],
        "check_error": None,
        "output_field": None,
        "passthrough_id_kept": None,
        "inferred_type": None,
        "schema_error": None,
        "warnings": [],
    }

    mapper = sm.PluginMapper(
        plugin_config={"stream_maps": {STREAM_NAME: {"out_field": expr}}},
        logger=logging.getLogger("repro-3520"),
    )
    mapper.register_raw_stream_schema(STREAM_NAME, INPUT_SCHEMA, ["id"])
    stream_map = mapper.stream_maps[STREAM_NAME][0]

    try:
        t_schema = stream_map.transformed_schema
        result["inferred_type"] = (t_schema or {}).get("properties", {}).get("out_field")
    except Exception as ex:  # schema inference must not mask evaluation results
        result["schema_error"] = f"{type(ex).__name__}: {ex}"

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        try:
            out = stream_map.transform(dict(INPUT_RECORD))
        except Exception as ex:
            result["status"] = "eval_error"
            result["error"] = f"{type(ex).__module__}.{type(ex).__name__}: {ex}"
            # The SDK wraps simpleeval errors in MapExpressionError; keep the
            # full chain so the underlying simpleeval exception is on record.
            chain = []
            seen = {id(ex)}
            cur = ex
            while True:
                cur = cur.__cause__ or cur.__context__
                if cur is None or id(cur) in seen:
                    break
                seen.add(id(cur))
                chain.append(f"{type(cur).__module__}.{type(cur).__name__}: {cur}")
            result["error_chain"] = chain
    result["warnings"] = [fmt_warning(w) for w in caught]

    if result["status"] is None:
        result["output_field"] = out.get("out_field") if isinstance(out, dict) else None
        result["passthrough_id_kept"] = isinstance(out, dict) and out.get("id") == INPUT_RECORD["id"]
        try:
            VALIDATORS[validator_name](result["output_field"])
            result["status"] = "pass"
        except (AssertionError, ValueError, TypeError) as ex:
            result["status"] = "check_fail"
            result["check_error"] = str(ex)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="path for the JSON result file")
    parser.add_argument(
        "--shadow-datetime-field",
        action="store_true",
        help="add a record field named 'datetime' to test the name-shadowing hypothesis",
    )
    args = parser.parse_args()

    if args.shadow_datetime_field:
        enable_shadow_datetime_field()

    import singer_sdk
    import simpleeval
    import singer_sdk.mapper as sm

    now_local = dt.datetime.now().astimezone()
    meta = {
        "script": os.path.abspath(__file__),
        "executed_at_local": now_local.isoformat(),
        "tz_local": time.tzname,
        "utc_offset": now_local.utcoffset().total_seconds() if now_local.utcoffset() else None,
        "python_version": platform.python_version(),
        "python_impl": platform.python_implementation(),
        "platform": platform.platform(),
        "executable": sys.executable,
        "cwd": os.getcwd(),
        "argv": sys.argv,
        "shadow_datetime_field": args.shadow_datetime_field,
    }
    packages = {
        "singer_sdk": {
            "version": dist_version("singer-sdk"),
            "module_file": singer_sdk.__file__,
            "mapper_file": sm.__file__,
            "inside_venv": str(singer_sdk.__file__).startswith(sys.prefix),
        },
        "simpleeval": {
            "version": dist_version("simpleeval"),
            "module_file": simpleeval.__file__,
            "inside_venv": str(simpleeval.__file__).startswith(sys.prefix),
        },
        "python_requires_note": "all cases use the same interpreter/patch version",
    }

    results = [run_expression(k, e, v) for k, e, v in EXPRESSIONS]
    all_pass = all(r["status"] == "pass" for r in results)

    payload = {"meta": meta, "packages": packages, "results": results, "all_pass": all_pass}
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=False)

    print(f"singer-sdk {packages['singer_sdk']['version']} ({packages['singer_sdk']['module_file']})")
    print(f"simpleeval {packages['simpleeval']['version']} ({packages['simpleeval']['module_file']})")
    print(f"python {meta['python_version']} tz={meta['tz_local']}")
    for r in results:
        line = f"[{r['status']:^11}] {r['key']}: {r['expr']}"
        print(line)
        if r["error"]:
            print(f"    error: {r['error']}")
            for c in r["error_chain"]:
                print(f"    caused by: {c}")
        if r["check_error"]:
            print(f"    check: {r['check_error']}")
        if r["output_field"] is not None:
            print(f"    output: {r['output_field']!r}")
        if r["inferred_type"] is not None:
            print(f"    inferred type: {r['inferred_type']}")
        for w in r["warnings"]:
            print(f"    warning: {w}")
    print(f"ALL_PASS={all_pass}")
    print(f"RESULT_JSON={os.path.abspath(args.out)}")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
