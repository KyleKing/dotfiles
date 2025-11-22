"""Tests for GitHub API wrapper with VCR."""

import pytest

from gh_orphaned_branches.github_api import (
    build_api_params,
    create_paginated_fetcher,
    fetch_branches,
    fetch_pulls_for_branch,
    fetch_repositories,
)


class TestAPIHelpers:
    """Test low-level API helpers."""

    def test_build_api_params(self):
        """Test building API parameters."""
        params = build_api_params(per_page=100, page=1)
        assert params == ["-f", "per_page=100", "-f", "page=1"]

    def test_build_api_params_empty(self):
        """Test building API parameters with no args."""
        params = build_api_params()
        assert params == []


class TestPaginationBuilder:
    """Test pagination function builder."""

    def test_create_paginated_fetcher(self, monkeypatch):
        """Test creating a paginated fetcher."""
        # Mock the run_gh_command function
        def mock_run_gh_command(args):
            return [{"name": "test"}]

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api.run_gh_command",
            mock_run_gh_command
        )

        fetcher = create_paginated_fetcher("/test/endpoint", per_page=100)
        result = fetcher(1)

        assert result == [{"name": "test"}]


class TestAPIFunctions:
    """Test API functions with mocked data."""

    def test_fetch_repositories_user(self, monkeypatch):
        """Test fetching repositories for a user."""
        mock_repos = [
            {"name": "repo1", "fork": False},
            {"name": "repo2", "fork": False},
        ]

        def mock_fetch_all_pages(endpoint, **params):
            return mock_repos

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api.fetch_all_pages",
            mock_fetch_all_pages
        )

        repos = fetch_repositories("testuser", include_forks=False)
        assert len(repos) == 2
        assert repos[0]["name"] == "repo1"

    def test_fetch_repositories_filter_forks(self, monkeypatch):
        """Test filtering forks when fetching repositories."""
        mock_repos = [
            {"name": "repo1", "fork": False},
            {"name": "repo2", "fork": True},
            {"name": "repo3", "fork": False},
        ]

        def mock_fetch_all_pages(endpoint, **params):
            return mock_repos

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api.fetch_all_pages",
            mock_fetch_all_pages
        )

        repos = fetch_repositories("testuser", include_forks=False)
        assert len(repos) == 2
        assert all(not r.get("fork") for r in repos)

    def test_fetch_repositories_include_forks(self, monkeypatch):
        """Test including forks when fetching repositories."""
        mock_repos = [
            {"name": "repo1", "fork": False},
            {"name": "repo2", "fork": True},
        ]

        def mock_fetch_all_pages(endpoint, **params):
            return mock_repos

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api.fetch_all_pages",
            mock_fetch_all_pages
        )

        repos = fetch_repositories("testuser", include_forks=True)
        assert len(repos) == 2

    def test_fetch_branches(self, monkeypatch):
        """Test fetching branches."""
        mock_branches = [
            {"name": "main"},
            {"name": "feature-1"},
        ]

        def mock_fetch_all_pages(endpoint, **params):
            return mock_branches

        monkeypatch.setattr(
            "gh_orphaned_branches.github_api.fetch_all_pages",
            mock_fetch_all_pages
        )

        branches = fetch_branches("owner", "repo")
        assert len(branches) == 2
        assert branches[0]["name"] == "main"


# VCR tests (these would record real API interactions)
@pytest.mark.vcr()
class TestGitHubAPIWithVCR:
    """Test GitHub API with VCR cassettes.

    These tests use pytest-vcr to record/replay HTTP interactions.
    On first run, they make real API calls and record the responses.
    Subsequent runs use the recorded cassettes.
    """

    @pytest.mark.skip(reason="Requires real GitHub API access")
    def test_fetch_repositories_vcr(self, vcr):
        """Test fetching repositories with VCR recording.

        This test is skipped by default as it requires real API access.
        To run: pytest -v -m 'not skip' and ensure 'gh' is authenticated.
        """
        repos = fetch_repositories("octocat", include_forks=False)
        assert isinstance(repos, list)
        if repos:
            assert "name" in repos[0]
            assert "owner" in repos[0]

    @pytest.mark.skip(reason="Requires real GitHub API access")
    def test_fetch_branches_vcr(self, vcr):
        """Test fetching branches with VCR recording.

        This test is skipped by default as it requires real API access.
        """
        branches = fetch_branches("octocat", "hello-world")
        assert isinstance(branches, list)
        if branches:
            assert "name" in branches[0]

    @pytest.mark.skip(reason="Requires real GitHub API access")
    def test_fetch_pulls_vcr(self, vcr):
        """Test fetching pull requests with VCR recording.

        This test is skipped by default as it requires real API access.
        """
        pulls = fetch_pulls_for_branch("octocat", "hello-world", "test-branch")
        assert isinstance(pulls, list)


class TestErrorHandling:
    """Test error handling in API functions."""

    def test_run_gh_command_not_found(self, monkeypatch):
        """Test error when gh CLI is not found."""
        from gh_orphaned_branches.github_api import run_gh_command

        def mock_run(*args, **kwargs):
            raise FileNotFoundError()

        monkeypatch.setattr("subprocess.run", mock_run)

        with pytest.raises(RuntimeError, match="GitHub CLI.*not found"):
            run_gh_command(["/test"])

    def test_run_gh_command_invalid_json(self, monkeypatch):
        """Test error when API returns invalid JSON."""
        from subprocess import CompletedProcess

        from gh_orphaned_branches.github_api import run_gh_command

        def mock_run(*args, **kwargs):
            return CompletedProcess(args=[], returncode=0, stdout="invalid json")

        monkeypatch.setattr("subprocess.run", mock_run)

        with pytest.raises(RuntimeError, match="Invalid JSON"):
            run_gh_command(["/test"])
