from fastapi import APIRouter, HTTPException

from smarthome_api.schemas.room import (
    RoomCreate,
    RoomResponse,
)

from smarthome_api.schemas.device import DeviceResponse

from smarthome_api.services.room_service import (
    create_room,
    delete_room,
    get_all_rooms,
    get_room,
)

from smarthome_api.services.device_service import (
    get_devices_by_room,
)


router = APIRouter(
    prefix="/api/v1/houses/{house_id}/rooms",
    tags=["Rooms"],
)


# ==================================================
# ROOMS
# ==================================================

@router.get(
    "",
    response_model=list[RoomResponse],
)
async def get_rooms(
    house_id: str,
):

    rooms = get_all_rooms(house_id)

    if rooms is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return rooms


@router.get(
    "/{room_id}",
    response_model=RoomResponse,
)
async def get_room_by_id(
    house_id: str,
    room_id: str,
):

    room = get_room(
        house_id,
        room_id,
    )

    if room is None:
        raise HTTPException(
            status_code=404,
            detail="Room not found",
        )

    return room


@router.post(
    "",
    response_model=RoomResponse,
    status_code=201,
)
async def create_new_room(
    house_id: str,
    room: RoomCreate,
):

    result = create_room(
        house_id,
        room.model_dump(),
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return result


@router.delete(
    "/{room_id}",
)
async def remove_room(
    house_id: str,
    room_id: str,
):

    result = delete_room(
        house_id,
        room_id,
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="Room not found",
        )

    return {
        "message": "Room deleted",
        "room": result,
    }


# ==================================================
# DEVICES IN ROOM
# ==================================================

@router.get(
    "/{room_id}/devices",
    response_model=list[DeviceResponse],
)
async def get_devices_in_room(
    house_id: str,
    room_id: str,
):

    devices = get_devices_by_room(
        house_id,
        room_id,
    )

    if devices is None:
        raise HTTPException(
            status_code=404,
            detail="House or room not found",
        )

    return devices