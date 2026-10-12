from pymongo import ReturnDocument

from smarthome_api.db import get_database
from smarthome_api.repositories.mongo.mapping import (
    strip_identity,
    to_api,
)


class RoomRepository:
    """
    MongoDB backed rooms.

    Every read is scoped by house_id, so a room can never
    be reached from the wrong house.
    """

    @property
    def collection(self):
        return get_database().rooms

    # ==================================================
    # READ
    # ==================================================

    def get_all(
        self,
        house_id: str,
    ):

        return [
            to_api(document)
            for document in self.collection.find(
                {"house_id": house_id}
            )
        ]

    def get_by_id(
        self,
        house_id: str,
        room_id: str,
    ):

        return to_api(
            self.collection.find_one(
                {
                    "_id": room_id,
                    "house_id": house_id,
                }
            )
        )

    # ==================================================
    # CREATE
    # ==================================================

    def create(
        self,
        room: dict,
    ):

        room_id = room["id"]

        # Room IDs must be unique.
        if self.collection.find_one({"_id": room_id}):
            return None

        # Every room must belong to a house.
        if not room.get("house_id"):
            return None

        document = {
            "_id": room_id,
            "name": room["name"],
            "house_id": room["house_id"],
        }

        self.collection.insert_one(document)

        return to_api(document)

    # ==================================================
    # UPDATE
    # ==================================================

    def update(
        self,
        house_id: str,
        room_id: str,
        data: dict,
    ):

        # ID and house relationship are not changed here.
        update_data = strip_identity(
            data,
            also={"house_id"},
        )

        if not update_data:
            return self.get_by_id(
                house_id,
                room_id,
            )

        return to_api(
            self.collection.find_one_and_update(
                {
                    "_id": room_id,
                    "house_id": house_id,
                },
                {"$set": update_data},
                return_document=ReturnDocument.AFTER,
            )
        )

    # ==================================================
    # DELETE
    # ==================================================

    def delete(
        self,
        house_id: str,
        room_id: str,
    ):

        return to_api(
            self.collection.find_one_and_delete(
                {
                    "_id": room_id,
                    "house_id": house_id,
                }
            )
        )
