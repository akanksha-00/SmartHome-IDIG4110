from datetime import datetime, timezone

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

    What a device IS lives in `devices`; what it is DOING
    lives in `device_state`, one document per device. They
    are separated because the registry is almost static
    while state is rewritten on every report, and because
    the state document is where `reported` and `desired`
    can sit side by side.

    Reads compose the two back together, so callers still
    receive a device with a `state` field and cannot tell
    the difference.
    """

    @property
    def collection(self):
        return get_database().devices

    @property
    def state_collection(self):
        return get_database().device_state

    # ==================================================
    # READ
    # ==================================================

    def get_all(
        self,
        house_id: str,
    ):

        documents = list(
            self.collection.find({"house_id": house_id})
        )

        states = self._states_for(
            [document["_id"] for document in documents]
        )

        return [
            self._compose(document, states)
            for document in documents
        ]

    def get_by_id(
        self,
        house_id: str,
        device_id: str,
    ):

        document = self.collection.find_one(
            {
                "_id": device_id,
                "house_id": house_id,
            }
        )

        if document is None:
            return None

        return self._compose(
            document,
            self._states_for([device_id]),
        )

    def get_by_room(
        self,
        house_id: str,
        room_id: str,
    ):

        documents = list(
            self.collection.find(
                {
                    "house_id": house_id,
                    "room_id": room_id,
                }
            )
        )

        states = self._states_for(
            [document["_id"] for document in documents]
        )

        return [
            self._compose(document, states)
            for document in documents
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

        # State is stored separately, not on the device.
        initial_state = document.pop("state", {})

        self.collection.insert_one(document)

        self._write_state(
            document["_id"],
            document["house_id"],
            initial_state,
        )

        return self.get_by_id(
            document["house_id"],
            document["_id"],
        )

    # ==================================================
    # DELETE
    # ==================================================

    def delete(
        self,
        house_id: str,
        device_id: str,
    ):

        removed = self.get_by_id(
            house_id,
            device_id,
        )

        if removed is None:
            return None

        self.collection.delete_one(
            {
                "_id": device_id,
                "house_id": house_id,
            }
        )

        self.state_collection.delete_one({"_id": device_id})

        return removed

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
        Record what the device reports.

        Merges into the existing state rather than
        replacing it, so a partial report does not erase
        capabilities the device did not mention.
        """

        exists = self.collection.find_one(
            {
                "_id": device_id,
                "house_id": house_id,
            },
            {"_id": 1},
        )

        if exists is None:
            return None

        self._write_state(
            device_id,
            house_id,
            state,
        )

        return self.get_by_id(
            house_id,
            device_id,
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

        document = self.collection.find_one_and_update(
            {
                "_id": device_id,
                "house_id": house_id,
            },
            update,
            return_document=ReturnDocument.AFTER,
        )

        if document is None:
            return None

        return self._compose(
            document,
            self._states_for([device_id]),
        )

    def _write_state(
        self,
        device_id: str,
        house_id: str,
        reported: dict,
    ) -> None:
        """
        Write what the device reported, creating the state
        document if this is the first report.

        `seq` counts updates from this device, so a stale
        message arriving after a reconnect can be
        recognised. `observed_at` is deliberately absent:
        the MQTT payload carries no device timestamp yet,
        and filling it in from the server clock would
        invent data.
        """

        self.state_collection.update_one(
            {"_id": device_id},
            {
                "$set": {
                    "house_id": house_id,
                    "received_at": datetime.now(timezone.utc),
                    **{
                        f"reported.{name}": value
                        for name, value in reported.items()
                    },
                },
                "$inc": {"seq": 1},
                "$setOnInsert": {
                    "desired": {},
                    "in_sync": True,
                },
            },
            upsert=True,
        )

    def _states_for(
        self,
        device_ids: list[str],
    ) -> dict[str, dict]:
        """
        All state documents for these devices, in one query
        rather than one per device.
        """

        if not device_ids:
            return {}

        return {
            document["_id"]: document
            for document in self.state_collection.find(
                {"_id": {"$in": device_ids}}
            )
        }

    def _compose(
        self,
        document: dict,
        states: dict,
    ) -> dict:
        """
        Put the device and its state back together, so
        callers see the same shape as before the split.
        """

        device = to_api(document)

        state = states.get(device["id"], {})

        device["state"] = state.get("reported", {})

        return device
