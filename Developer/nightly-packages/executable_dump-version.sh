#!/bin/bash -e

for cli in cs gotz lazygit shfmt superfile; do
    echo "$cli $($cli --version)"
done
