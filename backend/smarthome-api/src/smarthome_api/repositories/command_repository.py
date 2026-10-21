class CommandRepository:
    """
    Command records are not kept by the file backend.

    A command lifecycle is a sequence of small updates to
    the same record, which a JSON file handles badly, and
    the file store exists only as a fallback. Callers get
    the same interface and nothing is recorded.
    """

    def create(
        self,
        house_id: str,
        device_id: str,
        state: dict,
        request_id: str | None = None,
        issued_by: str | None = None,
        expiry_seconds: int = 30,
    ):
        return None

    def mark_dispatched(
        self,
        command_id: str,
    ):
        return None

    def mark_failed(
        self,
        command_id: str,
        error: str,
    ):
        return None

    def confirm_matching(
        self,
        house_id: str,
        device_id: str,
        reported: dict,
    ):
        return []

    def expire_overdue(self):
        return 0

    def get_recent(
        self,
        house_id: str,
        device_id: str | None = None,
        limit: int = 50,
    ):
        return []
