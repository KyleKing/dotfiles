# Project 1: IDE-like Completion Suggestions

## Overview

Add intelligent command completion suggestions to WezTerm, similar to IDE autocomplete or Warp's AI-powered suggestions. This would provide inline suggestions or a popup menu as you type commands.

## Current State

**What you have:**
- Shell-level completions (zsh built-in, likely zsh-autosuggestions)
- fzf for fuzzy finding
- Quick select for extracting text from output

**What's missing:**
- Visual inline suggestions in the terminal UI
- Context-aware command suggestions
- History-based intelligent completions
- Integration with WezTerm's UI layer

## Open Questions

### 1. Completion Style

**Question:** What UI style do you prefer?

Options:
- [ ] **Inline suggestions** (Warp/Fish style) - Shows grayed-out suggestion after cursor
- [ ] **Popup menu** (IDE style) - Shows dropdown with multiple options
- [ ] **Bottom panel** - Persistent panel showing top suggestions
- [ ] **Hybrid** - Inline for top match, keybinding for full menu

**[YOUR PREFERENCE:]**


### 2. Data Sources

**Question:** What should power the suggestions?

Options:
- [ ] **Shell history only** - Simple, fast, local
- [ ] **atuin** - Advanced history with sync, context, statistics
- [ ] **Context-aware** - Consider cwd, git branch, recent files
- [ ] **AI-powered** - External API (OpenAI, etc.) - requires API key
- [ ] **Hybrid** - Combine multiple sources

**[YOUR PREFERENCE:]**


### 3. Scope

**Question:** How should suggestions be scoped?

Options:
- [ ] **Global** - All history from all workspaces
- [ ] **Per-workspace** - Only commands from current workspace
- [ ] **Per-directory** - Only commands run in current directory
- [ ] **Smart** - Weighted by workspace/directory frequency

**[YOUR PREFERENCE:]**


### 4. Integration Complexity

**Question:** How deep should WezTerm integration be?

Options:
- [ ] **Shell-only** - Enhance shell tools (zsh-autosuggestions, atuin), minimal WezTerm changes
- [ ] **Light integration** - WezTerm keybinding to show suggestions popup
- [ ] **Deep integration** - WezTerm intercepts input, shows inline suggestions
- [ ] **Custom engine** - Build completion engine in Lua

**[YOUR PREFERENCE:]**


## Technical Proposal

### Option A: Enhanced Shell Integration (Recommended)

**Approach:** Leverage existing shell tools with WezTerm UI overlay

**Architecture:**
```
┌─────────────────────────────────────┐
│ WezTerm (UI Layer)                  │
│  - Keybinding trigger (CMD+;)       │
│  - Popup overlay for selection      │
│  - Format/display suggestions       │
└───────────┬─────────────────────────┘
            │
┌───────────▼─────────────────────────┐
│ atuin (History Engine)              │
│  - SQLite database                  │
│  - Context tracking                 │
│  - Fuzzy search                     │
│  - Statistics/ranking               │
└───────────┬─────────────────────────┘
            │
┌───────────▼─────────────────────────┐
│ Shell (zsh/bash)                    │
│  - Command execution                │
│  - History recording                │
└─────────────────────────────────────┘
```

**Implementation:**
```lua
-- In dot_wezterm.lua
local function get_command_suggestions(cwd, workspace)
    -- Query atuin for suggestions
    local handle = io.popen(string.format(
        "atuin search --cwd '%s' --limit 10 --format '{command}'",
        cwd
    ))
    local output = handle:read("*a")
    handle:close()

    local suggestions = {}
    for line in output:gmatch("[^\r\n]+") do
        table.insert(suggestions, { label = line })
    end
    return suggestions
end

-- Keybinding to show suggestions
{
    key = ";",
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
        local cwd = pane:get_current_working_dir().file_path
        local workspace = window:active_workspace()
        local suggestions = get_command_suggestions(cwd, workspace)

        window:perform_action(act.InputSelector({
            title = "Command Suggestions",
            choices = suggestions,
            fuzzy = true,
            action = wezterm.action_callback(function(win, pane, id, label)
                if label then
                    -- Send selected command to terminal
                    pane:send_text(label)
                end
            end),
        }), pane)
    end)
},
```

