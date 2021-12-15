# WIP Notes

Store the brew bundle per computer? May also mas? [Snippets from here](https://github.com/monfresh/dotfiles)

```sh
brew bundle dump --file=- > ~/.config/my_config/generated/Brewfile.local
mas list > ~/.config/my_config/generated/app_store.local

chmod 0600 "$HOME/.config/chezmoi/chezmoi.toml"
```

Could use this to check if the file exists?


```zsh
if [ ! -f "$HOME/.tbd" ]; then
  echo "TBD"
fi
```
