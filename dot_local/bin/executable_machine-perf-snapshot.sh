#!/usr/bin/env bash
# Read-only performance snapshot: load, top CPU/MEM processes, Docker VM
# allocation, and Firefox user.js state. Run before and after a tuning change
# (machine-perf-tune-firefox.sh, or a manual Docker Desktop resource edit),
# then diff the two output files. See docs/machine-performance-optimizations.md
# in the chezmoi source for the walkthrough this supports.
set -euo pipefail

out_dir="$HOME/.local/state/machine-perf/snapshots"
mkdir -p "$out_dir"
out_file="$out_dir/$(date '+%Y%m%d-%H%M%S').txt"

docker_settings="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
firefox_profiles_ini="$HOME/Library/Application Support/Firefox/profiles.ini"

{
  echo "=== machine-perf snapshot: $(date) ==="
  echo
  echo "--- load / cores ---"
  uptime
  echo "cores: $(sysctl -n hw.ncpu)"
  echo
  echo "--- top 15 by %CPU ---"
  ps aux -r | head -16 || true
  echo
  echo "--- top 15 by %MEM ---"
  ps aux -m | head -16 || true
  echo
  echo "--- Docker Desktop VM allocation ---"
  if [ -f "$docker_settings" ]; then
    python3 -c "
import json
with open('$docker_settings') as f:
    d = json.load(f)
print('Cpus =', d.get('Cpus'))
print('MemoryMiB =', d.get('MemoryMiB'))
"
  else
    echo "settings-store.json not found at $docker_settings"
  fi
  echo
  echo "--- Firefox user.js (default-release profile) ---"
  if [ -f "$firefox_profiles_ini" ]; then
    profile_rel=$(grep '^Path=' "$firefox_profiles_ini" | cut -d= -f2- | grep 'default-release$' | head -1)
    profile_dir="$HOME/Library/Application Support/Firefox/$profile_rel"
    user_js="$profile_dir/user.js"
    if [ -n "$profile_rel" ] && [ -f "$user_js" ]; then
      echo "profile: $profile_dir"
      cat "$user_js"
    else
      echo "no user.js present for the default-release profile"
    fi
  else
    echo "profiles.ini not found at $firefox_profiles_ini"
  fi
} >"$out_file"

echo "$out_file"
