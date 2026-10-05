from smarthome_api.repositories.house_repository import HouseRepository
from smarthome_api.repositories.room_repository import RoomRepository
from smarthome_api.repositories.device_repository import DeviceRepository


house_repository = HouseRepository()
room_repository = RoomRepository()
device_repository = DeviceRepository()


def get_house_dashboard(house_id: str):

    house = house_repository.get_by_id(house_id)

    if house is None:
        return None

    rooms = room_repository.get_all(house_id)
    devices = device_repository.get_all(house_id)

    dashboard_rooms = []

    for room in rooms:

        room_devices = [
            device
            for device in devices
            if device.get("room_id") == room["id"]
        ]

        dashboard_rooms.append({
            "id": room["id"],
            "name": room["name"],
            "devices": room_devices,
        })

    unassigned_devices = [
        device
        for device in devices
        if device.get("room_id") is None
    ]

    return {
        "house": house,
        "rooms": dashboard_rooms,
        "unassigned_devices": unassigned_devices,
    }