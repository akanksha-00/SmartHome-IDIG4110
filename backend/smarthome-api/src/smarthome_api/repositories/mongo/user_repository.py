from pymongo import ReturnDocument

from smarthome_api.db import get_database
from smarthome_api.repositories.mongo.mapping import (
    strip_identity,
    to_api,
    to_document,
)


class UserRepository:
    """
    MongoDB backed users.

    Holds the role attached to a Supabase user id. No
    credentials are stored here: authentication happens at
    Supabase and the backend only verifies the token and
    looks up what that user is allowed to do.
    """

    @property
    def collection(self):
        return get_database().users

    def get_all(self) -> list[dict]:
        return [
            to_api(document)
            for document in self.collection.find()
        ]

    def get_by_id(self, user_id: str) -> dict | None:
        return to_api(
            self.collection.find_one({"_id": user_id})
        )

    def create(self, user: dict) -> dict | None:
        document = to_document(user)

        if self.collection.find_one({"_id": document["_id"]}):
            return None

        self.collection.insert_one(document)

        return to_api(document)

    def update(self, user_id: str, data: dict) -> dict | None:
        # A user's identity must not be changed.
        update_data = strip_identity(data)

        if not update_data:
            return self.get_by_id(user_id)

        return to_api(
            self.collection.find_one_and_update(
                {"_id": user_id},
                {"$set": update_data},
                return_document=ReturnDocument.AFTER,
            )
        )
