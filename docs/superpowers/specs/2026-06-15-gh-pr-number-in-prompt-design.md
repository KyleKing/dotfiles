# PR Number in Oh My Posh Right Prompt

## Goal

Display the GitHub PR number for the current branch in the right prompt. Zero latency on every prompt; correct invalidation when switching remote branches; cache shared across directories for the same remote branch.

## Approach

Shell `precmd` hook computes the PR number before each prompt and exports it as `GH_PR_NUMBER`. Oh My Posh reads the env var — no OMP-level caching needed.

## Files Changed

| File                                                | Change                             |
| --------------------------------------------------- | ---------------------------------- |
| `dot_config/my_config/private__gh_pr.sh`            | New — precmd hook function         |
| `private_dot_zshrc.tmpl`                            | Add `source $MY_CONFIG/_gh_pr.sh`  |
| `dot_config/oh-my-posh/private_dot_config.omp.json` | Add `text` segment to right prompt |

## Cache Design

- **Location:** `~/.cache/gh_pr/<key>` (plain text: PR number or empty string)
- **Lock file:** `~/.cache/gh_pr/<key>.lock` (prevents concurrent background jobs)
- **Cache key:** `sha256(remote_url:tracking_ref)` where `tracking_ref` is the upstream tracking ref (e.g. `origin/feature-xyz`)
- **TTL:** 5 minutes, checked via file mtime
- **Sharing:** same remote branch checked out in two directories hits the same cache entry

## `_gh_pr_precmd` Logic

1. Get tracking ref: `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`
    - If empty or fails: `GH_PR_NUMBER=""`, return
1. Extract remote name from tracking ref (part before first `/`)
1. Get remote URL: `git remote get-url <remote> 2>/dev/null`
1. Compute cache key: `printf '%s:%s' "$remote_url" "$tracking_ref" | shasum -a 256 | cut -d' ' -f1`
1. **Read cache immediately** → `export GH_PR_NUMBER="$(cat "$cache_file" 2>/dev/null)"`
1. If cache is absent or stale (mtime > 5 min) and no lock file exists:
    - Create lock file
    - Spawn detached background subshell (`(... ) &!`):
        - Run `gh pr view --json number --jq '.number' 2>/dev/null`
        - On success: write number to cache file
        - On failure (no PR): write empty string to cache file
        - Remove lock file

Stale-while-revalidate: after a branch switch, the previous value shows for one prompt, then the background job updates the cache and subsequent prompts are correct.

## OMP Segment

Added to right prompt between `project` and `time`:

```json
{
  "type": "text",
  "style": "plain",
  "foreground": "p:blue",
  "background": "transparent",
  "template": "{{ if .Env.GH_PR_NUMBER }}#{{ .Env.GH_PR_NUMBER }} {{ end }}"
}
```

## Non-Goals

- No OMP-level segment cache (env var is set before OMP renders)
- No support for repos with no remote or detached HEAD (silently shows nothing)
- No streaming/async OMP segments (experimental, not production-ready)
