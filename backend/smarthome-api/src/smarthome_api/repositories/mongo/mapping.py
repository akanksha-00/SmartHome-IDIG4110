"""
Translation between MongoDB documents and the dictionaries
the rest of the application already uses.

MongoDB's primary key is `_id`; the API and the existing
repositories use `id`. The business id is stored directly
as `_id` rather than duplicated into a second field, so
there is exactly one identity per record.
"""


def to_api(document: dict | None) -> dict | None:
    """
    Document from MongoDB to the shape callers expect.
    """

    if document is None:
        return None

    result = dict(document)

    result["id"] = result.pop("_id")

    return result


def to_document(data: dict) -> dict:
    """
    Caller supplied dictionary to a MongoDB document.
    """

    result = dict(data)

    if "id" in result:
        result["_id"] = result.pop("id")

    return result


def strip_identity(
    data: dict,
    *,
    also: set[str] | None = None,
) -> dict:
    """
    Remove fields that identify a record, so an update
    cannot change what it is or who owns it.
    """

    protected = {"id", "_id"}

    if also:
        protected |= also

    return {
        key: value
        for key, value in data.items()
        if key not in protected
    }
