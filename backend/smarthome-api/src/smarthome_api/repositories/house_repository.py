import json
from pathlib import Path


class HouseRepository:

    def __init__(self):
        self.file_path = (
            Path(__file__).resolve().parents[3]
            / "data"
            / "houses.json"
        )

    # ==================================================
    # INTERNAL JSON OPERATIONS
    # ==================================================

    def _load(self) -> list[dict]:

        with self.file_path.open(
            "r",
            encoding="utf-8",
        ) as file:
            return json.load(file)

    def _save(
        self,
        houses: list[dict],
    ) -> None:

        with self.file_path.open(
            "w",
            encoding="utf-8",
        ) as file:
            json.dump(
                houses,
                file,
                indent=2,
                ensure_ascii=False,
            )

    # ==================================================
    # READ
    # ==================================================

    def get_all(self):

        houses = self._load()

        return houses

    def get_by_id(
        self,
        house_id: str,
    ):

        houses = self._load()

        for house in houses:

            if house.get("id") == house_id:
                return house

        return None

    # ==================================================
    # CREATE
    # ==================================================

    def create(
        self,
        house: dict,
    ):

        houses = self._load()

        house_id = house["id"]

        # House IDs must be unique.
        if any(
            existing["id"] == house_id
            for existing in houses
        ):
            return None

        houses.append(house)

        self._save(houses)

        return house

    # ==================================================
    # UPDATE
    # ==================================================

    def update(
        self,
        house_id: str,
        data: dict,
    ):

        houses = self._load()

        for house in houses:

            if house.get("id") != house_id:
                continue

            # The ID identifies the house and
            # should not be changed.
            update_data = {
                key: value
                for key, value in data.items()
                if key != "id"
            }

            house.update(update_data)

            self._save(houses)

            return house

        return None

    # ==================================================
    # DELETE
    # ==================================================

    def delete(
        self,
        house_id: str,
    ):

        houses = self._load()

        for index, house in enumerate(houses):

            if house.get("id") != house_id:
                continue

            removed_house = houses.pop(index)

            self._save(houses)

            return removed_house

        return None