#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Size-gated cache cleanup: a cache is only worth clearing once it's grown
# past a size worth reclaiming. Each entry below only gets swept when it
# crosses its own threshold, so caches stay warm day-to-day and only get
# cleaned when they're actually wasting disk.
#
# Run "cache-status" any time to see current sizes vs. thresholds.
# Run "cache-sweep" to clean whatever is currently over threshold (add
# --dry-run to preview, --all to ignore thresholds and clean everything).
#
# Some tools (mise, conda) already know which of their own files are unused
# and safe to remove, so pruning them doesn't need a size threshold. Run
# "cache-prune" (--dry-run to preview) to run those.

# path|threshold_GiB|cleanup_command
CACHE_SWEEP_TARGETS=(
    "$HOME/Library/Caches/Homebrew|10|brew cleanup -s"
    "$HOME/.bun/install/cache|5|bun pm cache rm"
    "$HOME/go/pkg/mod|5|go clean -modcache"
    "$HOME/.cache/uv|10|uv cache clean"
    "$HOME/Library/pnpm/store|5|pnpm store prune"
    "$HOME/Library/Caches/mise|2|mise cache clear"
    "$HOME/Library/Caches/com.spotify.client|3|pgrep -qx Spotify || rm -rf $HOME/Library/Caches/com.spotify.client"
    "$HOME/.cache/prek|1|prek cache gc"
    "/private/tmp/node-compile-cache|1|rm -rf /private/tmp/node-compile-cache"
    "$HOME/Library/Caches/pip|2|pip cache purge"
    "$HOME/.npm|2|npm cache clean --force"
    "$HOME/Library/Caches/Yarn|2|yarn cache clean"
    "$HOME/.cache/pre-commit|1|pre-commit clean"
    "$HOME/Library/Caches/node-gyp|1|rm -rf $HOME/Library/Caches/node-gyp"
    "$HOME/Library/Caches/go-build|2|go clean -cache"
    "$HOME/Library/Caches/pypoetry|1|rm -rf $HOME/Library/Caches/pypoetry"
    "$HOME/Library/Caches/deno|2|rm -rf $HOME/Library/Caches/deno"
    "$HOME/Library/Developer/Xcode/DerivedData|2|rm -rf $HOME/Library/Developer/Xcode/DerivedData"
    # Left at high thresholds and a manual command since these hold data you
    # may still want (downloaded models), not pure rebuild-cache.
    "$HOME/.cache/huggingface|20|huggingface-cli delete-cache"
)

# Tools whose own prune command already knows what's safe to remove (unused
# mise tool versions, untracked conda package tarballs) — no size threshold
# needed, just run them.
CACHE_PRUNE_COMMANDS=(
    "mise prune --yes"
    "conda clean --all -y"
)

_cache-du-gib() {
    # Print size of $1 in whole GiB (0 if the path doesn't exist)
    [ -d "$1" ] || { echo 0; return; }
    du -sg "$1" 2>/dev/null | cut -f1
}

cache-status() {
    printf "%-42s %10s %10s\n" "CACHE" "SIZE(GiB)" "THRESHOLD"
    for entry in "${CACHE_SWEEP_TARGETS[@]}"; do
        # NOTE: don't name this var "path" - zsh ties that name to $PATH
        IFS='|' read -r cache_path threshold _cmd <<<"$entry"
        printf "%-42s %10s %10s\n" "$cache_path" "$(_cache-du-gib "$cache_path")" "$threshold"
    done
}

cache-sweep() {
    # Clean only the caches that have grown past their threshold.
    local dry=false all=false
    for arg in "$@"; do
        [ "$arg" = "--dry-run" ] && dry=true
        [ "$arg" = "--all" ] && all=true
    done
    for entry in "${CACHE_SWEEP_TARGETS[@]}"; do
        IFS='|' read -r cache_path threshold cmd <<<"$entry"
        size=$(_cache-du-gib "$cache_path")
        if [ "$all" = true ] || [ "$size" -ge "$threshold" ]; then
            echo "==> [${size}GiB >= ${threshold}GiB] $cache_path: $cmd"
            if [ "$dry" = false ]; then
                eval "$cmd"
            fi
        fi
    done
    true
}

