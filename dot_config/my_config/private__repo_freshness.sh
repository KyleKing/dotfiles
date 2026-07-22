#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Tell me when the shared repos (chezmoi, nvim) have commits waiting to be pulled.
#
# Shell startup never runs git and never touches the network: it reads a cached
# answer and, if that answer is older than an hour, forks a detached refresh that
# does the fetching. Worst case a new shell reports an hour-old count.

_REPO_FRESHNESS_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/repo-freshness"
_REPO_FRESHNESS_MAX_AGE=3600

# name:path pairs; obsidian is intentionally absent (see back-pull-obs)
_REPO_FRESHNESS_REPOS=(
    "ch:$HOME/.local/share/chezmoi"
    "nvim:$HOME/.config/nvim"
)

_repo-freshness-refresh() {
    mkdir -p "$_REPO_FRESHNESS_DIR"
    # Stamp before fetching so a hung or offline fetch can't retrigger on every new shell
    : >|"$_REPO_FRESHNESS_DIR/stamp"

    local entry name dir behind
    local out=""
    for entry in "${_REPO_FRESHNESS_REPOS[@]}"; do
        name="${entry%%:*}"
        dir="${entry#*:}"
        if [ ! -d "$dir/.git" ]; then
            continue
        fi
        if ! git -C "$dir" fetch --quiet --no-tags 2>/dev/null; then
            continue
        fi
        behind=$(git -C "$dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || continue
        if [ "$behind" -gt 0 ]; then
            out="$out $name +$behind"
        fi
    done
    printf '%s\n' "${out# }" >|"$_REPO_FRESHNESS_DIR/behind"
}

_repo-freshness-stale() {
    local -a st
    zmodload -F zsh/stat b:zstat 2>/dev/null || return 1
    zstat -A st +mtime "$_REPO_FRESHNESS_DIR/stamp" 2>/dev/null || return 0
    ((EPOCHSECONDS - st[1] > _REPO_FRESHNESS_MAX_AGE))
}

_repo-freshness-report() {
    local behind=""
    if [ -r "$_REPO_FRESHNESS_DIR/behind" ]; then
        read -r behind <"$_REPO_FRESHNESS_DIR/behind"
    fi
    if [ -n "$behind" ]; then
        print -P "%F{yellow}behind upstream:%f $behind %F{8}(back-pull-all)%f"
    fi
    if _repo-freshness-stale; then
        # Subshell exits at once, so the fetch is orphaned and outlives this shell
        (_repo-freshness-refresh >/dev/null 2>&1 &)
    fi
}

# Force a check now, ignoring the hourly window
back-stale-all() {
    _repo-freshness-refresh
    local behind=""
    if [ -r "$_REPO_FRESHNESS_DIR/behind" ]; then
        read -r behind <"$_REPO_FRESHNESS_DIR/behind"
    fi
    printf '%s\n' "${behind:-all repos up to date}"
}

zmodload zsh/datetime 2>/dev/null
if [[ -o interactive ]]; then
    _repo-freshness-report
fi
