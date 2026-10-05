from fastapi import FastAPI

from smarthome_api.api.router import router

app = FastAPI(
    title="Smart Home API",
    version="1.0.0",
)

app.include_router(router)