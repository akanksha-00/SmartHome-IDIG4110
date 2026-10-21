import logging
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware

from fastapi import FastAPI

from smarthome_api.logging_config import setup_logging
from smarthome_api.mqtt.client import mqtt
from smarthome_api.api.router import router


setup_logging()

logger = logging.getLogger("smarthome")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        "Starting Smart Home API",
        extra={"event": "application_starting"},
    )

    await mqtt.mqtt_startup()

    logger.info(
        "Smart Home API started",
        extra={"event": "application_started"},
    )

    try:
        yield
    finally:
        await mqtt.mqtt_shutdown()


app = FastAPI(
    title="Smart Home API",
    version="1.0.0",
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:8080",
        "http://localhost:8080",
        "http://idig4110-h26-group2.iaas.iik.ntnu.no"
    ],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)