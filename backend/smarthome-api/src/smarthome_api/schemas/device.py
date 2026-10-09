from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


# ==================================================
# DEVICE CAPABILITY
# ==================================================

class DeviceCapability(BaseModel):
    """
    Defines one capability supported by a device.

    Examples:

        {
            "type": "boolean"
        }

        {
            "type": "integer",
            "min": 0,
            "max": 100
        }
    """

    type: str

    min: int | float | None = None
    max: int | float | None = None


# ==================================================
# CREATE DEVICE
# ==================================================

class DeviceCreate(BaseModel):
    """
    Data required when creating a device.
    """

    id: str
    name: str
    type: str

    room_id: str | None = None

    manufacturer: str | None = None
    model: str | None = None

    manufactured_year: int | None = None
    installed_year: int | None = None

    installer: str | None = None

    capabilities: dict[str, DeviceCapability] = Field(
        default_factory=dict
    )

    state: dict[str, Any] = Field(
        default_factory=dict
    )

    status: dict[str, Any] = Field(
        default_factory=dict
    )


# ==================================================
# PUT — DEVICE METADATA
# ==================================================

class DeviceUpdate(BaseModel):
    """
    PUT is used for relatively stable device metadata.

    Examples:
    - name
    - manufacturer
    - model
    - manufactured_year
    - installed_year
    - installer
    """

    name: str | None = None

    manufacturer: str | None = None

    model: str | None = None

    manufactured_year: int | None = None

    installed_year: int | None = None

    installer: str | None = None


# ==================================================
# PATCH — DEVICE CAPABILITY STATE
# ==================================================

class DeviceCapabilityUpdate(BaseModel):
    """
    Represents one capability state update.

    The name must match a capability supported
    by the device.
    """

    name: str = Field(
        ...,
        description="Name of the device capability to update.",
        examples=["speed"],
    )

    value: Any = Field(
        ...,
        description="New value for the capability.",
        examples=[4],
    )
# ==================================================
# DEVICE RESPONSE
# ==================================================

class DeviceResponse(BaseModel):
    """
    Device returned by the API.
    """

    id: str
    name: str
    type: str

    house_id: str
    room_id: str | None = None

    manufacturer: str | None = None
    model: str | None = None

    manufactured_year: int | None = None
    installed_year: int | None = None

    installer: str | None = None

    capabilities: dict[str, DeviceCapability] = Field(
        default_factory=dict
    )

    state: dict[str, Any] = Field(
        default_factory=dict,
        description=(
            "What the device last reported about itself."
        ),
    )

    desired: dict[str, Any] = Field(
        default_factory=dict,
        description=(
            "What was last asked of the device. Empty when "
            "nothing is outstanding."
        ),
    )

    in_sync: bool = Field(
        default=True,
        description=(
            "False while a command has been sent but not "
            "yet confirmed by the device."
        ),
    )

    status: dict[str, Any] = Field(
        default_factory=dict
    )

# ==================================================
# DEVICE HISTORY
# ==================================================

class HistoryPoint(BaseModel):
    """
    One recorded measurement.
    """

    metric: str
    value: Any

    observed_at: datetime = Field(
        description=(
            "When the measurement was taken, according to "
            "time_source."
        ),
    )

    received_at: datetime | None = None

    time_source: str | None = Field(
        default=None,
        description=(
            "Which clock filled observed_at. 'backend' "
            "until devices report their own timestamp."
        ),
    )
