# Remote access: quick reference

What's actually installed and how it's used. Background/alternatives-considered are in
[remote-access-research.md](remote-access-research.md); open items are in
[remote-access-todo.md](remote-access-todo.md).

## The pieces

| Tool | Role | Installed via |
| --- | --- | --- |
| Tailscale | Mesh VPN (WireGuard). Gives every device a stable IP/hostname (MagicDNS) that survives network changes, so you don't depend on the target's public IP or port-forwarding. This is the transport layer everything else rides on. | `brew "tailscale"` (daemon) + `cask "tailscale-app"` (menu bar UI) |
| RustDesk | Self-hosted-capable remote desktop (GUI control), an open-source alternative to TeamViewer/AnyDesk. GUI fallback for when SSH can't reach what you need. | `cask "rustdesk"` |
| Termius | Cross-platform SSH/mosh client with synced hosts and keys. Also provides "SSH ID" (`sshid.io`), a device-bound passkey for SSH auth. | `mas "Termius", id: 1176074088` |
| KeepingYouAwake | Menu-bar caffeinate wrapper; prevents the Mac from sleeping so it stays reachable for the above. A sleeping Mac drops SSH, VNC, and screen-sharing alike. | `cask "keepingyouawake"` |

Termius's "SSH ID" feature (`https://sshid.io/<handle>`) publishes device-bound public keys
(Face ID/Touch ID-gated, private key never leaves the device) at a stable URL — point a new
host's `authorized_keys` at that URL instead of copying key files around.

## How it all combines

1. **Tailscale** is the linchpin network layer everything else rides on.
2. **KeepingYouAwake** keeps the target Mac reachable — toggle it on the machine you intend to
   *reach*, not the client.
3. SSH to the Mac's MagicDNS hostname, attach a **tmux**/**sesh** session (see
   `dot_config/sesh/sesh.toml` — SSH targets are just named `sesh` sessions with a
   `startup_command`, fuzzy-picked with `<prefix> s` in tmux or `sz` in the shell; see
   `hetzner-demo` in `sesh.toml`), run lazygit/Claude Code/pytest/pre-commit inside it so work
   survives disconnects.
4. **Termius** is the mobile client driving that SSH session.
5. **RustDesk** is the occasional full-screen GUI fallback, over Tailscale for a private
   connection instead of the public RustDesk relay.

## Git over SSH (signing + auth)

`private_dot_gitconfig.tmpl` is configured for SSH-based commit signing, not GPG:

```
[commit]
    gpgsign = true
[gpg]
    format = ssh
[gpg "ssh"]
    allowedSignersFile = {{ .chezmoi.homeDir }}/.ssh/allowed_signers
```

The signing key itself comes from `{{ .github.ssh_public_key }}` (populated by
`~/.config/chezmoi/update-config.sh`, see `README.md`). This is the same SSH key used for both
GitHub authentication (`git@github.com:...` remotes) and commit signing — no separate GPG key.
`chezmoi init` and all `mani.yaml` projects use `git@github.com:...` SSH remotes exclusively (see
`README.md` step 2/3); there's no HTTPS fallback configured here.

If commits ever fail to sign, it's almost always one of:

- `~/.ssh/allowed_signers` missing/stale (regenerate from `gh ssh-key list` or the key file)
- the key not loaded in the agent (`ssh-add -l`; see the `SSH_AUTH_SOCK` pickup in
  `dot_config/my_config/private__mac.sh`, which reattaches panes in stale tmux sessions to the
  live `launchctl`-managed `ssh-agent` socket)
- GitHub's registered signing key not matching the local key (`gh ssh-key add ... --type signing`)
- the shell is non-interactive and the key is passphrase-protected — see the incident and open
  items in [remote-access-todo.md](remote-access-todo.md)
