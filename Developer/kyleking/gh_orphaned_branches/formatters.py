"""Output formatters (pure functions)."""

import json
from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from .core import RepositoryResults


# ============================================================================
# Pure Formatting Functions
# ============================================================================


def format_pr_status(merged: bool) -> str:
    """Format PR status as a string.

    Pure function.
    """
    return "Merged" if merged else "Closed"


def format_date(date_str: str) -> str:
    """Format an ISO date string to a short date.

    Pure function.
    """
    return date_str[:10] if date_str else "N/A"


def create_summary_text(summary: dict[str, int], stale_days: int) -> str:
    """Create summary text from statistics.

    Pure function that generates markup text.
    """
    return f"""[bold]Summary[/bold]

[red]Branches with closed/merged PRs:[/red] {summary['closed_pr_branches']}
[yellow]Stale branches without PR (>{stale_days} days):[/yellow] {summary['stale_no_pr_branches']}
[blue]Recent branches without PR (≤{stale_days} days):[/blue] {summary['recent_no_pr_branches']}

[bold]Suggested Actions:[/bold]
1. Delete branches with closed/merged PRs (safe to remove)
2. Review stale branches without PRs - may be abandoned work
3. Monitor recent branches - may be work in progress
    """


# ============================================================================
# Table Builders (Pure Functions Returning Table Objects)
# ============================================================================


def build_closed_pr_table(
    repo_name: str, branches: list[dict[str, Any]]
) -> Table:
    """Build a table for branches with closed PRs.

    Pure function that returns a Table object.
    """
    table = Table(
        title=f"{repo_name} - Branches with Closed/Merged PRs",
        show_header=True,
        header_style="bold magenta",
    )
    table.add_column("Branch", style="cyan")
    table.add_column("PR #", style="yellow")
    table.add_column("Status", style="green")
    table.add_column("Last Commit", style="blue")

    for branch in branches:
        status = format_pr_status(branch["merged"])
        table.add_row(
            branch["name"],
            f"#{branch['pr_number']}",
            status,
            format_date(branch["last_commit"]),
        )

    return table


def build_stale_branches_table(
    repo_name: str, branches: list[dict[str, Any]], stale_days: int
) -> Table:
    """Build a table for stale branches without PRs.

    Pure function that returns a Table object.
    """
    table = Table(
        title=f"{repo_name} - Stale Branches (>{stale_days} days, No PR)",
        show_header=True,
        header_style="bold red",
    )
    table.add_column("Branch", style="cyan")
    table.add_column("Age (days)", style="red")
    table.add_column("Last Commit", style="blue")

    for branch in branches:
        table.add_row(
            branch["name"],
            str(branch["age_days"]),
            format_date(branch["last_commit"]),
        )

    return table


def build_recent_branches_table(
    repo_name: str, branches: list[dict[str, Any]], stale_days: int
) -> Table:
    """Build a table for recent branches without PRs.

    Pure function that returns a Table object.
    """
    table = Table(
        title=f"{repo_name} - Recent Branches (≤{stale_days} days, No PR)",
        show_header=True,
        header_style="bold blue",
    )
    table.add_column("Branch", style="cyan")
    table.add_column("Age (days)", style="blue")
    table.add_column("Last Commit", style="blue")

    for branch in branches:
        table.add_row(
            branch["name"],
            str(branch["age_days"]),
            format_date(branch["last_commit"]),
        )

    return table


# ============================================================================
# Markdown Formatting (Pure Functions)
# ============================================================================


def format_closed_pr_markdown(
    repo_name: str, branches: list[dict[str, Any]]
) -> list[str]:
    """Format closed PR branches as Markdown.

    Pure function returning lines of text.
    """
    lines = ["### Branches with Closed/Merged PRs\n"]
    lines.append("| Branch | PR # | Status | Last Commit |")
    lines.append("|--------|------|--------|-------------|")

    for branch in branches:
        status = format_pr_status(branch["merged"])
        lines.append(
            f"| {branch['name']} | #{branch['pr_number']} | {status} | {format_date(branch['last_commit'])} |"
        )

    lines.append(f"\n**Action:** Delete {len(branches)} branch(es)\n")
    return lines


