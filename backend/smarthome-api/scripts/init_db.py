"""
Create the MongoDB collections and indexes.

Safe to run repeatedly: nothing is dropped and existing
collections are left alone.

    uv run python scripts/init_db.py

state_history must be created here rather than on first
write, because a time series collection cannot be
converted from an ordinary one later.
"""

import asyncio

from pymongo import ASCENDING, DESCENDING, AsyncMongoClient

from smarthome_api.config import settings


# Raw readings are kept for 90 days. Aggregates and
# incident evidence outlive them; see the retention
# policy in the data model documentation.
HISTORY_RETENTION_SECONDS = 60 * 60 * 24 * 90


async def main() -> None:

    client = AsyncMongoClient(settings.mongodb_uri)
    db = client[settings.mongodb_db]

    existing = await db.list_collection_names()

    print(f"Database: {settings.mongodb_db}")

    # ==================================================
    # TIME SERIES - must be created explicitly
    # ==================================================

    if "state_history" not in existing:

        await db.create_collection(
            "state_history",
            timeseries={
                "timeField": "observed_at",
                "metaField": "meta",
                "granularity": "seconds",
            },
            expireAfterSeconds=HISTORY_RETENTION_SECONDS,
        )

        print("created time series collection: state_history")

    else:
        print("state_history already exists, left alone")

    # ==================================================
    # INDEXES
    # ==================================================

    # Every query is scoped to one house, so house_id is
    # the first field of every compound index.

    await db.rooms.create_index(
        [("house_id", ASCENDING)],
        name="idx_rooms_by_house",
    )

    await db.devices.create_index(
        [("house_id", ASCENDING)],
        name="idx_devices_by_house",
    )

    await db.devices.create_index(
        [("house_id", ASCENDING), ("room_id", ASCENDING)],
        name="idx_devices_by_room",
    )

    # One state document per device: _id is the device id,
    # so uniqueness is free. This index serves
    # "what is currently out of sync in this house".
    await db.device_state.create_index(
        [("house_id", ASCENDING), ("in_sync", ASCENDING)],
        name="idx_state_diverging",
    )

    # The unique request_id is the whole duplicate
    # suppression mechanism: a repeated request fails to
    # insert instead of commanding the device twice.
    await db.commands.create_index(
        [("request_id", ASCENDING)],
        unique=True,
        name="uq_request_id",
    )

    await db.commands.create_index(
        [("house_id", ASCENDING), ("created_at", DESCENDING)],
        name="idx_commands_by_house",
    )

    await db.commands.create_index(
        [("status", ASCENDING), ("expires_at", ASCENDING)],
        name="idx_expiry_sweep",
    )

    await db.events.create_index(
        [("house_id", ASCENDING), ("observed_at", DESCENDING)],
        name="idx_events_by_house",
    )

    await db.events.create_index(
        [("device_id", ASCENDING), ("observed_at", DESCENDING)],
        name="idx_events_by_device",
    )

    print("indexes created")

    await client.close()


if __name__ == "__main__":
    asyncio.run(main())
