from fastapi import FastAPI
from smarthome_api.mqtt.client import mqtt, publish
from smarthome_api.api.router import router

app = FastAPI(
    title="Smart Home API",
    version="1.0.0",
)
mqtt.init_app(app)
app.include_router(router)
@app.post("/mqtt-test")
async def mqtt_test():
    publish(
        "smarthome/test",
        "Hello from FastAPI",
    )

    return {
        "message": "MQTT message published"
    }