SMARTHOME_PREFIX = "smarthome"


def command_topic(house_id: str, device_id: str) -> str:
    return f"{SMARTHOME_PREFIX}/{house_id}/{device_id}/command"


def state_topic(house_id: str, device_id: str) -> str:
    return f"{SMARTHOME_PREFIX}/{house_id}/{device_id}/state"


def event_topic(house_id: str, device_id: str) -> str:
    return f"{SMARTHOME_PREFIX}/{house_id}/{device_id}/event"


COMMAND_SUBSCRIPTION = f"{SMARTHOME_PREFIX}/+/+/command"
STATE_SUBSCRIPTION = f"{SMARTHOME_PREFIX}/+/+/state"
EVENT_SUBSCRIPTION = f"{SMARTHOME_PREFIX}/+/+/event"