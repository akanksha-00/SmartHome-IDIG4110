import json
import logging
from smarthome_api.mqtt.client import publish
from smarthome_api.mqtt.topics import command_topic
from smarthome_api.repositories.device_repository import DeviceRepository

logger = logging.getLogger("smarthome")
device_repository = DeviceRepository()


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
                    f"'{key}' must be a boolean; "
                    f"received {type(value).__name__}: {value!r}"
                )

        elif value_type == "integer":
            if not isinstance(value, int) or isinstance(value, bool):
                raise ValueError(
                    f"'{key}' must be an integer; "
                    f"received {type(value).__name__}: {value!r}"
                )

        elif value_type == "number":
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                raise ValueError(
                    f"'{key}' must be a number; "
                    f"received {type(value).__name__}: {value!r}"
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
):
    try:
        validate_device_command(
            house_id,
            device_id,
            state,
        )
    except ValueError as exc:
        logger.warning(
            "Device command rejected",
            extra={
                "event": "device_command_rejected",
                "details": {
                    "house_id": house_id,
                    "device_id": device_id,
                    "requested_fields": list(state.keys()),
                    "reason": str(exc),
                },
            },
        )
        raise
    topic = command_topic(
        house_id,
        device_id,
    )

    payload = json.dumps({
        "state": state
    })

    try:
        publish(topic, payload)
    except Exception:
        logger.exception(
            "Failed to publish device command",
            extra={
                "event": "device_command_publish_failed",
                "details": {
                    "house_id": house_id,
                    "device_id": device_id,
                    "requested_fields": list(state.keys()),
                },
            },
        )
        raise

    return {
        "house_id": house_id,
        "device_id": device_id,
        "topic": topic,
        "state": state,
    }