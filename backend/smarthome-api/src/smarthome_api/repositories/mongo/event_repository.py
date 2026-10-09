import uuid
from datetime import datetime, timezone

from smarthome_api.db import get_database


class EventRepository:

    @property
    def collection(self):
        return get_database().events

    @property
    def history_collection(self):
        return get_database().state_history

    def record_event(
        self,
        house_id: str,
        device_id: str,
        event_type: str,
        payload: dict,
    ):
        received_at = datetime.now(timezone.utc)

        document = {
            "_id": str(uuid.uuid4()),
            "house_id": house_id,
            "device_id": device_id,
            "type": event_type,
            "payload": payload,
            "observed_at": received_at,
            "received_at": received_at,
            # The MQTT payload carries no device timestamp,
            # so observed_at is the server clock. Recorded
            # explicitly rather than left to be assumed:
            # once devices send their own time, this becomes
            # "device" and the two values diverge.
            "time_source": "backend",
        }

        self.collection.insert_one(document)

        return document

    def record_history(
        self,
        house_id: str,
        device_id: str,
        state: dict,
    ):
        if not state:
            return []

        received_at = datetime.now(timezone.utc)

        documents = [
            {
                "meta": {
                    "device_id": device_id,
                    "house_id": house_id,
                    "metric": metric,
                },
                "value": value,
                "observed_at": received_at,
                "received_at": received_at,
                "time_source": "backend",
            }
            for metric, value in state.items()
        ]

        self.history_collection.insert_many(documents)

        return documents
