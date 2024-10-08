#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# Path to your oh-my-zsh installation.
export ZSH="/Users/kyleking/.oh-my-zsh"
# export ZSH_CUSTOM=$ZSH  # Set in `$ZSH/oh-my-zsh.sh`

# Remove some functionality to make omz much faster. Docs: https://github.com/ohmyzsh/ohmyzsh/wiki/Settings#library-settings
export DISABLE_MAGIC_FUNCTIONS=true
export DISABLE_UNTRACKED_FILES_DIRTY=true
# Decrease update check frequency
zstyle ':omz:update' frequency 14

# Configure the navi widget for completions
# TODO: Should I use navi, cheat, tldr, or other tool for all quick reference?
eval "$(navi widget zsh)"

# Source brew-installed package completions
# https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

# Use `omz plugin info <name>  | glow -` to learn more about each. Prints the README
#   omz plugin info zsh-autosuggestions | glow -
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins-Overview
export plugins=(
    # copybuffer: Ctrl+O to copy typed command
    # copypath: Copies current path or the path to the specified file
    # encode64: e64/d64: encodes or decode given data to/from base64 (`e64 '{"a": 1}'` // `pbpaste | d64 | gojq`)
    # git: a TON of aliases. See: https://github.com/davidde/git and the alternative https://github.com/unixorn/git-extra-commands
    # history: History. Use: h, hs <> (grep), hsi <> (grep -i)
    # macos: Mac commands. Use: quick-look, man-preview, hidefiles, showfiles, music, rmdsstore, btrestart
    # perms: recursively set permissions (fixperms, set755, set644)
    # python: useful aliases (`pyfind` recursively find .py / `pyclean` Delete byte and cache)
    # timer: time commands integration to the prompt (https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/timer)
    # tmux: auto-start in tmux session, tmuxconf to edit config, tl to list, ta to attach, etc.
    # urltools: urlencode/urldecode (urldecode 'https%3A%2F%2Fgithub.com%2Fohmyzsh%2Fohmyzsh%2Fsearch%3Fq%3Durltools%26type%3DCode')
    # copybuffer
    # copypath
    # encode64
    git
    # history
    # macos
    # perms
    # python
    timer
    tmux
    # urltools

    # lol: alias yolo="git commit -m "$(curl -s http://whatthecommit.com/index.txt)""

    # Chezmoi Git Submodules
    #
    # Docs: https://github.com/MichaelAquilina/zsh-auto-notify
    auto-notify
    # Docs: https://github.com/MichaelAquilina/zsh-you-should-use
    you-should-use
    # Docs (Extra completions not yet in Zsh-proper): https://github.com/zsh-users/zsh-completions
    zsh-completions
    # Docs: https://github.com/zsh-users/zsh-autosuggestions (Configuration below)
    zsh-autosuggestions
    # Syntax Highlighters must be last
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ----------------------------------------------------------------------------------------------------------------------
# User configuration

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
# FYI: Global variables are used as aliases for commands that take pipe input
#
# Example aliases
# alias zshconfig="mate $HOME/.zshrc"
# alias ohmyzsh="mate $HOME/.oh-my-zsh"

# Extend tmux plugin by auto-recognizing the current directory as the session name
#   'terminal session here'
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
