"""Interactive CLI functionality using Rich prompts."""

from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.syntax import Syntax
from rich.table import Table

from .github_api import compare_commits, create_pull_request, delete_branch
from .graph import (
    calculate_stacked_pr_order,
    export_to_dot,
    show_branch_comparison_matrix,
    visualize_branch_graph,
)


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


def _select_branches_interactive(branches: list[str], console: Console) -> list[str]:
    """Interactively select multiple branches."""
    if not branches:
        return []

    console.print("\n[bold]Select branches[/bold] (comma-separated numbers, or 'all'):")
    for i, branch in enumerate(branches, 1):
        console.print(f"  [{i}] {branch}")

    selection = Prompt.ask("\nEnter selection", default="")

    if not selection:
        return []

    if selection.lower() == "all":
        return branches.copy()

    selected = []
    try:
        for part in selection.split(","):
            part = part.strip()
            if "-" in part:
                start, end = part.split("-")
                start_idx = int(start) - 1
                end_idx = int(end)
                selected.extend(branches[start_idx:end_idx])
            else:
                idx = int(part) - 1
                if 0 <= idx < len(branches):
                    selected.append(branches[idx])
    except (ValueError, IndexError):
        console.print("[yellow]Invalid selection[/yellow]")
        return []

    return selected


def handle_stacked_prs(
    owner: str,
    repo: str,
    branches: list[str],
    default_branch: str,
    console: Console,
) -> int:
    """Handle creation of stacked PRs for selected branches."""
    if len(branches) < 2:
        console.print("[yellow]Need at least 2 branches for stacked PRs[/yellow]")
        return 0

    console.print(f"\n[bold cyan]Calculating stacked PR order for {len(branches)} branches...[/bold cyan]")
    pr_pairs = calculate_stacked_pr_order(owner, repo, branches, default_branch)

    if not pr_pairs:
        console.print("[yellow]Could not calculate PR order[/yellow]")
        return 0

    console.print("\n[bold]Proposed stacked PRs:[/bold]")
    for i, (base, head) in enumerate(pr_pairs, 1):
        console.print(f"  {i}. {base} ← {head}")

    if not Confirm.ask(f"\nCreate {len(pr_pairs)} pull requests?", default=False):
        console.print("[dim]Cancelled[/dim]")
        return 0

    created = 0
    for base, head in pr_pairs:
        title = Prompt.ask(f"\nPR title for {head} → {base}", default=f"Merge {head} into {base}")
        body = Prompt.ask("PR description (optional)", default="")

        try:
            pr = create_pull_request(owner, repo, title, head, base, body)
            pr_number = pr.get("number", "")
            pr_url = pr.get("html_url", "")
            console.print(f"[green]✓[/green] Created PR #{pr_number}: {pr_url}")
            created += 1
        except RuntimeError as e:
            console.print(f"[red]✗[/red] Failed to create PR {head} → {base}: {e}")

    console.print(f"\n[bold]Created {created}/{len(pr_pairs)} pull requests[/bold]")
    return created


def show_branch_graph_menu(
    owner: str, repo: str, branches: list[str], default_branch: str, console: Console
) -> str:
    """Show branch graph and interactive menu."""
    choices = {
        "t": "Show tree view",
        "m": "Show comparison matrix",
        "s": "Select branches for stacked PRs",
        "e": "Export to DOT/Graphviz",
        "b": "Back to main menu",
    }

    console.print(f"\n[bold cyan]Branch Graph:[/bold cyan] {owner}/{repo}")
    console.print("\n[dim]Actions:[/dim]")
    for key, action in choices.items():
        console.print(f"  [{key}] {action}")

    return Prompt.ask("Choose action", choices=list(choices.keys()), default="b")


def handle_branch_graph_interactive(
    owner: str, repo: str, all_branches: list[str], default_branch: str, console: Console
) -> bool:
    """Handle interactive branch graph exploration. Returns True to continue, False to exit."""
    branches = [b for b in all_branches if b != default_branch]

    if not branches:
        console.print("[yellow]No branches to analyze[/yellow]")
        return True

    while True:
        action = show_branch_graph_menu(owner, repo, branches, default_branch, console)

        if action == "b":
            return True
        elif action == "t":
            visualize_branch_graph(owner, repo, branches, default_branch, console)
        elif action == "m":
            show_branch_comparison_matrix(owner, repo, branches[:10], console)
        elif action == "e":
            filename = Prompt.ask("Output file", default=f"{repo}-graph.dot")
            try:
                export_to_dot(owner, repo, branches, default_branch, filename)
                console.print(f"[green]✓[/green] Exported graph to {filename}")
                console.print(f"[dim]Visualize with: dot -Tpng {filename} -o {repo}-graph.png[/dim]")
            except Exception as e:
                console.print(f"[red]✗[/red] Failed to export: {e}")
        elif action == "s":
            selected = _select_branches_interactive(branches, console)
            if selected:
                console.print(f"\n[bold]Selected {len(selected)} branches:[/bold]")
                for branch in selected:
                    console.print(f"  • {branch}")
                handle_stacked_prs(owner, repo, selected, default_branch, console)
            else:
                console.print("[dim]No branches selected[/dim]")
