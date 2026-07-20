# Remote access research: options considered

Background research behind [remote-access-quickref.md](remote-access-quickref.md) — why each
tool was picked, and the alternatives that were evaluated and rejected. Distilled from a
2026-07-07 research chat ("Remote controlling Mac from iPhone over internet"), which ran a
210-source comparison report. Not needed day-to-day; keep for re-evaluating later.

## Why terminal-first beats full remote-desktop

Full remote-desktop apps (macOS Screen Sharing/VNC, Jump Desktop, Screens 5, Chrome Remote
Desktop, NoMachine, TeamViewer/AnyDesk, Parsec) and BetterTouchTool's BTT Remote were evaluated
and rejected as the *primary* tool:

- **BTT Remote is confirmed LAN-only** by the vendor's own App Store description ("Your iPhone
  must be in the same WiFi network as your Mac") — Bonjour local-network discovery only, no
  internet path, no relay. Not usable off-network regardless of Tailscale.
- **Full-desktop apps have degraded iOS keyboard handling** (missing modifiers/function keys),
  which makes real terminal work (lazygit, Claude Code, pytest, pre-commit) painful. SSH clients
  render text natively with full external-keyboard support instead.
- Terminal-first over SSH is also faster, crisper, and more battery-efficient than pushing
  pixels over VNC/RDP.

Kept for occasional full-screen GUI fallback (see quickref): free macOS Screen Sharing over
Tailscale (cheapest, E2E encrypted), Jump Desktop (best iPad control, one-time purchase), or
Chrome Remote Desktop (free, but poor iOS keyboard — GUI clicking only, not text work). RustDesk
was the pick actually installed.

## iOS terminal client comparison

Evaluated Blink Shell, Termius, and Prompt 3. All three do Mosh + Tailscale fine; the
differences are keyboard handling and pricing:

- **Blink Shell** ($19.99/yr, no lifetime option, open-source so self-buildable for free) — best
  external-keyboard remapping (Caps→Ctrl/Esc, chorded shortcuts) and native Mosh. Top pick for
  heavy terminal use if Termius's free tier ever feels limiting.
- **Termius** (the one installed) — free tier works for basic SSH/Mosh; sync, port forwarding,
  and SFTP sit behind Pro (~$9.99/mo). Best if also using Android/Windows. "SSH ID" feature
  detailed in the quickref.
- **Prompt 3** (Panic, ~$19.99/yr or ~$99 lifetime) — one purchase covers
  Mac/iPhone/iPad/Vision Pro, supports Mosh + Eternal Terminal, slightly less keyboard depth
  than Blink.

## SSH vs Mosh vs tmux (they solve different problems)

- **SSH** — the connection protocol/auth. Fragile: switching wifi↔cellular or a dropped
  connection kills the session and everything running in it.
- **Mosh** — a UDP replacement for the SSH *transport* only. Survives network changes/IP
  changes/sleep without dropping the connection, but doesn't restore a shell after a reboot or
  let you reconnect from a different device later. Its advantage shrinks over a stable Tailscale
  tunnel (plain SSH is often already solid there), but it's low-cost to add and helps with
  cellular↔wifi handoffs.
- **tmux** — runs *on the Mac*, independent of how you connect. The actual shell session
  (lazygit, Claude Code, a running pytest) lives inside tmux, so you can disconnect entirely and
  `tmux attach` later from any device with everything exactly as you left it. This is the piece
  that actually gives persistence — SSH/Mosh is just the pipe to it.
- **sesh** is the DX layer on top of tmux, actually adopted — see quickref.
- **Eternal Terminal (et)** — an alternative to Mosh: TCP-based (needs an open port, not an issue
  over Tailscale), but supports full scrollback and tmux control mode, which Mosh handles
  poorly. Considered and skipped: Mosh + tmux already covers persistence for less setup, unless
  scrollback-over-the-wire specifically starts to matter.

## Tailscale SSH (considered, not adopted — RustDesk/Termius cover the need today)

`sudo tailscale up --ssh --reset` turns a Mac into an SSH server authenticated via Tailscale
identity/ACLs — no `authorized_keys`, no `known_hosts` prompts to manage.

**Known gotcha if this gets adopted later**: installing the Tailscale GUI app (App
Store/.pkg/`cask "tailscale-app"`) drops a shim at `/usr/local/bin/tailscale`, which isn't
removed by uninstalling the app and shadows the `brew "tailscale"` formula binary if
`/usr/local/bin` precedes `/opt/homebrew/bin` in `$PATH`. The Tailscale SSH server does **not**
run in the sandboxed GUI build — only the unsandboxed formula supports `--ssh`. Fix:
`which tailscale` to check which binary is active; if it's the GUI shim,
`sudo rm /usr/local/bin/tailscale && hash -r`, then
`sudo brew services start tailscale && sudo tailscale up --ssh --reset` (the `--reset` is
required — Tailscale otherwise errors on unstated existing flags). Debug via
`sudo brew services info tailscale` (plist/log paths) and
`sudo launchctl print system/homebrew.mxcl.tailscale`. If SSH connections hang/timeout after
that's fixed, check `tailscale/tailscale#18957` — the launchd daemon's `$PATH` can be missing
`getent`, which `tailscaled` needs for macOS user lookups. Bottom line: the GUI app/cask is fine
as a *client* (sandboxing only breaks serving SSH, not being a client or general VPN use); only
a machine that needs to *serve* SSH needs the unsandboxed formula.

## Localhost preview from iPhone/iPad Safari

`tailscale serve <port>` on the Mac exposes a local dev server over HTTPS at a stable
`https://<machine>.<tailnet>.ts.net` URL, private to the tailnet — the cleanest option if this is
ever needed. Fall back to SSH local port forwarding (`-L`, supported by all three iOS clients
above) or `tailscale funnel <port>` / Cloudflare Tunnel when a public (not just tailnet-private)
URL is actually needed.
