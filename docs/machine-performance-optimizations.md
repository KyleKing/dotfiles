# Machine performance optimizations

Notes from a slowdown investigation on 2026-08-13, plus the repeatable steps that came
out of it.
Load average was 16.5 against 12 cores: more runnable work than the machine
has cores for.
Two things accounted for most of it.

## Docker Desktop's VM

Docker Desktop's Linux VM (`com.apple.Virtualization.VirtualMachine`) was configured for
10 CPUs and 12GB (`~/Library/Group Containers/group.com.docker/settings-store.json`,
`Cpus` / `MemoryMiB`).
That's most of a 12-core, 24GB machine reserved for the VM
whether or not containers are actually busy.

Target: 6 CPUs / 8GB, which comfortably covers the IRM compose stack
(api + workers + orchestrator + Postgres) and leaves half the machine for everything
else.

Check current vs target:

```sh
machine-perf-docker-diff.sh
```

Apply (manual, on purpose — see below):

1. Docker Desktop → Settings → Resources → Advanced
1. Set CPUs to 6, Memory to 8 GB
1. Apply & Restart

This resizes the VM, which stops any running containers (`dev-api`, `dev-workers`,
etc.) for the duration of the restart.
There's no scripted path that edits
`settings-store.json` directly: Docker Desktop rewrites that file on its own settings
changes and on quit, so an external edit either gets clobbered or requires quitting the
app out from under whatever it's doing.
The GUI path is the one Docker actually
supports.

Rollback: same panel, back to 10 CPUs / 12GB, Apply & Restart.

## Firefox

A long-running Firefox session (~20 tabs) had grown to several GB.
Firefox has its own
tooling for finding the culprit before touching anything:

- **`about:processes`** — Firefox's task manager.
    Because Fission isolates sites into
    separate processes, sort by memory and you can usually see the biggest process's tab
    and thus reload/close.
- **`about:memory`** — click **Measure**, then **Minimize memory usage** and see how much
    frees.
    If it drops a lot, it was reclaimable; if not, something's genuinely holding
    references.
- **Troubleshoot Mode** (Menu → Help → Troubleshoot Mode) rules extensions and custom
    prefs in or out in one step.

The common leakers are heavy single-page apps left open for hours (Gmail, Docs/Sheets,
Slack, Discord, Figma, Notion, long AI-chat threads, live dashboards) — reloading the
worst offender is usually the fastest fix.

Two prefs are worth setting permanently regardless of what's leaking today:

- `browser.tabs.unloadOnLowMemory` (true) — lets Firefox auto-drop idle background tabs
    under memory pressure instead of letting them accumulate.
- `browser.cache.memory.capacity` (512000 KB) — caps the in-memory cache instead of
    leaving it at the default "automatic but generous" sizing.

Applied via a marked block in `user.js` on the `default-release` profile (the one
actually in daily use), so a stray hand edit above or below the block survives a rerun:

```sh
machine-perf-tune-firefox.sh
```

The script backs up any existing `user.js` to `user.js.bak-<timestamp>` in the same
profile directory before writing.
Firefox needs a full restart (all windows closed) to
pick up `user.js` changes — the script never touches the running process.

Rollback: restore the most recent `user.js.bak-*` over `user.js`, or delete the
`# BEGIN machine-perf-tune` / `# END machine-perf-tune` block by hand, then restart
Firefox.

## Other overhead worth knowing about

- **Multiple concurrent `claude` CLI sessions.** Each holds MCP connections and renders
    output continuously, at 2-7% CPU and 300-550MB RSS even idle.
    Closing panes that
    aren't actively being driven is the cheapest win available.
- **Electron apps (Slack, Linear, Notion).** Each spawns 3-5 helper processes at
    150-400MB apiece just for being open.
    Quit what isn't in active use.

No script for either of these — just close what you're not using.

## Before/after snapshots

`machine-perf-snapshot.sh` captures load average, the top 15 processes by CPU and by
memory, the current Docker VM allocation, and the Firefox `user.js` state, to a
timestamped file under `~/.local/state/machine-perf/snapshots/`.
Run it before a change
and again after, then `diff` the two files:

```sh
before=$(machine-perf-snapshot.sh)
# ... make a change (resize Docker, restart Firefox) ...
after=$(machine-perf-snapshot.sh)
diff "$before" "$after"
```
