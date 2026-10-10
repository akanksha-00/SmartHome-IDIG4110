import json
import logging
import os

from fastapi_mqtt import FastMQTT, MQTTConfig

from smarthome_api.mqtt.topics import (
    EVENT_SUBSCRIPTION,
    STATE_SUBSCRIPTION,
)

from smarthome_api.schemas.mqtt import (
    DeviceEvent,
    DeviceStateMessage,
)

from smarthome_api.services.device_service import (
    handle_device_event,
    handle_device_state,
)


logger = logging.getLogger("smarthome.mqtt")
security_logger = logging.getLogger("smarthome.security")


mqtt_config = MQTTConfig(
    host=os.getenv("MQTT_HOST", "localhost"),
    port=int(os.getenv("MQTT_PORT", "1883")),
)

mqtt = FastMQTT(config=mqtt_config)


@mqtt.on_connect()
def on_connect(client, flags, rc, properties):
    logger.info(
        "Connected to MQTT broker",
        extra={"event": "mqtt_connected"},
    )

    mqtt.client.subscribe(EVENT_SUBSCRIPTION)
    mqtt.client.subscribe(STATE_SUBSCRIPTION)

    logger.info(
        "Subscribed to MQTT topics",
        extra={
            "event": "mqtt_subscribed",
            "details": {
                "topics": [
                    EVENT_SUBSCRIPTION,
                    STATE_SUBSCRIPTION,
                ]
            },
        },
    )


@mqtt.on_message()
async def on_message(
    client,
    topic,
    payload,
    qos,
    properties,
):
    parts = topic.split("/")

    if len(parts) != 4 or parts[0] != "smarthome":
        security_logger.warning(
            "Rejected MQTT message with invalid topic",
            extra={"event": "mqtt_invalid_topic"},
        )
        return

    _, house_id, device_id, message_type = parts

    try:
        payload_text = payload.decode("utf-8")
    except UnicodeDecodeError:
        security_logger.warning(
            "Rejected MQTT message with invalid encoding",
            extra={"event": "mqtt_invalid_encoding"},
        )
        return

    if message_type == "event":
        try:
            data = json.loads(payload_text)
            message = DeviceEvent.model_validate(data)

        except (json.JSONDecodeError, ValueError):
            security_logger.warning(
                "Rejected invalid MQTT event payload",
                extra={
                    "event": "mqtt_invalid_event",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                    },
                },
            )
            return

        result = await handle_device_event(
            house_id=house_id,
            device_id=device_id,
            event=message.event,
            value=message.value,
        )

        if result is None:
            logger.warning(
                "MQTT event was not processed",
                extra={
                    "event": "mqtt_event_not_processed",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                    },
                },
            )
            return

        logger.info(
            "Device event processed",
            extra={
                "event": "device_event_processed",
                "details": {
                    "house_id": house_id,
                    "device_id": device_id,
                    "event_type": message.event,
                    "value": message.value,
                    "alert_triggered": result["alert"],
                    "notification_message": (
                        result.get("notification_message")
                        if result["alert"]
                        else None
                    ),
                },
            },
        )

        if result["alert"]:
            security_logger.warning(
                "Smart home alert triggered",
                extra={
                    "event": "device_alert",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                    },
                },
            )

        return

    if message_type == "state":
        try:
            data = json.loads(payload_text)
            message = DeviceStateMessage.model_validate(data)

        except (json.JSONDecodeError, ValueError):
            security_logger.warning(
                "Rejected invalid MQTT state payload",
                extra={
                    "event": "mqtt_invalid_state",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                    },
                },
            )
            return

        try:
            result = await handle_device_state(
                house_id=house_id,
                device_id=device_id,
                state=message.state,
            )

        except ValueError as exc:
            logger.warning(
                "Rejected invalid device state",
                extra={
                    "event": "device_state_rejected",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                        "reason": str(exc),
                    },
                },
            )
            return

        if result is None:
            logger.warning(
                "State received for unknown device",
                extra={
                    "event": "mqtt_unknown_device",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                    },
                },
            )
            return

        logger.info(
            "Device state processed",
            extra={
                "event": "device_state_processed",
                "details": {
                    "house_id": house_id,
                    "device_id": device_id,
                },
            },
        )

        for alert in result["alerts"]:
            security_logger.warning(
                "Smart home state alert triggered",
                extra={
                    "event": "device_state_alert",
                    "details": {
                        "house_id": house_id,
                        "device_id": device_id,
                    },
                },
            )

        return

    security_logger.warning(
        "Rejected MQTT message with unknown type",
        extra={"event": "mqtt_unknown_message_type"},
    )


def publish(topic: str, message: str):
    parts = topic.split("/")
    details = {"topic": topic}

    if len(parts) >= 4 and parts[0] == "smarthome":
        details["house_id"] = parts[1]
        details["device_id"] = parts[2]

    if not mqtt.client.is_connected:
        logger.error(
            "Cannot publish MQTT message: client disconnected",
            extra={
                "event": "mqtt_publish_failed",
                "details": details,
            },
        )
        raise RuntimeError("MQTT client is not connected")

    # Log BEFORE calling publish, so we know the function was reached.
    logger.info(
        "Attempting MQTT publish",
        extra={
            "event": "mqtt_publish_attempted",
            "details": details,
        },
    )

    mqtt.publish(topic, message)

    logger.info(
        "MQTT publish call returned",
        extra={
            "event": "mqtt_publish_requested",
            "details": details,
        },
    )