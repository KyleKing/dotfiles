#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Tell me when the shared repos (chezmoi, nvim) have commits waiting to be pulled,
# or local commits sitting unpushed for 10+ minutes.
#
# Shell startup never runs git and never touches the network: it reads a cached
# answer and, if that answer is older than an hour, forks a detached refresh that
# does the fetching. Worst case a new shell reports an hour-old count.

_REPO_FRESHNESS_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/repo-freshness"
_REPO_FRESHNESS_MAX_AGE=3600
_REPO_FRESHNESS_UNPUSHED_AGE=900

# name:zoxide-query:path triples; obsidian is intentionally absent (see back-pull-obs)
_REPO_FRESHNESS_REPOS=(
    "ch:chezmoi:$HOME/.local/share/chezmoi"
    "nvim:nvim:$HOME/.config/nvim"
)

_repo-freshness-refresh() {
    mkdir -p "$_REPO_FRESHNESS_DIR"
    # Stamp before fetching so a hung or offline fetch can't retrigger on every new shell
    : >|"$_REPO_FRESHNESS_DIR/stamp"

    local entry name zquery dir rest behind ahead ahead_aged oldest_ts now
    local -a lines=()
    for entry in "${_REPO_FRESHNESS_REPOS[@]}"; do
        name="${entry%%:*}"
        rest="${entry#*:}"
        zquery="${rest%%:*}"
        dir="${rest#*:}"
        if [ ! -d "$dir/.git" ]; then
            continue
        fi
        if ! git -C "$dir" fetch --quiet --no-tags 2>/dev/null; then
            continue
        fi
        behind=$(git -C "$dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || continue
        ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null) || continue
        ahead_aged=0
        if [ "$ahead" -gt 0 ]; then
            oldest_ts=$(git -C "$dir" log --format=%ct '@{upstream}..HEAD' | tail -1)
            if [ -n "$oldest_ts" ]; then
                now=$(date +%s)
                ((now - oldest_ts >= _REPO_FRESHNESS_UNPUSHED_AGE)) && ahead_aged=1
            fi
        fi
        # Colors follow the oh-my-posh git segment: grey behind, orange ahead, red diverged
        if [ "$behind" -gt 0 ] && [ "$ahead_aged" -eq 1 ]; then
            lines+=("%F{1}$name ↓$behind ↑$ahead%f (z $zquery && git pull; z $zquery && git push)")
        elif [ "$behind" -gt 0 ]; then
            lines+=("%F{8}$name ↓$behind%f (z $zquery && git pull)")
        elif [ "$ahead_aged" -eq 1 ]; then
            lines+=("%F{3}$name ↑$ahead%f (z $zquery && git push)")
        fi
    done
    # printf still emits one blank line for a zero-arg "${lines[@]}", so guard it
    if [ "${#lines[@]}" -gt 0 ]; then
        printf '%s\n' "${lines[@]}" >|"$_REPO_FRESHNESS_DIR/behind"
    else
        : >|"$_REPO_FRESHNESS_DIR/behind"
    fi
}

_repo-freshness-read() {
    # Read $_REPO_FRESHNESS_DIR/behind into the "lines" array of the caller
    lines=()
    [ -r "$_REPO_FRESHNESS_DIR/behind" ] || return 0
    local line
    while IFS= read -r line; do
        lines+=("$line")
    done <"$_REPO_FRESHNESS_DIR/behind"
}

_repo-freshness-stale() {
    local -a st
    zmodload -F zsh/stat b:zstat 2>/dev/null || return 1
    zstat -A st +mtime "$_REPO_FRESHNESS_DIR/stamp" 2>/dev/null || return 0
    ((EPOCHSECONDS - st[1] > _REPO_FRESHNESS_MAX_AGE))
}

_repo-freshness-report() {
    # Not named "status": zsh reserves that as a read-only alias for $?
    local -a lines
    _repo-freshness-read
    if [ "${#lines[@]}" -gt 0 ]; then
        print -P "%F{yellow}repo freshness:%f"
        local line
        for line in "${lines[@]}"; do
            print -P "  $line"
        done
        print -P "  %F{8}(back-fresh-clear to recheck now)%f"
    fi
    if _repo-freshness-stale; then
        # Subshell exits at once, so the fetch is orphaned and outlives this shell
        (_repo-freshness-refresh >/dev/null 2>&1 &)
    fi
}

# Force a check now, ignoring the hourly window
back-fresh-clear() {
    _repo-freshness-refresh
    local -a lines
    _repo-freshness-read
    if [ "${#lines[@]}" -gt 0 ]; then
        printf '%s\n' "${lines[@]}"
    else
        echo "all repos up to date"
    fi
}

zmodload zsh/datetime 2>/dev/null
if [[ -o interactive ]]; then
    _repo-freshness-report
fi
