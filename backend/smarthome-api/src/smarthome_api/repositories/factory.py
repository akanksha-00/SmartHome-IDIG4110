"""
Chooses the storage backend.

STORAGE_BACKEND=json  keeps the file based repositories.
STORAGE_BACKEND=mongo uses MongoDB.

Both implementations expose the same methods and return
the same shapes, so services import from here and never
know which one they got. Switching the variable and
comparing API responses is how the storage change is
verified.
"""

from smarthome_api.config import settings

if settings.storage_backend == "mongo":

    from smarthome_api.repositories.mongo import (
        DeviceRepository,
        EventRepository,
        HouseRepository,
        RoomRepository,
    )

else:

    from smarthome_api.repositories.device_repository import (
        DeviceRepository,
    )
    from smarthome_api.repositories.event_repository import (
        EventRepository,
    )
    from smarthome_api.repositories.house_repository import (
        HouseRepository,
    )
    from smarthome_api.repositories.room_repository import (
        RoomRepository,
    )


# One instance each, shared by the services.
device_repository = DeviceRepository()
event_repository = EventRepository()
house_repository = HouseRepository()
room_repository = RoomRepository()


__all__ = [
    "device_repository",
    "event_repository",
    "house_repository",
    "room_repository",
]
