# Comment draft for meltano/sdk#3520

- Status: ready to post; **not posted yet**. Whether to close the issue is the maintainers' call.
- Evidence: [verification-results-2026-10-25.md](verification-results-2026-10-25.md)
- Minimal repro: [`scripts/minimal_repro_3520.py`](../scripts/minimal_repro_3520.py), run on 2026-10-25 against singer-sdk 0.54.9 and 0.53.5 (native Windows, uv-managed Python 3.12). The output below is from that run; without `-W ignore::DeprecationWarning`, Python 3.12 also prints the `utcnow` deprecation warning.
- The statements "works on 0.53.5 with simpleeval 1.0.3" and "same on current main" come from the version matrix (B1, E, S3 on WSL2 / Python 3.12.3), not from the minimal repro.

## Comment

````markdown
I tried to reproduce this. The exact error quoted here appears when **the record itself has a property named `datetime`**: record properties take precedence over the SDK's helper names in expressions, so `datetime` resolves to the property value instead of the module. This still happens on the latest release (0.54.9) and on current main.

<details>
<summary>Minimal repro</summary>

```python
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
```

```
uv run --no-project --python 3.12 --with singer-sdk==0.54.9 python repro.py
```

```
without 'datetime' property: {'id': 1, 'loaded_at': '2026-10-25T09:28:50.779453'}
with 'datetime' property: MapExpressionError: Failed to evaluate simpleeval expressions datetime.datetime.utcnow().isoformat().
  caused by: simpleeval.AttributeDoesNotExist: Attribute 'datetime' does not exist in expression 'datetime.datetime.utcnow().isoformat()'
```

(plus Python 3.12's `DeprecationWarning` for `utcnow`)
</details>

Without such a property, attribute access on the `datetime` helper works: the expression evaluates fine on 0.54.9 and main, and also on 0.53.5 with simpleeval 1.0.3 (the latest simpleeval at the time this was reported). So entries in `functions` do support dot access, and adding `datetime` to `names` wouldn't help if a record property is shadowing it.

There is a separate failure on 0.53.5: it has no upper bound on simpleeval, so a fresh install today pulls simpleeval >= 1.0.5, where `datetime.*` expressions fail with a different error (`FeatureNotAvailable: Sorry, modules are not allowed`). That one was fixed in #3595 (0.53.7 and 0.54.0+).

Full version matrix and logs: https://github.com/cheese-and-cod/meltano-sdk-3520-verification

Could you share:

1. the simpleeval version you had installed,
2. whether the stream has a property named `datetime`, and
3. if possible, a minimal (redacted) record, schema, and stream map config?

That would tell us which case this is. Happy to follow up from there.
````

## Why it is written this way

- **Lead with the name collision.** It is the only reproduced path that matches the quoted exception word for word, and it still happens on current releases, so a "fixed by #3595, OK to close?" comment would contradict the evidence.
- **Module rejection is a side note.** It explains `datetime.*` failures on 0.53.5 with new simpleeval, but with a different exception (`FeatureNotAvailable`), and it is already fixed.
- **Correct the issue's stated mechanism in one sentence.** The issue says `functions` entries cannot be used with dot access and suggests adding `datetime` to `names`. Both are contradicted by the measurements, and the suggested fix would not help with a shadowing property.
- **No workaround.** `docs/stream_maps.md` suggests `record['...']` for property names that collide with built-ins, but that reads the property value; it does not bring back the shadowed `datetime` module. Renaming the property upstream avoids the collision but was not separately verified as a workaround.
- **No judgment on bug vs. expected behavior.** Whether the collision deserves a docs note, a clearer error, or nothing is left to the maintainers.

## Before posting

- [ ] Re-check the issue for new comments or state changes.
- [ ] Confirm versions still match (0.54.9 is the latest release and main is `6d61a40` as of 2026-10-25); update the comment if newer releases exist.
- [ ] No @mentions; the questions to the reporter are enough.
- [ ] AI disclosure is not customary for comments in this repo (it is done with `Co-authored-by` on commits and PRs).

## After posting

| Reply | Next step |
|---|---|
| The stream has a `datetime` property | Name collision. Offer a small docs PR noting that record properties shadow helper names such as `datetime` and `json`. |
| No such property, simpleeval >= 1.0.5 | Module rejection. Suggest upgrading to >= 0.53.7; this is when proposing to close as fixed by #3595 makes sense. |
| Neither | Ask for a minimal reproduction. |
| No reply after 2–4 weeks | Post a short follow-up: the module-rejection path is fixed in 0.53.7+, and the issue can be reopened with a reproduction. Leave closing to the maintainers. |
