#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "rich>=13.7.0",
#     "click>=8.1.7",
#     "python-dateutil>=2.8.2",
# ]
# ///
"""
Find orphaned branches across GitHub repositories.

This script identifies:
1. Branches that still exist after their PR was closed/merged
2. Branches without any associated PR (optionally filtered by age)

Usage:
    uv run gh-orphaned-branches.py --namespace USERNAME
    uv run gh-orphaned-branches.py -n ORG --stale-days 5
    uv run gh-orphaned-branches.py -n USER --output json
"""

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import click
from dateutil import parser as dateutil_parser
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text

console = Console()


class GitHubAPI:
    """Wrapper for GitHub CLI API calls."""

    @staticmethod
    def run_gh_command(args: list[str]) -> dict[str, Any] | list[dict[str, Any]]:
        """Run a gh api command and return JSON response."""
        try:
            result = subprocess.run(
                ["gh", "api", *args],
                capture_output=True,
                text=True,
                check=True,
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            console.print(f"[red]Error running gh command: {e.stderr}[/red]")
            sys.exit(1)
        except FileNotFoundError:
            console.print(
                "[red]Error: 'gh' CLI not found. Please install GitHub CLI.[/red]"
            )
            sys.exit(1)
        except json.JSONDecodeError as e:
            console.print(f"[red]Error decoding JSON response: {e}[/red]")
            sys.exit(1)

    def get_repositories(
        self, namespace: str, include_forks: bool = False
    ) -> list[dict[str, Any]]:
        """Get all repositories for a user or organization."""
        repos = []
        page = 1

        with console.status(f"[bold green]Fetching repositories for {namespace}..."):
            while True:
                # Try as user first, then as org
                try:
                    data = self.run_gh_command(
                        [
                            f"/users/{namespace}/repos",
                            "-f",
                            f"per_page=100",
                            "-f",
                            f"page={page}",
                        ]
                    )
                except Exception:
                    # Try as organization
                    data = self.run_gh_command(
                        [
                            f"/orgs/{namespace}/repos",
                            "-f",
                            f"per_page=100",
                            "-f",
                            f"page={page}",
                        ]
                    )

                if not data:
                    break

                for repo in data:
                    if include_forks or not repo.get("fork", False):
                        repos.append(repo)

                if len(data) < 100:
                    break

                page += 1

        return repos

    def get_branches(self, owner: str, repo: str) -> list[dict[str, Any]]:
        """Get all branches for a repository."""
        branches = []
        page = 1

        while True:
            data = self.run_gh_command(
                [
                    f"/repos/{owner}/{repo}/branches",
                    "-f",
                    f"per_page=100",
                    "-f",
                    f"page={page}",
                ]
            )

            if not data:
                break

            branches.extend(data)

            if len(data) < 100:
                break

            page += 1

        return branches

    def get_branch_details(
        self, owner: str, repo: str, branch: str
    ) -> dict[str, Any]:
        """Get detailed information about a branch."""
        return self.run_gh_command([f"/repos/{owner}/{repo}/branches/{branch}"])

    def get_pulls_for_branch(
        self, owner: str, repo: str, branch: str
    ) -> list[dict[str, Any]]:
        """Get all PRs (open and closed) for a specific branch."""
        # Get both open and closed PRs
        pulls = []

        for state in ["open", "closed"]:
            data = self.run_gh_command(
                [
                    f"/repos/{owner}/{repo}/pulls",
                    "-f",
                    f"head={owner}:{branch}",
                    "-f",
                    f"state={state}",
                    "-f",
                    "per_page=100",
                ]
            )
            if data:
                pulls.extend(data)

        return pulls


class OrphanedBranchFinder:
    """Find orphaned branches in GitHub repositories."""

    def __init__(self, stale_days: int = 7):
        self.api = GitHubAPI()
        self.stale_days = stale_days
        self.stale_threshold = datetime.now(timezone.utc) - timedelta(days=stale_days)

    def check_repository(
        self, repo: dict[str, Any], default_branch: str
    ) -> dict[str, Any]:
        """Check a single repository for orphaned branches."""
        owner = repo["owner"]["login"]
        repo_name = repo["name"]

        branches = self.api.get_branches(owner, repo_name)
        results = {
            "closed_pr_branches": [],
            "no_pr_branches_stale": [],
            "no_pr_branches_recent": [],
        }

        for branch in branches:
            branch_name = branch["name"]

            # Skip default branch
            if branch_name == default_branch:
                continue

            # Get branch details for commit date
            branch_details = self.api.get_branch_details(owner, repo_name, branch_name)
            commit_date_str = branch_details["commit"]["commit"]["committer"]["date"]
            commit_date = dateutil_parser.isoparse(commit_date_str)

            # Get PRs for this branch
            pulls = self.api.get_pulls_for_branch(owner, repo_name, branch_name)

            if not pulls:
                # No PR exists for this branch
                branch_info = {
                    "name": branch_name,
                    "last_commit": commit_date_str,
                    "age_days": (datetime.now(timezone.utc) - commit_date).days,
                }

                if commit_date < self.stale_threshold:
                    results["no_pr_branches_stale"].append(branch_info)
                else:
                    results["no_pr_branches_recent"].append(branch_info)
            else:
                # Check if any PR is closed/merged
                for pr in pulls:
                    if pr["state"] == "closed":
                        results["closed_pr_branches"].append(
                            {
                                "name": branch_name,
                                "pr_number": pr["number"],
                                "pr_title": pr["title"],
                                "pr_state": pr["state"],
                                "merged": pr.get("merged_at") is not None,
                                "closed_at": pr.get("closed_at", ""),
                                "last_commit": commit_date_str,
                            }
                        )

        return results

    def analyze_namespace(
        self, namespace: str, include_forks: bool = False
    ) -> dict[str, Any]:
        """Analyze all repositories in a namespace."""
        repos = self.api.get_repositories(namespace, include_forks)

        console.print(
            f"\n[bold]Found {len(repos)} repositories to analyze[/bold]\n"
        )

        all_results = {}

        for repo in repos:
            repo_name = repo["name"]
            default_branch = repo["default_branch"]

            console.print(f"Analyzing [cyan]{repo_name}[/cyan]...")

            results = self.check_repository(repo, default_branch)

            # Only include repos with orphaned branches
            if any(
                results[key]
                for key in [
                    "closed_pr_branches",
                    "no_pr_branches_stale",
                    "no_pr_branches_recent",
                ]
            ):
                all_results[repo_name] = results

        return all_results


def format_table_output(results: dict[str, Any], stale_days: int) -> None:
    """Format results as rich tables."""
    console.print("\n")

    total_closed_pr = 0
    total_stale_no_pr = 0
    total_recent_no_pr = 0

    for repo_name, repo_results in results.items():
        has_issues = False

        # Branches with closed PRs
        if repo_results["closed_pr_branches"]:
            has_issues = True
            total_closed_pr += len(repo_results["closed_pr_branches"])

            table = Table(
                title=f"{repo_name} - Branches with Closed/Merged PRs",
                show_header=True,
                header_style="bold magenta",
            )
            table.add_column("Branch", style="cyan")
            table.add_column("PR #", style="yellow")
            table.add_column("Status", style="green")
            table.add_column("Last Commit", style="blue")

            for branch in repo_results["closed_pr_branches"]:
                status = "Merged" if branch["merged"] else "Closed"
                table.add_row(
                    branch["name"],
                    f"#{branch['pr_number']}",
                    status,
                    branch["last_commit"][:10],
                )

            console.print(table)
            console.print(
                f"[yellow]→ Action: Delete {len(repo_results['closed_pr_branches'])} branch(es)[/yellow]\n"
            )

        # Stale branches without PRs
        if repo_results["no_pr_branches_stale"]:
            has_issues = True
            total_stale_no_pr += len(repo_results["no_pr_branches_stale"])

            table = Table(
                title=f"{repo_name} - Stale Branches (>{stale_days} days, No PR)",
                show_header=True,
                header_style="bold red",
            )
            table.add_column("Branch", style="cyan")
            table.add_column("Age (days)", style="red")
            table.add_column("Last Commit", style="blue")

            for branch in repo_results["no_pr_branches_stale"]:
                table.add_row(
                    branch["name"],
                    str(branch["age_days"]),
                    branch["last_commit"][:10],
                )

            console.print(table)
            console.print(
                f"[yellow]→ Action: Review and consider deleting {len(repo_results['no_pr_branches_stale'])} branch(es)[/yellow]\n"
            )

        # Recent branches without PRs (informational)
        if repo_results["no_pr_branches_recent"]:
            total_recent_no_pr += len(repo_results["no_pr_branches_recent"])

            table = Table(
                title=f"{repo_name} - Recent Branches (≤{stale_days} days, No PR)",
                show_header=True,
                header_style="bold blue",
            )
            table.add_column("Branch", style="cyan")
            table.add_column("Age (days)", style="blue")
            table.add_column("Last Commit", style="blue")

            for branch in repo_results["no_pr_branches_recent"]:
                table.add_row(
                    branch["name"],
                    str(branch["age_days"]),
                    branch["last_commit"][:10],
                )

            console.print(table)
            console.print(
                f"[blue]→ Info: {len(repo_results['no_pr_branches_recent'])} active branch(es)[/blue]\n"
            )

    # Summary
    summary = Panel(
        Text.from_markup(
            f"""[bold]Summary[/bold]

[red]Branches with closed/merged PRs:[/red] {total_closed_pr}
[yellow]Stale branches without PR (>{stale_days} days):[/yellow] {total_stale_no_pr}
[blue]Recent branches without PR (≤{stale_days} days):[/blue] {total_recent_no_pr}

[bold]Suggested Actions:[/bold]
1. Delete branches with closed/merged PRs (safe to remove)
2. Review stale branches without PRs - may be abandoned work
3. Monitor recent branches - may be work in progress
        """
        ),
        title="Orphaned Branches Report",
        border_style="green",
    )
    console.print(summary)


def format_json_output(results: dict[str, Any]) -> None:
    """Format results as JSON."""
    console.print(json.dumps(results, indent=2))


def format_markdown_output(results: dict[str, Any], stale_days: int) -> None:
    """Format results as Markdown."""
    output = ["# Orphaned Branches Report\n"]

    total_closed_pr = 0
    total_stale_no_pr = 0
    total_recent_no_pr = 0

    for repo_name, repo_results in results.items():
        output.append(f"\n## {repo_name}\n")

        if repo_results["closed_pr_branches"]:
            total_closed_pr += len(repo_results["closed_pr_branches"])
            output.append("### Branches with Closed/Merged PRs\n")
            output.append("| Branch | PR # | Status | Last Commit |")
            output.append("|--------|------|--------|-------------|")

            for branch in repo_results["closed_pr_branches"]:
                status = "Merged" if branch["merged"] else "Closed"
                output.append(
                    f"| {branch['name']} | #{branch['pr_number']} | {status} | {branch['last_commit'][:10]} |"
                )

            output.append(
                f"\n**Action:** Delete {len(repo_results['closed_pr_branches'])} branch(es)\n"
            )

        if repo_results["no_pr_branches_stale"]:
            total_stale_no_pr += len(repo_results["no_pr_branches_stale"])
            output.append(f"### Stale Branches (>{stale_days} days, No PR)\n")
            output.append("| Branch | Age (days) | Last Commit |")
            output.append("|--------|------------|-------------|")

            for branch in repo_results["no_pr_branches_stale"]:
                output.append(
                    f"| {branch['name']} | {branch['age_days']} | {branch['last_commit'][:10]} |"
                )

            output.append(
                f"\n**Action:** Review and consider deleting {len(repo_results['no_pr_branches_stale'])} branch(es)\n"
            )

        if repo_results["no_pr_branches_recent"]:
            total_recent_no_pr += len(repo_results["no_pr_branches_recent"])
            output.append(f"### Recent Branches (≤{stale_days} days, No PR)\n")
            output.append("| Branch | Age (days) | Last Commit |")
            output.append("|--------|------------|-------------|")

            for branch in repo_results["no_pr_branches_recent"]:
                output.append(
                    f"| {branch['name']} | {branch['age_days']} | {branch['last_commit'][:10]} |"
                )

            output.append(
                f"\n**Info:** {len(repo_results['no_pr_branches_recent'])} active branch(es)\n"
            )

    # Summary
    output.append("\n## Summary\n")
    output.append(f"- **Branches with closed/merged PRs:** {total_closed_pr}")
    output.append(
        f"- **Stale branches without PR (>{stale_days} days):** {total_stale_no_pr}"
    )
    output.append(
        f"- **Recent branches without PR (≤{stale_days} days):** {total_recent_no_pr}"
    )
    output.append("\n### Suggested Actions\n")
    output.append("1. Delete branches with closed/merged PRs (safe to remove)")
    output.append("2. Review stale branches without PRs - may be abandoned work")
    output.append("3. Monitor recent branches - may be work in progress")

    console.print("\n".join(output))


@click.command()
@click.option(
    "--namespace",
    "-n",
    required=True,
    help="GitHub username or organization name",
)
@click.option(
    "--stale-days",
    "-d",
    default=7,
    type=int,
    help="Number of days after which a branch without PR is considered stale (default: 7)",
)
@click.option(
    "--include-forks",
    is_flag=True,
    help="Include forked repositories in the analysis",
)
@click.option(
    "--output",
    "-o",
    type=click.Choice(["table", "json", "markdown"], case_sensitive=False),
    default="table",
    help="Output format (default: table)",
)
def main(namespace: str, stale_days: int, include_forks: bool, output: str) -> None:
    """
    Find orphaned branches across all repositories in a GitHub namespace.

    This tool identifies:
    1. Branches that still exist after their PR was closed/merged
    2. Branches without any associated PR (filtered by staleness)

    Examples:
        gh-orphaned-branches.py --namespace octocat
        gh-orphaned-branches.py -n myorg --stale-days 14 --output markdown
    """
    console.print(
        Panel.fit(
            f"[bold]Orphaned Branch Finder[/bold]\n"
            f"Namespace: {namespace}\n"
            f"Stale threshold: {stale_days} days\n"
            f"Include forks: {include_forks}\n"
            f"Output format: {output}",
            border_style="blue",
        )
    )

    finder = OrphanedBranchFinder(stale_days=stale_days)
    results = finder.analyze_namespace(namespace, include_forks)

    if not results:
        console.print(
            "\n[green]✓ No orphaned branches found! All repositories are clean.[/green]\n"
        )
        return

    if output == "json":
        format_json_output(results)
    elif output == "markdown":
        format_markdown_output(results, stale_days)
    else:
        format_table_output(results, stale_days)


if __name__ == "__main__":
    main()
