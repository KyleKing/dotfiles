#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# Path to your oh-my-zsh installation.
export ZSH="/Users/kyleking/.oh-my-zsh"
# export ZSH_CUSTOM=$ZSH  # Set in `$ZSH/oh-my-zsh.sh`

# Configure the navi widget for completions
eval "$(navi widget zsh)"

# Use `omz plugin info <name>  | glow -` to learn more about each. Prints the README
#   omz plugin info zsh-autosuggestions | glow -
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins-Overview
export plugins=(
    # brew: homebrew. Use: brewp (pin to prevent upgrade), brewsp (list pinned), bubu (update, upgrade, cleanup), bcubc (cask)
    # catimg: use the shell script to display images in terminal
    # command-not-found: looks up the possible missing homebrew package
    # copybuffer: Ctrl+O to copy typed command
    # copypath: Copies current path or the path to the specified file
    # dash: Kapeli Dash. Use: `dash python:tuple`
    # docker:
    # encode64: e64/d64: encodes or decode given data to/from base64 (`e64 '{"a": 1}'` // `pbpaste | d64 | gojq`)
    # git: a TON of aliases. See: https://github.com/davidde/git
    # history: History. Use: h, hs <> (grep), hsi <> (grep -i)
    # macos: Mac commands. Use: quick-look, man-preview, hidefiles, showfiles, music, rmdsstore, btrestart
    # # nvm: automatically sources nvm and adds completions
    # perms: recursively set permissions (fixperms, set755, set644)
    # python: useful aliases (`pyfind` recursively find .py / `pyclean` Delete byte and cache)
    # rust: Supports cargo and rustup
    # timer: Time commands (https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/timer)
    # urltools: urlencode/urldecode (urldecode 'https%3A%2F%2Fgithub.com%2Fohmyzsh%2Fohmyzsh%2Fsearch%3Fq%3Durltools%26type%3DCode')
    # vscode: Aliases for VSCode. Use: `vscd file file` (diff)
    brew
    catimg
    command-not-found
    copybuffer
    copypath
    dash
    docker
    encode64
    git
    history
    macos
    perms
    python
    rust
    timer
    urltools
    vscode

    # lol: alias yolo="git commit -m "$(curl -s http://whatthecommit.com/index.txt)""
    # Sublime plugin doesn't provide any benefit over `subl`

    # Chezmoi Git Submodules
    # Docs: https://github.com/MichaelAquilina/zsh-auto-notify
    auto-notify
    # Docs: https://github.com/MichaelAquilina/zsh-you-should-use
    you-should-use
    # Docs: https://github.com/unixorn/git-extra-commands#included-scripts
    git-extra-commands

    # Docs (Extra completions not yet in Zsh-proper): https://github.com/zsh-users/zsh-completions
    zsh-completions
    # Docs: https://github.com/zsh-users/zsh-autosuggestions
    zsh-autosuggestions
    # Syntax Highlighters must be last. There are two where FSyH was a hostile fork of ZSyH
    # https://github.com/zsh-users/zsh-syntax-highlighting
    zsh-syntax-highlighting
    # https://github.com/zdharma-continuum/fast-syntax-highlighting/issues/8
    # fast-syntax-highlighting
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

# ----------------------------------------------------------------------------------------------------------------------
# Plugin configuration

# Configuration for zsh-autosuggestions
export ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion history)
# Keyword shortcuts for different acceptance strategies
# Tab: List of Suggestions for next word. Auto-accepts if only one option
#   Tab (again): to scroll through list
#
# (ctrl space, ctrl shit n, ctrl shift p)
bindkey '^ ' autosuggest-accept

eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/.config.omp.json)"

# Customize zsh-auto-notify (https://github.com/MichaelAquilina/zsh-auto-notify#configuration)
# Set threshold to 15 seconds
export AUTO_NOTIFY_THRESHOLD=15
# Set notification expiry to 1 seconds
export AUTO_NOTIFY_EXPIRE_TIME=1000
# Create an allowlist for auto-notifications
export AUTO_NOTIFY_WHITELIST=("brew" "poetry install" "make install" "gh run" "gh workflow")
