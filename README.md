# README

## Modifications

### Wezterm

Custom tab color/title. Discussion here: <https://github.com/wez/wezterm/discussions/4945>

### Jujutsu (jj) with jj-stack

Configured for stacked diffs/PRs on GitHub using:
- **jj**: Git-compatible VCS installed via Homebrew
- **jj-stack**: npm package for creating/managing stacked PRs
- **lazyjj**: TUI for visual jj workflows

Documentation (with mermaid diagrams):
- **Quick start**: `~/.config/my_config/scripts/JJ_GETTING_STARTED.md`
- **Mental model**: `~/.config/my_config/scripts/JJ_MENTAL_MODEL.md` - Core concepts visualized
- **Workflows**: `~/.config/my_config/scripts/JJ_WORKFLOWS.md` - Operations and patterns
- **Decision trees**: `~/.config/my_config/scripts/JJ_DECISION_TREES.md` - Command selection guide
- **Stacked diffs**: `~/.config/my_config/scripts/JJ_STACKED_WORKFLOW.md` - jj-stack workflows
- **Quick reference**: Run `jhelp` in terminal

## Installation Instructions

```sh
brew install chezmoi
chezmoi init git@github.com:KyleKing/dotfiles.git --verbose

brew install --cask 1password 1password-cli
# In 1Password, turn on 1password-cli

# Sign in with 1Password-cli
eval "$(op signin)"

# Configure the local configuration file based on dot_config/chezmoi/chezmoi.toml.tmpl
# https://github.com/KyleKing/dotfiles/blob/main/dot_config/chezmoi/chezmoi.toml.tmpl
touch ~/.config/chezmoi/chezmoi.toml
open ~/.config/chezmoi/chezmoi.toml
# These values need to be close enough, but don't need to be perfect and can be fixed later

# Install oh-my-zsh from: https://ohmyz.sh/#install
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Apply synced files from Chezmoi
chezmoi apply --verbose

# Install all packages managed by brew
brew bundle --file ~/.Brewfile-personal --no-lock

# (Optional, hard to uninstall) Install Rosetta for Mac Silicon
/usr/sbin/softwareupdate --install-rosetta --agree-to-license

# Run the fzf post-install steps. Accept all prompts
# https://github.com/junegunn/fzf#using-homebrew
$(brew --prefix)/opt/fzf/install
```
