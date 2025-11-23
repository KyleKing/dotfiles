"""Branch relationship graph analysis and visualization."""

from datetime import datetime, timezone
from typing import Any

from rich.console import Console
from rich.tree import Tree

from .github_api import check_merge_conflict, compare_commits, fetch_branch_details
from .utils import parse_iso_date


def _build_branch_relationships(
    owner: str, repo: str, branches: list[str], base_branch: str, include_merge_status: bool = False
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

            branch_info = {
                "ahead_of_base": ahead,
                "behind_base": behind,
                "commits": comparison.get("commits", []),
                "base_branch": base_branch,
            }

            if include_merge_status:
                merge_status = check_merge_conflict(owner, repo, base_branch, branch)
                branch_info["can_merge"] = merge_status["can_merge"]
                branch_info["merge_status"] = merge_status["status"]

            try:
                details = fetch_branch_details(owner, repo, branch)
                commit_date = details.get("commit", {}).get("commit", {}).get("committer", {}).get("date")
                if commit_date:
                    parsed_date = parse_iso_date(commit_date)
                    age_days = (datetime.now(timezone.utc) - parsed_date).days
                    branch_info["age_days"] = age_days
                    branch_info["last_commit_date"] = commit_date
            except (RuntimeError, KeyError):
                pass

            relationships[branch] = branch_info
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
    owner: str, repo: str, branches: list[str], base_branch: str, console: Console, show_merge_status: bool = True
) -> None:
    """Visualize branch relationships as a tree."""
    console.print(f"\n[bold cyan]Branch Graph: {owner}/{repo}[/bold cyan]\n")

    relationships = _build_branch_relationships(owner, repo, branches, base_branch, include_merge_status=show_merge_status)

    tree = Tree(f"[bold blue]{base_branch}[/bold blue] (default)")

    sorted_branches = sorted(
        relationships.items(),
        key=lambda x: (x[1].get("ahead_of_base", 0), x[0])
    )

    for branch, rel in sorted_branches:
        ahead = rel["ahead_of_base"]
        behind = rel["behind_base"]
        age_days = rel.get("age_days")
        can_merge = rel.get("can_merge", True)

        if rel.get("error"):
            label = f"[dim]{branch}[/dim] (comparison error)"
        elif behind > 0:
            merge_indicator = "⚠ conflicts" if not can_merge else "⚠ behind"
            age_info = f", {age_days}d old" if age_days is not None else ""
            label = f"[yellow]{branch}[/yellow] ({ahead} ahead, {behind} behind{age_info}) {merge_indicator}"
        elif ahead == 0:
            age_info = f", {age_days}d old" if age_days is not None else ""
            label = f"[dim]{branch}[/dim] (up to date{age_info})"
        else:
            merge_indicator = "✓ can merge" if can_merge else "⚠ conflicts"
            age_info = f", {age_days}d old" if age_days is not None else ""
            label = f"[green]{branch}[/green] ({ahead} ahead{age_info}) {merge_indicator}"

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


def export_to_dot(
    owner: str, repo: str, branches: list[str], base_branch: str, output_file: str | None = None
) -> str:
    """Export branch graph to DOT/Graphviz format."""
    relationships = _build_branch_relationships(owner, repo, branches, base_branch, include_merge_status=True)

    lines = [
        "digraph branches {",
        '  rankdir=LR;',
        f'  node [shape=box, style=filled];',
        f'  "{base_branch}" [fillcolor=lightblue, label="{base_branch}\\n(default)"];',
    ]

    for branch, rel in relationships.items():
        ahead = rel["ahead_of_base"]
        behind = rel["behind_base"]
        can_merge = rel.get("can_merge", True)
        age_days = rel.get("age_days")

        if rel.get("error"):
            color = "lightgray"
            label_suffix = "\\n(error)"
        elif behind > 0:
            color = "yellow" if can_merge else "red"
            label_suffix = f"\\n{ahead}↑ {behind}↓"
        elif ahead == 0:
            color = "white"
            label_suffix = "\\n(up to date)"
        else:
            color = "lightgreen" if can_merge else "orange"
            label_suffix = f"\\n{ahead}↑"

        age_suffix = f"\\n{age_days}d" if age_days is not None else ""
        lines.append(f'  "{branch}" [fillcolor={color}, label="{branch}{label_suffix}{age_suffix}"];')
        lines.append(f'  "{base_branch}" -> "{branch}";')

    lines.append("}")
    dot_content = "\n".join(lines)

    if output_file:
        with open(output_file, "w") as f:
            f.write(dot_content)

    return dot_content
