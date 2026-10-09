import json

from smarthome_api.mqtt.client import publish
from smarthome_api.mqtt.topics import command_topic
from smarthome_api.repositories.factory import (
    command_repository,
    device_repository,
)


def validate_device_command(
    house_id: str,
    device_id: str,
    state: dict,
):
    if not state:
        raise ValueError(
        "Command state cannot be empty"
    )
    device = device_repository.get_by_id(
        house_id,
        device_id,
    )

    if device is None:
        raise ValueError(
            f"Device '{device_id}' does not exist"
        )

    capabilities = device.get("capabilities", {})

    for key, value in state.items():

        capability = capabilities.get(key)

        if capability is None:
            raise ValueError(
                f"Device '{device_id}' does not support '{key}'"
            )

        value_type = capability.get("type")

        if value_type == "boolean":
            if not isinstance(value, bool):
                raise ValueError(
                    f"'{key}' must be a boolean"
                )

        elif value_type == "integer":
            if not isinstance(value, int) or isinstance(value, bool):
                raise ValueError(
                    f"'{key}' must be an integer"
                )

        elif value_type == "number":
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                raise ValueError(
                    f"'{key}' must be a number"
                )

        minimum = capability.get("min")
        maximum = capability.get("max")

        if minimum is not None and value < minimum:
            raise ValueError(
                f"'{key}' cannot be less than {minimum}"
            )

        if maximum is not None and value > maximum:
            raise ValueError(
                f"'{key}' cannot be greater than {maximum}"
            )

    return device


def send_device_command(
    house_id: str,
    device_id: str,
    state: dict,
    request_id: str | None = None,
):
    validate_device_command(
        house_id,
        device_id,
        state,
    )

    # Recorded before publishing, so a command that is sent
    # but never confirmed still leaves a trace. "Published"
    # and "executed" are different facts and the status
    # keeps them apart.
    command = command_repository.create(
        house_id,
        device_id,
        state,
        request_id=request_id,
    )

    topic = command_topic(
        house_id,
        device_id,
    )

    payload = json.dumps({
        "state": state
    })

    try:
        publish(
            topic,
            payload,
        )

    except Exception as exc:
        # A command that never reached the broker must not
        # look pending. Recording the failure is what keeps
        # "we tried" and "it was sent" apart.
        if command is not None:
            command_repository.mark_failed(
                command["id"],
                "publish_failed",
            )

        raise

    if command is not None:
        command_repository.mark_dispatched(command["id"])

    # Record what was asked for. The device has not
    # answered yet, so the twin is knowingly out of sync
    # until a matching report arrives over MQTT. This is
    # what lets the interface say "turning on" rather than
    # claiming the device already obeyed.
    device_repository.set_desired(
        house_id,
        device_id,
        state,
    )

    return {
        "house_id": house_id,
        "device_id": device_id,
        "topic": topic,
        "state": state,
        "command_id": command["id"] if command else None,
        "request_id": (
            command["request_id"] if command else None
        ),
    }