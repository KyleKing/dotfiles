# Chezmoi Config Management

## Overview

The `chezmoi.toml` config file is managed through a hybrid approach:
- Initial creation: `run_once_before_setup-chezmoi-config.py.tmpl` creates the base config
- Updates: Run `~/.config/chezmoi/update-config.sh` to auto-update SSH key fields

## Why This Approach?

The config file provides data for templates, so it can't be a template itself (circular dependency). Instead:
1. The `run_once` script creates initial config with user input
2. The `.update-chezmoi-toml.tmpl` template auto-resolves `github.email` and `github.ssh_public_key` from your SSH key file
3. The `update-config.sh` helper applies the template when you need to refresh these fields

## When to Run update-config.sh

- After generating a new SSH key
- After changing your SSH key file
- When you want to sync github.email/ssh_public_key with your current key

## Manual Editing

You can also manually edit `~/.config/chezmoi/chezmoi.toml` directly - the helper script is optional.
