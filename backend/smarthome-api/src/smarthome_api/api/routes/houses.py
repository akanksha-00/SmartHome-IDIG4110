from fastapi import APIRouter, Depends, HTTPException
from smarthome_api.auth import (
    get_current_user_id,
    get_current_app_user,
)
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
async def get_houses(
    current_user: dict = Depends(get_current_app_user),
):
    if current_user["role"] == "platform_admin":
        return get_all_houses()

    return get_all_houses(owner_id=current_user["id"])



@router.get(
    "/{house_id}",
    response_model=HouseResponse,
    response_model_exclude_none=True,
)
async def get_house_by_id(
    house_id: str,
    current_user: dict = Depends(get_current_app_user),
):
    if current_user["role"] == "platform_admin":
        house = get_house(house_id)
    else:
        house = get_house(
            house_id,
            owner_id=current_user["id"],
        )

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
    user_id: str = Depends(get_current_user_id),
):
    house_data = house.model_dump(exclude_none=True)
    house_data["owner_id"] = user_id

    result = create_house(house_data)

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
    current_user: dict = Depends(get_current_app_user),
):
    if current_user["role"] == "platform_admin":
        existing_house = get_house(house_id)
    else:
        existing_house = get_house(
            house_id,
            owner_id=current_user["id"],
        )

    if existing_house is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    result = update_house(
        house_id,
        house.model_dump(exclude_none=True),
    )

    return result
@router.delete("/{house_id}")
async def remove_house(
    house_id: str,
    current_user: dict = Depends(get_current_app_user),
):
    if current_user["role"] == "platform_admin":
        existing_house = get_house(house_id)
    else:
        existing_house = get_house(
            house_id,
            owner_id=current_user["id"],
        )

    if existing_house is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    result = delete_house(house_id)

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
    current_user: dict = Depends(get_current_app_user),
):
    if current_user["role"] == "platform_admin":
        existing_house = get_house(house_id)
    else:
        existing_house = get_house(
            house_id,
            owner_id=current_user["id"],
        )

    if existing_house is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    result = update_house(
        house_id,
        house.model_dump(exclude_none=True),
    )
    return result