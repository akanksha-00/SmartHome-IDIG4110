class EventRepository:
    """
    Events and history are not kept by the file backend.

    Keeping no history is a deliberate limit of the JSON
    store rather than an oversight: appending every reading
    to a JSON file would rewrite the whole file on each
    message. Callers get the same interface and simply
    record nothing.
    """

    def record_event(
        self,
        house_id: str,
        device_id: str,
        event_type: str,
        payload: dict,
    ):
        return None

    def record_history(
        self,
        house_id: str,
        device_id: str,
        state: dict,
    ):
        return []

    def history(
        self,
        house_id: str,
        device_id: str,
        metric: str | None = None,
        limit: int = 200,
    ):
        return []
