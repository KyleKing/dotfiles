#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Oh My ZSH (OMZ) Configuration

# Path to your oh-my-zsh installation.
export ZSH="/Users/kyleking/.oh-my-zsh"
# export ZSH_CUSTOM=$ZSH  # Set in `$ZSH/oh-my-zsh.sh`

# Remove some functionality to make omz much faster. Docs: https://github.com/ohmyzsh/ohmyzsh/wiki/Settings#library-settings
export DISABLE_MAGIC_FUNCTIONS=true
export DISABLE_UNTRACKED_FILES_DIRTY=true
# Decrease update check frequency
zstyle ':omz:update' frequency 14

# Configure the navi widget for interactive cheat sheets with custom snippets
eval "$(navi widget zsh)"

# Source brew-installed package completions
# https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

# Use `omz plugin info <name> | glow -` to learn more about each
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
export plugins=(
    # Built-in OMZ plugins
    git        # Extensive git aliases. See: https://github.com/davidde/git
    jj         # Jujutsu VCS integration
    python     # Python aliases: pyfind (search .py files), pyclean (remove bytecode)
    timer      # Command timing in prompt
    tmux       # tmux integration: tmuxconf, tl, ta, etc.

    # External plugins (managed via chezmoi git submodules)
    auto-notify          # Desktop notifications for long-running commands
    you-should-use       # Reminds about existing aliases
    zsh-completions      # Additional completions not in zsh-proper
    zsh-autosuggestions  # Fish-like command suggestions (configured below)
    zsh-syntax-highlighting  # Must be last - syntax highlighting as you type
)

# Auto-activate venv (https://github.com/astral-sh/uv/issues/1910#issuecomment-2394878577)
export PYTHON_VENV_NAME=".venv"
export PYTHON_AUTO_VRUN=true

source "$ZSH/oh-my-zsh.sh"

# ----------------------------------------------------------------------------------------------------------------------
# User configuration

# Extend tmux plugin by auto-recognizing the current directory as the session name
# Usage: tsh - 'terminal session here'
tsh() {
    _name=$(basename "$PWD")
    (ts "$_name" || ta "$_name") || return 1
}

# ----------------------------------------------------------------------------------------------------------------------
# Plugin configuration

# Configuration for zsh-autosuggestions
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
# Keyword shortcuts for different acceptance strategies
# Tab: List of Suggestions for next word. Auto-accepts if only one option
#   Tab (again): to scroll through list
#
# (ctrl space, ctrl n, ctrl p)
bindkey '^]' autosuggest-accept

eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/.config.omp.json)"

# Customize zsh-auto-notify (https://github.com/MichaelAquilina/zsh-auto-notify#configuration)
# Set threshold to 15 seconds
export AUTO_NOTIFY_THRESHOLD=15
# Set notification expiry to 1 seconds
export AUTO_NOTIFY_EXPIRE_TIME=1000
# Create an allowlist for auto-notifications
export AUTO_NOTIFY_WHITELIST=("brew" "poetry install" "make install" "gh run" "gh workflow")
