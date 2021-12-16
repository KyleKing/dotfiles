# Oh My ZSH (OMZ) Configuration

# Path to your oh-my-zsh installation.
export ZSH="/Users/kyleking/.oh-my-zsh"
# export ZSH_CUSTOM=$ZSH  # Set in `$ZSH/oh-my-zsh.sh`

# > Look in ~/.oh-my-zsh/themes/
# https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# https://github.com/robbyrussell/oh-my-zsh/wiki/External-themes
# ZSH_THEME="powerlevel10k/powerlevel10k"
# Others: agnoster, oxide, Bullet train, lambda-mod, Spaceship ZSH, Halil
# > Note: installed with brew and not oh-my-zsh
source $(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme
# Create a new configuration file `p10k configure` or modify an existing one at ~/.p10k.zsh

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)

# Use `omz plugin info <name>` to learn more about each. Prints the README (`omz plugin info zsh-autosuggestions`)
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins-Overview
plugins=(
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
  # history
  # thefuck
  # wd

  # From Colin
  # lein
  # zsh-nvm

  # # From: https://www.howtogeek.com/362409/what-is-zsh-and-why-should-you-use-it-instead-of-bash/
  # zsh-autosuggestions
  # zsh-syntax-highlighting
  # mouse

  # > lol: alias yolo="git commit -m "$(curl -s http://whatthecommit.com/index.txt)""

  # > homebrew. Use: brewp (pin to prevent upgrade), brewsp (list pinned), bubu (update, upgrade, cleanup), bcubc (cask)
  brew
  # > Kapeli Dash. Use: `dash python:tuple`
  dash
  # > History. Use: h, hs <> (grep), hsi <> (grep -i)
  history
  # > Mac commands. Use: quick-look, man-preview, hidefiles, showfiles, music, rmdsstore, btrestart
  macos
  # > Time commands (https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/timer)
  timer
  # > Aliases for VSCode. Use: `vscd file file` (diff)
  vscode
  # > Sublime plugin doesn't provide any benefit over `subl``

  # Git checkouts
  # TODO: Add as git submodules to be avialable everywhere!
  # TODO: Compare against zsh-autosuggestions/zsh-completions & zsh-syntax-highlighting/fast-syntax-highlighting
  #
  # git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
  #   ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
  # # See: https://github.com/zdharma-continuum/fast-syntax-highlighting#oh-my-zsh
  # fast-syntax-highlighting
  #
  # git clone https://github.com/zsh-users/zsh-completions \
  #   ${ZSH_CUSTOM:=~/.oh-my-zsh/custom}/plugins/zsh-completions
  # # See: https://github.com/zsh-users/zsh-completions
  # zsh-completions
  #
  # # Install git-extra-commands
  # # See: https://github.com/unixorn/git-extra-commands#oh-my-zsh
  # git-extra-commands

  # https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md
  # git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  zsh-autosuggestions

  # https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md
  # git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  # > Must be last!
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ----------------------------------------------------------------------------------------------------------------------
# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nano'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
# FYI: Global variables are used as aliases for commands that take pipe input
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
