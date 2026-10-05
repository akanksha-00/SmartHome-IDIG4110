from fastapi import APIRouter

from smarthome_api.api.routes.health import router as health_router
from smarthome_api.api.routes.houses import router as houses_router
from smarthome_api.api.routes.rooms import router as rooms_router
from smarthome_api.api.routes.devices import router as devices_router
from smarthome_api.api.routes.dashboard import (
    router as dashboard_router,
)

router = APIRouter()

router.include_router(health_router)
router.include_router(houses_router)
router.include_router(rooms_router)
router.include_router(devices_router)
router.include_router(dashboard_router)