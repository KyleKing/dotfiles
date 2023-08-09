"""Overwrite the template files with latest version."""

import json
from pathlib import Path

try:
    from ruamel.yaml import YAML
except ImportError as exc:
    raise RuntimeError(
        "Run 'cd ~/.config && python -m pip install ruamel.yaml'"
    ) from exc


SUFFIX = 'placeholder'
"""Used to add template changes *after* JSON formatting."""


def back_sync_vscode_settings_to_template() -> None:
    """Overwrite the VSCode template."""
    path_source = Path.home() / 'Library/Application Support/Code/User/settings.json'
    path_dest = (
        Path.home()
        / '.local/share/chezmoi'
        / 'private_Library/private_Application Support/private_Code/User/private_settings.json.tmpl'
    )

    # YAML is superset of JSON and will handle trailing commas
    yaml = YAML(typ='safe')
    vscode_settings = yaml.load(path_source.read_text())

    replacement_lookup = {
        'sourcery.token': '{{ output "op" "item" "get" "Sourcery Token {Education}" "--field" "password" | trim }}',
        'checkov.token': '{{ output "op" "item" "get" "Checkov CI Token" "--field" "password" | trim }}',
    }
    for key in replacement_lookup:
        vscode_settings[key] = f'{key}-{SUFFIX}'

    new_settings = json.dumps(vscode_settings, indent=4, sort_keys=not True)
    for key, value in replacement_lookup.items():
        new_settings = new_settings.replace(f'{key}-{SUFFIX}', value)

    path_dest.write_text(new_settings)


if __name__ == '__main__':
    back_sync_vscode_settings_to_template()
