from fastapi import APIRouter, Depends

from smarthome_api.auth import get_current_user

from smarthome_api.api.routes.health import router as health_router
from smarthome_api.api.routes.houses import router as houses_router
from smarthome_api.api.routes.rooms import router as rooms_router
from smarthome_api.api.routes.devices import router as devices_router
from smarthome_api.api.routes.dashboard import (
    router as dashboard_router,
)
from smarthome_api.api.routes.websocket import (
    router as websocket_router,
)


router = APIRouter()

# Public endpoints
router.include_router(health_router)

# Protected HTTP endpoints
protected_router = APIRouter(
    dependencies=[Depends(get_current_user)]
)

protected_router.include_router(houses_router)
protected_router.include_router(rooms_router)
protected_router.include_router(devices_router)
protected_router.include_router(dashboard_router)

router.include_router(protected_router)

# WebSockets will be handled separately
router.include_router(websocket_router)