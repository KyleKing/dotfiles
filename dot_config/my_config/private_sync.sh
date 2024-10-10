#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Dot File Syncing Scripts

back-apply-ch() {
    # Apply any changes to local files
    eval "$(op signin)" || return 1
    chezmoi apply
}

back-pull-ch() {
    # Pull latest version and apply to local files
    eval "$(op signin)" || return 1
    cd "$(chezmoi source-path)" || return 1
    chezmoi update
}

back-scripts-ch() {
    # Run useful scripts to update generated files, such as listing plugins for Brew, uvx, etc.
    "$HOME/.config/my_config/generate_machine_snapshot.sh"
}

back-c-ch() {
    # Prevent overwriting chezmoi edits by checking for staged or unstaged changes
    cd "$(chezmoi source-path)" || return 1
    if output=$(git status --porcelain) && [ -z "$output" ]; then
        eval "$(op signin)" || return 1
        back-scripts-ch || return 1
        # Sync with files already tracked by chezmoi
        chezmoi re-add || return 1
    else
        RED='\033[0;31m'
        NC='\033[0m'
        echo -e "${RED}Chezmoi git status must be clean before re-adding${NC}"
    fi
    # open LazyGit to review changes
    lazygit
}

# Obsidian Syncing Snippets
alias back-pull-obs="cd / && z obsidian-kyleking-vault && git pull"
back-c-obs() {
    # FYI: `man strftime` provides the same information as Python docs and https://strftime.org/
    MSG="Manual vault backup - $(date -u "+%b %d, %Y %H:%M")"
    printf "Creating commit for: '%s'\n" "$MSG"
    cd / && z obsidian-kyleking-vault && ga . && gcmsg "$MSG" && lzg
}

# NVIM Syncing
alias back-pull-nvim="cd ~/.config/nvim && git pull"
back-c-nvim() {
    MSG="chore: manual nvim backup - $(date -u "+%b %d, %Y %H:%M")"
    printf "Creating commit for: '%s'\n" "$MSG"
    cd ~/.config/nvim && ga . && gcmsg "$MSG" && lzg
}

# Pull all changes
back-pull-all() {
    op signin &&
        printf "\n\n# back-pull-obs\n" && back-pull-obs && git status &&
        printf "\n\n# back-pull-nvim\n" && back-pull-nvim && git status &&
        printf "\n\n# back-pull-ch\n" && back-pull-ch && git status
}
# Just show status
back-stat-all() {
    op signin &&
        printf "\n\n# Obsidian:\n" && cd / && z obsidian-kyleking-vault && echo "$PWD" && git status &&
        printf "\n\n# nvim\n" && cd ~/.config/nvim && echo "$PWD" && git status &&
        printf "\n\n# Chezmoi\n" && cd / && z chezmoi && echo "$PWD" && git status
}
