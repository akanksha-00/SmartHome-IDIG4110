"""
Load the JSON fixtures into MongoDB.

    uv run python scripts/seed_db.py          # insert, skip existing
    uv run python scripts/seed_db.py --reset  # replace everything

The JSON files stay the source of the seed data, so the
two backends can be compared against identical content.
"""

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from pymongo import MongoClient

from smarthome_api.config import settings


DATA_DIR = Path(__file__).resolve().parents[1] / "data"

# file name -> collection name
SOURCES = {
    "houses.json": "houses",
    "rooms.json": "rooms",
    "devices.json": "devices",
}


def load(file_name: str) -> list[dict]:

    path = DATA_DIR / file_name

    if not path.exists():
        print(f"skipped {file_name}: not found")
        return []

    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def to_document(record: dict) -> dict:
    """
    The business id becomes _id, so there is one identity
    per record rather than two.
    """

    document = dict(record)
    document["_id"] = document.pop("id")

    return document


def seed_state(
    db,
    device_id: str,
    house_id: str,
    reported: dict,
) -> None:
    """
    Create the twin record for a seeded device.

    `reported` is what the fixture says the device last
    reported. `desired` starts empty, because nothing has
    been asked of it yet, which is why `in_sync` is true.
    """

    db.device_state.update_one(
        {"_id": device_id},
        {
            "$set": {
                "house_id": house_id,
                "reported": reported,
                "desired": {},
                "in_sync": True,
                "seq": 0,
                "received_at": datetime.now(timezone.utc),
            }
        },
        upsert=True,
    )


def main() -> None:

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--reset",
        action="store_true",
        help="delete existing documents first",
    )

    args = parser.parse_args()

    client = MongoClient(settings.mongodb_uri)
    db = client[settings.mongodb_db]

    print(f"Database: {settings.mongodb_db}")

    for file_name, collection_name in SOURCES.items():

        records = load(file_name)

        if not records:
            continue

        collection = db[collection_name]

        if args.reset:

            deleted = collection.delete_many({}).deleted_count
            print(f"{collection_name}: removed {deleted}")

            if collection_name == "devices":
                db.device_state.delete_many({})
                db.commands.delete_many({})
                db.events.delete_many({})

        inserted = 0
        skipped = 0

        for record in records:

            document = to_document(record)

            # A device's state belongs in device_state, not
            # on the device itself.
            state = (
                document.pop("state", {})
                if collection_name == "devices"
                else None
            )

            # Idempotent: re-running does not duplicate or
            # silently overwrite edited data.
            if collection.find_one({"_id": document["_id"]}):
                skipped += 1
                continue

            collection.insert_one(document)
            inserted += 1

            if state is not None:
                seed_state(
                    db,
                    document["_id"],
                    document["house_id"],
                    state,
                )

        print(
            f"{collection_name}: "
            f"inserted {inserted}, skipped {skipped}"
        )

    client.close()


if __name__ == "__main__":
    main()
