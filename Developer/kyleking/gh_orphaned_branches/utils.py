"""Generic reusable utility functions."""

from collections.abc import Callable, Iterable
from datetime import datetime, timedelta, timezone
from functools import reduce
from typing import Any, TypeVar

T = TypeVar("T")
U = TypeVar("U")


# ============================================================================
# Generic Functional Utilities
# ============================================================================


def compose(*functions: Callable) -> Callable:
    """Compose functions from right to left.

    Example:
        f = compose(str.upper, str.strip)
        f("  hello  ") # "HELLO"
    """
    return reduce(lambda f, g: lambda x: f(g(x)), functions, lambda x: x)


def pipe(*functions: Callable) -> Callable:
    """Compose functions from left to right (pipeline style).

    Example:
        f = pipe(str.strip, str.upper)
        f("  hello  ") # "HELLO"
    """
    return compose(*reversed(functions))


def filter_map(
    predicate: Callable[[T], bool],
    mapper: Callable[[T], U],
    items: Iterable[T],
) -> list[U]:
    """Filter and map in a single pass.

    More efficient than filter().map() as it only iterates once.
    """
    return [mapper(item) for item in items if predicate(item)]


def partition(
    predicate: Callable[[T], bool], items: Iterable[T]
) -> tuple[list[T], list[T]]:
    """Partition items into two lists based on predicate.

    Returns: (items_matching_predicate, items_not_matching_predicate)
    """
    matches, non_matches = [], []
    for item in items:
        (matches if predicate(item) else non_matches).append(item)
    return matches, non_matches


def flatten(nested: Iterable[Iterable[T]]) -> list[T]:
    """Flatten a nested iterable into a single list."""
    return [item for sublist in nested for item in sublist]


def group_by(key_fn: Callable[[T], str], items: Iterable[T]) -> dict[str, list[T]]:
    """Group items by a key function.

    Example:
        group_by(lambda x: x['type'], items)
    """
    groups: dict[str, list[T]] = {}
    for item in items:
        key = key_fn(item)
        groups.setdefault(key, []).append(item)
    return groups


def pluck(key: str, items: Iterable[dict[str, Any]]) -> list[Any]:
    """Extract a specific key from a list of dictionaries.

    Example:
        pluck('name', [{'name': 'a'}, {'name': 'b'}]) # ['a', 'b']
    """
    return [item.get(key) for item in items]


# ============================================================================
# Pagination Utilities
# ============================================================================


def paginate(
    fetch_fn: Callable[[int], list[T]],
    per_page: int = 100,
    max_pages: int | None = None,
) -> list[T]:
    """Generic pagination helper.

    Args:
        fetch_fn: Function that takes a page number and returns items
        per_page: Items per page (used to detect last page)
        max_pages: Optional maximum number of pages to fetch

    Returns:
        All items from all pages
    """
    all_items = []
    page = 1

    while max_pages is None or page <= max_pages:
        items = fetch_fn(page)

        if not items:
            break

        all_items.extend(items)

        if len(items) < per_page:
            break

        page += 1

    return all_items


# ============================================================================
# Date/Time Utilities
# ============================================================================


def parse_iso_date(date_str: str) -> datetime:
    """Parse an ISO 8601 date string to datetime.

    GitHub API returns ISO 8601 with 'Z' suffix for UTC.
    Python's fromisoformat() requires '+00:00' instead.

    Pure function using standard library only.
    """
    # GitHub returns: "2024-01-15T10:30:00Z"
    # Normalize to: "2024-01-15T10:30:00+00:00"
    normalized = date_str.replace("Z", "+00:00") if date_str.endswith("Z") else date_str
    return datetime.fromisoformat(normalized)


def days_ago(dt: datetime, reference: datetime | None = None) -> int:
    """Calculate the number of days between a datetime and now (or reference).

    Args:
        dt: The datetime to compare
        reference: Reference datetime (defaults to now in UTC)

    Returns:
        Number of days (can be negative if dt is in the future)
    """
    if reference is None:
        reference = datetime.now(timezone.utc)
    return (reference - dt).days


def is_older_than(dt: datetime, days: int, reference: datetime | None = None) -> bool:
    """Check if a datetime is older than a given number of days.

    Pure predicate function.
    """
    return days_ago(dt, reference) > days


def create_age_threshold(days: int, reference: datetime | None = None) -> datetime:
    """Create a datetime threshold for age comparisons.

    Returns a datetime that is 'days' before the reference (or now).
    """
    if reference is None:
        reference = datetime.now(timezone.utc)
    return reference - timedelta(days=days)


# ============================================================================
# Data Extraction Helpers
# ============================================================================


def safe_get(obj: dict[str, Any], path: str, default: Any = None) -> Any:
    """Safely get a nested value from a dictionary using dot notation.

    Example:
        safe_get({'a': {'b': 'c'}}, 'a.b') # 'c'
        safe_get({'a': {}}, 'a.b.c', 'default') # 'default'
    """
    keys = path.split(".")
    current = obj

    for key in keys:
        if isinstance(current, dict):
            current = current.get(key)
            if current is None:
                return default
        else:
            return default

    return current


def extract_fields(
    obj: dict[str, Any], fields: dict[str, str | tuple[str, Any]]
) -> dict[str, Any]:
    """Extract multiple fields from an object with optional defaults.

    Args:
        obj: Source dictionary
        fields: Mapping of output_key -> path (or (path, default))

    Example:
        extract_fields(
            {'user': {'name': 'Alice'}},
            {'username': 'user.name', 'age': ('user.age', 0)}
        )
        # {'username': 'Alice', 'age': 0}
    """
    result = {}
    for out_key, path_spec in fields.items():
        if isinstance(path_spec, tuple):
            path, default = path_spec
        else:
            path, default = path_spec, None

        result[out_key] = safe_get(obj, path, default)

    return result


# ============================================================================
# Result Aggregation
# ============================================================================


def count_by_key(items: Iterable[dict[str, Any]], key: str) -> dict[Any, int]:
    """Count occurrences of values for a specific key.

    Example:
        count_by_key([{'type': 'A'}, {'type': 'B'}, {'type': 'A'}], 'type')
        # {'A': 2, 'B': 1}
    """
    counts: dict[Any, int] = {}
    for item in items:
        value = item.get(key)
        counts[value] = counts.get(value, 0) + 1
    return counts


def sum_by_key(items: Iterable[dict[str, Any]], key: str) -> int | float:
    """Sum values for a specific key across all items."""
    return sum(item.get(key, 0) for item in items)
