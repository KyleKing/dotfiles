"""Core business logic for finding orphaned branches (functional)."""

from collections.abc import Callable
from datetime import datetime, timezone
from typing import Any, TypedDict

from .github_api import (
    fetch_branch_details,
    fetch_branches,
    fetch_pulls_for_branch,
    fetch_repositories,
)
from .utils import (
    create_age_threshold,
    days_ago,
    parse_iso_date,
)


# ============================================================================
# Type Definitions
# ============================================================================


class BranchInfo(TypedDict):
    """Information about a branch."""

    name: str
    last_commit: str
    age_days: int


class ClosedPRBranchInfo(TypedDict):
    """Information about a branch with a closed PR."""

    name: str
    pr_number: int
    pr_title: str
    pr_state: str
    merged: bool
    closed_at: str
    last_commit: str


class RepositoryResults(TypedDict):
    """Results for a single repository."""

    closed_pr_branches: list[ClosedPRBranchInfo]
    no_pr_branches_stale: list[BranchInfo]
    no_pr_branches_recent: list[BranchInfo]


# ============================================================================
# Pure Functions for Branch Classification
# ============================================================================


def extract_commit_date(branch_details: dict[str, Any]) -> datetime:
    """Extract and parse commit date from branch details.

    Pure function that navigates the API response structure.
    """
    date_str = branch_details["commit"]["commit"]["committer"]["date"]
    return parse_iso_date(date_str)


def is_default_branch(branch_name: str, default_branch: str) -> bool:
    """Check if a branch is the default branch.

    Simple pure predicate.
    """
    return branch_name == default_branch


def is_pr_closed(pr: dict[str, Any]) -> bool:
    """Check if a pull request is closed.

    Pure predicate function.
    """
    return pr.get("state") == "closed"


def is_pr_merged(pr: dict[str, Any]) -> bool:
    """Check if a pull request was merged.

    Pure predicate function.
    """
    return pr.get("merged_at") is not None


def create_branch_info(branch_name: str, commit_date: datetime) -> BranchInfo:
    """Create a BranchInfo object from raw data.

    Pure function for data transformation.
    """
    return BranchInfo(
        name=branch_name,
        last_commit=commit_date.isoformat(),
        age_days=days_ago(commit_date),
    )


def create_closed_pr_branch_info(
    branch_name: str, pr: dict[str, Any], commit_date: datetime
) -> ClosedPRBranchInfo:
    """Create a ClosedPRBranchInfo object from branch and PR data.

    Pure function for data transformation.
    """
    return ClosedPRBranchInfo(
        name=branch_name,
        pr_number=pr["number"],
        pr_title=pr["title"],
        pr_state=pr["state"],
        merged=is_pr_merged(pr),
        closed_at=pr.get("closed_at", ""),
        last_commit=commit_date.isoformat(),
    )


# ============================================================================
# Branch Classification Logic (Functional Composition)
# ============================================================================


def classify_branch(
    branch_name: str,
    commit_date: datetime,
    pulls: list[dict[str, Any]],
    stale_threshold: datetime,
) -> tuple[str, BranchInfo | ClosedPRBranchInfo]:
    """Classify a branch based on its PRs and age.

    Returns: (category, branch_info)
    Categories: 'closed_pr', 'stale_no_pr', 'recent_no_pr'

    Pure function with no side effects.
    """
    if not pulls:
        # No PR exists
        branch_info = create_branch_info(branch_name, commit_date)
        category = "stale_no_pr" if commit_date < stale_threshold else "recent_no_pr"
        return category, branch_info

    # Check for closed PRs
    closed_prs = [pr for pr in pulls if is_pr_closed(pr)]

    if closed_prs:
        # Use the first closed PR (could extend to handle multiple)
        pr = closed_prs[0]
        branch_info = create_closed_pr_branch_info(branch_name, pr, commit_date)
        return "closed_pr", branch_info

    # Has open PR - not orphaned
    return "active", create_branch_info(branch_name, commit_date)


def process_branch(
    branch: dict[str, Any],
    owner: str,
    repo: str,
    stale_threshold: datetime,
) -> tuple[str, BranchInfo | ClosedPRBranchInfo] | None:
    """Process a single branch and return its classification.

    Pure function that coordinates API calls and classification.
    Returns None if branch should be skipped (active).
    """
    branch_name = branch["name"]

    # Fetch additional data
    branch_details = fetch_branch_details(owner, repo, branch_name)
    commit_date = extract_commit_date(branch_details)
    pulls = fetch_pulls_for_branch(owner, repo, branch_name)

    # Classify the branch
    category, info = classify_branch(branch_name, commit_date, pulls, stale_threshold)

    # Filter out active branches
    if category == "active":
        return None

    return category, info


