"""
Measure what history costs and how fast it is to read.

    uv run python scripts/measure_storage.py

Runs in a database of its own, which is dropped afterwards.
Nothing touches the development data.

Three questions:
  1. What does a time series collection save over an
     ordinary one holding the same readings?
  2. What does downsampling to hourly aggregates save?
  3. How long does a typical history query take?
"""

import random
import statistics
import time
from datetime import datetime, timedelta, timezone

from pymongo import ASCENDING, MongoClient

from smarthome_api.config import settings


MEASURE_DB = "smarthome_measure"

DEVICES = 20
DAYS = 7
READINGS_PER_HOUR = 60

METRICS = ("temperature_c", "humidity_pct", "brightness")


def readings():
    """
    One week of a small house reporting every minute.
    """

    start = datetime.now(timezone.utc) - timedelta(days=DAYS)

    for device in range(DEVICES):

        device_id = f"device-{device:03d}"
        metric = METRICS[device % len(METRICS)]
        value = 20.0

        for step in range(DAYS * 24 * READINGS_PER_HOUR):

            value += random.uniform(-0.3, 0.3)

            yield {
                "meta": {
                    "device_id": device_id,
                    "house_id": "house-001",
                    "metric": metric,
                },
                "value": round(value, 2),
                "observed_at": start
                + timedelta(minutes=step),
                "received_at": start
                + timedelta(minutes=step),
                "time_source": "backend",
            }


def size_of(db, name):
    """
    $collStats rather than the deprecated collStats command.

    Two sizes are reported because they answer different
    questions: `size` is the logical size of the documents,
    `storageSize` is what is actually on disk after
    compression. A time series collection wins on the
    second, not the first.
    """

    stats = next(
        db[name].aggregate(
            [{"$collStats": {"storageStats": {}}}]
        )
    )["storageStats"]

    return {
        "docs": db[name].count_documents({}),
        "logical_mb": stats.get("size", 0) / 1_048_576,
        "stored_mb": stats.get("storageSize", 0) / 1_048_576,
    }


def timed(fn, runs=5):
    times = []

    for _ in range(runs):
        start = time.perf_counter()
        fn()
        times.append((time.perf_counter() - start) * 1000)

    return statistics.median(times)


def main():

    client = MongoClient(settings.mongodb_uri)
    client.drop_database(MEASURE_DB)
    db = client[MEASURE_DB]

    db.create_collection(
        "timeseries",
        timeseries={
            "timeField": "observed_at",
            "metaField": "meta",
            "granularity": "seconds",
        },
    )

    db.create_collection("plain")

    batch = []
    total = 0

    for reading in readings():

        batch.append(reading)

        if len(batch) == 5000:
            db.timeseries.insert_many(batch)
            db.plain.insert_many(
                [dict(r) for r in batch]
            )
            total += len(batch)
            batch = []

    if batch:
        db.timeseries.insert_many(batch)
        db.plain.insert_many([dict(r) for r in batch])
        total += len(batch)

    db.plain.create_index(
        [
            ("meta.device_id", ASCENDING),
            ("observed_at", ASCENDING),
        ]
    )

    # Hourly averages, the shape history would be kept in
    # once raw readings have expired.
    db.timeseries.aggregate(
        [
            {
                "$group": {
                    "_id": {
                        "device": "$meta.device_id",
                        "metric": "$meta.metric",
                        "hour": {
                            "$dateTrunc": {
                                "date": "$observed_at",
                                "unit": "hour",
                            }
                        },
                    },
                    "mean": {"$avg": "$value"},
                    "min": {"$min": "$value"},
                    "max": {"$max": "$value"},
                }
            },
            {"$out": "hourly"},
        ]
    )

    # Storage size only moves after a checkpoint; without
    # this the on-disk figures read as zero.
    try:
        client.admin.command("fsync")
    except Exception:
        pass

    ts = size_of(db, "timeseries")
    plain = size_of(db, "plain")
    hourly = size_of(db, "hourly")

    device = "device-005"

    latest = timed(
        lambda: list(
            db.timeseries.find(
                {"meta.device_id": device}
            )
            .sort("observed_at", -1)
            .limit(200)
        )
    )

    day = datetime.now(timezone.utc) - timedelta(days=1)

    range_query = timed(
        lambda: list(
            db.timeseries.find(
                {
                    "meta.device_id": device,
                    "observed_at": {"$gte": day},
                }
            )
        )
    )

    plain_latest = timed(
        lambda: list(
            db.plain.find({"meta.device_id": device})
            .sort("observed_at", -1)
            .limit(200)
        )
    )

    print()
    print(f"{DEVICES} devices, {DAYS} days, one reading per minute")
    print(f"{total:,} readings")
    print()
    print(
        f"{'collection':<14}{'documents':>12}"
        f"{'logical MB':>12}{'on disk MB':>12}{'bytes/reading':>15}"
    )

    for name, stats in (
        ("time series", ts),
        ("plain", plain),
        ("hourly means", hourly),
    ):
        per = (
            stats["logical_mb"] * 1_048_576 / stats["docs"]
            if stats["docs"]
            else 0
        )

        on_disk = (
            f"{stats['stored_mb']:.1f}"
            if stats["stored_mb"]
            else "not yet"
        )
        print(
            f"{name:<14}{stats['docs']:>12,}"
            f"{stats['logical_mb']:>12.1f}"
            f"{on_disk:>12}{per:>15.0f}"
        )

    # Compared on logical size, which is available
    # immediately and is what the data actually weighs.
    saved = 1 - ts["logical_mb"] / plain["logical_mb"]
    downsampled = 1 - hourly["logical_mb"] / ts["logical_mb"]

    print()
    print(f"time series vs plain : {saved:.0%} smaller")
    print(f"hourly vs raw        : {downsampled:.0%} smaller")
    print()
    print(f"{'query':<34}{'median ms':>10}")
    print(f"{'last 200 points (time series)':<34}{latest:>10.1f}")
    print(f"{'last 200 points (plain+index)':<34}{plain_latest:>10.1f}")
    print(f"{'one day of readings':<34}{range_query:>10.1f}")

    client.drop_database(MEASURE_DB)
    client.close()


if __name__ == "__main__":
    main()
