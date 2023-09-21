#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Add global go modules to PATH

GOPATH="$(go env GOPATH)"
export PATH="$PATH:$GOPATH/bin"

# Install gotz with: go install github.com/merschformann/gotz@latest
