import pytest
from pymongo import MongoClient

from smarthome_api.config import settings
from smarthome_api.repositories.mongo import (
    CommandRepository,
    DeviceRepository,
    EventRepository,
    HouseRepository,
)


TEST_DATABASE = "smarthome_test"

HISTORY_RETENTION_SECONDS = 60 * 60 * 24 * 90

COLLECTIONS_TO_CLEAR = (
    "houses",
    "rooms",
    "devices",
    "device_state",
    "commands",
    "events",
)


@pytest.fixture(scope="session", autouse=True)
def database():
    """
    A database of its own, created for the run and dropped
    afterwards.

    The name is swapped on the settings object rather than
    through the environment, so these tests do not change
    which backend the rest of the suite uses.
    """

    original = settings.mongodb_db
    settings.mongodb_db = TEST_DATABASE

    client = MongoClient(settings.mongodb_uri)
    client.drop_database(TEST_DATABASE)

    db = client[TEST_DATABASE]

    db.create_collection(
        "state_history",
        timeseries={
            "timeField": "observed_at",
            "metaField": "meta",
            "granularity": "seconds",
        },
        expireAfterSeconds=HISTORY_RETENTION_SECONDS,
    )

    db.commands.create_index("request_id", unique=True)

    yield db

    client.drop_database(TEST_DATABASE)
    client.close()

    settings.mongodb_db = original


@pytest.fixture(autouse=True)
def clean(database):
    for name in COLLECTIONS_TO_CLEAR:
        database[name].delete_many({})

    yield


@pytest.fixture
def devices():
    return DeviceRepository()


@pytest.fixture
def commands():
    return CommandRepository()


@pytest.fixture
def events():
    return EventRepository()


@pytest.fixture
def house():
    return HouseRepository().create(
        {
            "id": "house-test",
            "name": "Test House",
            "address": "Somewhere 1",
            "postal_code": "2815",
            "city": "Gjovik",
        }
    )


@pytest.fixture
def lamp(house, devices):
    return devices.create(
        {
            "id": "lamp-test",
            "house_id": "house-test",
            "room_id": "room-test",
            "name": "Test Lamp",
            "type": "light",
            "capabilities": {
                "power": {"type": "boolean"},
                "brightness": {
                    "type": "integer",
                    "min": 0,
                    "max": 100,
                },
            },
            "state": {"power": False, "brightness": 0},
        }
    )
