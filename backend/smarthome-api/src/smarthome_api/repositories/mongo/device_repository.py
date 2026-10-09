from pymongo import ReturnDocument

from smarthome_api.db import get_database
from smarthome_api.repositories.mongo.mapping import (
    strip_identity,
    to_api,
    to_document,
)


class DeviceRepository:
    """
    MongoDB backed devices.

    Same methods and return shapes as the JSON repository.
    Every query is scoped by house_id, so a device is never
    reachable from the wrong house.
    """

    @property
    def collection(self):
        return get_database().devices

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
        device_id: str,
    ):

        return to_api(
            self.collection.find_one(
                {
                    "_id": device_id,
                    "house_id": house_id,
                }
            )
        )

    def get_by_room(
        self,
        house_id: str,
        room_id: str,
    ):

        return [
            to_api(document)
            for document in self.collection.find(
                {
                    "house_id": house_id,
                    "room_id": room_id,
                }
            )
        ]

    # ==================================================
    # CREATE
    # ==================================================

    def create(
        self,
        device: dict,
    ):

        document = to_document(device)

        # Device IDs must be unique.
        if self.collection.find_one({"_id": document["_id"]}):
            return None

        # Every device must belong to a house.
        if not document.get("house_id"):
            return None

        # Room assignment is optional.
        document.setdefault("room_id", None)

        self.collection.insert_one(document)

        return to_api(document)

    # ==================================================
    # DELETE
    # ==================================================

    def delete(
        self,
        house_id: str,
        device_id: str,
    ):

        return to_api(
            self.collection.find_one_and_delete(
                {
                    "_id": device_id,
                    "house_id": house_id,
                }
            )
        )

    # ==================================================
    # GENERAL UPDATE
    # ==================================================

    def update(
        self,
        house_id: str,
        device_id: str,
        data: dict,
    ):

        # Relationships are managed separately.
        update_data = strip_identity(
            data,
            also={"house_id", "room_id"},
        )

        if not update_data:
            return self.get_by_id(
                house_id,
                device_id,
            )

        return self._update(
            house_id,
            device_id,
            {"$set": update_data},
        )

    # ==================================================
    # DEVICE STATE
    # ==================================================

    def update_state(
        self,
        house_id: str,
        device_id: str,
        state: dict,
    ):
        """
        Merge into the existing state rather than replacing
        it, so a partial report does not erase capabilities
        the device did not mention.
        """

        return self._update(
            house_id,
            device_id,
            {
                "$set": {
                    f"state.{name}": value
                    for name, value in state.items()
                }
            },
        )

    # ==================================================
    # DEVICE STATUS
    # ==================================================

    def update_status(
        self,
        house_id: str,
        device_id: str,
        status: dict,
    ):

        return self._update(
            house_id,
            device_id,
            {
                "$set": {
                    f"status.{name}": value
                    for name, value in status.items()
                }
            },
        )

    # ==================================================
    # DEVICE - ROOM
    # ==================================================

    def assign_room(
        self,
        house_id: str,
        device_id: str,
        room_id: str,
    ):

        return self._update(
            house_id,
            device_id,
            {"$set": {"room_id": room_id}},
        )

    def unassign_room(
        self,
        house_id: str,
        device_id: str,
    ):

        return self._update(
            house_id,
            device_id,
            {"$set": {"room_id": None}},
        )

    # ==================================================
    # INTERNAL
    # ==================================================

    def _update(
        self,
        house_id: str,
        device_id: str,
        update: dict,
    ):
        """
        One place where the house scope is applied, so no
        update can reach a device in another house.
        """

        return to_api(
            self.collection.find_one_and_update(
                {
                    "_id": device_id,
                    "house_id": house_id,
                },
                update,
                return_document=ReturnDocument.AFTER,
            )
        )