def create_empty_results() -> RepositoryResults:
    """Create an empty results dictionary.

    Pure function for initialization.
    """
    return RepositoryResults(
        closed_pr_branches=[],
        no_pr_branches_stale=[],
        no_pr_branches_recent=[],
    )


def add_to_results(
    results: RepositoryResults,
    category: str,
    info: BranchInfo | ClosedPRBranchInfo,
) -> RepositoryResults:
    """Add a branch to the appropriate category in results.

    Pure function that returns a new results dict (functional approach).
    """
    # Create a copy to maintain immutability
    new_results = RepositoryResults(
        closed_pr_branches=results["closed_pr_branches"][:],
        no_pr_branches_stale=results["no_pr_branches_stale"][:],
        no_pr_branches_recent=results["no_pr_branches_recent"][:],
    )

    if category == "closed_pr":
        new_results["closed_pr_branches"].append(info)  # type: ignore
    elif category == "stale_no_pr":
        new_results["no_pr_branches_stale"].append(info)  # type: ignore
    elif category == "recent_no_pr":
        new_results["no_pr_branches_recent"].append(info)  # type: ignore

    return new_results


# ============================================================================
# Repository Analysis (Main Logic)
# ============================================================================


def analyze_repository(
    repo: dict[str, Any],
    stale_days: int,
    progress_callback: Callable[[str], None] | None = None,
) -> RepositoryResults:
    """Analyze a single repository for orphaned branches.

    Functional approach: takes data, returns results, minimal side effects.
    Only side effect is the optional progress callback.
    """
    owner = repo["owner"]["login"]
    repo_name = repo["name"]
    default_branch = repo["default_branch"]

    if progress_callback:
        progress_callback(repo_name)

    # Fetch all branches
    branches = fetch_branches(owner, repo_name)

    # Filter out default branch (pure function)
    non_default_branches = [
        b for b in branches if not is_default_branch(b["name"], default_branch)
    ]

    # Create age threshold
    stale_threshold = create_age_threshold(stale_days)

    # Process each branch and accumulate results
    results = create_empty_results()

    for branch in non_default_branches:
        classification = process_branch(branch, owner, repo_name, stale_threshold)

        if classification is not None:
            category, info = classification
            results = add_to_results(results, category, info)

    return results


def has_orphaned_branches(results: RepositoryResults) -> bool:
    """Check if results contain any orphaned branches.

    Pure predicate function.
    """
    return bool(
        results["closed_pr_branches"]
        or results["no_pr_branches_stale"]
        or results["no_pr_branches_recent"]
    )


def filter_non_empty_results(
    all_results: dict[str, RepositoryResults]
) -> dict[str, RepositoryResults]:
    """Filter out repositories with no orphaned branches.

    Pure function that returns only repos with results.
    """
    return {
        repo_name: results
        for repo_name, results in all_results.items()
        if has_orphaned_branches(results)
    }


# ============================================================================
# Namespace Analysis (Top-level Function)
# ============================================================================


def analyze_namespace(
    namespace: str,
    stale_days: int,
    include_forks: bool = False,
    progress_callback: Callable[[str], None] | None = None,
) -> dict[str, RepositoryResults]:
    """Analyze all repositories in a namespace.

    Main entry point for the analysis logic.
    Mostly functional with controlled side effects (progress callback).
    """
    # Fetch all repositories
    repos = fetch_repositories(namespace, include_forks)

    # Analyze each repository
    all_results = {}
    for repo in repos:
        repo_name = repo["name"]
        results = analyze_repository(repo, stale_days, progress_callback)
        all_results[repo_name] = results

    # Filter to only non-empty results
    return filter_non_empty_results(all_results)


# ============================================================================
# Summary Statistics (Pure Functions)
# ============================================================================


def calculate_summary(results: dict[str, RepositoryResults]) -> dict[str, int]:
    """Calculate summary statistics from results.

    Pure function that aggregates data.
    """
    total_closed_pr = sum(
        len(repo_results["closed_pr_branches"]) for repo_results in results.values()
    )
    total_stale_no_pr = sum(
        len(repo_results["no_pr_branches_stale"]) for repo_results in results.values()
    )
    total_recent_no_pr = sum(
        len(repo_results["no_pr_branches_recent"]) for repo_results in results.values()
    )

    return {
        "closed_pr_branches": total_closed_pr,
        "stale_no_pr_branches": total_stale_no_pr,
        "recent_no_pr_branches": total_recent_no_pr,
        "total_orphaned": total_closed_pr + total_stale_no_pr,
        "total_repositories": len(results),
    }
