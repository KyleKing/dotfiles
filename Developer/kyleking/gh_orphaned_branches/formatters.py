"""Output formatters."""

import json
from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from .core import RepositoryResults


def _format_date(date_str: str) -> str:
    """Format ISO date string to short date."""
    return date_str[:10] if date_str else "N/A"


def _create_summary_text(summary: dict[str, int], stale_days: int) -> str:
    """Create summary markup text."""
    return f"""[bold]Summary[/bold]

[red]Branches with closed/merged PRs:[/red] {summary['closed_pr_branches']}
[yellow]Stale branches without PR (>{stale_days} days):[/yellow] {summary['stale_no_pr_branches']}
[blue]Recent branches without PR (≤{stale_days} days):[/blue] {summary['recent_no_pr_branches']}

[bold]Suggested Actions:[/bold]
1. Delete branches with closed/merged PRs (safe to remove)
2. Review stale branches without PRs - may be abandoned work
3. Monitor recent branches - may be work in progress
    """


def _build_table(repo_name: str, title: str, columns: list[tuple[str, str]], rows: list[tuple], header_style: str) -> Table:
    """Build a generic table."""
    table = Table(title=f"{repo_name} - {title}", show_header=True, header_style=header_style)
    for col_name, col_style in columns:
        table.add_column(col_name, style=col_style)
    for row in rows:
        table.add_row(*row)
    return table


def output_json(results: dict[str, RepositoryResults], console: Console) -> None:
    """Output results as JSON."""
    console.print(json.dumps(results, indent=2))


def output_markdown(results: dict[str, RepositoryResults], summary: dict[str, int], stale_days: int, console: Console) -> None:
    """Output results as Markdown."""
    lines = ["# Orphaned Branches Report\n"]

    for repo_name, repo_results in results.items():
        lines.append(f"\n## {repo_name}\n")

        if repo_results["closed_pr_branches"]:
            lines.append("### Branches with Closed/Merged PRs\n")
            lines.append("| Branch | PR # | Status | Last Commit |")
            lines.append("|--------|------|--------|-------------|")
            for b in repo_results["closed_pr_branches"]:
                status = "Merged" if b["merged"] else "Closed"
                lines.append(f"| {b['name']} | #{b['pr_number']} | {status} | {_format_date(b['last_commit'])} |")
            lines.append(f"\n**Action:** Delete {len(repo_results['closed_pr_branches'])} branch(es)\n")

        if repo_results["no_pr_branches_stale"]:
            lines.append(f"### Stale Branches (>{stale_days} days, No PR)\n")
            lines.append("| Branch | Age (days) | Last Commit |")
            lines.append("|--------|------------|-------------|")
            for b in repo_results["no_pr_branches_stale"]:
                lines.append(f"| {b['name']} | {b['age_days']} | {_format_date(b['last_commit'])} |")
            lines.append(f"\n**Action:** Review and consider deleting {len(repo_results['no_pr_branches_stale'])} branch(es)\n")

        if repo_results["no_pr_branches_recent"]:
            lines.append(f"### Recent Branches (≤{stale_days} days, No PR)\n")
            lines.append("| Branch | Age (days) | Last Commit |")
            lines.append("|--------|------------|-------------|")
            for b in repo_results["no_pr_branches_recent"]:
                lines.append(f"| {b['name']} | {b['age_days']} | {_format_date(b['last_commit'])} |")
            lines.append(f"\n**Info:** {len(repo_results['no_pr_branches_recent'])} active branch(es)\n")

    lines.extend([
        "\n## Summary\n",
        f"- **Branches with closed/merged PRs:** {summary['closed_pr_branches']}",
        f"- **Stale branches without PR (>{stale_days} days):** {summary['stale_no_pr_branches']}",
        f"- **Recent branches without PR (≤{stale_days} days):** {summary['recent_no_pr_branches']}",
        "\n### Suggested Actions\n",
        "1. Delete branches with closed/merged PRs (safe to remove)",
        "2. Review stale branches without PRs - may be abandoned work",
        "3. Monitor recent branches - may be work in progress",
    ])

    console.print("\n".join(lines))


def output_table(results: dict[str, RepositoryResults], summary: dict[str, int], stale_days: int, console: Console) -> None:
    """Output results as rich tables."""
    console.print("\n")

    for repo_name, repo_results in results.items():
        if repo_results["closed_pr_branches"]:
            rows = [(b["name"], f"#{b['pr_number']}", "Merged" if b["merged"] else "Closed", _format_date(b["last_commit"]))
                    for b in repo_results["closed_pr_branches"]]
            table = _build_table(repo_name, "Branches with Closed/Merged PRs",
                                [("Branch", "cyan"), ("PR #", "yellow"), ("Status", "green"), ("Last Commit", "blue")],
                                rows, "bold magenta")
            console.print(table)
            console.print(f"[yellow]→ Action: Delete {len(repo_results['closed_pr_branches'])} branch(es)[/yellow]\n")

        if repo_results["no_pr_branches_stale"]:
            rows = [(b["name"], str(b["age_days"]), _format_date(b["last_commit"]))
                    for b in repo_results["no_pr_branches_stale"]]
            table = _build_table(repo_name, f"Stale Branches (>{stale_days} days, No PR)",
                                [("Branch", "cyan"), ("Age (days)", "red"), ("Last Commit", "blue")],
                                rows, "bold red")
            console.print(table)
            console.print(f"[yellow]→ Action: Review and consider deleting {len(repo_results['no_pr_branches_stale'])} branch(es)[/yellow]\n")

        if repo_results["no_pr_branches_recent"]:
            rows = [(b["name"], str(b["age_days"]), _format_date(b["last_commit"]))
                    for b in repo_results["no_pr_branches_recent"]]
            table = _build_table(repo_name, f"Recent Branches (≤{stale_days} days, No PR)",
                                [("Branch", "cyan"), ("Age (days)", "blue"), ("Last Commit", "blue")],
                                rows, "bold blue")
            console.print(table)
            console.print(f"[blue]→ Info: {len(repo_results['no_pr_branches_recent'])} active branch(es)[/blue]\n")

    summary_panel = Panel(Text.from_markup(_create_summary_text(summary, stale_days)),
                          title="Orphaned Branches Report", border_style="green")
    console.print(summary_panel)
