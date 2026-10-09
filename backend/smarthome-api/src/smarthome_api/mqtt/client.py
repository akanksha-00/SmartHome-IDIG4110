import json
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


mqtt_config = MQTTConfig(
    host=os.getenv("MQTT_HOST", "localhost"),
    port=int(os.getenv("MQTT_PORT", "1883")),
)

mqtt = FastMQTT(config=mqtt_config)


@mqtt.on_connect()
def on_connect(client, flags, rc, properties):
    print("Connected to MQTT broker")

    mqtt.client.subscribe(EVENT_SUBSCRIPTION)
    mqtt.client.subscribe(STATE_SUBSCRIPTION)

    print(
        f"Subscribed to: "
        f"{EVENT_SUBSCRIPTION}"
    )

    print(
        f"Subscribed to: "
        f"{STATE_SUBSCRIPTION}"
    )


@mqtt.on_message()
async def on_message(
    client,
    topic,
    payload,
    qos,
    properties,
):
    print("MQTT message received")
    print(f"Topic:   {topic}")
    print(f"Payload: {payload.decode()}")

    parts = topic.split("/")

    if len(parts) != 4:
        print(
            f"Ignoring invalid MQTT topic: "
            f"{topic}"
        )
        return

    _, house_id, device_id, message_type = parts

    # ==================================================
    # EVENT
    # ==================================================

    if message_type == "event":

        try:
            data = json.loads(
                payload.decode()
            )

            message = DeviceEvent.model_validate(
                data
            )

        except (
            json.JSONDecodeError,
            ValueError,
        ) as exc:

            print(
                f"Invalid MQTT event: "
                f"{exc}"
            )

            return

        result = await handle_device_event(
            house_id=house_id,
            device_id=device_id,
            event=message.event,
            value=message.value,
        )

        if result is None:
            return

        print(
            f"Event accepted: "
            f"{device_id} → "
            f"{message.event}="
            f"{message.value}"
        )

        # Check whether the event triggered
        # an alert.
        if result["alert"]:

            print(
                f"🚨 ALERT: "
                f"{result['notification_message']}"
            )

        return

    # ==================================================
    # STATE
    # ==================================================

    if message_type == "state":

        try:
            data = json.loads(
                payload.decode()
            )

            message = DeviceStateMessage.model_validate(
                data
            )

        except (
            json.JSONDecodeError,
            ValueError,
        ) as exc:

            print(
                f"Invalid MQTT state: "
                f"{exc}"
            )

            return

        try:
            result = await handle_device_state(
                house_id=house_id,
                device_id=device_id,
                state=message.state,
            )

        except ValueError as exc:

            print(
                f"Invalid device state: "
                f"{exc}"
            )

            return

        if result is None:

            print(
                f"Ignoring MQTT state: "
                f"device '{device_id}' "
                f"does not exist"
            )

            return

        print(
            f"State accepted: "
            f"{device_id} → "
            f"{message.state}"
        )

        # Check whether any state capability
        # triggered an alert.
        for alert in result["alerts"]:

            print(
                f"🚨 ALERT: "
                f"{alert['notification_message']}"
            )

        return

    # ==================================================
    # UNKNOWN MESSAGE TYPE
    # ==================================================

    print(
        f"Ignoring unknown MQTT "
        f"message type: {message_type}"
    )


# ==================================================
# PUBLISH
# ==================================================

def publish(
    topic: str,
    message: str,
):
    print(f"MQTT PUBLISH: {topic}")
    print(f"MQTT PAYLOAD: {message}")
    print(f"MQTT CONNECTED: {mqtt.client.is_connected}")

    mqtt.publish(
        topic,
        message,
    )
