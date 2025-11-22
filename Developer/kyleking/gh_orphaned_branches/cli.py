#!/usr/bin/env python3
"""CLI interface for orphaned branches finder."""

import argparse
import sys

from rich.console import Console
from rich.panel import Panel

from . import __version__
from .core import analyze_namespace, calculate_summary
from .formatters import output_json, output_markdown, output_table

console = Console()


def _print_banner(namespace: str, stale_days: int, include_forks: bool, output: str) -> None:
    """Print startup banner."""
    console.print(Panel.fit(
        f"[bold]Orphaned Branch Finder v{__version__}[/bold]\n"
        f"Namespace: {namespace}\n"
        f"Stale threshold: {stale_days} days\n"
        f"Include forks: {include_forks}\n"
        f"Output format: {output}",
        border_style="blue",
    ))


def _print_progress(repo_name: str) -> None:
    """Print progress for repository."""
    console.print(f"Analyzing [cyan]{repo_name}[/cyan]...")


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
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def main(argv: list[str] | None = None) -> None:
    """Main entry point."""
    parser = _create_parser()
    args = parser.parse_args(argv)
    _print_banner(args.namespace, args.stale_days, args.include_forks, args.output)

    try:
        results = analyze_namespace(args.namespace, args.stale_days, args.include_forks, _print_progress)
        if not results:
            console.print("\n[green]✓ No orphaned branches found! All repositories are clean.[/green]\n")
            return

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
