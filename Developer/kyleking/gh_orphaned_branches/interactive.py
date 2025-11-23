"""Interactive CLI functionality using Rich prompts."""

from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.syntax import Syntax
from rich.table import Table

from .github_api import compare_commits, create_pull_request, delete_branch


def _format_commit_summary(commits: list[dict[str, Any]], limit: int = 5) -> str:
    """Format commit list as readable text."""
    if not commits:
        return "No commits"
    lines = []
    for commit in commits[:limit]:
        sha = commit.get("sha", "")[:7]
        message = commit.get("commit", {}).get("message", "").split("\n")[0]
        lines.append(f"  • {sha} {message}")
    if len(commits) > limit:
        lines.append(f"  ... and {len(commits) - limit} more")
    return "\n".join(lines)


def _show_branch_details(owner: str, repo: str, branch: str, base_branch: str, console: Console) -> None:
    """Display detailed information about a branch."""
    console.print(f"\n[bold cyan]Branch Details: {branch}[/bold cyan]")
    try:
        comparison = compare_commits(owner, repo, base_branch, branch)
        ahead = comparison.get("ahead_by", 0)
        behind = comparison.get("behind_by", 0)
        commits = comparison.get("commits", [])

        table = Table(show_header=False, box=None)
        table.add_column("Key", style="dim")
        table.add_column("Value")
        table.add_row("Repository", f"{owner}/{repo}")
        table.add_row("Branch", branch)
        table.add_row("Base", base_branch)
        table.add_row("Commits ahead", f"[green]{ahead}[/green]")
        table.add_row("Commits behind", f"[yellow]{behind}[/yellow]")
        console.print(table)

        if commits:
            console.print("\n[bold]Recent commits on this branch:[/bold]")
            console.print(_format_commit_summary(commits))
    except RuntimeError as e:
        console.print(f"[yellow]Could not fetch branch details: {e}[/yellow]")


def _confirm_delete_branch(owner: str, repo: str, branch: str, console: Console) -> bool:
    """Confirm and delete a branch."""
    console.print(f"\n[bold red]Delete branch:[/bold red] {owner}/{repo}:{branch}")
    if Confirm.ask("Are you sure you want to delete this branch?", default=False):
        try:
            delete_branch(owner, repo, branch)
            console.print(f"[green]✓[/green] Deleted branch {branch}")
            return True
        except RuntimeError as e:
            console.print(f"[red]✗[/red] Failed to delete branch: {e}")
            return False
    console.print("[dim]Cancelled[/dim]")
    return False


def _create_pr_for_branch(
    owner: str, repo: str, branch: str, base_branch: str, console: Console
) -> bool:
    """Interactively create a PR for a branch."""
    console.print(f"\n[bold cyan]Create PR:[/bold cyan] {branch} → {base_branch}")
    title = Prompt.ask("PR title", default=f"Merge {branch} into {base_branch}")
    body = Prompt.ask("PR description (optional)", default="")

    if Confirm.ask("Create this pull request?", default=True):
        try:
            pr = create_pull_request(owner, repo, title, branch, base_branch, body)
            pr_url = pr.get("html_url", "")
            pr_number = pr.get("number", "")
            console.print(f"[green]✓[/green] Created PR #{pr_number}: {pr_url}")
            return True
        except RuntimeError as e:
            console.print(f"[red]✗[/red] Failed to create PR: {e}")
            return False
    console.print("[dim]Cancelled[/dim]")
    return False


def _show_branch_menu(
    owner: str, repo: str, branch_name: str, base_branch: str, console: Console
) -> str:
    """Show action menu for a single branch."""
    choices = {
        "d": "Delete branch",
        "p": "Create pull request",
        "v": "View details",
        "s": "Skip",
        "q": "Quit interactive mode",
    }

    console.print(f"\n[bold]Branch:[/bold] {branch_name}")
    console.print("\n[dim]Actions:[/dim]")
    for key, action in choices.items():
        console.print(f"  [{key}] {action}")

    return Prompt.ask("Choose action", choices=list(choices.keys()), default="s")


def handle_branch_interactive(
    owner: str,
    repo: str,
    branch_name: str,
    base_branch: str,
    console: Console,
) -> bool:
    """Handle interactive actions for a single branch. Returns True to continue, False to quit."""
    while True:
        action = _show_branch_menu(owner, repo, branch_name, base_branch, console)

        if action == "q":
            return False
        elif action == "s":
            return True
        elif action == "v":
            _show_branch_details(owner, repo, branch_name, base_branch, console)
        elif action == "d":
            if _confirm_delete_branch(owner, repo, branch_name, console):
                return True
        elif action == "p":
            if _create_pr_for_branch(owner, repo, branch_name, base_branch, console):
                return True


def handle_batch_delete(
    owner: str, repo: str, branches: list[str], console: Console
) -> int:
    """Handle batch deletion of branches with confirmation."""
    if not branches:
        return 0

    console.print(f"\n[bold yellow]Batch delete {len(branches)} branches from {owner}/{repo}[/bold yellow]")
    console.print("\nBranches to delete:")
    for branch in branches:
        console.print(f"  • {branch}")

    if not Confirm.ask(f"\nDelete all {len(branches)} branches?", default=False):
        console.print("[dim]Cancelled[/dim]")
        return 0

    deleted = 0
    for branch in branches:
        try:
            delete_branch(owner, repo, branch)
            console.print(f"[green]✓[/green] Deleted {branch}")
            deleted += 1
        except RuntimeError as e:
            console.print(f"[red]✗[/red] Failed to delete {branch}: {e}")

    console.print(f"\n[bold]Deleted {deleted}/{len(branches)} branches[/bold]")
    return deleted


def show_category_menu(category: str, count: int, console: Console) -> str:
    """Show menu for a category of branches."""
    choices = {
        "i": "Review branches individually",
        "d": "Delete all branches in this category",
        "s": "Skip this category",
        "q": "Quit interactive mode",
    }

    console.print(f"\n[bold cyan]Category:[/bold cyan] {category} ([bold]{count}[/bold] branches)")
    console.print("\n[dim]Actions:[/dim]")
    for key, action in choices.items():
        console.print(f"  [{key}] {action}")

    return Prompt.ask("Choose action", choices=list(choices.keys()), default="s")
