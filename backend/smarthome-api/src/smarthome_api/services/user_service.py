from smarthome_api.repositories.factory import user_repository


def get_user(user_id: str):
    return user_repository.get_by_id(user_id)


def get_or_create_user(user_id: str) -> dict:
    user = get_user(user_id)

    if user is not None:
        return user

    new_user = {
        "id": user_id,
        "role": "customer",
    }

    return user_repository.create(new_user)


def update_user(user_id: str, data: dict):
    return user_repository.update(user_id, data)