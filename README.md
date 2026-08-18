# README

## Modifications

### Wezterm

Custom tab color/title. Discussion here:
<https://github.com/wez/wezterm/discussions/4945>

### Machine performance

Docker Desktop VM sizing and Firefox memory prefs, plus the
`machine-perf-*` scripts under `dot_local/bin` that check/apply/snapshot them.
See
[docs/machine-performance-optimizations.md](docs/machine-performance-optimizations.md).

## Installation Instructions

### 1. Bootstrap (minimal tools)

```sh
brew install chezmoi gh

# Authenticate with GitHub CLI (enables SSH key management)
gh auth login
```

### 2. SSH Key Setup (Required)

**Create SSH key before initializing chezmoi:**

```sh
# Generate SSH key
ssh-keygen -t ed25519 -C "KyleKing@users.noreply.github.com" -f ~/.ssh/id_ed25519_github_2026

# Add to macOS keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github_2026

# Add to GitHub for authentication and signing
gh ssh-key add ~/.ssh/id_ed25519_github_2026.pub --title "$(scutil --get ComputerName)" --type authentication
gh ssh-key add ~/.ssh/id_ed25519_github_2026.pub --title "$(scutil --get ComputerName)-signing" --type signing

# Verify SSH connection
ssh -T git@github.com
```

### 3. Initialize Chezmoi

```sh
# Initialize chezmoi repository
chezmoi init git@github.com:KyleKing/dotfiles.git --verbose

# Interactive setup prompts for missing values
chezmoi apply --verbose

# Auto-populate github.email and github.ssh_public_key from SSH key
~/.config/chezmoi/update-config.sh
```

Setup behavior:

- **New installation**: Prompts for all configuration values
- **Upgrade**: Loads existing config, only prompts for new fields
- **SSH key resolution**: Run `~/.config/chezmoi/update-config.sh` to extract email and
    public key from SSH file

Alternatively, create config manually:

```sh
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml << 'EOF'
[data]
computer_name = "placeholder"
email = "placeholder"
github_ssh_key_name = "id_ed25519_github_2026"
homebrew_prefix = "/opt/homebrew"

[data.github]
username = "placeholder"

[data.onepassword]
domain = "placeholder"

[data.obsidian]
vault_name = "placeholder"

[edit]
command = "nvim"
EOF

# Edit with actual values
nvim ~/.config/chezmoi/chezmoi.toml

# Apply dotfiles and populate SSH key fields
chezmoi apply --verbose
~/.config/chezmoi/update-config.sh
```

### 4. Shell and Packages

```sh
# Install oh-my-zsh (https://ohmyz.sh/#install)
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install brew packages
brew bundle --file ~/.Brewfile-personal --no-lock

# fzf post-install (accept all prompts)
$(brew --prefix)/opt/fzf/install
```

### 5. Optional

```sh
# Rosetta for Mac Silicon (hard to uninstall)
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
```

### Verify Signing

```sh
# Test commit signing
cd /tmp && git init test-signing && cd test-signing
git config user.name "Test User" && git config user.email "test@example.com"
echo "test" > test.txt && git add . && git commit -m "test: verify signing"
git log --show-signature -1
cd .. && rm -rf test-signing
```
