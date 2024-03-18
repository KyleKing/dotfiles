#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Dot File Syncing Scripts

ch-app() {
    # Apply any changes to local files
    eval "$(op signin)" || return 1
    PAGER="" chezmoi apply --verbose
}

ch-sync() {
    # Pull latest version and apply to local files
    eval "$(op signin)" || return 1
    cd "$(chezmoi source-path)" || return 1
    PAGER="" chezmoi update --verbose

    # Ensure other packages are up to date:
    tldr --update
}

ch-scripts() {
    # Run useful scripts to update generated files, such as listing plugins for Brew, pipx, etc.
    "$HOME/.config/my_config/generate_machine_snapshot.sh"
}

ch-rad() {
    # Prevent overwriting chezmoi edits by checking for staged or unstaged changes
    cd "$(chezmoi source-path)" || return 1
    if output=$(git status --porcelain) && [ -z "$output" ]; then
        eval "$(op signin)" || return 1
        ch-scripts || return 1
        # Sync with files already tracked by chezmoi
        PAGER="" chezmoi re-add --verbose || return 1
    else
        RED='\033[0;31m'
        NC='\033[0m'
        echo -e "${RED}Chezmoi git status must be clean before re-adding${NC}"
    fi
    # open LazyGit to review changes
    lazygit
}

# Obsidian Syncing Snippets
alias mvl="cd / && z obsidian-kyleking-vault && git pull"
mvb() {
    # FYI: `man strftime` provides the same information as Python docs and https://strftime.org/
    MSG="Manual vault backup - $(date -u "+%b %d, %Y %H:%M")"
    printf "Creating commit for: '%s'\n" "$MSG"
    cd / && z obsidian-kyleking-vault && git add . && gcmsg "$MSG" && lzg
}

# NVIM Syncing
alias mnl="cd ~/.config/nvim && git pull"
mnb() {
    MSG="Manual nvim backup - $(date -u "+%b %d, %Y %H:%M")"
    printf "Creating commit for: '%s'\n" "$MSG"
    cd ~/.config/nvim && git add . && gcmsg "$MSG" && lzg
}

# Pull all changes
alias mla="op signin && echo '\n\n# mvl\n' && mvl && echo '\n\n# mnl\n' && mnl && echo '\n\n# ch-sync\n' && ch-sync"
