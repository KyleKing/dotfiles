#!/bin/bash -e

for cli in cs gotz lazygit shfmt; do
    echo "$cli $($cli --version)"
done
