#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "ruamel.yaml>=0.18.16",
# ]
# ///
"""Manage mani.yaml by identifying untracked directories and sorting projects.

Usage:

```sh
# Identify untracked directories
./mani_manager.py identify

# Interactively add untracked directories (select by number: 1,3,5 or 'all')
./mani_manager.py add

# Add a specific directory name (doesn't need to exist)
./mani_manager.py add-name my-project

# Sort projects alphabetically
./mani_manager.py sort

# Custom paths
./mani_manager.py --mani-path path/to/mani.yaml --base-path /path/to/repos identify
```

"""

from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
from typing import Any

from ruamel.yaml import YAML


def _parse_mani_yaml(mani_path: Path) -> tuple[dict[str, Any], YAML]:
    """Parse mani.yaml and return config dict and YAML instance."""
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.default_flow_style = False
    yaml.width = 4096
    yaml.indent(mapping=2, sequence=4, offset=2)

    with mani_path.open() as f:
        config = yaml.load(f)

    return config, yaml


def _get_tracked_projects(config: dict[str, Any]) -> set[str]:
    """Extract set of tracked project names from config."""
    projects = config.get('projects', {})
    return set(projects.keys()) if projects else set()


def _get_local_directories(base_path: Path) -> set[str]:
    """Get set of directory names in base_path."""
    return {
        d.name
        for d in base_path.iterdir()
        if d.is_dir() and not d.name.startswith('.')
    }


def _find_untracked_dirs(
    local_dirs: set[str],
    tracked_projects: set[str],
) -> list[str]:
    """Return sorted list of directories not tracked in mani.yaml."""
    untracked = local_dirs - tracked_projects
    return sorted(untracked)


def _prompt_project_details(dir_name: str) -> dict[str, Any]:
    """Prompt for URL and tags for a project."""
    url = input(f"  URL [git@github.com:kyleking/{dir_name}.git]: ").strip()
    if not url:
        url = f"git@github.com:kyleking/{dir_name}.git"

    tags_input = input('  Tags (comma-separated, optional): ').strip()

    project_config: dict[str, Any] = {'url': url}
    if tags_input:
        tags = [t.strip() for t in tags_input.split(',')]
        project_config['tags'] = tags

    return project_config


def _parse_selection(selection: str, max_index: int) -> set[int]:
    """Parse comma-separated numbers into a set of valid indices."""
    indices = set()
    parts = selection.split(',')

    for part in parts:
        part = part.strip()
        if not part:
            continue

        try:
            idx = int(part)
            if 1 <= idx <= max_index:
                indices.add(idx - 1)
        except ValueError:
            continue

    return indices


def _add_projects_interactively(
    config: dict[str, Any],
    untracked: list[str],
) -> bool:
    """Prompt to add untracked projects. Returns True if any were added."""
    if not untracked:
        print('No untracked directories found.')
        return False

    print(f"\nFound {len(untracked)} untracked directories:")
    for idx, dir_name in enumerate(untracked, 1):
        print(f"  {idx}. {dir_name}")
    print()

    selection = input("Enter numbers to add (comma-separated, or 'all'): ").strip()

    if selection.lower() == 'all':
        selected_indices = set(range(len(untracked)))
    else:
        selected_indices = _parse_selection(selection, len(untracked))

    if not selected_indices:
        print('No valid selections made.')
        return False

    if 'projects' not in config:
        config['projects'] = {}

    projects = config['projects']
    added_count = 0

    print()
    for idx in sorted(selected_indices):
        dir_name = untracked[idx]
        print(f"Configure '{dir_name}':")
        project_config = _prompt_project_details(dir_name)
        projects[dir_name] = project_config
        added_count += 1
        print()

    print(f"Added {added_count} project(s)")
    return True


def _sort_projects_alphabetically(config: dict[str, Any]) -> None:
    """Sort projects section alphabetically by key."""
    if 'projects' not in config or not config['projects']:
        return

    projects = config['projects']
    sorted_projects = dict(sorted(projects.items(), key=lambda item: item[0].lower()))
    config['projects'] = sorted_projects


