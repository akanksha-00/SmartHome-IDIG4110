"""
The user record holds a role against a Supabase user id.
No credentials live here; authentication happens at
Supabase and this only answers what the user may do.
"""


def test_create_and_read_back(users):
    created = users.create({"id": "u1", "role": "customer"})

    assert created["id"] == "u1"
    assert users.get_by_id("u1")["role"] == "customer"


def test_unknown_user_is_none(users):
    assert users.get_by_id("nobody") is None


def test_duplicate_is_refused(users):
    users.create({"id": "u1", "role": "customer"})

    assert users.create({"id": "u1", "role": "admin"}) is None
    assert users.get_by_id("u1")["role"] == "customer"


def test_role_can_be_changed(users):
    users.create({"id": "u1", "role": "customer"})

    updated = users.update("u1", {"role": "provider"})

    assert updated["role"] == "provider"


def test_identity_cannot_be_changed(users):
    users.create({"id": "u1", "role": "customer"})

    users.update("u1", {"id": "someone-else", "role": "admin"})

    assert users.get_by_id("u1")["role"] == "admin"
    assert users.get_by_id("someone-else") is None
