#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Configure CLI Tools

# Mise-en-place asdf alternative: https://mise.jdx.dev/tasks/running-tasks.html
alias mr="mise task run"

# See local weather. Full docs: https://github.com/chubin/wttr.in
alias wttr="curl v2d.wttr.in"

# Interactive Make TUI
alias lzm='lazymake'

# Aliases for find (fd)
alias fdh='fd --hidden'

# Aliases for ripgrep (rg)
export RIPGREP_CONFIG_PATH=~/.config/ripgrep/.ripgreprc
# FYI: Add -A/-B/-C for context before/after the match
alias rgh='rg --hidden'
alias rgfs='rgh --fixed-strings --'
rgso() {
    _search=$1
    echo "Searching with: '$_search'"
    if [[ -z "$_search" ]]; then
        echo "The search strings must be specified. Expected: 'rgso ...'"
        return 1
    else
        paths=$(rgh --fixed-strings --files-with-matches -- "$_search")
        echo "Found: '$paths'"
        # for path in $paths;
        #     do $EDITOR "$path";
        # done
        echo "^ FIXME: These paths aren't absolute and raise other errors..."
    fi
}

# Replace ls with eza
alias ls='eza --icons'
alias lsa='ls --all'
alias lsl='ls --long --header --created --git'
alias lst='lsl -TL 2'

# Use fd to filter files based on gitignore rules
# From: https://github.com/junegunn/fzf/tree/d01ae551090bb2f7c7ad6a9013937b65e08921cc#respecting-gitignore
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Preview fzf results with bat syntax highlighting
# > cd ~/.config && fzf-bat
fzf-bat() {
    fzf --preview 'bat --color=always --style=numbers --line-range=:40 {}'
}

# Tail a file with syntax highlighting. Infers from extension or can be set manually
# > btail ~/.zprofile zsh
btail() {
    tail -f "$1" | bat --paging=never -l "${2:-${1##*.}}"
}

# Review CLI: https://github.com/kyleking/second-look
alias sl='second-look'

# Format markdown with the same mdformat plugins/args as .pre-commit-config.yaml
# mdformat-mkdocs[recommended] already pulls in mdformat-front-matters, so it's not listed separately
# > mdformatters README.md docs/CONTRIBUTING.md
mdformatters() {
    uvx --with "mdformat-mkdocs[recommended]>=5.3.0" \
        --with "mdformat-slw>=0.4.0" \
        mdformat --wrap=keep "$@"
}

# Same as mdformatters, but against every *.md file in and below the cwd,
# skipping the files .pre-commit-config.yaml also excludes
# > mdformatters-matcher
mdformatters-matcher() {
    local -a files
    files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(fd --extension md --exclude '_*.md' --exclude 'CHANGELOG.md' --exclude 'CODE_TAG_SUMMARY.md')
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No markdown files found"
        return 0
    fi
    mdformatters "${files[@]}"
}
