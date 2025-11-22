"""Pytest configuration and fixtures."""

from datetime import datetime, timezone
from pathlib import Path

import pytest


@pytest.fixture
def vcr_config():
    """Configure VCR for recording/replaying HTTP interactions."""
    return {
        "filter_headers": ["authorization", "cookie"],
        "filter_query_parameters": ["access_token"],
        "decode_compressed_response": True,
    }


@pytest.fixture
def cassette_dir():
    """Directory for VCR cassettes."""
    return Path(__file__).parent / "fixtures" / "vcr_cassettes"


@pytest.fixture
def sample_repo():
    """Sample repository data."""
    return {
        "name": "test-repo",
        "owner": {"login": "testuser"},
        "default_branch": "main",
        "fork": False,
    }


@pytest.fixture
def sample_branch():
    """Sample branch data."""
    return {
        "name": "feature-branch",
        "commit": {
            "sha": "abc123",
        },
    }


@pytest.fixture
def sample_branch_details():
    """Sample branch details with commit info."""
    return {
        "name": "feature-branch",
        "commit": {
            "sha": "abc123",
            "commit": {
                "committer": {
                    "date": "2024-01-01T12:00:00Z",
                },
            },
        },
    }


@pytest.fixture
def sample_pr_closed():
    """Sample closed pull request."""
    return {
        "number": 42,
        "title": "Add new feature",
        "state": "closed",
        "merged_at": "2024-01-15T10:00:00Z",
        "closed_at": "2024-01-15T10:00:00Z",
    }


@pytest.fixture
def sample_pr_open():
    """Sample open pull request."""
    return {
        "number": 43,
        "title": "Work in progress",
        "state": "open",
        "merged_at": None,
        "closed_at": None,
    }


@pytest.fixture
def fixed_datetime():
    """Fixed datetime for testing."""
    return datetime(2024, 2, 1, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture
def sample_branch_info():
    """Sample branch info data."""
    return {
        "name": "feature-branch",
        "last_commit": "2024-01-01T12:00:00Z",
        "age_days": 31,
    }