**Prerequisites:**
- Install atuin: `brew install atuin`
- Configure atuin: `atuin init zsh` in .zshrc
- Build up history database

**Pros:**
- Leverages mature, fast tooling (atuin)
- Relatively simple implementation
- Context-aware out of the box
- Can sync history across machines

**Cons:**
- Requires atuin installation
- Popup-based, not inline
- Manual trigger (not automatic)


### Option B: Inline Suggestions (Advanced)

**Approach:** WezTerm intercepts input and shows inline suggestions

**Architecture:**
```lua
-- This is more complex and requires deeper WezTerm integration
-- WezTerm doesn't currently support inline text overlay
-- Would need custom rendering or shell prompt integration
```

**Status:** ⚠️ Not currently feasible with WezTerm's API

**Alternative:** Use shell-level inline suggestions (zsh-autosuggestions, Fish shell)


### Option C: Custom Completion Engine

**Approach:** Build custom Lua-based completion engine

**Features:**
- Parse shell history directly
- Track command patterns per workspace
- Learn from usage patterns
- Show in WezTerm popup

**Pros:**
- Full control
- No external dependencies
- Customizable ranking

**Cons:**
- Reinventing the wheel
- Performance concerns with large history
- No sync/advanced features


## Recommended Implementation Plan

### Phase 1: MVP (Quick Win)
1. Install and configure atuin
2. Add WezTerm keybinding (CMD+;) to show atuin suggestions
3. Use `InputSelector` for popup display
4. Test with your workflow

**Estimated effort:** 1-2 hours
**Files changed:** `dot_wezterm.lua`, `.zshrc`

### Phase 2: Enhanced UX
1. Add workspace filtering to suggestions
2. Show command metadata (last run time, frequency)
3. Add quick-pick letters for top 10 suggestions
4. Keyboard navigation improvements

**Estimated effort:** 2-3 hours

### Phase 3: Advanced Features
1. Integrate with recent files (fd/rg output)
2. Git-aware suggestions (branch names, commit hashes)
3. Directory-specific command templates
4. Custom ranking algorithm

**Estimated effort:** 4-6 hours


## Related Ideas

### A. Command Templates
Pre-defined commands with placeholders:
```lua
command_templates = {
    docker_exec = "docker exec -it <container> /bin/bash",
    git_fix = "git commit --fixup <hash>",
    ssh_tunnel = "ssh -L <local>:localhost:<remote> <host>",
}
```

### B. Smart Command Palette
Enhanced command palette showing:
- Recent commands (this workspace)
- Workspace-specific scripts
- Git operations
- Saved aliases

### C. Context-Aware Suggestions
Consider:
- Current git branch
- Files in current directory
- Running processes
- Environment variables

### D. Command Cheat Sheet
Quick reference for common commands:
```
CMD+Shift+; → Show command cheat sheet
  - Git commands
  - Docker commands
  - kubectl commands
  - Custom aliases
```


## Dependencies

### Required
- atuin (if using Option A): `brew install atuin`

### Optional
- fzf (already have): Enhanced fuzzy finding
- ripgrep (already have): Fast file content search
- fd (optional): Fast file finding


## Success Metrics

How will we know this is working well?

- [ ] Can trigger suggestions with single keybinding
- [ ] Shows relevant commands based on context
- [ ] Faster than typing full commands
- [ ] Reduces need to remember exact syntax
- [ ] Works seamlessly with nvim workflow


## Notes & Decisions

**[Add your notes, decisions, and preferences here]**

Example:
```
[DECISION: Use Option A with atuin]
Reason: Mature tool, good performance, syncs across machines

[QUESTION: Do I already have atuin installed?]
Check: which atuin

[PREFERENCE: Popup menu over inline]
Reason: More visible, shows multiple options, less intrusive
```


## Next Steps

1. **Review this document** - Add your preferences and decisions
2. **Answer open questions** - Mark your choices with [x]
3. **Choose implementation option** - A, B, or C?
4. **Verify prerequisites** - Is atuin installed? Shell configured?
5. **Approve for implementation** - Ready to code?

---

**Status:** 🟡 Awaiting decisions
**Last Updated:** 2025-11-22
**Assigned To:** Claude + User collaboration
