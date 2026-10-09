from datetime import datetime, timedelta, timezone

def command_for(commands, state, **kwargs):
    return commands.create(
        "house-test",
        "lamp-test",
        state,
        **kwargs,
    )


def test_new_command_is_accepted(commands, lamp):
    command = command_for(commands, {"brightness": 80})

    assert command["status"] == "accepted"
    assert command["request_id"]
    assert command["completed_at"] is None


def test_repeated_request_id_returns_the_original(commands, lamp):
    first = command_for(
        commands,
        {"power": True},
        request_id="same-request",
    )

    second = command_for(
        commands,
        {"power": True},
        request_id="same-request",
    )

    assert first["id"] == second["id"]


def test_dispatch_records_the_time(commands, lamp):
    command = command_for(commands, {"power": True})

    dispatched = commands.mark_dispatched(
        command["id"]
    )

    assert dispatched["status"] == "dispatched"
    assert dispatched["dispatched_at"] is not None


def test_report_confirms_a_matching_command(commands, lamp):
    command = command_for(commands, {"brightness": 80})
    commands.mark_dispatched(command["id"])

    confirmed = commands.confirm_matching(
        "house-test",
        "lamp-test",
        {"brightness": 80, "power": True},
    )

    assert [c["status"] for c in confirmed] == ["acked"]


def test_report_leaves_an_unmet_command_open(commands, lamp):
    command = command_for(commands, {"brightness": 80})
    commands.mark_dispatched(command["id"])

    confirmed = commands.confirm_matching(
        "house-test",
        "lamp-test",
        {"brightness": 40},
    )

    assert confirmed == []

    still_open = commands.get_recent(
        "house-test",
        "lamp-test",
    )[0]

    assert still_open["status"] == "dispatched"


def test_overdue_commands_expire(commands, lamp):
    command = command_for(
        commands,
        {"power": True},
        expiry_seconds=-1,
    )

    assert commands.expire_overdue() == 1

    expired = commands.get_recent(
        "house-test",
        "lamp-test",
    )[0]

    assert expired["status"] == "expired"


def test_failed_publish_is_recorded(commands, lamp):
    command = command_for(commands, {"power": True})

    failed = commands.mark_failed(
        command["id"],
        "publish_failed",
    )

    assert failed["status"] == "failed"
    assert failed["error"] == "publish_failed"
