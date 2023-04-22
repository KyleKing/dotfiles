#!/bin/bash -e

original_dir=$PWD
for pth in gotz lazygit "sh/cmd/shfmt"; do echo "Upgrading $pth" && cd "$pth" && git pull && go install . && cd "$original_dir"; done
