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
def get_all(
    self,
    owner_id: str | None = None,
    provider_id: str | None = None,
):
    query = {}

    if owner_id is not None:
        query["owner_id"] = owner_id

    if provider_id is not None:
        query["provider_id"] = provider_id

    return [
        to_api(document)
        for document in self.collection.find(query)
    ]

def get_by_id(
    self,
    house_id: str,
    owner_id: str | None = None,
    provider_id: str | None = None,
):
    query = {"_id": house_id}

    if owner_id is not None:
        query["owner_id"] = owner_id

    if provider_id is not None:
        query["provider_id"] = provider_id

    document = self.collection.find_one(query)
    return to_api(document)