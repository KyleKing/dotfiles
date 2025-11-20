# Post-Simplification Steps

**Date**: 2025-11-20
**Status**: Ready for execution on your Mac

## Overview

Configuration files have been simplified and enhanced. Follow these steps to apply changes on your machine.

---

## Phase 1: Remove Duplicate Packages (5 minutes)

These packages are duplicated between brew and mise. Remove from brew:

```bash
# Remove duplicate tools (now managed by mise instead)
brew uninstall pyright prettier

# Note: pipenv is in both brew and mise - verify you still need it
# If you're using uv + poetry, you probably don't need pipenv:
brew uninstall pipenv  # Optional - only if not using pipenv workflows
```

### Verify mise manages these tools

```bash
# Check that mise has these tools
mise list | grep -E "pyright|prettier"

# Should show:
# pipx:pyright    <version>
# npm:@fsouza/prettierd  <version>
```

---

## Phase 2: Apply Updated Configuration (2 minutes)

```bash
# Navigate to chezmoi source
cd $(chezmoi source-path)

# Pull latest changes (this branch)
git pull

# Review changes
git diff HEAD~1

# Apply to your home directory
chezmoi apply --verbose
```

### What Changed?
- ✅ Cleaned up commented code in `.zshrc`
- ✅ Simplified OMZ plugin configuration
- ✅ Removed `dot_default-npm-packages` (npm managed via mise now)
- ✅ Added usage analytics functions
- ✅ Enhanced machine snapshot tracking

---

## Phase 3: Regenerate Machine Snapshot (3 minutes)

```bash
# Sign in to 1Password
eval "$(op signin)"

# Run the snapshot script
~/.config/my_config/generate_machine_snapshot.sh

# Review generated files
cd ~/.config/my_config/scripts
ls -la *personal-m2*

# You should see NEW files:
# - mise_list.personal-m2.txt
# - mise_plugins.personal-m2.txt
```

---

## Phase 4: Test New Features (5 minutes)

### Test Usage Analytics

```bash
# Reload your shell (or open new terminal)
source ~/.zshrc

# Run usage analysis
analyze-commands        # See your most-used commands
analyze-tool-sources    # See package manager summary
analyze-all            # Full report
```

### Test Shell Startup

```bash
# Verify no errors in zsh startup
zsh -c 'echo "Shell loaded successfully"'

# Check startup time (should be similar or faster)
time-zsh-startup
```

---

## Phase 5: Commit Snapshot Changes (2 minutes)

```bash
# Navigate to chezmoi source
cd $(chezmoi source-path)

# Check what was regenerated
git status

# You should see:
# - New mise snapshot files
# - Updated Brewfile (without pyright, prettier)

# Commit the changes
git add dot_config/my_config/scripts/
git commit -m "chore: update machine snapshot after package simplification"
```

---

## Phase 6: Review Tool Purposes (10 minutes)

```bash
# Read the tool purpose documentation
cat ~/.config/my_config/scripts/TOOL_PURPOSES.md | less

# Or open in your editor
nvim ~/.config/my_config/scripts/TOOL_PURPOSES.md
```

**Action Items from Review:**
1. ⚠️ **gojq** - Check if you use this separately from jq
   ```bash
   # If you don't use gojq:
   brew uninstall gojq
   ```

2. ⚠️ **walk** - Clarify if you use this vs fd/yazi
   ```bash
   # Test walk
   walk --help
   # If unfamiliar, consider removing:
   brew uninstall walk
   ```

3. ⚠️ **pipenv** - If using uv + poetry, you might not need pipenv
   ```bash
   # Check recent usage
   history | grep pipenv
   # If not using, remove (already suggested in Phase 1)
   ```

---

## Verification Checklist

After completing all phases:

- [ ] Brew packages reduced by 2-4 packages
- [ ] No errors when starting new zsh session
- [ ] `analyze-commands` command works
- [ ] Machine snapshot includes mise tracking
- [ ] TOOL_PURPOSES.md is readable and helpful
- [ ] Startup time is same or faster (`time-zsh-startup`)

---

## Rollback (if needed)

If anything breaks:

```bash
cd $(chezmoi source-path)

# Revert to previous state
git reset --hard HEAD~1

# Reapply old config
chezmoi apply --verbose

# Reinstall removed packages
brew install pyright prettier pipenv
```

---

## Next Steps

### Immediate (Optional)
- Run `analyze-all` to generate your first usage report
- Remove additional redundant tools (gojq, walk) if confirmed unused

### Quarterly (Set Reminder for Feb 2026)
```bash
# Run full analysis
analyze-all > ~/Downloads/shell-usage-$(date +%Y-%m).txt

# Review tool purposes
nvim ~/.config/my_config/scripts/TOOL_PURPOSES.md

# Update machine snapshot
back-scripts-ch

# Review for new package overlaps
comm -12 \
  <(brew leaves | sort) \
  <(mise list | awk '{print $1}' | sed 's/.*://' | sort)
```

---

## Questions?

- Review changes: `SIMPLIFICATION_CHANGES.md`
- Tool documentation: `~/.config/my_config/scripts/TOOL_PURPOSES.md`
- Usage analytics: `analyze-all`

**Estimated Total Time**: 25-30 minutes
**Risk Level**: Low (easy rollback available)
**Benefits**: Cleaner config, better tracking, reduced redundancy
