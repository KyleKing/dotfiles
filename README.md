# README

## Installation Instructions

```sh
# Install oh-my-zsh from: https://ohmyz.sh/#install
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

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

# Apply synced files from Chezmoi
chezmoi apply --verbose

# Install all packages managed by brew
brew bundle --file ~/.Brewfile-personal

# Install Rosetta for Mac Silicon
/usr/sbin/softwareupdate --install-rosetta --agree-to-license

# Run the fzf post-install steps. Accept all prompts
# https://github.com/junegunn/fzf#using-homebrew
$(brew --prefix)/opt/fzf/install
```

## Sublime

[Sublime is synced through Dropbox](https://packagecontrol.io/docs/syncing#dropbox-osx)

```sh
cd ~/Library/Application\ Support/Sublime\ Text/Packages
# On 1st computer: mv User ~/Library/CloudStorage/Dropbox/Apps/Sublime
# On n+1 computers:
mv User User-Backup
ln -s ~/Library/CloudStorage/Dropbox/Apps/Sublime/User
```