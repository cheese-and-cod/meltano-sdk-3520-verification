"""Minimal reproduction for meltano/sdk#3520 (record property named ``datetime``).

Run, e.g.:
  uv run --no-project --python 3.12 --with singer-sdk==0.54.9 python minimal_repro_3520.py
"""
import logging

from singer_sdk.mapper import PluginMapper

EXPR = "datetime.datetime.utcnow().isoformat()"


def run(with_datetime_property: bool) -> None:
    schema = {"type": "object", "properties": {"id": {"type": "integer"}}}
    record = {"id": 1}
    if with_datetime_property:
        schema["properties"]["datetime"] = {"type": "string"}
        record["datetime"] = "2026-04-01"

    mapper = PluginMapper(
        plugin_config={"stream_maps": {"mystream": {"loaded_at": EXPR}}},
        logger=logging.getLogger("repro"),
    )
    mapper.register_raw_stream_schema("mystream", schema, ["id"])
    label = "with 'datetime' property" if with_datetime_property else "without 'datetime' property"
    try:
        print(f"{label}: {mapper.stream_maps['mystream'][0].transform(record)}")
    except Exception as ex:
        print(f"{label}: {type(ex).__name__}: {ex}")
        print(f"  caused by: {type(ex.__cause__).__module__}.{type(ex.__cause__).__name__}: {ex.__cause__}")


run(with_datetime_property=False)
run(with_datetime_property=True)
