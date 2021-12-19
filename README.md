# README

## Installation Insctructions

```sh
brew install chezmoi
chezmoi init https://github.com/KyleKing/dotfiles --verbose

# Note if symlinks are reported as broken, see where they should point to with `ls -l <>`
mkdir ~/.config/chezmoi-dual-linked/Sublime-Packages-User/Projects

# The "create_" rules didn't seem to working, so you may need to manually create these files initially
mkdir -p "~/.config/chezmoi-dual-linked/Sublime-Packages-User/CodeMap"
touch "~/.config/chezmoi-dual-linked/Sublime-Packages-User/CodeMap/Code - Map"
touch "~/.config/chezmoi-dual-linked/Sublime-Packages-User/CodeMap/Code - Map.source"
touch "~/.config/chezmoi-dual-linked/Sublime-Packages-User/Terminus.hidden-color-scheme"
```
