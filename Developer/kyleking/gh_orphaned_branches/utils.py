"""Generic reusable utility functions."""

from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from typing import TypeVar

T = TypeVar("T")


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


def create_age_threshold(days: int, reference: datetime | None = None) -> datetime:
    """Create a datetime threshold for age comparisons.

    Returns a datetime that is 'days' before the reference (or now).
    """
    if reference is None:
        reference = datetime.now(timezone.utc)
    return reference - timedelta(days=days)
