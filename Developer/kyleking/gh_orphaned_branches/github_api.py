"""GitHub API wrapper using httpx for HTTP requests (VCR-compatible)."""

import json
import os
import subprocess
from collections.abc import Callable
from typing import Any

import httpx

from .utils import paginate


def _get_github_token() -> str:
    """Get GitHub token from GITHUB_TOKEN/GH_TOKEN env or gh CLI."""
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        return token
    try:
        result = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError("No GitHub token found. Set GITHUB_TOKEN or run 'gh auth login'") from e


def _create_github_client(token: str | None = None) -> httpx.Client:
    """Create authenticated GitHub API client."""
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


def _make_request(client: httpx.Client, endpoint: str, params: dict[str, Any] | None = None) -> dict[str, Any] | list[dict[str, Any]]:
    """Make GitHub API request."""
    try:
        response = client.get(endpoint, params=params or {})
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        raise RuntimeError(f"GitHub API error ({e.response.status_code}): {e.response.text}") from e
    except httpx.RequestError as e:
        raise RuntimeError(f"Network error: {e}") from e
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Invalid JSON response: {e}") from e


def _create_paginated_fetcher(client: httpx.Client, endpoint: str, per_page: int = 100, **base_params: Any) -> Callable[[int], list[dict[str, Any]]]:
    """Create paginated fetch function for endpoint."""

    def fetch_page(page: int) -> list[dict[str, Any]]:
        params = {**base_params, "per_page": per_page, "page": page}
        result = _make_request(client, endpoint, params)
        return result if isinstance(result, list) else []

    return fetch_page


def _fetch_all_pages(client: httpx.Client, endpoint: str, per_page: int = 100, **params: Any) -> list[dict[str, Any]]:
    """Fetch all pages from paginated endpoint."""
    fetcher = _create_paginated_fetcher(client, endpoint, per_page, **params)
    return paginate(fetcher, per_page=per_page)


def _fetch_single(client: httpx.Client, endpoint: str) -> dict[str, Any]:
    """Fetch single resource (non-paginated)."""
    result = _make_request(client, endpoint)
    return result if isinstance(result, dict) else {}


def _fetch_with_fallback(client: httpx.Client, primary_endpoint: str, fallback_endpoint: str, **params: Any) -> list[dict[str, Any]]:
    """Fetch from primary endpoint, fallback to secondary if fails."""
    try:
        return _fetch_all_pages(client, primary_endpoint, **params)
    except RuntimeError:
        return _fetch_all_pages(client, fallback_endpoint, **params)


def fetch_repositories(namespace: str, include_forks: bool = False, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    """Fetch all repositories for user or organization."""
    should_close = client is None
    if client is None:
        client = _create_github_client()
    try:
        repos = _fetch_with_fallback(client, f"/users/{namespace}/repos", f"/orgs/{namespace}/repos", per_page=100)
        return repos if include_forks else [repo for repo in repos if not repo.get("fork", False)]
    finally:
        if should_close:
            client.close()


def fetch_branches(owner: str, repo: str, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    """Fetch all branches for repository."""
    should_close = client is None
    if client is None:
        client = _create_github_client()
    try:
        return _fetch_all_pages(client, f"/repos/{owner}/{repo}/branches", per_page=100)
    finally:
        if should_close:
            client.close()


def fetch_branch_details(owner: str, repo: str, branch: str, client: httpx.Client | None = None) -> dict[str, Any]:
    """Fetch detailed information about specific branch."""
    should_close = client is None
    if client is None:
        client = _create_github_client()
    try:
        return _fetch_single(client, f"/repos/{owner}/{repo}/branches/{branch}")
    finally:
        if should_close:
            client.close()


def fetch_pulls_for_branch(owner: str, repo: str, branch: str, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    """Fetch all PRs (open and closed) for specific branch."""
    should_close = client is None
    if client is None:
        client = _create_github_client()
    try:
        open_pulls = _fetch_all_pages(client, f"/repos/{owner}/{repo}/pulls", head=f"{owner}:{branch}", state="open", per_page=100)
        closed_pulls = _fetch_all_pages(client, f"/repos/{owner}/{repo}/pulls", head=f"{owner}:{branch}", state="closed", per_page=100)
        return open_pulls + closed_pulls
    finally:
        if should_close:
            client.close()
