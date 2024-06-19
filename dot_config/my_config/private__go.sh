#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Add global go modules to PATH

# Note: go CLI packages are managed in nightly-packages by mani
GOPATH="$(go env GOPATH)"
export PATH="$PATH:$GOPATH/bin"
