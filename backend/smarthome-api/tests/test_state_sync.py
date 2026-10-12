from smarthome_api.repositories.state_sync import is_in_sync


def test_nothing_requested_is_in_sync():
    assert is_in_sync({"power": True}, {}) is True
    assert is_in_sync({}, None) is True


def test_matching_values_are_in_sync():
    assert is_in_sync(
        {"power": True, "brightness": 80},
        {"brightness": 80},
    ) is True


def test_mismatch_is_not_in_sync():
    assert is_in_sync(
        {"brightness": 40},
        {"brightness": 80},
    ) is False


def test_missing_reported_value_is_not_in_sync():
    assert is_in_sync({}, {"power": True}) is False


def test_unrequested_values_are_ignored():
    """
    A device may report things nobody asked about. That is
    not a disagreement.
    """

    assert is_in_sync(
        {"power": True, "temperature": 21},
        {"power": True},
    ) is True
