from pydantic import BaseModel


class HouseCreate(BaseModel):
    id: str
    name: str
    address: str | None = None
    postal_code: str | None = None
    city: str | None = None


class HouseUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    postal_code: str | None = None
    city: str | None = None

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "name": "House2"
                }
            ]
        }
    }


class HouseResponse(BaseModel):
    id: str
    name: str
    address: str | None = None
    postal_code: str | None = None
    city: str | None = None