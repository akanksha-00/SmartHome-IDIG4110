from smarthome_api.repositories.factory import house_repository


# ==================================================
# HOUSES
# ==================================================

def get_all_houses():

    return house_repository.get_all()


def get_house(
    house_id: str,
):

    return house_repository.get_by_id(
        house_id,
    )


def create_house(
    house: dict,
):

    return house_repository.create(
        house,
    )


def update_house(
    house_id: str,
    data: dict,
):

    return house_repository.update(
        house_id,
        data,
    )


def delete_house(
    house_id: str,
):

    return house_repository.delete(
        house_id,
    )