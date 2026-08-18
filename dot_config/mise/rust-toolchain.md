# Rust toolchain: Homebrew instead of rustup

Rust on this machine comes from `brew install rust`, with no `rustup` and no
`rust`/`cargo:*` entry pinned in `mise.toml`.
`cargo`/`rustc` resolve from
`/opt/homebrew/bin`, and mise's `cargo:*` backend (used for `cargo:selene`,
`cargo:tree-sitter-cli`, and per-project tools like `cargo:emmylua_check`)
just shells out to whatever `cargo` is on `PATH`, so it needs nothing more
than that.

## Why not mise's `rust` core tool

mise ships a `rust` backend, but it is a wrapper around rustup, not an
independent installer:

> "Rust/cargo can be installed which uses rustup under the hood.
> mise will
> install rustup if it is not already installed and install the requested
> toolchain, components, and targets...
> Unlike most tools, these won't exist
> inside of `~/.local/share/mise/installs` because they are managed by
> rustup.
> mise keeps a symlink there for install tracking..."
> -- [mise docs: Rust](https://mise.jdx.dev/lang/rust.html)

Declaring `rust = "stable"` in any `mise.toml` makes mise reinstall rustup on
`mise install` if it's missing.
Since the whole point here is not running
rustup, that entry has to stay out of every `mise.toml`, both this global one
and any per-project one (e.g. `~/.config/nvim/mise.toml`).

## Why this came up

`cargo:emmylua_check@0.24.0` failed to compile
(`error[E0658]: use of unstable library feature 'path_file_prefix'`) against
a stale pinned rustup toolchain (`1.89.0`) that had drifted behind the
`path_file_prefix` stabilization.
The fix was updating rustc, which raised
the question of how to pin/manage the Rust version going forward so it
doesn't drift again.

## Tradeoffs accepted by dropping rustup

- No per-project toolchain pinning via `rust-toolchain.toml`.
    A file like
    `[toolchain]\nchannel = "1.93"` is inert without rustup's shim binaries;
    brew's `cargo`/`rustc` always run whatever version brew has installed
    globally.
    (Concrete case dropped: a temporary local checkout under
    `TBD-footnote-testing/` pinned `1.93` -- accepted as fine, since that
    checkout was throwaway.)
- No nightly channel, and no side-by-side toolchains (this machine
    previously had `stable`, `nightly`, `1.85`, and `1.89.0` installed via
    rustup simultaneously).
    Homebrew's `rust` formula is a single fixed
    version; switching versions means `brew upgrade rust` for everyone on the
    machine, not a per-shell/per-project override.
- `rustup component add`/`rustup target add` (e.g. `wasm32-unknown-unknown`)
    aren't available.
    Cross-compilation targets or extra components would need
    a different mechanism (e.g. a project-local rustup reappearing, or a
    separate target-specific toolchain).
- `mise`'s `rust` core tool (see above) can't be used in any `mise.toml`
    without reintroducing rustup.

## What's kept

- mise's `cargo:*` backend still works unmodified, since it only requires
    `cargo` on `PATH` -- see
    [mise docs: cargo backend](https://mise.jdx.dev/dev-tools/backends/cargo.html).
- Cargo-installed binaries that lived in `~/.cargo/bin` (`bacon`,
    `cargo-flamegraph`, `cargo-insta`, `cargo-nextest`, `flamegraph`) were
    reinstalled with `cargo install` against the brew toolchain after
    `rustup self uninstall`; `~/.cargo/bin` is still on `PATH` via
    `~/.zprofile` for that purpose.

## Reference

- [mise: Rust](https://mise.jdx.dev/lang/rust.html)
- [mise: cargo backend](https://mise.jdx.dev/dev-tools/backends/cargo.html)
- [Homebrew formula: rust](https://formulae.brew.sh/formula/rust)
- [rustup: uninstall](https://rust-lang.github.io/rustup/installation/index.html#uninstall)
