# Python, pipx, and pyenv Configuration

# Configure pyenv
# https://github.com/pyenv/pyenv/issues/849#issuecomment-285229619
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# > pipx completions require bashcompinit
# autoload -U bashcompinit
# bashcompinit
eval "$(register-python-argcomplete pipx)"
