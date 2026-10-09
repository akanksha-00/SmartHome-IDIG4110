def test_create_returns_device_with_state(devices, lamp):
    assert lamp["id"] == "lamp-test"
    assert lamp["state"] == {"power": False, "brightness": 0}
    assert lamp["in_sync"] is True


def test_state_is_stored_outside_the_device(devices, database, lamp):
    stored = database.devices.find_one({"_id": "lamp-test"})

    assert "state" not in stored
    assert database.device_state.find_one(
        {"_id": "lamp-test"}
    )["reported"] == {"power": False, "brightness": 0}


def test_device_is_not_reachable_from_another_house(devices, lamp):
    assert devices.get_by_id(
        "house-other",
        "lamp-test",
    ) is None


def test_update_state_merges(devices, lamp):
    devices.update_state(
        "house-test",
        "lamp-test",
        {"brightness": 60},
    )

    device = devices.get_by_id(
        "house-test",
        "lamp-test",
    )

    assert device["state"] == {
        "power": False,
        "brightness": 60,
    }


def test_command_then_report_closes_the_gap(devices, lamp):
    devices.set_desired(
        "house-test",
        "lamp-test",
        {"brightness": 80},
    )

    device = devices.get_by_id(
        "house-test",
        "lamp-test",
    )

    assert device["desired"] == {"brightness": 80}
    assert device["in_sync"] is False

    devices.update_state(
        "house-test",
        "lamp-test",
        {"brightness": 80},
    )

    device = devices.get_by_id(
        "house-test",
        "lamp-test",
    )

    assert device["in_sync"] is True


def test_seq_counts_reports(devices, lamp):
    for value in (10, 20, 30):
        devices.update_state(
            "house-test",
            "lamp-test",
            {"brightness": value},
        )

    assert database_seq() == 4


def database_seq():
    from smarthome_api.db import get_database

    # create() writes the initial state, so the counter
    # starts at one before any report arrives.
    return get_database().device_state.find_one(
        {"_id": "lamp-test"}
    )["seq"]


def test_delete_removes_the_state_document(devices, database, lamp):
    devices.delete("house-test", "lamp-test")

    assert database.device_state.find_one(
        {"_id": "lamp-test"}
    ) is None
