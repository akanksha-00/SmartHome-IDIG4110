"""
Check that the API behaves identically on both storage
backends.

    uv run python scripts/compare_backends.py

Every GET route is called against STORAGE_BACKEND=json and
again against STORAGE_BACKEND=mongo, and the responses are
compared. This is the evidence that replacing the storage
engine changed nothing the API promises.

Run `scripts/seed_db.py --reset` first. The two backends
hold separate copies of the data, so they only have the
same content immediately after seeding; anything written
to one afterwards makes the comparison meaningless.

Each backend runs in its own process, because the backend
is chosen when modules are first imported.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


# Values substituted into path parameters. They have to
# exist in both backends for the comparison to mean
# anything.
SAMPLE_IDS = {
    "house_id": "house-001",
    "room_id": "living-room",
    "device_id": "device-001",
}


def capture() -> dict:
    """
    Call every parameterless GET route and return the
    responses. Runs inside the child process.
    """

    from fastapi.testclient import TestClient

    from smarthome_api.main import app

    client = TestClient(app)

    results = {}

    # The OpenAPI schema is a stable way to enumerate
    # routes, including those behind nested routers.
    paths = app.openapi().get("paths", {})

    for template, operations in paths.items():

        if "get" not in operations:
            continue

        path = template

        # Fill in the path parameters we have samples for.
        for name, value in SAMPLE_IDS.items():
            path = path.replace(f"{{{name}}}", value)

        # Anything still parameterised cannot be called.
        if "{" in path:
            print(f"skipping {template}", file=sys.stderr)
            continue

        try:
            response = client.get(path)
        except Exception as exc:
            results[path] = {"error": repr(exc)}
            continue

        try:
            body = response.json()
        except ValueError:
            body = response.text

        results[path] = {
            "status": response.status_code,
            "body": body,
        }

    return results


def run_backend(backend: str) -> dict:
    """
    Run this script again with the backend selected, and
    read back what it captured.
    """

    env = dict(os.environ)
    env["STORAGE_BACKEND"] = backend

    # The application prints to stdout on startup, so the
    # result is handed over in a file rather than mixed
    # into that output.
    with tempfile.TemporaryDirectory() as directory:

        out_path = Path(directory) / "capture.json"

        completed = subprocess.run(
            [
                sys.executable,
                __file__,
                "--capture",
                str(out_path),
            ],
            capture_output=True,
            text=True,
            env=env,
            cwd=str(Path(__file__).resolve().parents[1]),
        )

        if completed.returncode != 0 or not out_path.exists():
            print(completed.stdout)
            print(completed.stderr, file=sys.stderr)
            raise SystemExit(
                f"capture failed for backend '{backend}'"
            )

        return json.loads(
            out_path.read_text(encoding="utf-8")
        )


def normalise(value):
    """
    Order is not part of the API contract for collections,
    so sort lists of records by id before comparing.
    """

    if isinstance(value, list):

        if all(
            isinstance(item, dict) and "id" in item
            for item in value
        ):
            return sorted(
                (normalise(item) for item in value),
                key=lambda item: item["id"],
            )

        return [normalise(item) for item in value]

    if isinstance(value, dict):
        return {
            key: normalise(item)
            for key, item in value.items()
        }

    return value


def main() -> None:

    json_results = run_backend("json")
    mongo_results = run_backend("mongo")

    paths = sorted(
        set(json_results) | set(mongo_results)
    )

    differences = 0

    for path in paths:

        left = normalise(json_results.get(path))
        right = normalise(mongo_results.get(path))

        if left == right:
            print(f"  same  {path}")
            continue

        differences += 1

        print(f"  DIFF  {path}")
        print(f"        json : {json.dumps(left)[:300]}")
        print(f"        mongo: {json.dumps(right)[:300]}")

    print()

    if differences:
        print(
            f"{differences} of {len(paths)} routes differ"
        )
        raise SystemExit(1)

    print(f"all {len(paths)} routes identical")


if __name__ == "__main__":

    if "--capture" in sys.argv:

        destination = Path(sys.argv[sys.argv.index("--capture") + 1])

        destination.write_text(
            json.dumps(capture()),
            encoding="utf-8",
        )

    else:
        main()
