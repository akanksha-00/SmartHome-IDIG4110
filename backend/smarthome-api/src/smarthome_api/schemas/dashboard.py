from pydantic import BaseModel

from smarthome_api.schemas.device import DeviceResponse
from smarthome_api.schemas.house import HouseResponse


class DashboardRoom(BaseModel):
    id: str
    name: str
    devices: list[DeviceResponse]


class HouseDashboard(BaseModel):
    house: HouseResponse
    rooms: list[DashboardRoom]
    unassigned_devices: list[DeviceResponse]