#!/bin/bash
# Source: https://til.hashrocket.com/posts/n44hnf0z99-show-better-image-diff-on-git

if [[ -f "$1" ]] && [[ -f "$2" ]]; then
    compare "$2" "$1" png:- | montage -geometry +4+4 "$2" - "$1" png:- | wezterm imgcat
else
    if [[ -f "$1" ]]; then
        echo "+ Image Added"
        wezterm imgcat "$1"
    else
        echo "- Image Removed"
        wezterm imgcat "$2"
    fi
fi

exit 0
