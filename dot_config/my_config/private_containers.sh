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

# Helpers for quickly reviewing what is deployed to the specified environment
first-pod() {
    # Use with: first-pod reviewer
    _search=$1
    if [[ -z "$_search" ]]; then
        echo "The search strings must be specified. Expected: 'first-pod ...'"
        return 1
    else
        _match=$(kubectl get pods -o json | jq ".items[].metadata.name" | grep --max-count=1 "$_search")
        if [[ -z "$_match" ]]; then
            kubectl get pods
            echo "Failed to find a match. Ensure that you set a namespace"
            return 1
        else
            echo "$_match"
        fi
    fi
}
desc-first-pod() {
    # Use with: desc-first-pod reviewer
    first-pod "$1" | xargs kubectl describe pods
}
current-img() {
    # Use with: desc-first-pod reviewer
    desc-first-pod "$1" | grep "Image:" | awk -F '  +' '{print $3}'
}
