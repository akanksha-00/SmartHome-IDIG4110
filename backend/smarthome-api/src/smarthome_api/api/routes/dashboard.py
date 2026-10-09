from fastapi import APIRouter, HTTPException

from smarthome_api.schemas.dashboard import HouseDashboard
from smarthome_api.services.dashboard_service import (
    get_house_dashboard,
)


router = APIRouter(
    prefix="/api/v1/houses/{house_id}",
    tags=["Dashboard"],
)


@router.get(
    "/dashboard",
    response_model=HouseDashboard,
    response_model_exclude_none=True
)
async def get_dashboard(
    house_id: str,
):

    result = get_house_dashboard(house_id)

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="House not found",
        )

    return result