"""Generic reusable utility functions."""

from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from typing import TypeVar

T = TypeVar("T")


def paginate(fetch_fn: Callable[[int], list[T]], per_page: int = 100, max_pages: int | None = None) -> list[T]:
    """Generic pagination helper."""
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


def parse_iso_date(date_str: str) -> datetime:
    """Parse ISO 8601 date string. Handles GitHub's 'Z' suffix."""
    normalized = date_str.replace("Z", "+00:00") if date_str.endswith("Z") else date_str
    return datetime.fromisoformat(normalized)


def days_ago(dt: datetime, reference: datetime | None = None) -> int:
    """Calculate days between datetime and reference (defaults to now in UTC)."""
    return ((reference or datetime.now(timezone.utc)) - dt).days


def create_age_threshold(days: int, reference: datetime | None = None) -> datetime:
    """Create datetime threshold for age comparisons."""
    return (reference or datetime.now(timezone.utc)) - timedelta(days=days)
