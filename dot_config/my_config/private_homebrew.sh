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
# > cd ~/.config && fzfp
fzfp () {
  fzf --preview 'bat --color=always --style=numbers --line-range=:40 {}'
}

# Tail a file with syntax highlighting. Infers from extension or can be set manually
# > btail ~/.zprofile zsh
btail() {
  tail -f $1 | bat --paging=never -l ${2:-${1##*.}}
}
