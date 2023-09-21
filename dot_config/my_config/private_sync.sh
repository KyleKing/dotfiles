#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Dot File Syncing Scripts

ch-app() {
    # Apply any changes to local files
    eval "$(op signin)" || return
    PAGER="" chezmoi apply --verbose
}

ch-sync() {
    # Pull latest version and apply to local files
    eval "$(op signin)" || return
    cd "$(chezmoi source-path)" || return
    PAGER="" chezmoi update --verbose

    # Ensure other packages are up to date:
    tldr --update
}

ch-scripts() {
    # Run useful scripts to update generated files, such as listing plugins for Brew, pipx, etc.
    $HOME/.config/my_config/generate_machine_snapshot.sh
}

ch-rad() {
    # Prevent overwriting chezmoi edits by checking for staged or unstaged changes
    cd "$(chezmoi source-path)" || return
    if output=$(git status --porcelain) && [ -z "$output" ]; then
        eval "$(op signin)" || return
        ch-scripts || return
        # Sync with files already tracked by chezmoi
        PAGER="" chezmoi re-add --verbose || return
        # Previously attempted to sync with directories, but too much noise
        # FIXME: Move VSCode to Symlinks:
        # 	https://github.com/twpayne/chezmoi/blob/master/docs/HOWTO.md#handle-configuration-files-which-are-externally-modified
        #
        # ch-add-dir ~/Library/Application\ Support/Code/User/
        # chezmoi cd
        # cd private_Library/private_Application\ Support/private_Sublime\ Text
        # rm -rf User
        # mv /Users/kyleking/Library/Application\ Support/Sublime\ Text/Packages/User/ ./User
        # cd ~/Library/Application\ Support/Sublime\ Text/Packages/
        # ln -s /Users/kyleking/.local/share/chezmoi/private_Library/private_Application\ Support/private_Sublime\ Text/private_Packages/User
    else
        RED='\033[0;31m'
        NC='\033[0m'
        echo -e "${RED}Chezmoi git status must be clean before re-adding${NC}"
    fi
    # open LazyGit to review changes
    lazygit
}
