from typing import Any


def evaluate_threshold(value: Any, threshold: dict) -> bool:
    operator = threshold["operator"]
    expected = threshold["value"]

    if operator == "==":
        return value == expected

    if operator == ">":
        return value > expected

    if operator == ">=":
        return value >= expected

    if operator == "<":
        return value < expected

    if operator == "<=":
        return value <= expected

    return False