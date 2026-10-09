"""
MongoDB connection handling.

One client for the process, created on first use and
reused afterwards. Nothing outside the repositories
should import from here.

The synchronous driver is used deliberately: the existing
services and repositories are synchronous, so this keeps
the storage swap a drop-in change. FastAPI runs
synchronous endpoints in a worker thread, so this does
not block the event loop there. The MQTT handlers are
async and do block briefly on each call, which is
acceptable at prototype scale; moving to the async driver
is recorded as future work.
"""

from pymongo import MongoClient
from pymongo.database import Database

from smarthome_api.config import settings


_client: MongoClient | None = None


def get_database() -> Database:
    """
    The database handle, for repositories.
    """

    global _client

    if _client is None:

        _client = MongoClient(
            settings.mongodb_uri,
            tz_aware=True,
        )

    return _client[settings.mongodb_db]


def close_database() -> None:
    """
    Close the connection. Used by tests and scripts.
    """

    global _client

    if _client is not None:
        _client.close()
        _client = None
