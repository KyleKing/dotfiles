#!/usr/bin/env bash
# Idempotently sets the memory-related Firefox prefs recommended in
# docs/machine-performance-optimizations.md (chezmoi source) on the
# default-release profile, via a marked block in that profile's user.js.
# Backs up any existing user.js first. Does not touch a running Firefox
# process -- a full restart (all windows closed) is required to pick up
# user.js changes.
set -euo pipefail

begin_marker="# BEGIN machine-perf-tune"
end_marker="# END machine-perf-tune"

profiles_ini="$HOME/Library/Application Support/Firefox/profiles.ini"
if [ ! -f "$profiles_ini" ]; then
  echo "profiles.ini not found at $profiles_ini" >&2
  exit 1
fi

candidates=$(grep '^Path=' "$profiles_ini" | cut -d= -f2- | grep 'default-release$' || true)
candidate_count=$(printf '%s' "$candidates" | grep -c . || true)

if [ "$candidate_count" -eq 0 ]; then
  echo "no default-release profile found in $profiles_ini" >&2
  exit 1
fi
if [ "$candidate_count" -gt 1 ]; then
  echo "multiple default-release profiles found, refusing to guess:" >&2
  printf '%s\n' "$candidates" >&2
  exit 1
fi

profile_dir="$HOME/Library/Application Support/Firefox/$candidates"
user_js="$profile_dir/user.js"

if [ ! -d "$profile_dir" ]; then
  echo "resolved profile dir does not exist: $profile_dir" >&2
  exit 1
fi

block=$(
  cat <<EOF
$begin_marker
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("browser.cache.memory.capacity", 512000);
$end_marker
EOF
)

before=""
[ -f "$user_js" ] && before=$(cat "$user_js")

if [ -f "$user_js" ]; then
  backup="$user_js.bak-$(date '+%Y%m%d-%H%M%S')"
  cp "$user_js" "$backup"
  echo "backed up existing user.js to $backup"
fi

if [ -f "$user_js" ]; then
  sed -e "/^${begin_marker}\$/,/^${end_marker}\$/d" "$user_js" >"$user_js.tmp"
else
  : >"$user_js.tmp"
fi
printf '%s\n' "$block" >>"$user_js.tmp"
mv "$user_js.tmp" "$user_js"

echo "profile: $profile_dir"
echo "--- diff ---"
diff <(printf '%s\n' "$before") "$user_js" || true
echo "------------"
echo "Restart Firefox (all windows closed) for these prefs to take effect."
