from smarthome_api.repositories.factory import (
    device_repository,
    event_repository,
    house_repository,
    room_repository,
)
from smarthome_api.services.threshold_service import evaluate_threshold
from smarthome_api.websocket.manager import manager


# ==================================================
# DEVICES
# ==================================================

def get_all_devices(house_id: str):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    return device_repository.get_all(house_id)


def get_device(
    house_id: str,
    device_id: str,
):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    return device_repository.get_by_id(
        house_id,
        device_id,
    )


def get_devices_by_room(
    house_id: str,
    room_id: str,
):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    room = room_repository.get_by_id(
        house_id,
        room_id,
    )

    if room is None:
        return None

    return device_repository.get_by_room(
        house_id,
        room_id,
    )


def create_device(device: dict):

    house_id = device.get("house_id")

    if not house_id:
        return None

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    return device_repository.create(device)


def delete_device(
    house_id: str,
    device_id: str,
):

    return device_repository.delete(
        house_id,
        device_id,
    )


# ==================================================
# DEVICE UPDATE
# ==================================================

def update_device(
    house_id: str,
    device_id: str,
    data: dict,
):

    return device_repository.update(
        house_id,
        device_id,
        data,
    )


# ==================================================
# DEVICE STATE
# ==================================================

def update_device_state(
    house_id: str,
    device_id: str,
    state: dict,
):
    """
    Update the requested device state capabilities.

    Every requested capability must:
    1. Exist in the device capabilities.
    2. Have the correct data type.
    3. Respect min/max constraints.

    Nothing is written to the repository until
    all requested capabilities have passed validation.
    """

    device = device_repository.get_by_id(
        house_id,
        device_id,
    )

    if device is None:
        return None

    capabilities = device.get(
        "capabilities",
        {},
    )

    # --------------------------------------------------
    # Validate every requested capability first.
    # --------------------------------------------------

    for name, value in state.items():

        capability = capabilities.get(name)

        # Capability is not supported by this device.
        if capability is None:
            raise ValueError(
                f"Device does not support capability '{name}'"
            )

        capability_type = capability.get("type")

        # --------------------------------------------------
        # Validate type
        # --------------------------------------------------

        if capability_type == "integer":

            # bool is a subclass of int in Python,
            # so explicitly reject bool.
            if (
                not isinstance(value, int)
                or isinstance(value, bool)
            ):
                raise ValueError(
                    f"'{name}' must be an integer"
                )

        elif capability_type == "number":

            if (
                not isinstance(value, (int, float))
                or isinstance(value, bool)
            ):
                raise ValueError(
                    f"'{name}' must be a number"
                )

        elif capability_type == "boolean":

            if not isinstance(value, bool):
                raise ValueError(
                    f"'{name}' must be a boolean"
                )

        else:
            raise ValueError(
                f"Unsupported capability type "
                f"'{capability_type}' for '{name}'"
            )

        # --------------------------------------------------
        # Validate minimum
        # --------------------------------------------------

        minimum = capability.get("min")

        if minimum is not None and value < minimum:
            raise ValueError(
                f"'{name}' cannot be less than {minimum}"
            )

        # --------------------------------------------------
        # Validate maximum
        # --------------------------------------------------

        maximum = capability.get("max")

        if maximum is not None and value > maximum:
            raise ValueError(
                f"'{name}' cannot be greater than {maximum}"
            )

    # --------------------------------------------------
    # All validation passed.
    # Now persist the state.
    # --------------------------------------------------

    return device_repository.update_state(
        house_id,
        device_id,
        state,
    )
