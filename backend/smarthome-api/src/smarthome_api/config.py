from pydantic_settings import (
    BaseSettings,
    SettingsConfigDict,
)


class Settings(BaseSettings):
    """
    Application configuration, read from environment
    variables or a .env file.

    Nothing here has a secret as its default. Anything
    environment specific belongs in .env, which is not
    committed.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ==================================================
    # STORAGE
    # ==================================================

    # "json" keeps the existing file based repositories.
    # "mongo" uses MongoDB. Switching this is how the
    # storage change is verified: the API must behave
    # identically either way.
    storage_backend: str = "json"

    mongodb_uri: str = "mongodb://localhost:27017"

    mongodb_db: str = "smarthome"

    # ==================================================
    # MQTT
    # ==================================================

    mqtt_host: str = "localhost"

    mqtt_port: int = 1883

    # ==================================================
    # DEVICES
    # ==================================================

    # Silence longer than this means the device is treated
    # as absent. Long enough to survive a slow reporting
    # cycle, short enough that a dead device is noticed.
    device_stale_after_seconds: int = 120


settings = Settings()
