from smarthome_api.repositories.factory import (
    device_repository,
    house_repository,
    room_repository,
)


def get_all_rooms(house_id: str):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    return room_repository.get_all(house_id)


def get_room(
    house_id: str,
    room_id: str,
):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    return room_repository.get_by_id(
        house_id,
        room_id,
    )


def create_room(
    house_id: str,
    room: dict,
):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    room_data = {
        "id": room["id"],
        "name": room["name"],
        "house_id": house_id,
    }

    return room_repository.create(room_data)


def delete_room(
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

    # Devices are not deleted.
    # They simply become unassigned.
    room_devices = device_repository.get_by_room(
        house_id,
        room_id,
    )

    for device in room_devices:
        device["room_id"] = None

    return room_repository.delete(
        house_id,
        room_id,
    )