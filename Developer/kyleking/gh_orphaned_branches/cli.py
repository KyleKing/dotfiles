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


def print_banner(namespace: str, stale_days: int, include_forks: bool, output: str) -> None:
    """Print the startup banner.

    Side effect function.
    """
    console.print(
        Panel.fit(
            f"[bold]Orphaned Branch Finder v{__version__}[/bold]\n"
            f"Namespace: {namespace}\n"
            f"Stale threshold: {stale_days} days\n"
            f"Include forks: {include_forks}\n"
            f"Output format: {output}",
            border_style="blue",
        )
    )


def print_repo_count(count: int) -> None:
    """Print the repository count.

    Side effect function.
    """
    console.print(f"\n[bold]Found {count} repositories to analyze[/bold]\n")


def print_progress(repo_name: str) -> None:
    """Print progress for a repository.

    Side effect function for progress callback.
    """
    console.print(f"Analyzing [cyan]{repo_name}[/cyan]...")


def print_no_results() -> None:
    """Print message when no orphaned branches are found.

    Side effect function.
    """
    console.print(
        "\n[green]✓ No orphaned branches found! All repositories are clean.[/green]\n"
    )


def handle_error(error: Exception) -> None:
    """Handle and display errors.

    Side effect function.
    """
    console.print(f"\n[red]Error: {error}[/red]\n")
    sys.exit(1)


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser.

    Pure function that returns a configured parser.
    """
    parser = argparse.ArgumentParser(
        description="Find orphaned branches across all repositories in a GitHub namespace.",
        epilog="""
Examples:
  %(prog)s --namespace octocat
  %(prog)s -n myorg --stale-days 14 --output markdown
  %(prog)s -n username --include-forks -o json

This tool identifies:
  1. Branches that still exist after their PR was closed/merged
  2. Branches without any associated PR (filtered by staleness)
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--namespace",
        "-n",
        required=True,
        help="GitHub username or organization name",
    )
    parser.add_argument(
        "--stale-days",
        "-d",
        type=int,
        default=7,
        help="Number of days after which a branch without PR is considered stale (default: 7)",
    )
    parser.add_argument(
        "--include-forks",
        action="store_true",
        help="Include forked repositories in the analysis",
    )
    parser.add_argument(
        "--output",
        "-o",
        choices=["table", "json", "markdown"],
        default="table",
        help="Output format (default: table)",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )

    return parser


def main(argv: list[str] | None = None) -> None:
    """
    Main entry point for the CLI.

    Args:
        argv: Command line arguments (defaults to sys.argv)
    """
    parser = create_parser()
    args = parser.parse_args(argv)

    print_banner(args.namespace, args.stale_days, args.include_forks, args.output)

    try:
        # Analyze namespace
        results = analyze_namespace(
            namespace=args.namespace,
            stale_days=args.stale_days,
            include_forks=args.include_forks,
            progress_callback=print_progress,
        )

        if not results:
            print_no_results()
            return

        # Calculate summary
        summary = calculate_summary(results)

        # Output results based on format
        if args.output == "json":
            output_json(results, console)
        elif args.output == "markdown":
            output_markdown(results, summary, args.stale_days, console)
        else:
            output_table(results, summary, args.stale_days, console)

    except Exception as e:
        handle_error(e)


if __name__ == "__main__":
    main()
