"""
Fails when the HTTP contract changes.

The Flutter app parses exactly what this API returns, so a
renamed field or a removed route breaks it at runtime rather
than at build time. This test turns that into a failing
check at the moment the change is made.

Only the shape is compared - routes, methods, field names
and types - not descriptions or examples, so wording can be
improved without anyone having to regenerate anything.

When a change is intentional:

    UPDATE_OPENAPI_SNAPSHOT=1 uv run pytest tests/test_openapi_contract.py

and commit the updated snapshot alongside the change, so the
contract moves visibly in review.
"""

import json
import os
from pathlib import Path

import pytest

from smarthome_api.main import app


SNAPSHOT = Path(__file__).parent / "openapi_snapshot.json"


def fingerprint(schema: dict) -> dict:
    """
    The parts of the schema a client actually depends on.
    """

    paths = {
        path: sorted(
            method
            for method in operations
            if method
            in {
                "get",
                "post",
                "put",
                "patch",
                "delete",
            }
        )
        for path, operations in schema.get("paths", {}).items()
    }

    models = {}

    components = schema.get("components", {}).get(
        "schemas", {}
    )

    for name, model in components.items():

        properties = model.get("properties", {})

        models[name] = {
            "fields": {
                field: describe(definition)
                for field, definition in properties.items()
            },
            "required": sorted(model.get("required", [])),
        }

    return {"paths": paths, "models": models}


def describe(definition: dict) -> str:
    """
    A field's type, reduced to something stable. References
    keep their target so a swapped model is noticed.
    """

    if "$ref" in definition:
        return definition["$ref"].rsplit("/", 1)[-1]

    if "anyOf" in definition:
        return "|".join(
            sorted(
                describe(option)
                for option in definition["anyOf"]
            )
        )

    return definition.get("type", "unknown")


def test_api_contract_is_unchanged():

    current = fingerprint(app.openapi())

    if os.environ.get("UPDATE_OPENAPI_SNAPSHOT"):
        SNAPSHOT.write_text(
            json.dumps(current, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        pytest.skip("snapshot updated")

    if not SNAPSHOT.exists():
        pytest.fail(
            "No snapshot yet. Create one with "
            "UPDATE_OPENAPI_SNAPSHOT=1 uv run pytest "
            "tests/test_openapi_contract.py"
        )

    expected = json.loads(
        SNAPSHOT.read_text(encoding="utf-8")
    )

    assert current["paths"] == expected["paths"], (
        "The set of routes or methods changed. If that was "
        "intended, regenerate the snapshot and say so in "
        "the pull request."
    )

    assert current["models"] == expected["models"], (
        "A request or response model changed shape. The "
        "frontend parses these. If that was intended, "
        "regenerate the snapshot."
    )
