#!/usr/bin/env bash
# Show who holds the heavy-job slots and the Docker lock, and who is queued: elapsed, checkout, command.
set -euo pipefail
dir="$(getconf DARWIN_USER_TEMP_DIR)"
holders=$(for f in "$dir"pr-pass-heavy*.lock; do
  open=$(lsof -t "$f" 2>/dev/null || true)
  pid=$(cat "$f" 2>/dev/null || true)
  # The legacy lockf wrapper writes no pid, but it only has the file open while holding it.
  grep -qx "${pid:-x}" <<<"$open" || pid=$(pgrep -f "lockf -k $f" | grep -xF "$open" | head -1 || true)
  [ -n "$pid" ] && echo "$pid $(basename "$f" .lock | sed 's/^pr-pass-heavy//; s/^$/.0/; s/^\.//')"
done || true)
for pid in $(pgrep -f "scripts/heavy.py|lockf -k ${dir}pr-pass-heavy" || true); do
  cwd=$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p')
  held=$(awk -v p="$pid" '$1==p {printf "%s%s", sep, $2; sep=","}' <<<"$holders")
  role=$([ -n "$held" ] && echo "HOLDS $held" || echo waits)
  printf '%-14s %8s %-14s %s\n' "$role" "$(ps -o etime= -p "$pid" | tr -d ' ')" "$(basename "$cwd")" \
    "$(ps -o command= -p "$pid" | sed -E 's|.*(heavy\.py\|\.lock) ||' | cut -c1-110)"
done
