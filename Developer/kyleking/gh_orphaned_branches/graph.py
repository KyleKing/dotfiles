"""Branch relationship graph analysis and visualization."""

from typing import Any

from rich.console import Console
from rich.tree import Tree

from .github_api import compare_commits


def _build_branch_relationships(
    owner: str, repo: str, branches: list[str], base_branch: str
) -> dict[str, dict[str, Any]]:
    """Build relationship graph comparing all branches."""
    relationships = {}

    for branch in branches:
        if branch == base_branch:
            continue

        try:
            comparison = compare_commits(owner, repo, base_branch, branch)
            ahead = comparison.get("ahead_by", 0)
            behind = comparison.get("behind_by", 0)

            relationships[branch] = {
                "ahead_of_base": ahead,
                "behind_base": behind,
                "commits": comparison.get("commits", []),
                "base_branch": base_branch,
            }
        except RuntimeError:
            relationships[branch] = {
                "ahead_of_base": 0,
                "behind_base": 0,
                "commits": [],
                "base_branch": base_branch,
                "error": True,
            }

    return relationships


def _compare_branch_pair(owner: str, repo: str, base: str, head: str) -> dict[str, Any]:
    """Compare two branches to see their relationship."""
    try:
        comparison = compare_commits(owner, repo, base, head)
        return {
            "ahead": comparison.get("ahead_by", 0),
            "behind": comparison.get("behind_by", 0),
            "status": comparison.get("status", "unknown"),
            "can_compare": True,
        }
    except RuntimeError:
        return {
            "ahead": 0,
            "behind": 0,
            "status": "error",
            "can_compare": False,
        }


def _build_dependency_graph(
    owner: str, repo: str, branches: list[str]
) -> dict[str, list[tuple[str, int]]]:
    """Build graph of which branches depend on others (based on ahead commits)."""
    dependencies = {}

    for branch in branches:
        dependencies[branch] = []

        for other_branch in branches:
            if branch == other_branch:
                continue

            comparison = _compare_branch_pair(owner, repo, other_branch, branch)

            if comparison["can_compare"] and comparison["ahead"] > 0 and comparison["behind"] == 0:
                dependencies[branch].append((other_branch, comparison["ahead"]))

    return dependencies


def _find_base_branch(branch: str, dependencies: dict[str, list[tuple[str, int]]]) -> str | None:
    """Find the most suitable base branch (closest parent in dependency tree)."""
    potential_bases = dependencies.get(branch, [])

    if not potential_bases:
        return None

    potential_bases.sort(key=lambda x: x[1])
    return potential_bases[0][0]


def calculate_stacked_pr_order(
    owner: str, repo: str, selected_branches: list[str], default_branch: str
) -> list[tuple[str, str]]:
    """Calculate optimal order for stacked PRs. Returns list of (base, head) tuples."""
    if not selected_branches:
        return []

    dependencies = _build_dependency_graph(owner, repo, selected_branches + [default_branch])
    pr_pairs = []
    processed = {default_branch}

    branches_by_distance = []
    for branch in selected_branches:
        comparison = _compare_branch_pair(owner, repo, default_branch, branch)
        if comparison["can_compare"]:
            branches_by_distance.append((branch, comparison["ahead"]))

    branches_by_distance.sort(key=lambda x: x[1])

    for branch, _ in branches_by_distance:
        base = _find_base_branch(branch, dependencies)

        if base and base in processed:
            pr_pairs.append((base, branch))
        else:
            pr_pairs.append((default_branch, branch))

        processed.add(branch)

    return pr_pairs


def visualize_branch_graph(
    owner: str, repo: str, branches: list[str], base_branch: str, console: Console
) -> None:
    """Visualize branch relationships as a tree."""
    console.print(f"\n[bold cyan]Branch Graph: {owner}/{repo}[/bold cyan]\n")

    relationships = _build_branch_relationships(owner, repo, branches, base_branch)

    tree = Tree(f"[bold blue]{base_branch}[/bold blue] (default)")

    sorted_branches = sorted(
        relationships.items(),
        key=lambda x: (x[1].get("ahead_of_base", 0), x[0])
    )

    for branch, rel in sorted_branches:
        ahead = rel["ahead_of_base"]
        behind = rel["behind_base"]

        if rel.get("error"):
            label = f"[dim]{branch}[/dim] (comparison error)"
        elif behind > 0:
            label = f"[yellow]{branch}[/yellow] ({ahead} ahead, {behind} behind) ⚠"
        elif ahead == 0:
            label = f"[dim]{branch}[/dim] (up to date)"
        else:
            label = f"[green]{branch}[/green] ({ahead} ahead) ✓"

        tree.add(label)

    console.print(tree)
    console.print()


def show_branch_comparison_matrix(
    owner: str, repo: str, branches: list[str], console: Console
) -> None:
    """Show a matrix of branch comparisons."""
    from rich.table import Table

    console.print("\n[bold cyan]Branch Comparison Matrix[/bold cyan]")
    console.print("[dim]Shows commits ahead (row vs column)[/dim]\n")

    table = Table(show_header=True, header_style="bold cyan")
    table.add_column("Branch", style="cyan")

    for branch in branches:
        table.add_column(branch[:15], justify="center")

    for base_branch in branches:
        row = [base_branch[:15]]

        for head_branch in branches:
            if base_branch == head_branch:
                row.append("-")
            else:
                comparison = _compare_branch_pair(owner, repo, base_branch, head_branch)
                if comparison["can_compare"]:
                    ahead = comparison["ahead"]
                    if ahead == 0:
                        row.append("[dim]0[/dim]")
                    else:
                        row.append(f"[green]{ahead}[/green]")
                else:
                    row.append("[red]?[/red]")

        table.add_row(*row)

    console.print(table)
    console.print()
