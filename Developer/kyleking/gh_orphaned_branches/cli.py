#!/usr/bin/env python3
"""CLI interface for orphaned branches finder."""

import argparse
import sys

from rich.console import Console
from rich.panel import Panel

from . import __version__
from .core import analyze_namespace, calculate_summary
from .formatters import output_json, output_markdown, output_table
from .interactive import handle_batch_delete, handle_branch_interactive, show_category_menu

console = Console()


def _print_banner(namespace: str, stale_days: int, include_forks: bool, output: str, interactive: bool = False) -> None:
    """Print startup banner."""
    mode = "Interactive" if interactive else f"Output: {output}"
    console.print(Panel.fit(
        f"[bold]Orphaned Branch Finder v{__version__}[/bold]\n"
        f"Namespace: {namespace}\n"
        f"Stale threshold: {stale_days} days\n"
        f"Include forks: {include_forks}\n"
        f"Mode: {mode}",
        border_style="blue",
    ))


def _print_progress(repo_name: str) -> None:
    """Print progress for repository."""
    console.print(f"Analyzing [cyan]{repo_name}[/cyan]...")


def _handle_interactive_mode(results: dict, stale_days: int) -> None:
    """Handle interactive mode for reviewing and acting on orphaned branches."""
    from .formatters import output_table
    from .core import calculate_summary

    summary = calculate_summary(results)
    output_table(results, summary, stale_days, console)

    console.print("\n[bold cyan]Interactive Mode[/bold cyan]")
    console.print("Review and take actions on orphaned branches\n")

    for repo_name, repo_results in results.items():
        owner, repo = repo_name.split("/")
        default_branch = "main"

        console.print(f"\n[bold]═══ Repository: {repo_name} ═══[/bold]")

        categories = [
            ("Closed/Merged PR Branches", repo_results["closed_pr_branches"]),
            (f"Stale Branches (>{stale_days} days, no PR)", repo_results["no_pr_branches_stale"]),
            (f"Recent Branches (≤{stale_days} days, no PR)", repo_results["no_pr_branches_recent"]),
        ]

        for category_name, branches in categories:
            if not branches:
                continue

            action = show_category_menu(category_name, len(branches), console)

            if action == "q":
                console.print("\n[dim]Exiting interactive mode[/dim]")
                return
            elif action == "s":
                continue
            elif action == "d":
                branch_names = [b["name"] for b in branches]
                handle_batch_delete(owner, repo, branch_names, console)
            elif action == "i":
                for branch in branches:
                    branch_name = branch["name"]
                    if not handle_branch_interactive(owner, repo, branch_name, default_branch, console):
                        console.print("\n[dim]Exiting interactive mode[/dim]")
                        return

    console.print("\n[green]✓ Interactive review complete[/green]")


def _create_parser() -> argparse.ArgumentParser:
    """Create argument parser."""
    parser = argparse.ArgumentParser(
        description="Find orphaned branches across all repositories in a GitHub namespace.",
        epilog="""
Examples:
  %(prog)s --namespace octocat
  %(prog)s -n myorg --stale-days 14 --output markdown
  %(prog)s -n username --include-forks -o json

Identifies:
  1. Branches that still exist after their PR was closed/merged
  2. Branches without any associated PR (filtered by staleness)
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--namespace", "-n", required=True, help="GitHub username or organization name")
    parser.add_argument("--stale-days", "-d", type=int, default=7,
                       help="Days after which branch without PR is stale (default: 7)")
    parser.add_argument("--include-forks", action="store_true", help="Include forked repositories")
    parser.add_argument("--output", "-o", choices=["table", "json", "markdown"], default="table",
                       help="Output format (default: table)")
    parser.add_argument("--interactive", "-i", action="store_true",
                       help="Interactive mode for branch review and actions")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def main(argv: list[str] | None = None) -> None:
    """Main entry point."""
    parser = _create_parser()
    args = parser.parse_args(argv)
    _print_banner(args.namespace, args.stale_days, args.include_forks, args.output, args.interactive)

    try:
        results = analyze_namespace(args.namespace, args.stale_days, args.include_forks, _print_progress)
        if not results:
            console.print("\n[green]✓ No orphaned branches found! All repositories are clean.[/green]\n")
            return

        if args.interactive:
            _handle_interactive_mode(results, args.stale_days)
        else:
            summary = calculate_summary(results)
            if args.output == "json":
                output_json(results, console)
            elif args.output == "markdown":
                output_markdown(results, summary, args.stale_days, console)
            else:
                output_table(results, summary, args.stale_days, console)
    except Exception as e:
        console.print(f"\n[red]Error: {e}[/red]\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
