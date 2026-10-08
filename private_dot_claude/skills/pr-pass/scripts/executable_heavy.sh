#!/usr/bin/env bash
# Usage: heavy.sh <command> [args...]   (waits for a heavy-job slot; exits with the command's status)
set -euo pipefail
exec python3 "$(dirname "$0")/heavy.py" "$@"
