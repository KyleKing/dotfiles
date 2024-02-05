# README

## Modifications

### Wezterm

Custom tab color/title. Discussion here: <https://github.com/wez/wezterm/discussions/4945>

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
# On 1st computer: mv User $HOMR/Library/CloudStorage/Dropbox/Apps/Sublime
# On n+1 computers:
mv User User-Backup
ln -s "$HOME/Library/CloudStorage/Dropbox/Apps/Sublime/User"
```

## Custom Colorschems

### K9s

<https://github.com/catppuccin/k9s>

```sh
K9S_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/Library/Application Support}/k9s"
gh repo clone catppuccin/k9s "${K9S_CONFIG_PATH}/skins/catppuccin" -- --depth 1
cp "${K9S_CONFIG_PATH}/skins/catppuccin/dist/mocha.yml" "${K9S_CONFIG_PATH}/skin.yml"
```

### bat

<https://github.com/catppuccin/bat>

```sh
CAT_BAT_DIR="$HOME/Developer/nightly-packages/catppuccin-bat"
gh repo clone catppuccin/bat "$CAT_BAT_DIR" -- --depth 1
BAT_CONFIG_DIR="$(bat --config-dir)"
chdir "$CAT_BAT_DIR"
mkdir "$BAT_CONFIG_DIR/themes" || return true
cp *.tmTheme "$BAT_CONFIG_DIR/themes"
bat cache --build
```
