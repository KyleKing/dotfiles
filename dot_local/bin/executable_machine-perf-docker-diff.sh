#!/usr/bin/env bash
# Read-only: reports Docker Desktop's current VM CPU/memory allocation
# against the documented target, without touching settings-store.json.
# Docker Desktop rewrites that file on its own settings changes and on quit,
# so the resize itself stays manual: Docker Desktop -> Settings -> Resources.
# See docs/machine-performance-optimizations.md in the chezmoi source.
set -euo pipefail

target_cpus=6
target_memory_mib=8192

docker_settings="$HOME/Library/Group Containers/group.com.docker/settings-store.json"

if [ ! -f "$docker_settings" ]; then
  echo "settings-store.json not found at $docker_settings" >&2
  exit 1
fi

python3 -c "
import json
with open('$docker_settings') as f:
    d = json.load(f)
cpus = d.get('Cpus')
memory_mib = d.get('MemoryMiB')
print(f'current: {cpus} CPUs / {memory_mib} MiB')
print(f'target:  $target_cpus CPUs / $target_memory_mib MiB')
if cpus == $target_cpus and memory_mib == $target_memory_mib:
    print('already at target')
else:
    print()
    print('To apply: Docker Desktop -> Settings -> Resources -> Advanced,')
    print(f'set CPUs to $target_cpus and Memory to {$target_memory_mib / 1024:.0f} GB, then Apply & Restart.')
"
