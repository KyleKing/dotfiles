# Chezmoi Config Management

## Overview

Config file (`chezmoi.toml`) is managed through:

1. **Initial creation**: `run_once_before_setup-chezmoi-config.py.tmpl` prompts for values
1. **SSH key fields**: `update-config.sh` extracts `github.email` and
    `github.ssh_public_key` from SSH key

## Why Separate Update Script?

The config provides data for templates, so it can't be a template itself (circular
dependency).
The `.update-chezmoi-toml.tmpl` template resolves SSH fields from your key file, and
`update-config.sh` applies it.

## Usage

Run `~/.config/chezmoi/update-config.sh` after:

- Initial setup
- Generating new SSH key
- Changing SSH key file
