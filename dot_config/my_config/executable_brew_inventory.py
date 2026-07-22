#!/usr/bin/env python3
"""Report on installed brew packages: what is direct, what is shared, what looks unused.

`brew leaves` answers the wrong question. It hides any package something else
depends on, so tools used every day (fzf, ripgrep, neovim, tmux) drop off the
list. This uses `installed_on_request` instead, which is what was asked for by
name, and marks the ones that are also pulled in as a dependency.
"""

import argparse
import json
import re
import sqlite3
import subprocess
import sys
import time
from collections import Counter
from dataclasses import dataclass
from functools import cache
from pathlib import Path


ATUIN_DB = Path.home() / '.local/share/atuin/history.db'
BREW_OPT = Path('/opt/homebrew/opt')
CHEZMOI_SRC = Path.home() / '.local/share/chezmoi'
STALE_DAYS = 180

# Scripts outside chezmoi that invoke brew-installed tools. Searched for shell
# files only: a word like "gum" or "walk" matches far too much prose and Python
# to be worth reporting across a whole code checkout.
SCRIPT_ROOTS = (Path.home() / 'Developer',)
SCRIPT_INCLUDES = ('*.sh', '*.zsh', '*.bash', 'justfile', 'Makefile')

LOOSE_FILES = '(outside any repo)'

_COMMAND_NOISE = frozenset({'command', 'doas', 'env', 'exec', 'nohup', 'sudo', 'time', 'watch'})
_REPOS_SHOWN = 6


class SearchError(RuntimeError):
    """A search tool failed, as opposed to finding nothing.

    Worth its own type: a silent empty result reads as "nothing uses this
    package", which is the wrong answer to act on right before an uninstall.
    """


@dataclass(frozen=True)
class Package:
    name: str
    full_name: str
    desc: str
    kind: str
    direct: bool
    required_by: tuple[str, ...]
    binaries: tuple[Path, ...]
    match_keys: tuple[str, ...]

    @property
    def shared(self) -> bool:
        return self.direct and bool(self.required_by)


@dataclass(frozen=True)
class Usage:
    typed: int
    last_run_days: int | None
    running: bool

    @property
    def unused(self) -> bool:
        return not self.typed and not self.running


