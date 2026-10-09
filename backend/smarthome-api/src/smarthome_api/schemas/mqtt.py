from typing import Any

from pydantic import BaseModel


class DeviceEvent(BaseModel):
    event: str
    value: Any

class DeviceStateMessage(BaseModel):
    state: dict[str, Any]

class DeviceCommand(BaseModel):
    state: dict[str, Any]