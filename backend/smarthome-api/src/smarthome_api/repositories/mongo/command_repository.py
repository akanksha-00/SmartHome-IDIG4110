import uuid
from datetime import datetime, timedelta, timezone

from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from smarthome_api.repositories.mongo.mapping import to_api
from smarthome_api.db import get_database


# A command that has not been confirmed within this window
# is treated as expired rather than left pending forever.
DEFAULT_EXPIRY_SECONDS = 30


class CommandRepository:

    @property
    def collection(self):
        return get_database().commands

    def create(
        self,
        house_id: str,
        device_id: str,
        state: dict,
        request_id: str | None = None,
        issued_by: str | None = None,
        expiry_seconds: int = DEFAULT_EXPIRY_SECONDS,
    ):
        """
        Record a command before it is published.

        `request_id` is unique. The caller may supply one so
        that a retry of the same request is recognised
        instead of commanding the device twice; when none is
        given a fresh one is generated, which makes the
        command unique by definition.
        """

        created_at = datetime.now(timezone.utc)

        document = {
            "_id": str(uuid.uuid4()),
            "request_id": request_id or str(uuid.uuid4()),
            "house_id": house_id,
            "device_id": device_id,
            "state": state,
            "status": "accepted",
            "issued_by": issued_by,
            "created_at": created_at,
            "expires_at": created_at
            + timedelta(seconds=expiry_seconds),
            "dispatched_at": None,
            "completed_at": None,
            "error": None,
        }

        try:
            self.collection.insert_one(document)
        except DuplicateKeyError:
            return to_api(
                self.collection.find_one(
                    {"request_id": document["request_id"]}
                )
            )

        return to_api(document)

    def mark_dispatched(
        self,
        command_id: str,
    ):
        return self._set_status(
            command_id,
            "dispatched",
            {"dispatched_at": datetime.now(timezone.utc)},
        )

    def mark_failed(
        self,
        command_id: str,
        error: str,
    ):
        return self._set_status(
            command_id,
            "failed",
            {
                "completed_at": datetime.now(timezone.utc),
                "error": error,
            },
        )

    def confirm_matching(
        self,
        house_id: str,
        device_id: str,
        reported: dict,
    ):
        """
        Close the commands this report satisfies.

        A command is confirmed when every value it asked for
        appears in what the device now reports. Matching on
        content rather than on an identifier is a
        consequence of the MQTT contract carrying no
        request id back; once it does, this becomes an exact
        lookup instead of a comparison.
        """

        if not reported:
            return []

        confirmed = []

        open_commands = self.collection.find(
            {
                "house_id": house_id,
                "device_id": device_id,
                "status": {
                    "$in": ["accepted", "dispatched"]
                },
            }
        )

        for command in list(open_commands):

            wanted = command.get("state") or {}

            satisfied = all(
                reported.get(name) == value
                for name, value in wanted.items()
            )

            if not satisfied:
                continue

            confirmed.append(
                self._set_status(
                    command["_id"],
                    "acked",
                    {
                        "completed_at": datetime.now(
                            timezone.utc
                        )
                    },
                )
            )

        return confirmed

    def expire_overdue(self):
        """
        Move commands past their deadline out of the open
        state, so nothing sits pending indefinitely after a
        broker or device outage.
        """

        result = self.collection.update_many(
            {
                "status": {
                    "$in": ["accepted", "dispatched"]
                },
                "expires_at": {
                    "$lt": datetime.now(timezone.utc)
                },
            },
            {
                "$set": {
                    "status": "expired",
                    "completed_at": datetime.now(
                        timezone.utc
                    ),
                }
            },
        )

        return result.modified_count

    def get_recent(
        self,
        house_id: str,
        device_id: str | None = None,
        limit: int = 50,
    ):
        query = {"house_id": house_id}

        if device_id:
            query["device_id"] = device_id

        return [
            to_api(document)
            for document in self.collection.find(query)
            .sort("created_at", -1)
            .limit(limit)
        ]

    def _set_status(
        self,
        command_id: str,
        status: str,
        fields: dict,
    ):
        return to_api(
            self.collection.find_one_and_update(
                {"_id": command_id},
                {"$set": {"status": status, **fields}},
                return_document=ReturnDocument.AFTER,
            )
        )
