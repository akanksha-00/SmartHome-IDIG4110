"""
The validators are only useful if they actually reject
things, so each case here is a mistake we expect to make.
"""

import pytest
from pymongo.errors import WriteError

from smarthome_api.db.validators import VALIDATORS


@pytest.fixture(autouse=True)
def validators(database):
    for name, validator in VALIDATORS.items():
        if name not in database.list_collection_names():
            database.create_collection(name)

        database.command(
            "collMod",
            name,
            validator=validator,
            validationLevel="moderate",
            validationAction="error",
        )

    yield


def test_device_without_a_house_is_rejected(database):
    with pytest.raises(WriteError):
        database.devices.insert_one(
            {"_id": "orphan", "name": "No house"}
        )


def test_unknown_command_status_is_rejected(database):
    with pytest.raises(WriteError):
        database.commands.insert_one(
            {
                "_id": "c1",
                "request_id": "r1",
                "house_id": "h1",
                "device_id": "d1",
                "status": "probably_fine",
            }
        )


def test_wrong_type_is_rejected(database):
    with pytest.raises(WriteError):
        database.rooms.insert_one(
            {
                "_id": "r1",
                "house_id": 123,
                "name": "Kitchen",
            }
        )


def test_misspelled_field_is_rejected(database):
    """
    houseId instead of house_id. The field drifts, the
    required one is missing, and the write fails here
    rather than in a query that silently returns nothing.
    """

    with pytest.raises(WriteError):
        database.events.insert_one(
            {
                "_id": "e1",
                "houseId": "h1",
                "device_id": "d1",
                "type": "state_change",
            }
        )


def test_valid_documents_are_accepted(database):
    database.commands.insert_one(
        {
            "_id": "c2",
            "request_id": "r2",
            "house_id": "h1",
            "device_id": "d1",
            "status": "accepted",
        }
    )

    assert database.commands.find_one({"_id": "c2"})
