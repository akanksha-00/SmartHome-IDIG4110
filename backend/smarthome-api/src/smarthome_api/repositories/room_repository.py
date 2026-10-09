import json
from pathlib import Path


class RoomRepository:

    def __init__(self):
        self.file_path = (
            Path(__file__).resolve().parents[3]
            / "data"
            / "rooms.json"
        )

    # ==================================================
    # INTERNAL PERSISTENCE
    # ==================================================

    def _load(self) -> list[dict]:

        with self.file_path.open(
            "r",
            encoding="utf-8",
        ) as file:
            return json.load(file)

    def _save(
        self,
        rooms: list[dict],
    ) -> None:

        with self.file_path.open(
            "w",
            encoding="utf-8",
        ) as file:
            json.dump(
                rooms,
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

        rooms = self._load()

        return [
            room
            for room in rooms
            if room.get("house_id") == house_id
        ]

    def get_by_id(
        self,
        house_id: str,
        room_id: str,
    ):

        rooms = self._load()

        for room in rooms:

            if room.get("id") != room_id:
                continue

            if room.get("house_id") != house_id:
                return None

            return room

        return None

    # ==================================================
    # CREATE
    # ==================================================

    def create(
        self,
        room: dict,
    ):

        rooms = self._load()

        room_id = room["id"]

        # Room IDs must be unique.
        if any(
            existing["id"] == room_id
            for existing in rooms
        ):
            return None

        # Every room must belong to a house.
        if not room.get("house_id"):
            return None

        room_data = {
            "id": room_id,
            "name": room["name"],
            "house_id": room["house_id"],
        }

        rooms.append(room_data)

        self._save(rooms)

        return room_data

    # ==================================================
    # UPDATE
    # ==================================================

    def update(
        self,
        house_id: str,
        room_id: str,
        data: dict,
    ):

        rooms = self._load()

        for room in rooms:

            if room.get("id") != room_id:
                continue

            if room.get("house_id") != house_id:
                return None

            # ID and house relationship are not changed here.
            update_data = {
                key: value
                for key, value in data.items()
                if key not in {
                    "id",
                    "house_id",
                }
            }

            room.update(update_data)

            self._save(rooms)

            return room

        return None

    # ==================================================
    # DELETE
    # ==================================================

    def delete(
        self,
        house_id: str,
        room_id: str,
    ):

        rooms = self._load()

        for index, room in enumerate(rooms):

            if room.get("id") != room_id:
                continue

            if room.get("house_id") != house_id:
                return None

            removed_room = rooms.pop(index)

            self._save(rooms)

            return removed_room

        return None