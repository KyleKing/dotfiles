# Configure CLI Tools

# Set an alias for thefuck installed with brew: https://github.com/nvbn/thefuck
eval $(thefuck --alias oop)

# Map exa to ls with some default options
alias ls='exa --icons'
alias lsa='ls --all'
alias lsl='ls --long --header --created --git'
alias lst='lsl -TL 2'

# # https://github.com/junegunn/fzf
# # To install useful key bindings and fuzzy completion:
# # Run once!
# # $(brew --prefix)/opt/fzf/install
# # To uninstall!
# # $(brew --prefix)/opt/fzf/uninstall
# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# # cat $(fzf)
# https://github.com/ajeetdsouza/zoxide
# After fzf
eval "$(zoxide init zsh)"
# zoxide query  --list --score
# z foo              # cd into highest ranked directory matching foo
# z foo bar          # cd into highest ranked directory matching foo and bar
#
# z ~/foo            # z also works like a regular cd command
# z foo/             # cd into relative path
# z ..               # cd one level up
# z -                # cd into previous directory
#
# zi foo             # cd with interactive selection (using fzf)
#
# z foo<SPACE><TAB>  # show interactive completions (zoxide v0.7.10+, bash/fish/zsh only)
