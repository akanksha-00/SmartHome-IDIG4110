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

    def history(
        self,
        house_id: str,
        device_id: str,
        metric: str | None = None,
        limit: int = 200,
    ):
        """
        Recent measurements, newest first.

        Scoped by house as well as device so history cannot
        be read from the wrong house by guessing an id.
        """

        query = {
            "meta.device_id": device_id,
            "meta.house_id": house_id,
        }

        if metric:
            query["meta.metric"] = metric

        return [
            {
                "metric": document["meta"]["metric"],
                "value": document["value"],
                "observed_at": document["observed_at"],
                "received_at": document.get("received_at"),
                "time_source": document.get("time_source"),
            }
            for document in self.history_collection.find(query)
            .sort("observed_at", -1)
            .limit(limit)
        ]
