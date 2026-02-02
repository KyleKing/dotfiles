# README

## Modifications

### Wezterm

Custom tab color/title. Discussion here: <https://github.com/wez/wezterm/discussions/4945>

## Installation Instructions

### 1. Bootstrap (minimal tools)

```sh
brew install chezmoi gh

# Authenticate with GitHub CLI (enables SSH key management)
gh auth login
```

### 2. SSH Key Setup

Generate a local SSH key and register it with GitHub for both authentication and commit signing:

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

# Interactive setup (Python script runs automatically)
# Auto-detects: homebrew prefix, computer name, SSH key fields (if key exists)
# New installs: prompts for all values
# Upgrades: only prompts for missing fields, merges with existing config
chezmoi apply --verbose
```

The setup script intelligently handles both new installations and upgrades:

- **New installation**: Prompts for all configuration values, auto-detects SSH key email/public key if SSH key already exists
- **Upgrade**: Loads existing config, only prompts for new fields added in dotfiles updates
- **SSH key auto-resolution**: If SSH key exists during setup, fields are auto-populated. Otherwise run `~/.config/chezmoi/update-config.sh` after creating the key
- Uses Python's `tomllib` (3.11+) or falls back to `tomli` for TOML parsing

Alternatively, skip interactive setup and create config manually:

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
coderabbit_machineId = "placeholder"

[data.aws]
aws_profile = "placeholder"

[data.onepassword]
domain = "placeholder"

[data.obsidian]
vault_name = "placeholder"

[edit]
command = "nvim"
EOF

# Edit with actual values, then apply
nvim ~/.config/chezmoi/chezmoi.toml
chezmoi apply --verbose
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
