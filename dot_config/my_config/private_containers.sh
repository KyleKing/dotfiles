#!/bin/bash
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Configuration for working with containers (Kube, Docker, etc.)

# Source: https://github.com/jesseduffield/lazydocker
alias lzd='lazydocker'

# FYI: Found that podman can't fully replace Docker yet
# # Replace docker with Podman: https://podman.io/getting-started/
# alias docker=podman
# alias docker-compose=podman-compose

# Configure the Krew plugin manager for kubectl
export PATH="${PATH}:${HOME}/.krew/bin"