cache-prune() {
    local dry=false
    [ "$1" = "--dry-run" ] && dry=true
    for cmd in "${CACHE_PRUNE_COMMANDS[@]}"; do
        echo "==> $cmd"
        if [ "$dry" = false ]; then
            eval "$cmd"
        fi
    done
}

TEMP_SWEEP_MAX_AGE_DAYS=3

_temp-stale-entries() {
    local tmp="${TMPDIR:-/tmp}" entry
    tmp="${tmp%/}"
    {
        find "$tmp" /private/tmp -mindepth 1 -maxdepth 1 \( -name 'go-build*' -o -name 'npm-*' \
            -o -name 'pip-*' -o -name 'playwright*' -o -name 'pytest-of-*' -o -name 'tmp*' \
            -o -name 'watchdoggo-*' \) 2>/dev/null
        find /private/tmp/claude-501 -mindepth 2 -maxdepth 2 2>/dev/null
    } | while IFS= read -r entry; do
        # Stale means nothing inside changed within the window, so live sessions are never touched
        [ -z "$(find "$entry" -mtime "-$TEMP_SWEEP_MAX_AGE_DAYS" -print -quit 2>/dev/null)" ] && echo "$entry"
    done
}

temp-sweep() {
    local dry=false total_kb=0 kb entry
    [ "$1" = "--dry-run" ] && dry=true
    while IFS= read -r entry; do
        kb=$(du -sk "$entry" 2>/dev/null | cut -f1)
        total_kb=$((total_kb + ${kb:-0}))
        echo "==> $((${kb:-0} / 1024))MiB $entry"
        [ "$dry" = true ] || rm -rf "$entry"
    done < <(_temp-stale-entries)
    echo "$((total_kb / 1024))MiB stale (older than ${TEMP_SWEEP_MAX_AGE_DAYS}d)"
}

BROWSER_PRUNE_DAYS=30
BROWSER_CACHES=("$HOME/Library/Caches/ms-playwright" "$HOME/Library/Caches/camoufox")
BROWSER_CACHES_DEEP=("$HOME/.cache/puppeteer")

browser-prune() {
    # Browser versions change too often to keep: clear monthly, or now with --deep (adds puppeteer)
    local dry=false deep=false stamp="$HOME/.local/state/cache-cleanup/browser-prune" dir targets
    for arg in "$@"; do
        [ "$arg" = "--dry-run" ] && dry=true
        [ "$arg" = "--deep" ] && deep=true
    done
    if [ "$deep" = false ] && [ -n "$(find "$stamp" -mtime "-$BROWSER_PRUNE_DAYS" 2>/dev/null)" ]; then
        echo "browser caches cleared within ${BROWSER_PRUNE_DAYS}d, use --deep to force"
        return
    fi
    targets=("${BROWSER_CACHES[@]}")
    [ "$deep" = true ] && targets+=("${BROWSER_CACHES_DEEP[@]}")
    for dir in "${targets[@]}"; do
        echo "==> $dir"
        [ "$dry" = true ] || rm -rf "$dir"
    done
    [ "$dry" = true ] || { mkdir -p "${stamp%/*}" && touch "$stamp"; }
}

docker-prune() {
    # Explicit only: not part of bcbd-deep, so Docker is never touched implicitly
    docker system df
    docker builder prune -f --filter "until=168h"
    docker image prune -af --filter "until=168h"
}

alias cs='cache-status'
alias csweep='cache-sweep'
# Full post-upgrade routine: upgrade, drop unused deps, brew cleanup/doctor, then
# sweep any dev-tool cache that's grown past its threshold, prune unused
# mise tool versions / conda package tarballs, clear browser caches monthly, and clear
# stale temp dirs.
alias bcbd-deep='brew upgrade && brew autoremove && bcbd && cache-sweep && cache-prune && browser-prune && temp-sweep'
