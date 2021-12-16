# Dot File Syncing Scripts

export CHEZMOI_DIR=$(chezmoi source-path)

ch-sync() {
	# Pull latest version and apply to local files
	cd $CHEZMOI_DIR
	chezmoi update --verbose
}

ch-scripts() {
	# Run useful scripts to update generated files, such as listing plugins for Brew, pipx, etc.
}

ch-rad() {
	# Prevent overwriting chezmoi edits by checking for changes
	cd $CHEZMOI_DIR
	if output=$(git status --porcelain) && [ -z "$output" ]; then
		ch-scripts
		# Sync with files already tracked by chezmoi
		chezmoi re-add --verbose
		# Re-sync directories to catch any new files
		alias ch-add-dir="chezmoi add --recursive --autotemplate --verbose"
		ch-add-dir ~/.config/alacritty/
		ch-add-dir ~/.config/chezmoi/
		ch-add-dir ~/.config/gh/
		ch-add-dir ~/.config/kitty/
		ch-add-dir ~/.config/my_config/
		ch-add-dir ~/.config/zellij/
		ch-add-dir ~/.gnupg/
		ch-add-dir ~/Library/Application\ Support/lazygit/
		ch-add-dir ~/Library/Application\ Support/lazydocker/
		# FIXME: Move Sublime and VSCode to Symlinks:
		# 	https://github.com/twpayne/chezmoi/blob/master/docs/HOWTO.md#handle-configuration-files-which-are-externally-modified
		# ch-add-dir ~/Library/Application\ Support/Code/User/
		# ch-add-dir ~/Library/Application\ Support/Sublime\ Text/Packages/User/
		ch-add-dir ~/Library/Application\ Support/prs/
		ch-add-dir ~/Library/Application\ Support/pypoetry/
	else
		RED='\033[0;31m'
		NC='\033[0m'
		echo -e "${RED}Chezmoi git status must be clean before re-adding${NC}"
	fi
	# open LazyGit to review changes
	lazygit
}
