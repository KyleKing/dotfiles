#!/bin/bash -e

# FYI: if adding any CLI tools, make sure to also update dump-version.sh

mani run install --tags=go-install

original_dir=$PWD

pth="sh/cmd/shfmt"
echo "Upgrading $original_dir/$pth"
cd "$pth" && git pull && go install . && cd "$original_dir"
