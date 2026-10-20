from fastapi import APIRouter, HTTPException

from smarthome_api.schemas.house import (
    HouseCreate,
    HouseResponse,
    HouseUpdate,
)
from smarthome_api.services.house_service import (
    create_house,
    delete_house,
    get_all_houses,
    get_house,
    update_house,
)


router = APIRouter(
    prefix="/api/v1/houses",
    tags=["Houses"],
)


# ==================================================
# HOUSES
# ==================================================

@router.get(
    "",
    response_model=list[HouseResponse],
    response_model_exclude_none=True,
)
async def get_houses():

    return get_all_houses()


@router.get(
    "/{house_id}",
    response_model=HouseResponse,
    response_model_exclude_none=True,
)
async def get_house_by_id(
    house_id: str,
):

    house = get_house(house_id)

    if house is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return house


@router.post(
    "",
    response_model=HouseResponse,
    response_model_exclude_none=True,
    status_code=201,
)
async def create_new_house(
    house: HouseCreate,
):

    result = create_house(
        house.model_dump(
            exclude_none=True
        )
    )

    if result is None:
        raise HTTPException(
            status_code=409,
            detail="House already exists",
        )

    return result


@router.put(
    "/{house_id}",
    response_model=HouseResponse,
    response_model_exclude_none=True,
)
async def update_existing_house(
    house_id: str,
    house: HouseUpdate,
):

    result = update_house(
        house_id,
        house.model_dump(
            exclude_none=True
        ),
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return result


@router.delete(
    "/{house_id}",
)
async def remove_house(
    house_id: str,
):

    result = delete_house(house_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return {
        "message": "House deleted",
        "house": result,
    }
@router.patch(
    "/{house_id}",
    response_model=HouseResponse,
    response_model_exclude_none=True,
)
async def patch_house(
    house_id: str,
    house: HouseUpdate,
):

    result = update_house(
        house_id,
        house.model_dump(
            exclude_none=True
        ),
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return result