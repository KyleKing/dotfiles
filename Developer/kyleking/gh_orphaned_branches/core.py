"""Core business logic for finding orphaned branches."""

from collections.abc import Callable
from datetime import datetime
from typing import Any, TypedDict

from .github_api import fetch_branch_details, fetch_branches, fetch_pulls_for_branch, fetch_repositories
from .utils import create_age_threshold, days_ago, parse_iso_date


class BranchInfo(TypedDict):
    name: str
    last_commit: str
    age_days: int


class ClosedPRBranchInfo(TypedDict):
    name: str
    pr_number: int
    pr_title: str
    pr_state: str
    merged: bool
    closed_at: str
    last_commit: str


class RepositoryResults(TypedDict):
    closed_pr_branches: list[ClosedPRBranchInfo]
    no_pr_branches_stale: list[BranchInfo]
    no_pr_branches_recent: list[BranchInfo]


def _extract_commit_date(branch_details: dict[str, Any]) -> datetime:
    """Extract and parse commit date from branch details."""
    return parse_iso_date(branch_details["commit"]["commit"]["committer"]["date"])


def _create_branch_info(branch_name: str, commit_date: datetime) -> BranchInfo:
    """Create BranchInfo from branch name and commit date."""
    return BranchInfo(name=branch_name, last_commit=commit_date.isoformat(), age_days=days_ago(commit_date))


def _create_closed_pr_branch_info(branch_name: str, pr: dict[str, Any], commit_date: datetime) -> ClosedPRBranchInfo:
    """Create ClosedPRBranchInfo from branch, PR, and commit data."""
    return ClosedPRBranchInfo(
        name=branch_name,
        pr_number=pr["number"],
        pr_title=pr["title"],
        pr_state=pr["state"],
        merged=pr.get("merged_at") is not None,
        closed_at=pr.get("closed_at", ""),
        last_commit=commit_date.isoformat(),
    )


def _classify_branch(
    branch_name: str,
    commit_date: datetime,
    pulls: list[dict[str, Any]],
    stale_threshold: datetime,
) -> tuple[str, BranchInfo | ClosedPRBranchInfo]:
    """Classify branch based on PRs and age. Returns (category, branch_info)."""
    if not pulls:
        branch_info = _create_branch_info(branch_name, commit_date)
        category = "stale_no_pr" if commit_date < stale_threshold else "recent_no_pr"
        return category, branch_info

    closed_prs = [pr for pr in pulls if pr.get("state") == "closed"]
    if closed_prs:
        return "closed_pr", _create_closed_pr_branch_info(branch_name, closed_prs[0], commit_date)

    return "active", _create_branch_info(branch_name, commit_date)


def _process_branch(
    branch: dict[str, Any],
    owner: str,
    repo: str,
    stale_threshold: datetime,
) -> tuple[str, BranchInfo | ClosedPRBranchInfo] | None:
    """Process a single branch and return its classification or None if active."""
    branch_name = branch["name"]
    branch_details = fetch_branch_details(owner, repo, branch_name)
    commit_date = _extract_commit_date(branch_details)
    pulls = fetch_pulls_for_branch(owner, repo, branch_name)

    category, info = _classify_branch(branch_name, commit_date, pulls, stale_threshold)
    return None if category == "active" else (category, info)


def _create_empty_results() -> RepositoryResults:
    """Create empty results dictionary."""
    return RepositoryResults(closed_pr_branches=[], no_pr_branches_stale=[], no_pr_branches_recent=[])


def _add_to_results(results: RepositoryResults, category: str, info: BranchInfo | ClosedPRBranchInfo) -> RepositoryResults:
    """Add branch to appropriate category. Returns new results dict."""
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


def analyze_repository(
    repo: dict[str, Any],
    stale_days: int,
    progress_callback: Callable[[str], None] | None = None,
) -> RepositoryResults:
    """Analyze a single repository for orphaned branches."""
    owner = repo["owner"]["login"]
    repo_name = repo["name"]
    default_branch = repo["default_branch"]

    if progress_callback:
        progress_callback(repo_name)

    branches = fetch_branches(owner, repo_name)
    non_default_branches = [b for b in branches if b["name"] != default_branch]
    stale_threshold = create_age_threshold(stale_days)

    results = _create_empty_results()
    for branch in non_default_branches:
        classification = _process_branch(branch, owner, repo_name, stale_threshold)
        if classification is not None:
            category, info = classification
            results = _add_to_results(results, category, info)

    return results


def _has_orphaned_branches(results: RepositoryResults) -> bool:
    """Check if results contain any orphaned branches."""
    return bool(results["closed_pr_branches"] or results["no_pr_branches_stale"] or results["no_pr_branches_recent"])


def analyze_namespace(
    namespace: str,
    stale_days: int,
    include_forks: bool = False,
    progress_callback: Callable[[str], None] | None = None,
) -> dict[str, RepositoryResults]:
    """Analyze all repositories in a namespace. Returns only non-empty results."""
    repos = fetch_repositories(namespace, include_forks)
    all_results = {repo["name"]: analyze_repository(repo, stale_days, progress_callback) for repo in repos}
    return {name: results for name, results in all_results.items() if _has_orphaned_branches(results)}


def calculate_summary(results: dict[str, RepositoryResults]) -> dict[str, int]:
    """Calculate summary statistics from results."""
    total_closed = sum(len(r["closed_pr_branches"]) for r in results.values())
    total_stale = sum(len(r["no_pr_branches_stale"]) for r in results.values())
    total_recent = sum(len(r["no_pr_branches_recent"]) for r in results.values())
    return {
        "closed_pr_branches": total_closed,
        "stale_no_pr_branches": total_stale,
        "recent_no_pr_branches": total_recent,
        "total_orphaned": total_closed + total_stale,
        "total_repositories": len(results),
    }
