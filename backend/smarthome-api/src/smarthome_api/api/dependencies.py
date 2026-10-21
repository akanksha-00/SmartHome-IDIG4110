from fastapi import Depends, HTTPException

from smarthome_api.auth import get_current_app_user
from smarthome_api.services.house_service import get_house


def require_house_access(
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