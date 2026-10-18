import json
from pathlib import Path


class UserRepository:

    def __init__(self):
        self.file_path = (
            Path(__file__).resolve().parents[3]
            / "data"
            / "users.json"
        )

    def _load(self) -> list[dict]:
        with self.file_path.open("r", encoding="utf-8") as file:
            return json.load(file)

    def _save(self, users: list[dict]) -> None:
        with self.file_path.open("w", encoding="utf-8") as file:
            json.dump(users, file, indent=2, ensure_ascii=False)

    def get_all(self) -> list[dict]:
        return self._load()

    def get_by_id(self, user_id: str) -> dict | None:
        users = self._load()

        for user in users:
            if user.get("id") == user_id:
                return user

        return None

    def create(self, user: dict) -> dict | None:
        users = self._load()

        user_id = user["id"]

        if any(existing.get("id") == user_id for existing in users):
            return None

        users.append(user)
        self._save(users)

        return user

    def update(self, user_id: str, data: dict) -> dict | None:
        users = self._load()

        for user in users:
            if user.get("id") != user_id:
                continue

            # A user's identity must not be changed.
            update_data = {
                key: value
                for key, value in data.items()
                if key != "id"
            }

            user.update(update_data)
            self._save(users)

            return user

        return None