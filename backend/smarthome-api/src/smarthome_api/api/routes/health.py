from fastapi import APIRouter

from smarthome_api.mqtt.client import mqtt

router = APIRouter(
    prefix="/api/v1/health",
    tags=["Health"],
)


@router.get("/")
async def health_check():
    mqtt_connected = mqtt.client.is_connected

    return {
        "status": "ok" if mqtt_connected else "degraded",
        "services": {
            "api": "ok",
            "mqtt": "connected" if mqtt_connected else "disconnected",
        },
    }