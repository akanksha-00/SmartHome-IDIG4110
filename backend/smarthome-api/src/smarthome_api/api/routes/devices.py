from fastapi import APIRouter, HTTPException

from smarthome_api.schemas.mqtt import DeviceCommand

from smarthome_api.services.device_command_service import (
    send_device_command,
)

from smarthome_api.schemas.device import (
    DeviceCapabilityUpdate,
    DeviceCreate,
    DeviceResponse,
    DeviceUpdate,
)

from smarthome_api.services.device_service import (
    assign_device_to_room,
    create_device,
    delete_device,
    get_all_devices,
    get_device,
    unassign_device_from_room,
    update_device,
    update_device_state,
)


router = APIRouter(
    prefix="/api/v1/houses/{house_id}/devices",
    tags=["Devices"],
)


# ==================================================
# DEVICES
# ==================================================

@router.get(
    "",
    response_model=list[DeviceResponse],
    response_model_exclude_none=True,
)
async def get_devices(
    house_id: str,
):
    result = get_all_devices(house_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return result


# ==================================================
# CREATE DEVICE
# ==================================================

@router.post(
    "",
    response_model=DeviceResponse,
    response_model_exclude_none=True,
    status_code=201,
)
async def create_new_device(
    house_id: str,
    device: DeviceCreate,
):
    device_data = device.model_dump()

    # The URL determines the house.
    device_data["house_id"] = house_id

    result = create_device(device_data)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return result


# ==================================================
# DEVICE COMMAND
# ==================================================

@router.post(
    "/{device_id}/command",
)
async def send_command(
    house_id: str,
    device_id: str,
    command: DeviceCommand,
):
    """
    Send a command to a device through MQTT.

    Example:

    {
        "state": {
            "power": true,
            "brightness": 70
        }
    }

    FastAPI validates the command and publishes it to:

    smarthome/{house_id}/{device_id}/command

    The device should then report its actual state
    through the MQTT state topic.
    """

    try:
        return send_device_command(
            house_id=house_id,
            device_id=device_id,
            state=command.state,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        )


# ==================================================
# GET DEVICE BY ID
# ==================================================

@router.get(
    "/{device_id}",
    response_model=DeviceResponse,
    response_model_exclude_none=True,
)
async def get_device_by_id(
    house_id: str,
    device_id: str,
):
    result = get_device(
        house_id,
        device_id,
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Device not found",
        )

    return result


# ==================================================
# PUT — DEVICE METADATA
# ==================================================

@router.put(
    "/{device_id}",
    response_model=DeviceResponse,
    response_model_exclude_none=True,
)
async def update_existing_device(
    house_id: str,
    device_id: str,
    update: DeviceUpdate,
):
    """
    Update relatively stable device metadata.

    Examples:
    - name
    - manufacturer
    - model
    - manufactured_year
    - installed_year
    - installer
    """

    result = update_device(
        house_id,
        device_id,
        update.model_dump(
            exclude_none=True
        ),
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Device not found",
        )

    return result


# ==================================================
# PATCH — DEVICE STATE
# ==================================================

@router.patch(
    "/{device_id}",
    response_model=DeviceResponse,
    response_model_exclude_none=True,
)
async def patch_device_state(
    house_id: str,
    device_id: str,
    updates: list[DeviceCapabilityUpdate],
):
    """
    Update one or more device capabilities.

    Example:

    [
        {
            "name": "speed",
            "value": 4
        }
    ]
    """

    state = {}

    for update in updates:

        if update.name in state:
            raise HTTPException(
                status_code=400,
                detail=f"Duplicate capability '{update.name}'",
            )

        state[update.name] = update.value

    try:
        result = update_device_state(
            house_id,
            device_id,
            state,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Device not found",
        )

    return result


# ==================================================
# DELETE DEVICE
# ==================================================

@router.delete(
    "/{device_id}",
)
async def remove_device(
    house_id: str,
    device_id: str,
):
    result = delete_device(
        house_id,
        device_id,
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Device not found",
        )

    return {
        "message": "Device deleted",
        "device": result,
    }


# ==================================================
# DEVICE ↔ ROOM
# ==================================================

@router.put(
    "/{device_id}/room/{room_id}",
    response_model=DeviceResponse,
    response_model_exclude_none=True,
)
async def assign_device(
    house_id: str,
    device_id: str,
    room_id: str,
):
    result = assign_device_to_room(
        house_id,
        device_id,
        room_id,
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    if result is False:
        raise HTTPException(
            status_code=404,
            detail="Device or room not found",
        )

    return result


@router.delete(
    "/{device_id}/room",
    response_model=DeviceResponse,
    response_model_exclude_none=True,
)
async def unassign_device(
    house_id: str,
    device_id: str,
):
    result = unassign_device_from_room(
        house_id,
        device_id,
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Device not found",
        )

    return result
print("DEVICE ROUTER LOADED")