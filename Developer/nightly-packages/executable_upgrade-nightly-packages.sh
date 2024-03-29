#!/bin/bash -e

# FYI: if adding any CLI tools, make sure to also update dump-version.sh

original_dir=$PWD

for pth in cs gotz lazygit "sh/cmd/shfmt"; do
    echo "Upgrading $original_dir/$pth" && (cd "$pth" && git pull && go install . && cd "$original_dir") || echo "error"
done

# pth="catppuccin-bat"
# BAT_CONFIG_DIR="$(bat --config-dir)"
# echo "Upgrading $pth" && cd "$pth" && git pull && ...(See README) && cd "$original_dir"
# bat cache --build

pth="firefox-vertical-tabs"
echo "Upgrading $pth" && cd "$pth" && git pull && cd "$original_dir"
# # Note: symlink this project into the Firefox profiles (id's might differ per system)
# > cd /Users/kyleking/Library/Application\ Support/Firefox/Profiles
# > lsl
# Permissions Size User     Date Created Name
# drwx------@    - kyleking  2 Sep  2022  4c2wgopw.dev-edition-default
# drwx------@    - kyleking  2 Sep  2022  6zuyes7x.default-release
# drwx------@    - kyleking  2 Sep  2022  trii2qfj.default
# > mkcd 4c2wgopw.dev-edition-default/chrome
# > ln -s /Users/kyleking/Developer/nightly-packages/firefox-vertical-tabs/userChrome.css userChrome.css
# > ...
# > # Repeat
