#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
# Oh My ZSH (OMZ) Configuration

# Path to your oh-my-zsh installation.
export ZSH="/Users/kyleking/.oh-my-zsh"
# export ZSH_CUSTOM=$ZSH  # Set in `$ZSH/oh-my-zsh.sh`

# > Look in $HOME/.oh-my-zsh/themes/
# https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# https://github.com/robbyrussell/oh-my-zsh/wiki/External-themes
# ZSH_THEME="powerlevel10k/powerlevel10k"
# Others: agnoster, oxide, Bullet train, lambda-mod, Spaceship ZSH, Halil
# > Note: installed with brew and not oh-my-zsh
source "$(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme"
# Create a new configuration file `p10k configure` or modify an existing one at $HOME/.p10k.zsh

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
export HYPHEN_INSENSITIVE="true"

# Uncomment the following line to automatically update without prompting.
# export DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line if pasting URLs and other text is messed up.
# export DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to enable command auto-correction.
# export ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
export COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# export DISABLE_UNTRACKED_FILES_DIRTY="true"

# Would you like to use another custom folder than $ZSH/custom?
# export ZSH_CUSTOM=/path/to/new-custom-folder

# Improve OMZ Timer (https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/timer)
export TIMER_FORMAT='[%d]'
export TIMER_PRECISION=2

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# Which plugins would you like to load? (plugins can be found in $HOME/.oh-my-zsh/plugins/*)

# Configure the navi widget for completions
eval "$(navi widget zsh)"

# Use `omz plugin info <name>` to learn more about each. Prints the README (`omz plugin info zsh-autosuggestions`)
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins-Overview
export plugins=(
#   # autopep8
#   # branch
#   # bundler
#   # cask
#   # catimg
#   # celery
#   # chucknorris
#   # codeclimate
#   # coffee
#   # composer
#   # copybuffer
#   # cpanm
#   # dirpersist
#   # dnf
#   # dnote
#   # docker
#   # doctl
#   # dotenv
#   # droplr
#   # emoji
#   # emoji-clock
#   # emotty
#   # extract
#   # fancy-ctrl-z
#   # fasd
#   # fbterm
#   # fd
#   # firewalld
#   # frontend-search
#   # fzf
#   # gas
#   # gb
#   # git-flow
#   # git-hubflow
#   # git-prompt
#   # git-remote-branch
#   # github
#   # glassfish
#   # globalias
#   # gnu-utils
#   # hanami
#   # history-substring-search
#   # homestead
#   # httpie
#   # kate
#   # keychain
#   # kitchen
#   # knife
#   # last-working-dir - may interfere with VS Code
#   # lighthouse
#   # macports
#   # magic-enter
#   # marked2
#   # mix
#   # mix-fast
#   # mosh
#   # nanoc
#   # ng
#   # node
#   # nomad
#   # npm
#   # npx
#   # nvm
#   # oc
#   # otp
#   # pep
#   # per-directory-history
#   # percol
#   # perms
#   # phing
#   # pip
#   # pj
#   # please
#   # pod
#   # pow
#   # powder
#   # powify
#   # profiles
#   # pyenv
#   # python
#   # rand-quote
#   # react-native
#   # repo
#   # ripgrep
#   # rsync
#   # safe-paste
#   # salt
#   # sbt
#   # scd
#   # screen
#   # scw
#   # sdk
#   # sfdx
#   # sfffe
#   # shrink-path
#   # siftpm
#   # singlechar
#   # spring
#   # sprunge
#   # ssh-agent
#   # stack
#   # supervisor
#   # svcat
#   # symfony2
#   # systemadmin
#   # systemd
#   # taskwarrior
#   # terminitor
#   # terraform
#   # tig
#   # transfer
#   # tugboat
#   # ubuntu
#   # ufw
#   # urltools
#   # vault
#   # vundle
#   # wakeonlan
#   # web-search
#   # wp-cli
#   # xcode
#   # yarn
#   # yum
#   # zeus
#   # zsh-navigation-tools

#   colored-man-pages
#   colorize
#   command-not-found
#   common-aliases
#   compleat
#   copydir
#   copyfile
#   cp
#   dircycle
#   dirhistory
#   docker
#   encode64
#   git
#   git-auto-fetch
#   git-extras
#   gitfast
#   gitignore
#   jsontools
#   nmap
#   sudo
#   themes

  # man
  # thefuck
  # wd

  # From Colin
  # lein
  # zsh-nvm

  # brew: homebrew. Use: brewp (pin to prevent upgrade), brewsp (list pinned), bubu (update, upgrade, cleanup), bcubc (cask)
  # dash: Kapeli Dash. Use: `dash python:tuple`
  # history: History. Use: h, hs <> (grep), hsi <> (grep -i)
  # macos: Mac commands. Use: quick-look, man-preview, hidefiles, showfiles, music, rmdsstore, btrestart
  # timer: Time commands (https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/timer)
  # vscode: Aliases for VSCode. Use: `vscd file file` (diff)
  brew
  dash
  history
  macos
  timer
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
  # Docs (Requires "brew install terminal-notifier"): https://github.com/marzocchi/zsh-notify
  zsh-notify
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

# To customize prompt, run `p10k configure` or edit $HOME/.p10k.zsh.
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh
