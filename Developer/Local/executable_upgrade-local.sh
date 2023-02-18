#!/bin/bash -e

cd gotz
git pull && go install .
cd ..

cd lazygit
git pull && go install .
cd ..