def _save_mani_yaml(mani_path: Path, config: dict[str, Any], yaml: YAML) -> None:
    """Save config back to mani.yaml."""
    with mani_path.open('w') as f:
        yaml.dump(config, f)
    print(f"\nSaved to {mani_path}")


def _identify_untracked(mani_path: Path, base_path: Path) -> None:
    """Identify and display untracked directories."""
    config, _ = _parse_mani_yaml(mani_path)
    tracked = _get_tracked_projects(config)
    local_dirs = _get_local_directories(base_path)
    untracked = _find_untracked_dirs(local_dirs, tracked)

    if not untracked:
        print('No untracked directories found.')
        return

    print(f"\nFound {len(untracked)} untracked directories:")
    for dir_name in untracked:
        print(f"  - {dir_name}")


def _add_interactive(mani_path: Path, base_path: Path) -> None:
    """Interactively add untracked directories to mani.yaml."""
    config, yaml = _parse_mani_yaml(mani_path)
    tracked = _get_tracked_projects(config)
    local_dirs = _get_local_directories(base_path)
    untracked = _find_untracked_dirs(local_dirs, tracked)

    if _add_projects_interactively(config, untracked):
        _save_mani_yaml(mani_path, config, yaml)


def _sort_projects(mani_path: Path) -> None:
    """Sort projects in mani.yaml alphabetically."""
    config, yaml = _parse_mani_yaml(mani_path)
    _sort_projects_alphabetically(config)
    _save_mani_yaml(mani_path, config, yaml)
    print('Projects sorted alphabetically.')


def _add_named_project(mani_path: Path, dir_name: str) -> None:
    """Add a specific directory name to mani.yaml."""
    config, yaml = _parse_mani_yaml(mani_path)

    if 'projects' not in config:
        config['projects'] = {}

    projects = config['projects']

    if dir_name in projects:
        print(f"Project '{dir_name}' already exists in mani.yaml")
        return

    url = input(f"URL [git@github.com:kyleking/{dir_name}.git]: ").strip()
    if not url:
        url = f"git@github.com:kyleking/{dir_name}.git"

    tags_input = input('Tags (comma-separated, optional): ').strip()

    project_config: dict[str, Any] = {'url': url}
    if tags_input:
        tags = [t.strip() for t in tags_input.split(',')]
        project_config['tags'] = tags

    projects[dir_name] = project_config
    _sort_projects_alphabetically(config)
    _save_mani_yaml(mani_path, config, yaml)
    print(f"Added '{dir_name}' and sorted projects alphabetically.")


def main() -> None:
    """Main entry point."""
    parser = ArgumentParser(description='Manage mani.yaml projects')
    parser.add_argument(
        '--mani-path',
        type=Path,
        default=Path('mani.yaml'),
        help='Path to mani.yaml file (default: mani.yaml)',
    )
    parser.add_argument(
        '--base-path',
        type=Path,
        default=Path.cwd(),
        help='Base directory to scan for projects (default: current directory)',
    )

    subparsers = parser.add_subparsers(dest='command', required=True)

    subparsers.add_parser(
        'identify',
        help='Identify untracked directories',
    )

    subparsers.add_parser(
        'add',
        help='Interactively add untracked directories',
    )

    add_name_parser = subparsers.add_parser(
        'add-name',
        help='Add a specific directory name to mani.yaml',
    )
    add_name_parser.add_argument(
        'dir_name',
        type=str,
        help='Directory name to add',
    )

    subparsers.add_parser(
        'sort',
        help='Sort projects alphabetically',
    )

    args = parser.parse_args()

    match args.command:
        case 'identify':
            _identify_untracked(args.mani_path, args.base_path)
        case 'add':
            _add_interactive(args.mani_path, args.base_path)
        case 'add-name':
            _add_named_project(args.mani_path, args.dir_name)
        case 'sort':
            _sort_projects(args.mani_path)


if __name__ == '__main__':
    main()
