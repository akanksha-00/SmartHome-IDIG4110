from pymongo import ReturnDocument

from smarthome_api.db import get_database
from smarthome_api.repositories.mongo.mapping import (
    strip_identity,
    to_api,
    to_document,
)


class HouseRepository:
    """
    MongoDB backed houses.

    Same methods and return shapes as the JSON repository,
    so services cannot tell which one they are using.
    """

    @property
    def collection(self):
        return get_database().houses

    # ==================================================
    # READ
    # ==================================================

    def get_all(self):

        return [
            to_api(document)
            for document in self.collection.find()
        ]

    def get_by_id(
        self,
        house_id: str,
    ):

        return to_api(
            self.collection.find_one({"_id": house_id})
        )

    # ==================================================
    # CREATE
    # ==================================================

    def create(
        self,
        house: dict,
    ):

        document = to_document(house)

        # House IDs must be unique. The _id index enforces
        # this, so a duplicate is reported rather than
        # silently overwriting.
        if self.collection.find_one({"_id": document["_id"]}):
            return None

        self.collection.insert_one(document)

        return to_api(document)

    # ==================================================
    # UPDATE
    # ==================================================

    def update(
        self,
        house_id: str,
        data: dict,
    ):

        # The ID identifies the house and is not changed.
        update_data = strip_identity(data)

        if not update_data:
            return self.get_by_id(house_id)

        return to_api(
            self.collection.find_one_and_update(
                {"_id": house_id},
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
    ):

        return to_api(
            self.collection.find_one_and_delete(
                {"_id": house_id}
            )
        )
