from smarthome_api.repositories.device_repository import DeviceRepository
from smarthome_api.repositories.house_repository import HouseRepository
from smarthome_api.repositories.room_repository import RoomRepository


device_repository = DeviceRepository()
house_repository = HouseRepository()
room_repository = RoomRepository()


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