import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path


LOG_DIR = Path(os.getenv("LOG_DIR", "/app/logs"))


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


def _create_file_handler(filename: str) -> logging.FileHandler:
    handler = logging.FileHandler(
        LOG_DIR / filename,
        encoding="utf-8",
    )
    handler.setFormatter(JsonlFormatter())
    return handler


def setup_logging() -> None:
    """Configure application and security JSONL logging."""

    LOG_DIR.mkdir(parents=True, exist_ok=True)

    application_logger = logging.getLogger("smarthome")
    application_logger.setLevel(logging.INFO)
    application_logger.propagate = False

    security_logger = logging.getLogger("smarthome.security")
    security_logger.setLevel(logging.INFO)
    security_logger.propagate = False

    mqtt_logger = logging.getLogger("smarthome.mqtt")
    mqtt_logger.setLevel(logging.INFO)
    mqtt_logger.propagate = False

    if not application_logger.handlers:
        application_logger.addHandler(
            _create_file_handler("application.jsonl")
        )

    if not security_logger.handlers:
        security_logger.addHandler(
            _create_file_handler("security.jsonl")
        )

    if not mqtt_logger.handlers:
        mqtt_logger.addHandler(
            _create_file_handler("application.jsonl")
        )