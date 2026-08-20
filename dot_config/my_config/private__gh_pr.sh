#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Add GitHub PR Number to Oh-My-Posh

_gh_pr_precmd() {
  # Disable job control for this call only, so the disowned background
  # fetch below doesn't print a "[N] PID" line into the prompt.
  setopt localoptions nomonitor

  local tracking_ref
  tracking_ref=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [[ -z "$tracking_ref" ]]; then
    export GH_PR_NUMBER=""
    return
  fi

  local remote_name="${tracking_ref%%/*}"

  local remote_url
  remote_url=$(git remote get-url "$remote_name" 2>/dev/null)
  if [[ -z "$remote_url" ]]; then
    export GH_PR_NUMBER=""
    return
  fi

  local cache_key
  cache_key=$(printf '%s:%s' "$remote_url" "$tracking_ref" | shasum -a 256 | awk '{print $1}')

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/gh_pr"
  local cache_file="$cache_dir/$cache_key"
  local lock_file="$cache_dir/$cache_key.lock"

  GH_PR_NUMBER="$(cat "$cache_file" 2>/dev/null)"
  export GH_PR_NUMBER

  # A lock outliving its fetch (killed shell, disowned job reaped, sleep) would
  # block refreshes forever, so treat it as orphaned past this age.
  if [[ -f "$lock_file" ]] && [[ -n "$(find "$lock_file" -mmin +1 2>/dev/null)" ]]; then
    rm -f "$lock_file"
  fi

  local stale=0
  if [[ ! -f "$cache_file" ]] || [[ -n "$(find "$cache_file" -mmin +5 2>/dev/null)" ]]; then
    stale=1
  fi

  if [[ "$stale" -eq 1 ]] && [[ ! -f "$lock_file" ]]; then
    mkdir -p "$cache_dir"
    touch "$lock_file"
    (
      local pr_number
      pr_number=$(gh pr view --json number --jq '.number' 2>/dev/null)
      printf '%s' "$pr_number" > "$cache_file"
      rm -f "$lock_file"
    ) & disown
  fi
}

# A precmd hook lands after oh-my-posh renders PS1, lagging the number by a
# prompt. Must be sourced after `oh-my-posh init`.
set_poshcontext() {
  _gh_pr_precmd
}