async def handle_device_state(
    house_id: str,
    device_id: str,
    state: dict,
):
    device = device_repository.get_by_id(
        house_id,
        device_id,
    )

    if device is None:
        return None

    updated_device = update_device_state(
        house_id,
        device_id,
        state,
    )

    event_repository.record_event(
        house_id,
        device_id,
        "state_change",
        state,
    )

    event_repository.record_history(
        house_id,
        device_id,
        state,
    )

    thresholds = device.get(
        "thresholds",
        {},
    )

    alerts = []

    for name, value in state.items():

        threshold = thresholds.get(name)

        if threshold is None:
            continue

        alert = evaluate_threshold(
            value,
            threshold,
        )

        if not alert:
            continue

        notification_message = threshold.get(
            "notification_message"
        )

        if notification_message:
            notification_message = notification_message.format(
                event=name,
                value=value,
                device_name=device.get("name"),
                room_name=device.get("room_id"),
            )

        alerts.append(
            {
                "capability": name,
                "value": value,
                "notification_message": notification_message,
            }
        )

    # Broadcast the accepted state to connected clients.
    await manager.broadcast(
        house_id,
        {
            "type": "device_state",
            "device_id": device_id,
            "state": state,
        },
    )

    return {
        "accepted": True,
        "device": updated_device,
        "alerts": alerts,
    }
# ==================================================
# DEVICE STATUS
# ==================================================

def update_device_status(
    house_id: str,
    device_id: str,
    status: dict,
):

    return device_repository.update_status(
        house_id,
        device_id,
        status,
    )


# ==================================================
# DEVICE ↔ ROOM
# ==================================================

def assign_device_to_room(
    house_id: str,
    device_id: str,
    room_id: str,
):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    device = device_repository.get_by_id(
        house_id,
        device_id,
    )

    if device is None:
        return False

    room = room_repository.get_by_id(
        house_id,
        room_id,
    )

    if room is None:
        return False

    return device_repository.assign_room(
        house_id,
        device_id,
        room_id,
    )


def unassign_device_from_room(
    house_id: str,
    device_id: str,
):

    device = device_repository.get_by_id(
        house_id,
        device_id,
    )

    if device is None:
        return None

    return device_repository.unassign_room(
        house_id,
        device_id,
    )




async def handle_device_event(
    house_id: str,
    device_id: str,
    event: str,
    value,
):
    device = device_repository.get_by_id(
        house_id,
        device_id,
    )

    if device is None:
        print(
            f"Ignoring MQTT event: "
            f"device '{device_id}' does not exist"
        )
        return None

    capabilities = device.get("capabilities", {})

    if event not in capabilities:
        print(
            f"Ignoring MQTT event: "
            f"device '{device_id}' does not support '{event}'"
        )
        return None

    # Validate the event value using existing
    # capability validation.
    try:
        updated_device = update_device_state(
            house_id,
            device_id,
            {event: value},
        )
    except ValueError as exc:
        print(
            f"Ignoring MQTT event: "
            f"invalid value for '{event}': {exc}"
        )
        return None

    event_repository.record_event(
        house_id,
        device_id,
        "device_event",
        {
            "event": event,
            "value": value,
        },
    )

    event_repository.record_history(
        house_id,
        device_id,
        {event: value},
    )

    # Get threshold configuration
    thresholds = device.get("thresholds", {})
    threshold = thresholds.get(event)

    alert = False
    notification_message = None

    # Evaluate threshold if one is configured
    if threshold is not None:
        alert = evaluate_threshold(
            value,
            threshold,
        )

        # Build dynamic notification message
        notification_message = threshold.get(
            "notification_message"
        )

        if alert and notification_message:
            notification_message = notification_message.format(
                event=event,
                value=value,
                device_name=device.get("name"),
                room_name=device.get("room_id"),
            )

    # Broadcast every accepted event
    await manager.broadcast(
        house_id,
        {
            "type": "device_event",
            "device_id": device_id,
            "event": event,
            "value": value,
            "alert": alert,
            "notification_message": notification_message,
        },
    )

    return {
        "accepted": True,
        "alert": alert,
        "device": updated_device,
        "event": event,
        "value": value,
        "notification_message": notification_message,
    }
