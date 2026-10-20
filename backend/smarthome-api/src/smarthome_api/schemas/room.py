from pydantic import BaseModel


class RoomCreate(BaseModel):
    id: str
    name: str


class RoomUpdate(BaseModel):
    name: str | None = None

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "name": "Living Room"
                }
            ]
        }
    }


class RoomResponse(BaseModel):
    id: str
    house_id: str
    name: str