def _brew_json() -> dict:
    out = subprocess.run(
        ['brew', 'info', '--json=v2', '--installed'],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(out.stdout)


def _load_packages() -> list[Package]:
    data = _brew_json()
    required_by: dict[str, set[str]] = {}
    for formula in data['formulae']:
        for keg in formula['installed']:
            for dep in keg.get('runtime_dependencies', []):
                required_by.setdefault(dep['full_name'].split('/')[-1], set()).add(formula['name'])

    packages = []
    for formula in data['formulae']:
        name = formula['name']
        binaries = _formula_binaries(name)
        packages.append(
            Package(
                name=name,
                full_name=formula['full_name'],
                desc=formula.get('desc') or '',
                kind='formula',
                direct=any(k.get('installed_on_request') for k in formula['installed']),
                required_by=tuple(sorted(required_by.get(name, ()))),
                binaries=binaries,
                match_keys=tuple(sorted({name, *(p.name for p in binaries)})),
            )
        )
    for cask in data['casks']:
        binaries, apps = _cask_artifacts(cask['artifacts'])
        token = cask['token']
        packages.append(
            Package(
                name=token,
                full_name=cask['full_token'],
                desc=cask.get('desc') or '',
                kind='cask',
                direct=True,
                required_by=(),
                binaries=binaries,
                match_keys=tuple(
                    sorted({token, token.removesuffix('-app'), *apps, *(p.name for p in binaries)})
                ),
            )
        )
    return sorted(packages, key=lambda p: (p.kind, p.name))


def _formula_binaries(name: str) -> tuple[Path, ...]:
    bin_dir = BREW_OPT / name / 'bin'
    return tuple(p for p in bin_dir.iterdir() if p.is_file()) if bin_dir.is_dir() else ()


def _cask_artifacts(artifacts: list) -> tuple[tuple[Path, ...], set[str]]:
    """Locate what a cask installs that macOS stamps an access time on when run.

    Fonts and preference panes install nothing that records a run, so they come
    back empty and land in the report's unmeasured pile rather than the unused one.
    """
    binaries: list[Path] = []
    apps: set[str] = set()
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            continue
        for key, value in artifact.items():
            if key == 'app':
                app = Path(artifact.get('target') or f'/Applications/{value[0]}')
                apps.add(app.stem)
                macos = app / 'Contents/MacOS'
                if macos.is_dir():
                    binaries.extend(p for p in macos.iterdir() if p.is_file())
            elif key == 'binary':
                target = artifact.get('target')
                binaries.append(Path(target) if target else Path('/opt/homebrew/bin') / value[0])
    return tuple(binaries), apps


def _typed_commands() -> Counter:
    if not ATUIN_DB.exists():
        return Counter()
    with sqlite3.connect(f'file:{ATUIN_DB}?mode=ro', uri=True) as conn:
        rows = conn.execute('select command from history').fetchall()
    counts: Counter = Counter()
    for (command,) in rows:
        for token in command.strip().split():
            if '=' in token.split('/')[-1] or token in _COMMAND_NOISE:
                continue
            counts[token.split('/')[-1]] += 1
            break
    return counts


def _running_processes() -> str:
    """One lowercased blob of every running executable path.

    Menu-bar apps and login agents are launched once and never touched again, so
    access time reads as months stale while they run the whole time. Karabiner
    also runs its real binaries out of /Library, not the bundle brew installed,
    which is why this matches on name rather than exact path.
    """
    out = subprocess.run(['ps', '-Ao', 'comm='], capture_output=True, text=True, check=False)
    return out.stdout.lower()


def _days_since(paths: tuple[Path, ...]) -> int | None:
    times = [p.stat().st_atime for p in paths if p.exists()]
    return int((time.time() - max(times)) / 86400) if times else None


def _usage(package: Package, typed: Counter, processes: str) -> Usage:
    return Usage(
        typed=sum(typed.get(key, 0) for key in package.match_keys),
        last_run_days=_days_since(package.binaries),
        running=any(len(key) > 3 and key.lower() in processes for key in package.match_keys),
    )


def _search_index(terms: list[str], root: Path, globs: list[str]) -> dict[str, set[Path]]:
    """Find every file under root that uses one of these names as a whole word.

    ripgrep rather than grep: BSD grep takes 22 seconds to carry ~700 literal
    patterns across even a tiny tree, where rg does the same in well under one.
    """
    if not root.is_dir():
        return {}
    command = [
        'rg',
        '--fixed-strings',
        '--word-regexp',
        '--with-filename',
        '--line-number',
        '--only-matching',
        '--no-heading',
        '--hidden',
        '-g',
        '!.git',
        *(arg for glob in globs for arg in ('-g', glob)),
        '-f',
        '-',
        '.',
    ]
    wanted = set(terms)
    index: dict[str, set[Path]] = {}
    for line in _search(command, root, '\n'.join(terms)).splitlines():
        path, _, term = line.rsplit(':', 2)
        if term in wanted:
            index.setdefault(term, set()).add(root / path.removeprefix('./'))
    return index


def _search(command: list[str], root: Path, stdin: str) -> str:
    """Run a search, treating anything past "found nothing" as a failure."""
    out = subprocess.run(
        command, input=stdin, capture_output=True, text=True, check=False, cwd=root
    )
    if out.returncode > 1:
        raise SearchError(f'{command[0]} failed in {root}: {out.stderr.strip()}')
    return out.stdout


def _reference_index(terms: list[str]) -> dict[str, set[Path]]:
    """Map each package name to the config and scripts that mention it, in one pass each."""
    snapshots = ['!Brewfile.*', '!brew_*', '!mise_*', '!*brew_inventory.py']
    index = _search_index(terms, CHEZMOI_SRC, snapshots)
    for root in SCRIPT_ROOTS:
        for term, paths in _search_index(terms, root, list(SCRIPT_INCLUDES)).items():
            index.setdefault(term, set()).update(paths)
    return index


@cache
def _repo_root(directory: Path) -> Path | None:
    """Walk up to the enclosing checkout, caching each directory on the way.

    Cheaper than enumerating every repo up front, and it has no depth limit, so
    a checkout nested seven deep still resolves.
    """
    if (directory / '.git').exists():
        return directory
    return None if directory == directory.parent else _repo_root(directory.parent)


def _repo_of(path: Path) -> str:
    root = _repo_root(path.parent)
    return root.name if root else LOOSE_FILES


def _parse_brewfile(path: Path) -> dict[str, dict[str, str]]:
    """Read a dumped Brewfile into {kind: {name: description}}.

    `brew bundle dump` writes each description as a comment on the line above,
    so the parse has to carry it forward.
    """
    entries: dict[str, dict[str, str]] = {'brew': {}, 'cask': {}}
    pattern = re.compile(r'^(brew|cask) "([^"]+)"')
    pending = ''
    for line in path.read_text().splitlines():
        if match := pattern.match(line):
            entries[match[1]][match[2].split('/')[-1]] = pending
            pending = ''
        else:
            pending = line[2:] if line.startswith('# ') else ''
    return entries


def _paths_for(package: Package, index: dict[str, set[Path]]) -> list[Path]:
    return sorted({path for key in package.match_keys for path in index.get(key, ())})


def _print_references(package: Package, index: dict[str, set[Path]]) -> None:
    counts = Counter(_repo_of(path) for path in _paths_for(package, index))
    if counts:
        named = ', '.join(f'{repo} ({count})' for repo, count in sorted(counts.items()))
        print(f'{"":8} {"":32}        called from: {named}')


def _report_repos(packages: list[Package], only: str | None) -> None:
    """Show which checkouts call each tool, so a formula's blast radius is visible.

    Shell files only, so anything driven from a Python or JS project is missed.
    A hit means the name appears as a word, not that the line still runs.
    """
    chosen = [p for p in packages if p.direct and (not only or only == p.name)]
    if not chosen:
        raise SearchError(f'no package installed on request is named {only!r}')
    index = _reference_index(sorted({key for p in chosen for key in p.match_keys}))

    called, unseen = [], []
    for package in chosen:
        counts = Counter(_repo_of(path) for path in _paths_for(package, index))
        (called if counts else unseen).append((package, counts))

    called.sort(key=lambda row: row[0].name)
    print(f'## called from a git repo ({len(called)} of {len(chosen)})\n')
    print('A wide spread usually means the name is a common word rather than a')
    print('popular tool: go, code, git and github all match ordinary prose.\n')
    for package, counts in called:
        top = counts.most_common(_REPOS_SHOWN)
        named = ', '.join(f'{repo} ({count})' for repo, count in top)
        more = f', +{len(counts) - _REPOS_SHOWN} more' if len(counts) > _REPOS_SHOWN else ''
        label = 'repo ' if len(counts) == 1 else 'repos'
        print(f'{package.name:24} {len(counts):>3} {label}  {named}{more}')

    print(f'\n## nothing searched mentions these ({len(unseen)})\n')
    print(', '.join(package.name for package, _ in unseen))


def _report_list(packages: list[Package]) -> None:
    for kind in ('formula', 'cask'):
        chosen = [p for p in packages if p.kind == kind and p.direct]
        print(f'\n## {kind}s installed on request ({len(chosen)})\n')
        for package in chosen:
            marker = f' [also a dependency of {len(package.required_by)}]' if package.shared else ''
            print(f'{package.full_name}{marker} — {package.desc}')

    indirect = [p for p in packages if p.kind == 'formula' and not p.direct]
    orphans = [p for p in indirect if not p.required_by]
    print(f'\n## pulled in as dependencies ({len(indirect)})\n')
    print(f'{len(indirect) - len(orphans)} are still required by something installed.')
    if orphans:
        names = ' '.join(p.name for p in orphans)
        print(f'{len(orphans)} are required by nothing — run `brew autoremove`: {names}')


def _report_prune(packages: list[Package], stale_days: int) -> None:
    typed = _typed_commands()
    if not typed:
        print(f'No atuin history at {ATUIN_DB}; ranking on file access time alone.\n')
    processes = _running_processes()

    stale, unmeasured = [], []
    for package in (p for p in packages if p.direct and not p.shared):
        usage = _usage(package, typed, processes)
        if not usage.unused:
            continue
        if usage.last_run_days is None:
            unmeasured.append((package, usage))
        elif usage.last_run_days >= stale_days:
            stale.append((package, usage))

    index = _reference_index(
        sorted({key for package, _ in stale + unmeasured for key in package.match_keys})
    )
    stale.sort(key=lambda row: (-row[1].last_run_days, row[0].name))
    print(f'## never typed, not running, and not launched in {stale_days}+ days ({len(stale)})\n')
    print('Access time is a hint, not proof: a GUI app that was quit months ago but')
    print('is still wanted looks the same as one you abandoned.\n')
    for package, usage in stale:
        print(f'{package.kind:8} {package.name:32} {usage.last_run_days:>4}d  {package.desc}')
        _print_references(package, index)

    print(f'\n## no usage signal to read ({len(unmeasured)})\n')
    print('Fonts and libraries install nothing that records a run. Judge by name.\n')
    for package, _ in unmeasured:
        print(f'{package.kind:8} {package.name:32}       {package.desc}')
        _print_references(package, index)


def _machine_of(path: Path) -> str:
    """Name the machine a dumped Brewfile came from, falling back to its filename."""
    return path.suffix.lstrip('.') or path.name


def _report_compare(left: Path, right: Path) -> None:
    lhs, rhs = _parse_brewfile(left), _parse_brewfile(right)
    for kind in ('brew', 'cask'):
        for label, mine, theirs in (
            (_machine_of(left), lhs[kind], rhs[kind]),
            (_machine_of(right), rhs[kind], lhs[kind]),
        ):
            missing = sorted(set(mine) - set(theirs))
            print(f'\n## {kind} only on {label} ({len(missing)})\n')
            for name in missing:
                print(f'{name} — {mine[name]}')
        print(f'\n## {kind} on both ({len(set(lhs[kind]) & set(rhs[kind]))})')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('list', help='every package asked for by name, with descriptions')
    prune = sub.add_parser('prune', help='direct packages with no sign of use')
    prune.add_argument(
        '--days',
        type=int,
        default=STALE_DAYS,
        help=f'how long unused counts as stale (default {STALE_DAYS})',
    )
    compare = sub.add_parser('compare', help='diff two checked-in Brewfiles')
    compare.add_argument('left', type=Path)
    compare.add_argument('right', type=Path)
    repos = sub.add_parser('repos', help='which git checkouts call each package')
    repos.add_argument('only', nargs='?', help='one package name; omit to scan them all')
    args = parser.parse_args()

    match args.command:
        case 'list':
            _report_list(_load_packages())
        case 'prune':
            _report_prune(_load_packages(), args.days)
        case 'compare':
            _report_compare(args.left, args.right)
        case 'repos':
            _report_repos(_load_packages(), args.only)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SearchError as err:
        sys.exit(f'brew_inventory: {err}')
