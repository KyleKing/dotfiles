# Remote access / git-SSH: open items

Not-yet-built ideas, plus the incident that motivates them. See
[remote-access-quickref.md](remote-access-quickref.md) for the current working setup.

## Incident: SSH auth/signing breaks in a non-interactive shell (2026-07-08, `mdformat-plugin-template`)

Reconstructed from session `8fac90f4` (`~/Developer/kyleking/mdformat-plugin-template`): an agent
needed to fetch/rebase/push and hit `git@github.com: Permission denied (publickey)`. Root cause
chain:

1. No live `ssh-agent` in the shell's env (`ssh-add -l` → "Error connecting to agent").
2. Found the real agent socket via `launchctl list | grep ssh` /
   `launchctl print gui/$(id -u)/com.openssh.ssh-agent` — this is exactly the lookup
   `dot_config/my_config/private__mac.sh`'s `SSH_AUTH_SOCK` snippet now automates for new panes.
3. Even after exporting the correct `SSH_AUTH_SOCK`, `ssh-add -l` **timed out** — the key
   (`~/.ssh/id_ed25519_github_2026`) is passphrase-protected, and a non-interactive/sandboxed
   shell has no TTY for `ssh-add` to prompt on. This is the actual blocker, not a config bug: an
   agentic/CI-style shell can't unlock a passphrase-protected key it doesn't already hold.
4. Workaround: switch to `gh`'s HTTPS auth instead of fixing the SSH agent — `gh auth setup-git`
   (wires `gh` as the credential helper) + `git remote set-url origin
   https://github.com/<owner>/<repo>.git`. This was the "toggle SSH → HTTPS" recalled after the
   fact — a per-repo, one-off `git remote set-url`, not a chezmoi/global config change.
5. Commit **signing** hit the identical root cause (SSH-format signing also needs the same
   passphrase-locked agent) when rebasing — resolved per-command with explicit approval via
   `git rebase --no-gpg-sign` / `git commit --no-gpg-sign`, not by disabling `commit.gpgsign`
   globally.
6. Separately, GitHub's username casing had changed (`kyleking` → `KyleKing`), so the remote was
   updated a second time to the canonical-cased HTTPS URL to avoid a redirect warning.

**Takeaway**: this isn't a persistent problem with the gitconfig (still fully correct — see
quickref), it's what happens when a non-interactive shell needs a passphrase-locked SSH agent
that was never unlocked interactively in that session. Two real mitigations: (a) use a
passphrase-less key or keychain-backed agent (`ssh-add --apple-use-keychain`, already in
`README.md` step 2) so `ssh-add -l` never blocks on a prompt, or (b) accept HTTPS-via-`gh` as the
deliberate fallback for agentic/non-interactive shells specifically, while interactive/human
sessions stay on SSH.

## Idea: SSH-preferred health check

Before reaching for HTTPS, first *verify* whether SSH is actually broken vs. just needing the
right `SSH_AUTH_SOCK` exported (per the incident above, step 2 alone would have fixed it without
falling back at all) — a cheap `ssh -T git@github.com` / `ssh-add -l` probe, prefer-SSH-if-healthy
check that runs before any toggle logic. This closes the gap between "SSH looks broken" and
"SSH is broken" so the fallback only fires for the real passphrase/TTY case, not a fixable
`SSH_AUTH_SOCK` miss.

## Idea: a toggle/fallback helper

Worth a small tool rather than hand-run `git remote set-url` each time: detect current remote
scheme, run the SSH health check above, and only then swap
`git@github.com:owner/repo.git` ↔ `https://github.com/owner/repo.git` (+ `gh auth setup-git` for
the HTTPS credential helper). Two placement options worth weighing, and the health check applies
to either:

- **A standalone zsh/bash function** in `dot_config/my_config/` — fits the existing
  alias/function pattern in `private__mac.sh`, but is single-machine/manual-invoke only.
- **A `gh` extension** — natural fit for `gh-repo-dashboard` if that project ends up needing
  per-repo remote-health/auth-state visibility anyway, since it would already be iterating over
  repos and could surface "SSH auth broken, fell back to HTTPS" (or "SSH healthy, no fallback
  needed") as a dashboard signal rather than a silent one-off fix.

Not yet decided which; revisit once `gh-repo-dashboard` scope is clearer.
