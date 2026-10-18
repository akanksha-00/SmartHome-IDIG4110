import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path


LOG_DIR = Path(os.getenv("LOG_DIR", "/app/logs"))
LOG_TO_FILE = os.getenv("LOG_TO_FILE", "false").lower() == "true"


class JsonlFormatter(logging.Formatter):
    """Format each log record as one JSON object per line."""

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        event = getattr(record, "event", None)
        if event:
            entry["event"] = event

        details = getattr(record, "details", None)
        if details:
            entry["details"] = details

        if record.exc_info:
            entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(entry, ensure_ascii=False)


def setup_logging() -> None:
    """Configure application, security, and MQTT logging."""

    application_logger = logging.getLogger("smarthome")
    security_logger = logging.getLogger("smarthome.security")
    mqtt_logger = logging.getLogger("smarthome.mqtt")

    loggers = (
        application_logger,
        security_logger,
        mqtt_logger,
    )

    # Always log to the console.
    for logger in loggers:
        logger.setLevel(logging.INFO)
        logger.propagate = False

        if not any(
            type(handler) is logging.StreamHandler
            for handler in logger.handlers
        ):
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(JsonlFormatter())
            logger.addHandler(console_handler)

    # Stop here if file logging is disabled.
    if not LOG_TO_FILE:
        return

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    # Application and MQTT logs share one file.
    for logger in (application_logger, mqtt_logger):
        if not any(
            isinstance(handler, logging.FileHandler)
            for handler in logger.handlers
        ):
            handler = logging.FileHandler(
                LOG_DIR / "application.jsonl",
                encoding="utf-8",
            )
            handler.setFormatter(JsonlFormatter())
            logger.addHandler(handler)

    # Security events have their own file.
    if not any(
        isinstance(handler, logging.FileHandler)
        for handler in security_logger.handlers
    ):
        handler = logging.FileHandler(
            LOG_DIR / "security.jsonl",
            encoding="utf-8",
        )
        handler.setFormatter(JsonlFormatter())
        security_logger.addHandler(handler)