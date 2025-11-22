"""GitHub API wrapper with functional approach."""

import json
import subprocess
import sys
from collections.abc import Callable
from typing import Any

from .utils import paginate


# ============================================================================
# Low-level API Helpers (Pure Functions)
# ============================================================================


def run_gh_command(args: list[str]) -> dict[str, Any] | list[dict[str, Any]]:
    """Run a gh api command and return JSON response.

    Pure function that either returns data or raises an exception.
    """
    try:
        result = subprocess.run(
            ["gh", "api", *args],
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"GitHub API error: {e.stderr}") from e
    except FileNotFoundError as e:
        raise RuntimeError(
            "GitHub CLI ('gh') not found. Please install it from https://cli.github.com/"
        ) from e
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Invalid JSON response from GitHub API: {e}") from e


def build_api_params(**kwargs: Any) -> list[str]:
    """Build GitHub API parameter list from kwargs.

    Pure function that converts kwargs to gh CLI format.

    Example:
        build_api_params(per_page=100, page=1)
        # ['-f', 'per_page=100', '-f', 'page=1']
    """
    params = []
    for key, value in kwargs.items():
        params.extend(["-f", f"{key}={value}"])
    return params


# ============================================================================
# API Endpoint Builders (Higher-order Functions)
# ============================================================================


def create_paginated_fetcher(
    endpoint: str, **base_params: Any
) -> Callable[[int], list[dict[str, Any]]]:
    """Create a paginated fetch function for a specific endpoint.

    Returns a function that takes a page number and returns results.
    This is a higher-order function that returns a configured fetcher.
    """

    def fetch_page(page: int) -> list[dict[str, Any]]:
        params = build_api_params(**base_params, page=page)
        result = run_gh_command([endpoint, *params])
        return result if isinstance(result, list) else []

    return fetch_page


def fetch_with_fallback(
    primary_endpoint: str, fallback_endpoint: str, **params: Any
) -> list[dict[str, Any]]:
    """Fetch from primary endpoint, fall back to secondary if it fails.

    Useful for user vs organization endpoints.
    """
    try:
        return fetch_all_pages(primary_endpoint, **params)
    except RuntimeError:
        return fetch_all_pages(fallback_endpoint, **params)


# ============================================================================
# Generic Fetch Functions
# ============================================================================


def fetch_all_pages(endpoint: str, **params: Any) -> list[dict[str, Any]]:
    """Fetch all pages from a paginated endpoint.

    Pure function that returns all results from all pages.
    """
    per_page = params.get("per_page", 100)
    fetcher = create_paginated_fetcher(endpoint, **params)
    return paginate(fetcher, per_page=per_page)


def fetch_single(endpoint: str) -> dict[str, Any]:
    """Fetch a single resource (non-paginated).

    Pure function for endpoints that return a single object.
    """
    result = run_gh_command([endpoint])
    return result if isinstance(result, dict) else {}


# ============================================================================
# Domain-Specific API Functions
# ============================================================================


def fetch_repositories(namespace: str, include_forks: bool = False) -> list[dict[str, Any]]:
    """Fetch all repositories for a user or organization.

    Functional wrapper that tries user endpoint first, then org endpoint.
    """
    repos = fetch_with_fallback(
        f"/users/{namespace}/repos",
        f"/orgs/{namespace}/repos",
        per_page=100,
    )

    if include_forks:
        return repos

    # Filter out forks (pure function)
    return [repo for repo in repos if not repo.get("fork", False)]


def fetch_branches(owner: str, repo: str) -> list[dict[str, Any]]:
    """Fetch all branches for a repository.

    Pure function that returns all branch data.
    """
    return fetch_all_pages(f"/repos/{owner}/{repo}/branches", per_page=100)


def fetch_branch_details(owner: str, repo: str, branch: str) -> dict[str, Any]:
    """Fetch detailed information about a specific branch.

    Pure function for a single branch.
    """
    return fetch_single(f"/repos/{owner}/{repo}/branches/{branch}")


def fetch_pulls_for_branch(owner: str, repo: str, branch: str) -> list[dict[str, Any]]:
    """Fetch all pull requests for a specific branch.

    Returns both open and closed PRs. Pure function.
    """
    # Fetch both states and combine
    open_pulls = fetch_all_pages(
        f"/repos/{owner}/{repo}/pulls",
        head=f"{owner}:{branch}",
        state="open",
        per_page=100,
    )
    closed_pulls = fetch_all_pages(
        f"/repos/{owner}/{repo}/pulls",
        head=f"{owner}:{branch}",
        state="closed",
        per_page=100,
    )

    return open_pulls + closed_pulls


# ============================================================================
# Batch Operations (Functional Composition)
# ============================================================================


def fetch_all_branches_with_details(
    owner: str, repo: str
) -> list[dict[str, Any]]:
    """Fetch all branches with their detailed information.

    Combines multiple API calls into a single functional operation.
    """
    branches = fetch_branches(owner, repo)

    # Map each branch to include its detailed info
    return [
        {
            **branch,
            "details": fetch_branch_details(owner, repo, branch["name"]),
        }
        for branch in branches
    ]


def fetch_repository_with_branches(
    repo: dict[str, Any],
) -> dict[str, Any]:
    """Enrich a repository object with its branches.

    Pure function that takes a repo and returns it with branches.
    """
    owner = repo["owner"]["login"]
    repo_name = repo["name"]

    return {
        **repo,
        "branches": fetch_branches(owner, repo_name),
    }
