#!/bin/bash -e

for cli in cs gotz shfmt; do
    echo "$cli $($cli --version)"
done
