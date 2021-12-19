# Homebrew configuration

# Source homebrew-installed completions
# Explanantion: https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

# Preview fzf results with bat syntax highlighting
# > cd ~/.config && fzf-bat
fzf-bat () {
  fzf --preview 'bat --color=always --style=numbers --line-range=:40 {}'
}
# FYI: fzfp will use stpv for image previews as well
#   https://github.com/Naheel-Azawy/stpv

# Tail a file with syntax highlighting. Infers from extension or can be set manually
# > btail ~/.zprofile zsh
btail() {
  tail -f $1 | bat --paging=never -l ${2:-${1##*.}}
}

# load lf, but use cd on exit
# https://github.com/gokcehan/lf/wiki/Tutorial#working-directory
source ~/.config/lf/lfcd.sh

# Note: Pistol requires a difficult manual install
# # Use pistol for previewing matches from fd
# alias fd-pr="$EDITOR $(fd --extension py | fzf --preview='pistol {}')"
