import json
from pathlib import Path


class DeviceRepository:

    def __init__(self):
        self.file_path = (
            Path(__file__).resolve().parents[3]
            / "data"
            / "devices.json"
        )

    # ==================================================
    # INTERNAL JSON OPERATIONS
    # ==================================================

    def _load(self) -> list[dict]:

        with self.file_path.open(
            "r",
            encoding="utf-8",
        ) as file:
            return json.load(file)

    def _save(
        self,
        devices: list[dict],
    ) -> None:

        with self.file_path.open(
            "w",
            encoding="utf-8",
        ) as file:
            json.dump(
                devices,
                file,
                indent=2,
                ensure_ascii=False,
            )

    # ==================================================
    # READ
    # ==================================================

    def get_all(
        self,
        house_id: str,
    ):

        devices = self._load()

        return [
            device
            for device in devices
            if device.get("house_id") == house_id
        ]

    def get_by_id(
        self,
        house_id: str,
        device_id: str,
    ):

        devices = self._load()

        for device in devices:

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            return device

        return None

    def get_by_room(
        self,
        house_id: str,
        room_id: str,
    ):

        devices = self._load()

        return [
            device
            for device in devices
            if device.get("house_id") == house_id
            and device.get("room_id") == room_id
        ]

    # ==================================================
    # CREATE
    # ==================================================

    def create(
        self,
        device: dict,
    ):

        devices = self._load()

        device_id = device["id"]

        # Device IDs must be unique.
        if any(
            existing["id"] == device_id
            for existing in devices
        ):
            return None

        # Every device must belong to a house.
        if not device.get("house_id"):
            return None

        # Room assignment is optional.
        if "room_id" not in device:
            device["room_id"] = None

        devices.append(device)

        self._save(devices)

        return device

    # ==================================================
    # DELETE
    # ==================================================

    def delete(
        self,
        house_id: str,
        device_id: str,
    ):

        devices = self._load()

        for index, device in enumerate(devices):

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            removed_device = devices.pop(index)

            self._save(devices)

            return removed_device

        return None

    # ==================================================
    # GENERAL UPDATE
    # ==================================================

    def update(
        self,
        house_id: str,
        device_id: str,
        data: dict,
    ):

        devices = self._load()

        for device in devices:

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            # Relationships are managed separately.
            update_data = {
                key: value
                for key, value in data.items()
                if key not in {
                    "id",
                    "house_id",
                    "room_id",
                }
            }

            device.update(update_data)

            self._save(devices)

            return device

        return None

    # ==================================================
    # DEVICE STATE
    # ==================================================

    def update_state(
        self,
        house_id: str,
        device_id: str,
        state: dict,
    ):

        devices = self._load()

        for device in devices:

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            device.setdefault(
                "state",
                {},
            )

            device["state"].update(state)

            self._save(devices)

            return device

        return None

    # ==================================================
    # DEVICE STATUS
    # ==================================================

    def update_status(
        self,
        house_id: str,
        device_id: str,
        status: dict,
    ):

        devices = self._load()

        for device in devices:

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            device.setdefault(
                "status",
                {},
            )

            device["status"].update(status)

            self._save(devices)

            return device

        return None

    # ==================================================
    # DEVICE ↔ ROOM
    # ==================================================

    def assign_room(
        self,
        house_id: str,
        device_id: str,
        room_id: str,
    ):

        devices = self._load()

        for device in devices:

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            device["room_id"] = room_id

            self._save(devices)

            return device

        return None

    def unassign_room(
        self,
        house_id: str,
        device_id: str,
    ):

        devices = self._load()

        for device in devices:

            if device.get("id") != device_id:
                continue

            if device.get("house_id") != house_id:
                return None

            device["room_id"] = None

            self._save(devices)

            return device

        return None
def patch(
    self,
    house_id: str,
    device_id: str,
    data: dict,
):
    devices = self._load()

    for device in devices:

        if device.get("id") != device_id:
            continue

        if device.get("house_id") != house_id:
            return None

        device.update(data)

        self._save(devices)

        return device

    return None