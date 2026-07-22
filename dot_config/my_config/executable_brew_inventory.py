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

_COMMAND_NOISE = frozenset({'command', 'doas', 'env', 'exec', 'nohup', 'sudo', 'time', 'watch'})
_SKIP_DIRS = ('.git', 'node_modules', '.venv', 'target')


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
    measurable: bool

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
                measurable=bool(binaries),
            )
        )
    for cask in data['casks']:
        binaries, apps, measurable = _cask_artifacts(cask['artifacts'])
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
                measurable=measurable,
            )
        )
    return sorted(packages, key=lambda p: (p.kind, p.name))


def _formula_binaries(name: str) -> tuple[Path, ...]:
    bin_dir = BREW_OPT / name / 'bin'
    return tuple(p for p in bin_dir.iterdir() if p.is_file()) if bin_dir.is_dir() else ()


def _cask_artifacts(artifacts: list) -> tuple[tuple[Path, ...], set[str], bool]:
    """Locate what a cask installs that macOS stamps an access time on when run.

    Fonts and preference panes never get one, so report them as unmeasurable
    rather than letting them fall into the unused pile.
    """
    binaries: list[Path] = []
    apps: set[str] = set()
    measurable = False
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            continue
        for key, value in artifact.items():
            if key == 'app':
                measurable = True
                app = Path(artifact.get('target') or f'/Applications/{value[0]}')
                apps.add(app.stem)
                macos = app / 'Contents/MacOS'
                if macos.is_dir():
                    binaries.extend(p for p in macos.iterdir() if p.is_file())
            elif key == 'binary':
                measurable = True
                target = artifact.get('target')
                binaries.append(Path(target) if target else Path('/opt/homebrew/bin') / value[0])
    return tuple(binaries), apps, measurable


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


def _days_since(paths: tuple[Path, ...], now: float) -> int | None:
    times = [p.stat().st_atime for p in paths if p.exists()]
    return int((now - max(times)) / 86400) if times else None


def _usage(package: Package, typed: Counter, processes: str, now: float) -> Usage:
    return Usage(
        typed=sum(typed.get(key, 0) for key in package.match_keys),
        last_run_days=_days_since(package.binaries, now),
        running=any(len(key) > 3 and key.lower() in processes for key in package.match_keys),
    )


def _grep_index(terms: list[str], root: Path, extra: list[str]) -> dict[str, set[str]]:
    if not root.is_dir():
        return {}
    command = [
        'grep',
        '-rnow',
        *(f'--exclude-dir={name}' for name in _SKIP_DIRS),
        *extra,
        *(arg for term in terms for arg in ('-e', term)),
        '.',
    ]
    out = subprocess.run(command, capture_output=True, text=True, check=False, cwd=root)
    index: dict[str, set[str]] = {}
    for line in out.stdout.splitlines():
        path, _, rest = line.partition(':')
        _, _, term = rest.partition(':')
        if term in terms:
            index.setdefault(term, set()).add(f'{root.name}/{path.removeprefix("./")}')
    return index


def _reference_index(terms: list[str]) -> dict[str, set[str]]:
    """Map each package name to the config and scripts that mention it, in one pass each."""
    snapshots = [
        '--exclude=Brewfile.*',
        '--exclude=brew_*',
        '--exclude=mise_*',
        '--exclude=*brew_inventory.py',
    ]
    index = _grep_index(terms, CHEZMOI_SRC, snapshots)
    for root in SCRIPT_ROOTS:
        for term, paths in _grep_index(terms, root, [f'--include={g}' for g in SCRIPT_INCLUDES]).items():
            index.setdefault(term, set()).update(paths)
    return index


def _parse_brewfile(path: Path) -> dict[str, set[str]]:
    entries: dict[str, set[str]] = {'brew': set(), 'cask': set()}
    pattern = re.compile(r'^(brew|cask) "([^"]+)"')
    for line in path.read_text().splitlines():
        if match := pattern.match(line):
            entries[match[1]].add(match[2].split('/')[-1])
    return entries


def _descriptions(path: Path) -> dict[str, str]:
    lookup = {}
    pending = ''
    pattern = re.compile(r'^(?:brew|cask) "([^"]+)"')
    for line in path.read_text().splitlines():
        if line.startswith('# '):
            pending = line[2:]
        elif match := pattern.match(line):
            lookup[match[1].split('/')[-1]] = pending
            pending = ''
        else:
            pending = ''
    return lookup


def _print_references(package: Package, index: dict[str, set[str]]) -> None:
    references = sorted({path for key in package.match_keys for path in index.get(key, ())})
    if references:
        shown = ', '.join(references[:4])
        more = f' (+{len(references) - 4} more)' if len(references) > 4 else ''
        print(f'{"":8} {"":32}        referenced in: {shown}{more}')


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


def _report_prune(packages: list[Package], now: float) -> None:
    typed = _typed_commands()
    if not typed:
        print(f'No atuin history at {ATUIN_DB}; ranking on file access time alone.\n')
    processes = _running_processes()

    stale, unmeasured = [], []
    for package in (p for p in packages if p.direct and not p.shared):
        usage = _usage(package, typed, processes, now)
        if not usage.unused:
            continue
        if package.measurable and usage.last_run_days is not None:
            if usage.last_run_days >= STALE_DAYS:
                stale.append((package, usage))
        else:
            unmeasured.append((package, usage))

    index = _reference_index(
        sorted({key for package, _ in stale + unmeasured for key in package.match_keys})
    )

    stale.sort(key=lambda row: (-row[1].last_run_days, row[0].name))
    print(f'## never typed, not running, and not launched in {STALE_DAYS}+ days ({len(stale)})\n')
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


def _report_compare(left: Path, right: Path) -> None:
    lhs, rhs = _parse_brewfile(left), _parse_brewfile(right)
    descs = _descriptions(left) | _descriptions(right)
    for kind in ('brew', 'cask'):
        for label, missing in (
            (f'only on {left.suffix.lstrip(".")}', lhs[kind] - rhs[kind]),
            (f'only on {right.suffix.lstrip(".")}', rhs[kind] - lhs[kind]),
        ):
            print(f'\n## {kind} {label} ({len(missing)})\n')
            for name in sorted(missing):
                print(f'{name} — {descs.get(name, "")}')
        print(f'\n## {kind} on both ({len(lhs[kind] & rhs[kind])})')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('list', help='every package asked for by name, with descriptions')
    sub.add_parser('prune', help='direct packages with no sign of use')
    compare = sub.add_parser('compare', help='diff two checked-in Brewfiles')
    compare.add_argument('left', type=Path)
    compare.add_argument('right', type=Path)
    args = parser.parse_args()

    now = time.time()
    match args.command:
        case 'list':
            _report_list(_load_packages())
        case 'prune':
            _report_prune(_load_packages(), now)
        case 'compare':
            _report_compare(args.left, args.right)
    return 0


if __name__ == '__main__':
    sys.exit(main())
