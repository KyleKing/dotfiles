# Configure CLI Tools

# Set an alias for thefuck installed with brew: https://github.com/nvbn/thefuck
eval "$(thefuck --alias oop)"

# Map exa to ls with some default options
alias ls='exa --icons'
alias lsa='ls --all'
alias lsl='ls --long --header --created --git'
alias lst='lsl -TL 2'

# Preview fzf results with bat syntax highlighting
# > cd ~/.config && fzf-bat
fzf-bat () {
  fzf --preview 'bat --color=always --style=numbers --line-range=:40 {}'
}
# FYI: fzfp will use stpv for image previews as well
#   https://github.com/Naheel-Azawy/stpv

# Tail a file with syntax highlighting. Infers from extension or can be set manually
# > btail ~/.zprofile zsh
tail-bat() {
  tail -f $1 | bat --paging=never -l ${2:-${1##*.}}
}

# load lf, but use cd on exit
# https://github.com/gokcehan/lf/wiki/Tutorial#working-directory
source ~/.config/lf/lfcd.sh

# Note: Pistol requires a difficult manual install
# # Use pistol for previewing matches from fd
# alias fd-pr="$EDITOR $(fd --extension py | fzf --preview='pistol {}')"
# # Chose stpv instead, which is installed as a submodule of chezmoi
export PATH="$PATH:$(chezmoi source-path)/dot_config/stpv/stpv"

# HSTR configuration - add this to ~/.zshrc
alias hh=hstr                    # hh to be alias for hstr
setopt histignorespace           # skip cmds w/ leading space from history
export HSTR_CONFIG=hicolor       # get more colors
bindkey -s "\C-r" "\C-a hstr -- \C-j"     # bind hstr to Ctrl-r (for Vi mode check doc)
