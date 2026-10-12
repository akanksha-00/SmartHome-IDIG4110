"""
Document rules enforced by MongoDB itself.

Pydantic validates what arrives over HTTP, but nothing
validates what a script, a migration or a future service
writes directly. These schemas close that gap: a field name
that drifts, or a status outside the allowed set, is rejected
at the point of writing instead of being discovered months
later in a query that quietly returns nothing.

They are deliberately permissive about fields they do not
name. The point is to pin down what the application relies
on, not to freeze the shape of every document.

state_history is absent: MongoDB does not support validators
on time series collections.
"""

STRING = {"bsonType": "string"}
OPTIONAL_STRING = {"bsonType": ["string", "null"]}
DATE = {"bsonType": ["date", "null"]}


def _schema(required: list[str], properties: dict) -> dict:
    return {
        "$jsonSchema": {
            "bsonType": "object",
            "required": required,
            "properties": properties,
        }
    }


VALIDATORS = {
    "houses": _schema(
        ["_id", "name"],
        {
            "_id": STRING,
            "name": STRING,
            "address": OPTIONAL_STRING,
            "postal_code": OPTIONAL_STRING,
            "city": OPTIONAL_STRING,
        },
    ),
    "rooms": _schema(
        ["_id", "house_id", "name"],
        {
            "_id": STRING,
            "house_id": STRING,
            "name": STRING,
        },
    ),
    "devices": _schema(
        ["_id", "house_id"],
        {
            "_id": STRING,
            "house_id": STRING,
            "room_id": OPTIONAL_STRING,
            "type": OPTIONAL_STRING,
            "name": OPTIONAL_STRING,
            "capabilities": {"bsonType": ["object", "null"]},
            "status": {"bsonType": ["object", "null"]},
            "available": {"bsonType": ["bool", "null"]},
            "last_seen_at": DATE,
        },
    ),
    "device_state": _schema(
        ["_id", "house_id"],
        {
            "_id": STRING,
            "house_id": STRING,
            "reported": {"bsonType": ["object", "null"]},
            "desired": {"bsonType": ["object", "null"]},
            "in_sync": {"bsonType": ["bool", "null"]},
            "seq": {"bsonType": ["int", "long", "null"]},
            "received_at": DATE,
        },
    ),
    "commands": _schema(
        ["_id", "request_id", "house_id", "device_id", "status"],
        {
            "_id": STRING,
            "request_id": STRING,
            "house_id": STRING,
            "device_id": STRING,
            "status": {
                "enum": [
                    "accepted",
                    "rejected",
                    "dispatched",
                    "acked",
                    "failed",
                    "expired",
                ],
                "description": (
                    "Published and executed are different "
                    "facts, so this is not a boolean."
                ),
            },
            "error": OPTIONAL_STRING,
        },
    ),
    "events": _schema(
        ["_id", "house_id", "device_id", "type"],
        {
            "_id": STRING,
            "house_id": STRING,
            "device_id": STRING,
            "type": STRING,
            "time_source": OPTIONAL_STRING,
        },
    ),
}
