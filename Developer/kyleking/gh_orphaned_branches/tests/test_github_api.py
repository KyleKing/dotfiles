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


class TestAuthentication:
    """Test authentication helpers."""

    def test_get_github_token_from_env(self, monkeypatch):
        """Test getting token from environment variable."""
        monkeypatch.setenv("GITHUB_TOKEN", "test_token_123")
        token = _get_github_token()
        assert token == "test_token_123"

    def test_get_github_token_gh_token_env(self, monkeypatch):
        """Test getting token from GH_TOKEN environment variable."""
        monkeypatch.delenv("GITHUB_TOKEN", raising=False)
        monkeypatch.setenv("GH_TOKEN", "gh_token_456")
        token = _get_github_token()
        assert token == "gh_token_456"

    def test_create_github_client(self):
        """Test creating GitHub client."""
        client = _create_github_client(token="test_token")
        assert isinstance(client, httpx.Client)
        assert client.base_url == "https://api.github.com"
        assert "Authorization" in client.headers
        client.close()


class TestAPIFunctions:
    """Test API functions with mocked httpx."""

    def test_fetch_repositories(self, monkeypatch):
        """Test fetching repositories."""
        mock_repos = [
            {"name": "repo1", "fork": False, "owner": {"login": "testuser"}},
            {"name": "repo2", "fork": False, "owner": {"login": "testuser"}},
        ]

        class MockClient:
            base_url = "https://api.github.com"
            headers = {}

            def get(self, endpoint, params=None):
                class MockResponse:
                    status_code = 200

                    def raise_for_status(self):
                        pass

                    def json(self):
                        return mock_repos

                return MockResponse()

            def close(self):
                pass

        def mock_create_client(token=None):
            return MockClient()

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api._create_github_client",
            mock_create_client,
        )

        repos = fetch_repositories("testuser", include_forks=False)
        assert len(repos) == 2
        assert repos[0]["name"] == "repo1"

    def test_fetch_repositories_filter_forks(self, monkeypatch):
        """Test filtering forks when fetching repositories."""
        mock_repos = [
            {"name": "repo1", "fork": False, "owner": {"login": "testuser"}},
            {"name": "repo2", "fork": True, "owner": {"login": "testuser"}},
            {"name": "repo3", "fork": False, "owner": {"login": "testuser"}},
        ]

        class MockClient:
            base_url = "https://api.github.com"
            headers = {}

            def get(self, endpoint, params=None):
                class MockResponse:
                    status_code = 200

                    def raise_for_status(self):
                        pass

                    def json(self):
                        return mock_repos

                return MockResponse()

            def close(self):
                pass

        def mock_create_client(token=None):
            return MockClient()

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api._create_github_client",
            mock_create_client,
        )

        repos = fetch_repositories("testuser", include_forks=False)
        assert len(repos) == 2
        assert all(not r.get("fork") for r in repos)


class TestErrorHandling:
    """Test error handling in API functions."""

    def test_make_request_http_error(self, monkeypatch):
        """Test error when API returns HTTP error."""
        from gh_orphaned_branches.github_api import _make_request

        class MockClient:
            def get(self, endpoint, params=None):
                class MockResponse:
                    status_code = 404
                    text = "Not found"

                    def raise_for_status(self):
                        raise httpx.HTTPStatusError(
                            "404", request=None, response=self
                        )

                return MockResponse()

        client = MockClient()
        with pytest.raises(RuntimeError, match="GitHub API error"):
            _make_request(client, "/test")


# VCR tests (these would record real API interactions)
@pytest.mark.vcr()
class TestGitHubAPIWithVCR:
    """Test GitHub API with VCR cassettes.

    These tests use pytest-vcr to record/replay HTTP interactions.
    On first run, they make real API calls and record the responses.
    Subsequent runs use the recorded cassettes.
    """

    @pytest.mark.skip(reason="Requires real GitHub API access and token")
    def test_fetch_repositories_vcr(self, vcr):
        """Test fetching repositories with VCR recording.

        This test is skipped by default as it requires real API access.
        To run: pytest -v -m 'not skip' and ensure GITHUB_TOKEN is set.
        """
        repos = fetch_repositories("octocat", include_forks=False)
        assert isinstance(repos, list)
        if repos:
            assert "name" in repos[0]
            assert "owner" in repos[0]

    @pytest.mark.skip(reason="Requires real GitHub API access and token")
    def test_fetch_branches_vcr(self, vcr):
        """Test fetching branches with VCR recording.

        This test is skipped by default as it requires real API access.
        """
        branches = fetch_branches("octocat", "hello-world")
        assert isinstance(branches, list)
        if branches:
            assert "name" in branches[0]
