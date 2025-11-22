"""GitHub API wrapper using httpx for HTTP requests (VCR-compatible)."""

import json
import os
import subprocess
from collections.abc import Callable
from typing import Any

import httpx

from .utils import paginate


# ============================================================================
# GitHub Authentication
# ============================================================================


def _get_github_token() -> str:
    """Get GitHub token from gh CLI or environment.

    Tries in order:
    1. GITHUB_TOKEN environment variable
    2. GH_TOKEN environment variable
    3. gh auth token command

    Raises:
        RuntimeError: If no token can be obtained
    """
    # Try environment variables first
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        return token

    # Fall back to gh CLI
    try:
        result = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(
            "No GitHub token found. Set GITHUB_TOKEN or authenticate with 'gh auth login'"
        ) from e


# ============================================================================
# HTTP Client
# ============================================================================


def _create_github_client(token: str | None = None) -> httpx.Client:
    """Create an authenticated GitHub API client.

    Args:
        token: GitHub personal access token (fetched automatically if None)

    Returns:
        Configured httpx.Client
    """
    if token is None:
        token = _get_github_token()

    return httpx.Client(
        base_url="https://api.github.com",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        timeout=30.0,
    )


# ============================================================================
# Low-level API Helpers
# ============================================================================


def _make_request(
    client: httpx.Client,
    endpoint: str,
    params: dict[str, Any] | None = None,
) -> dict[str, Any] | list[dict[str, Any]]:
    """Make a GitHub API request.

    Pure function that either returns data or raises an exception.

    Args:
        client: httpx client
        endpoint: API endpoint (e.g., "/users/octocat/repos")
        params: Query parameters

    Returns:
        JSON response (dict or list)

    Raises:
        RuntimeError: On API errors
    """
    try:
        response = client.get(endpoint, params=params or {})
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        raise RuntimeError(
            f"GitHub API error ({e.response.status_code}): {e.response.text}"
        ) from e
    except httpx.RequestError as e:
        raise RuntimeError(f"Network error: {e}") from e
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Invalid JSON response: {e}") from e


# ============================================================================
# Pagination
# ============================================================================


def _create_paginated_fetcher(
    client: httpx.Client,
    endpoint: str,
    per_page: int = 100,
    **base_params: Any,
) -> Callable[[int], list[dict[str, Any]]]:
    """Create a paginated fetch function for a specific endpoint.

    Returns a function that takes a page number and returns results.
    This is a higher-order function that returns a configured fetcher.
    """

    def fetch_page(page: int) -> list[dict[str, Any]]:
        params = {**base_params, "per_page": per_page, "page": page}
        result = _make_request(client, endpoint, params)
        return result if isinstance(result, list) else []

    return fetch_page


def _fetch_all_pages(
    client: httpx.Client,
    endpoint: str,
    per_page: int = 100,
    **params: Any,
) -> list[dict[str, Any]]:
    """Fetch all pages from a paginated endpoint.

    Pure function that returns all results from all pages.
    """
    fetcher = _create_paginated_fetcher(client, endpoint, per_page, **params)
    return paginate(fetcher, per_page=per_page)


def _fetch_single(client: httpx.Client, endpoint: str) -> dict[str, Any]:
    """Fetch a single resource (non-paginated).

    Pure function for endpoints that return a single object.
    """
    result = _make_request(client, endpoint)
    return result if isinstance(result, dict) else {}


# ============================================================================
# Fetch with Fallback
# ============================================================================


def _fetch_with_fallback(
    client: httpx.Client,
    primary_endpoint: str,
    fallback_endpoint: str,
    **params: Any,
) -> list[dict[str, Any]]:
    """Fetch from primary endpoint, fall back to secondary if it fails.

    Useful for user vs organization endpoints.
    """
    try:
        return _fetch_all_pages(client, primary_endpoint, **params)
    except RuntimeError:
        return _fetch_all_pages(client, fallback_endpoint, **params)


# ============================================================================
# Domain-Specific API Functions
# ============================================================================


def fetch_repositories(
    namespace: str,
    include_forks: bool = False,
    client: httpx.Client | None = None,
) -> list[dict[str, Any]]:
    """Fetch all repositories for a user or organization.

    Functional wrapper that tries user endpoint first, then org endpoint.

    Args:
        namespace: GitHub username or organization name
        include_forks: Whether to include forked repositories
        client: Optional httpx client (created if None)

    Returns:
        List of repository objects
    """
    should_close = client is None
    if client is None:
        client = _create_github_client()

    try:
        repos = _fetch_with_fallback(
            client,
            f"/users/{namespace}/repos",
            f"/orgs/{namespace}/repos",
            per_page=100,
        )

        if include_forks:
            return repos

        # Filter out forks
        return [repo for repo in repos if not repo.get("fork", False)]
    finally:
        if should_close:
            client.close()


def fetch_branches(
    owner: str,
    repo: str,
    client: httpx.Client | None = None,
) -> list[dict[str, Any]]:
    """Fetch all branches for a repository.

    Args:
        owner: Repository owner
        repo: Repository name
        client: Optional httpx client (created if None)

    Returns:
        List of branch objects
    """
    should_close = client is None
    if client is None:
        client = _create_github_client()

    try:
        return _fetch_all_pages(client, f"/repos/{owner}/{repo}/branches", per_page=100)
    finally:
        if should_close:
            client.close()


def fetch_branch_details(
    owner: str,
    repo: str,
    branch: str,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    """Fetch detailed information about a specific branch.

    Args:
        owner: Repository owner
        repo: Repository name
        branch: Branch name
        client: Optional httpx client (created if None)

    Returns:
        Branch details object
    """
    should_close = client is None
    if client is None:
        client = _create_github_client()

    try:
        return _fetch_single(client, f"/repos/{owner}/{repo}/branches/{branch}")
    finally:
        if should_close:
            client.close()


def fetch_pulls_for_branch(
    owner: str,
    repo: str,
    branch: str,
    client: httpx.Client | None = None,
) -> list[dict[str, Any]]:
    """Fetch all pull requests for a specific branch.

    Returns both open and closed PRs.

    Args:
        owner: Repository owner
        repo: Repository name
        branch: Branch name
        client: Optional httpx client (created if None)

    Returns:
        List of pull request objects
    """
    should_close = client is None
    if client is None:
        client = _create_github_client()

    try:
        # Fetch both states and combine
        open_pulls = _fetch_all_pages(
            client,
            f"/repos/{owner}/{repo}/pulls",
            head=f"{owner}:{branch}",
            state="open",
            per_page=100,
        )
        closed_pulls = _fetch_all_pages(
            client,
            f"/repos/{owner}/{repo}/pulls",
            head=f"{owner}:{branch}",
            state="closed",
            per_page=100,
        )

        return open_pulls + closed_pulls
    finally:
        if should_close:
            client.close()
