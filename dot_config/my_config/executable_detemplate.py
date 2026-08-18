"""Rewrite literal personal values back into template placeholders in chezmoi source .tmpl files.

`chezmoi re-add` copies the live rendered file back into the source tree verbatim, so a
literal value that lands in the rendered file (e.g. Docker Desktop appending your home
directory to ~/.zshrc) gets baked into the .tmpl source instead of staying templated.
Run this after `chezmoi re-add` to catch that.
"""

import json
import subprocess
from pathlib import Path

WHITELIST_KEYS = [
    'email',
    'github.username',
    'github.ssh_key_path',
    'onepassword.domain',
    'onepassword.account_id',
    'obsidian.vault_name',
    'computer_name',
    'homebrew_prefix',
]
"""chezmoi data keys safe to fold back into `{{ .key }}`; excludes secrets and free-text fields."""

SHELL_FILENAME_MARKERS = ('zshrc', 'zprofile', 'bashrc', 'bash_profile')


def _flatten(data: dict, prefix: str = '') -> dict[str, str]:
    flat = {}
    for key, value in data.items():
        path = f'{prefix}{key}'
        if isinstance(value, dict):
            flat.update(_flatten(value, f'{path}.'))
        elif isinstance(value, str):
            flat[path] = value
    return flat


def _is_shell_file(path: Path) -> bool:
    stem = path.name.removesuffix('.tmpl')
    return Path(stem).suffix in {'.sh', '.zsh', '.bash'} or any(
        marker in stem for marker in SHELL_FILENAME_MARKERS
    )


def detemplate() -> None:
    source_dir = Path(
        subprocess.run(
            ['chezmoi', 'source-path'], check=True, capture_output=True, text=True
        ).stdout.strip()
    )
    data = json.loads(
        subprocess.run(
            ['chezmoi', 'data', '--format=json'], check=True, capture_output=True, text=True
        ).stdout
    )
    flat = _flatten(data)

    substitutions = [(data['chezmoi']['homeDir'], '$HOME', True)]
    for key in WHITELIST_KEYS:
        value = flat.get(key)
        if value and len(value) >= 6:
            substitutions.append((value, '{{ .' + key + ' }}', False))
    # Longest values first so a shorter value can't clobber part of a longer match.
    substitutions.sort(key=lambda item: len(item[0]), reverse=True)

    changed = []
    for path in source_dir.rglob('*.tmpl'):
        if '.git' in path.parts:
            continue
        original = path.read_text()
        text = original
        for value, replacement, shell_only in substitutions:
            if shell_only and not _is_shell_file(path):
                continue
            text = text.replace(value, replacement)
        if text != original:
            path.write_text(text)
            changed.append(path.relative_to(source_dir))

    if changed:
        print('Detemplated:')
        for path in changed:
            print(f'  {path}')
    else:
        print('No literal personal values found in .tmpl files.')


if __name__ == '__main__':
    detemplate()
