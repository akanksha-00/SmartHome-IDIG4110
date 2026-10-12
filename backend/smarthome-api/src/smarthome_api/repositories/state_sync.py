"""
Whether a device has done what was asked of it.

`reported` is what the device says it is. `desired` is what
was last requested. They are compared here so both storage
backends answer the question the same way.
"""


def is_in_sync(
    reported: dict | None,
    desired: dict | None,
) -> bool:
    """
    True when every requested capability matches what the
    device reports.

    Nothing requested means nothing outstanding, so a
    device with no desired state is in sync. Only the
    requested capabilities are compared: a device may
    report values nobody asked about, and that is not a
    disagreement.
    """

    if not desired:
        return True

    reported = reported or {}

    return all(
        reported.get(name) == value
        for name, value in desired.items()
    )
