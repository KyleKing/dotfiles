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
ssh-keygen -t ed25519 -C "KyleKing@users.noreply.github.com"

# Add to macOS keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Add to GitHub for authentication and signing
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(scutil --get ComputerName)" --type authentication
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(scutil --get ComputerName)-signing" --type signing

# Verify SSH connection
ssh -T git@github.com
```

### 3. Initialize Chezmoi

```sh
chezmoi init git@github.com:KyleKing/dotfiles.git --verbose

# Create local config from template
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml << 'EOF'
[data]
computer_name = ""
email = ""
homebrew_prefix = "/opt/homebrew"

[data.github]
email = "KyleKing@users.noreply.github.com"
username = "kyleking"
ssh_public_key = ""
coderabbit_machineId = ""

[data.aws]
aws_profile = ""

[data.obsidian]
vault_name = ""

[edit]
command = "nvim"
EOF

# Fill in ssh_public_key from the generated key
SSH_PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)
echo "Copy this to ssh_public_key: $SSH_PUB_KEY"

# Edit config with actual values
chezmoi edit-config
```

### 4. Shell and Packages

```sh
# Install oh-my-zsh (https://ohmyz.sh/#install)
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Apply dotfiles
chezmoi apply --verbose

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
echo "test" > test.txt && git add . && git commit -m "test"
git log --show-signature -1
cd .. && rm -rf test-signing
```
