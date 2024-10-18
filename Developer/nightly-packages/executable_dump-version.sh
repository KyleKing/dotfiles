#!/bin/bash -e

for cli in gotz shfmt; do
    echo "$cli $($cli --version)"
done