def format_stale_branches_markdown(
    repo_name: str, branches: list[dict[str, Any]], stale_days: int
) -> list[str]:
    """Format stale branches as Markdown.

    Pure function returning lines of text.
    """
    lines = [f"### Stale Branches (>{stale_days} days, No PR)\n"]
    lines.append("| Branch | Age (days) | Last Commit |")
    lines.append("|--------|------------|-------------|")

    for branch in branches:
        lines.append(
            f"| {branch['name']} | {branch['age_days']} | {format_date(branch['last_commit'])} |"
        )

    lines.append(f"\n**Action:** Review and consider deleting {len(branches)} branch(es)\n")
    return lines


def format_recent_branches_markdown(
    repo_name: str, branches: list[dict[str, Any]], stale_days: int
) -> list[str]:
    """Format recent branches as Markdown.

    Pure function returning lines of text.
    """
    lines = [f"### Recent Branches (≤{stale_days} days, No PR)\n"]
    lines.append("| Branch | Age (days) | Last Commit |")
    lines.append("|--------|------------|-------------|")

    for branch in branches:
        lines.append(
            f"| {branch['name']} | {branch['age_days']} | {format_date(branch['last_commit'])} |"
        )

    lines.append(f"\n**Info:** {len(branches)} active branch(es)\n")
    return lines


def format_summary_markdown(summary: dict[str, int], stale_days: int) -> list[str]:
    """Format summary as Markdown.

    Pure function returning lines of text.
    """
    return [
        "\n## Summary\n",
        f"- **Branches with closed/merged PRs:** {summary['closed_pr_branches']}",
        f"- **Stale branches without PR (>{stale_days} days):** {summary['stale_no_pr_branches']}",
        f"- **Recent branches without PR (≤{stale_days} days):** {summary['recent_no_pr_branches']}",
        "\n### Suggested Actions\n",
        "1. Delete branches with closed/merged PRs (safe to remove)",
        "2. Review stale branches without PRs - may be abandoned work",
        "3. Monitor recent branches - may be work in progress",
    ]


# ============================================================================
# Main Output Functions (Side Effects: Console Output)
# ============================================================================


def output_json(results: dict[str, RepositoryResults], console: Console) -> None:
    """Output results as JSON.

    Side effect: prints to console.
    """
    console.print(json.dumps(results, indent=2))


def output_markdown(
    results: dict[str, RepositoryResults],
    summary: dict[str, int],
    stale_days: int,
    console: Console,
) -> None:
    """Output results as Markdown.

    Side effect: prints to console.
    """
    lines = ["# Orphaned Branches Report\n"]

    for repo_name, repo_results in results.items():
        lines.append(f"\n## {repo_name}\n")

        if repo_results["closed_pr_branches"]:
            lines.extend(format_closed_pr_markdown(repo_name, repo_results["closed_pr_branches"]))

        if repo_results["no_pr_branches_stale"]:
            lines.extend(format_stale_branches_markdown(repo_name, repo_results["no_pr_branches_stale"], stale_days))

        if repo_results["no_pr_branches_recent"]:
            lines.extend(format_recent_branches_markdown(repo_name, repo_results["no_pr_branches_recent"], stale_days))

    lines.extend(format_summary_markdown(summary, stale_days))

    console.print("\n".join(lines))


def output_table(
    results: dict[str, RepositoryResults],
    summary: dict[str, int],
    stale_days: int,
    console: Console,
) -> None:
    """Output results as rich tables.

    Side effect: prints to console.
    """
    console.print("\n")

    for repo_name, repo_results in results.items():
        if repo_results["closed_pr_branches"]:
            table = build_closed_pr_table(repo_name, repo_results["closed_pr_branches"])
            console.print(table)
            console.print(
                f"[yellow]→ Action: Delete {len(repo_results['closed_pr_branches'])} branch(es)[/yellow]\n"
            )

        if repo_results["no_pr_branches_stale"]:
            table = build_stale_branches_table(repo_name, repo_results["no_pr_branches_stale"], stale_days)
            console.print(table)
            console.print(
                f"[yellow]→ Action: Review and consider deleting {len(repo_results['no_pr_branches_stale'])} branch(es)[/yellow]\n"
            )

        if repo_results["no_pr_branches_recent"]:
            table = build_recent_branches_table(repo_name, repo_results["no_pr_branches_recent"], stale_days)
            console.print(table)
            console.print(
                f"[blue]→ Info: {len(repo_results['no_pr_branches_recent'])} active branch(es)[/blue]\n"
            )

    # Summary panel
    summary_text = create_summary_text(summary, stale_days)
    summary_panel = Panel(
        Text.from_markup(summary_text),
        title="Orphaned Branches Report",
        border_style="green",
    )
    console.print(summary_panel)
