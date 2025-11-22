"""Tests for GitHub API wrapper with httpx and VCR."""

import pytest
import httpx

from gh_orphaned_branches.github_api import (
    _get_github_token,
    _create_github_client,
    _make_request,
    fetch_repositories,
    fetch_branches,
)


@pytest.mark.parametrize("env_var,value", [
    ("GITHUB_TOKEN", "test_token_123"),
    ("GH_TOKEN", "gh_token_456"),
])
def test_get_github_token_from_env(monkeypatch, env_var, value):
    """Test getting token from environment variables."""
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    monkeypatch.delenv("GH_TOKEN", raising=False)
    monkeypatch.setenv(env_var, value)
    token = _get_github_token()
    assert token == value


def test_create_github_client():
    """Test creating GitHub client."""
    client = _create_github_client(token="test_token")
    assert isinstance(client, httpx.Client)
    assert client.base_url == "https://api.github.com"
    assert "Authorization" in client.headers
    client.close()


class MockClient:
    """Mock httpx client for testing."""
    base_url = "https://api.github.com"
    headers = {}

    def __init__(self, response_data):
        self.response_data = response_data

    def get(self, endpoint, params=None):
        class MockResponse:
            def __init__(self, data):
                self.data = data
                self.status_code = 200

            def raise_for_status(self):
                pass

            def json(self):
                return self.data

        return MockResponse(self.response_data)

    def close(self):
        pass


@pytest.mark.parametrize("include_forks,expected_count", [
    (False, 2),
    (True, 3),
])
def test_fetch_repositories(monkeypatch, include_forks, expected_count):
    """Test fetching repositories with fork filtering."""
    mock_repos = [
        {"name": "repo1", "fork": False, "owner": {"login": "testuser"}},
        {"name": "repo2", "fork": True, "owner": {"login": "testuser"}},
        {"name": "repo3", "fork": False, "owner": {"login": "testuser"}},
    ]

    def mock_create_client(token=None):
        return MockClient(mock_repos)

    monkeypatch.setattr(
        "gh_orphaned_branches.github_api._create_github_client",
        mock_create_client,
    )

    repos = fetch_repositories("testuser", include_forks=include_forks)
    assert len(repos) == expected_count
    if not include_forks:
        assert all(not r.get("fork") for r in repos)


def test_make_request_http_error():
    """Test error when API returns HTTP error."""
    class MockErrorClient:
        def get(self, endpoint, params=None):
            class MockResponse:
                status_code = 404
                text = "Not found"

                def raise_for_status(self):
                    raise httpx.HTTPStatusError(
                        "404", request=None, response=self
                    )

            return MockResponse()

    client = MockErrorClient()
    with pytest.raises(RuntimeError, match="GitHub API error"):
        _make_request(client, "/test")


@pytest.mark.vcr()
@pytest.mark.skip(reason="Requires real GitHub API access and token")
def test_fetch_repositories_vcr(vcr):
    """Test fetching repositories with VCR recording."""
    repos = fetch_repositories("octocat", include_forks=False)
    assert isinstance(repos, list)
    if repos:
        assert "name" in repos[0]
        assert "owner" in repos[0]


@pytest.mark.vcr()
@pytest.mark.skip(reason="Requires real GitHub API access and token")
def test_fetch_branches_vcr(vcr):
    """Test fetching branches with VCR recording."""
    branches = fetch_branches("octocat", "hello-world")
    assert isinstance(branches, list)
    if branches:
        assert "name" in branches[0]
