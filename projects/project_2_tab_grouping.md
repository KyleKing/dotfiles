# Project 2: Tab Grouping & Reordering

## Overview

Add intelligent tab organization to WezTerm through visual grouping, reordering capabilities, and automatic organization. This addresses the challenge of managing many tabs across different contexts.

## Current State

**What you have:**
- Tabs color-coded by git repository root
- Workspace switcher (zoxide integration)
- Tab navigation keybindings (CMD+1-9, CMD+ALT+Left/Right)
- Custom tab titles with process icons

**What's missing:**
- Manual tab reordering
- Visual grouping beyond color
- Tab organization persistence
- Quick tab switching beyond numbers
- Collapsible tab groups


## Open Questions

### 1. Grouping Criteria

**Question:** How should tabs be grouped?

Options:
- [ ] **Manual groups** - User assigns tabs to named groups
- [ ] **Automatic by git repo** - All tabs in same repo grouped together
- [ ] **By process type** - nvim tabs, shell tabs, build tabs, etc.
- [ ] **By directory pattern** - backend/, frontend/, infrastructure/, etc.
- [ ] **Hybrid** - Automatic with manual override

**[YOUR PREFERENCE:]**


### 2. Visual Representation

**Question:** How should groups be displayed?

Options:
- [ ] **Color bands** - Different colored segments in tab bar
- [ ] **Separators** - Visual dividers between groups
- [ ] **Group labels** - Show group name before tabs
- [ ] **Indentation** - Nested visual hierarchy
- [ ] **Icons** - Group type indicators

**[YOUR PREFERENCE:]**


### 3. Group Behavior

**Question:** Should groups be functional or just visual?

Options:
- [ ] **Visual only** - Just color coding/separators
- [ ] **Collapsible** - Minimize groups to save space
- [ ] **Group operations** - Close all, move all, etc.
- [ ] **Tab stacking** - Overlay tabs (like browser tab groups)
- [ ] **Workspace integration** - Groups auto-save per workspace

**[YOUR PREFERENCE:]**


### 4. Reordering Mechanism

**Question:** How to reorder tabs?

Options:
- [ ] **Keybindings** - CMD+Ctrl+Arrow to move tab left/right
- [ ] **Numbers** - CMD+Shift+3 to move tab to position 3
- [ ] **Quick menu** - Show numbered list, pick new position
- [ ] **Drag-and-drop** - (not supported by WezTerm)
- [ ] **Automatic sorting** - By name, last access, etc.

**[YOUR PREFERENCE:]**


### 5. Persistence

**Question:** Should tab organization persist across sessions?

Options:
- [ ] **Ephemeral** - Resets on restart
- [ ] **Per-workspace** - Each workspace remembers its tab layout
- [ ] **Global config** - Save in wezterm.lua
- [ ] **Session files** - Save/load named layouts

**[YOUR PREFERENCE:]**


## Technical Proposal

### Option A: Tab Reordering (Quick Win) ✅

**Approach:** Add keybindings to move tabs left/right

**Implementation:**
```lua
-- Add to config.keys
{
    key = "LeftArrow",
    mods = "CMD|CTRL",
    action = act.MoveTabRelative(-1)
},
{
    key = "RightArrow",
    mods = "CMD|CTRL",
    action = act.MoveTabRelative(1)
},
{
    key = "h",
    mods = "CMD|CTRL",
    action = act.MoveTabRelative(-1)
},
{
    key = "l",
    mods = "CMD|CTRL",
    action = act.MoveTabRelative(1)
},
```

**Complexity:** Low
**Impact:** Immediate utility
**Recommendation:** Implement this first


### Option B: Visual Tab Grouping

**Approach:** Color-code and label tab groups

**Implementation:**
```lua
-- Define groups with patterns
local tab_groups = {
    {
        name = "backend",
        pattern = "api|server|backend",
        color = "#A6DA95",
        icon = wezterm.nerdfonts.dev_code,
    },
    {
        name = "frontend",
        pattern = "ui|web|client|frontend",
        color = "#8AADF4",
        icon = wezterm.nerdfonts.md_monitor,
    },
    {
        name = "infrastructure",
        pattern = "docker|k8s|terraform|infra",
        color = "#F5A97F",
        icon = wezterm.nerdfonts.md_server,
    },
    {
        name = "data",
        pattern = "db|postgres|redis|mongo",
        color = "#EED49F",
        icon = wezterm.nerdfonts.md_database,
    },
}

-- Function to detect group
local function get_tab_group(tab)
    local cwd = tab.active_pane.current_working_dir.file_path or ""

    for _, group in ipairs(tab_groups) do
        if cwd:match(group.pattern) then
            return group
        end
    end

    return nil
end

-- Modify format-tab-title to include group indicator
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local group = get_tab_group(tab)

    if group then
        -- Add group icon to tab
        -- Use group.color for background
        -- Show group.icon before tab content
    end

    -- ... existing tab formatting
end)
```

**Complexity:** Medium
**Impact:** Better visual organization


### Option C: Tab Group Manager

**Approach:** Dedicated UI for managing tab groups

**Implementation:**
```lua
-- Show group manager
{
    key = "g",
    mods = "CMD|SHIFT",
    action = wezterm.action_callback(function(window, pane)
        -- Show InputSelector with groups
        local groups = get_all_groups(window)
        window:perform_action(act.InputSelector({
            title = "Manage Tab Groups",
            choices = groups,
            action = wezterm.action_callback(function(win, pane, id, label)
                -- Operations: rename, collapse, move, close all
            end),
        }), pane)
    end)
},
```

**Complexity:** High
**Impact:** Full-featured management


### Option D: Automatic Tab Organization

**Approach:** Auto-organize tabs by criteria

**Implementation:**
```lua
-- Auto-sort tabs by various criteria
local function auto_organize_tabs(window)
    local tabs = window:mux_window():tabs()

    -- Sort by git repo, then by process type
    table.sort(tabs, function(a, b)
        local a_repo = get_git_root(a)
        local b_repo = get_git_root(b)

        if a_repo ~= b_repo then
            return a_repo < b_repo
        end

        -- Within same repo, sort by process
        return get_process(a) < get_process(b)
    end)

    -- Reorder tabs
    for i, tab in ipairs(tabs) do
        tab:set_position(i - 1)
    end
end

-- Keybinding to trigger
{
    key = "o",
    mods = "CMD|SHIFT",
    action = wezterm.action_callback(function(window, pane)
        auto_organize_tabs(window)
    end)
},
```

**Complexity:** Medium-High
**Impact:** Reduces manual organization


## Recommended Implementation Plan

### Phase 1: Foundation (Quick Wins)

**Goal:** Basic reordering and visual grouping

1. **Tab reordering keybindings** ✅
   ```lua
   CMD+Ctrl+Left/Right - Move tab
   CMD+Ctrl+H/L - Move tab (vim-style)
   ```

2. **Tab labels/markers**
   ```lua
   CMD+Shift+L - Set custom tab label
   Persists until tab closes
   ```

3. **Quick tab switching**
   ```lua
   CMD+P - Show fuzzy tab selector
   Type to filter, Enter to switch
   ```

**Estimated effort:** 2-3 hours
**Files changed:** `dot_wezterm.lua`

### Phase 2: Visual Grouping

**Goal:** Automatic group detection and visual indicators

1. **Define group patterns** in config
2. **Add group icons** to tab titles
3. **Color-code by group** (in addition to git repo)
4. **Group separators** in tab bar

**Estimated effort:** 3-4 hours

### Phase 3: Advanced Management

**Goal:** Full-featured group management

1. **Manual group assignment**
2. **Group operations** (collapse, close all, etc.)
3. **Workspace-specific groups**
4. **Session persistence**

**Estimated effort:** 6-8 hours


## Implementation Examples

### Example 1: Tab Reordering

```lua
-- Simple left/right movement
config.keys = {
    -- ... existing keys

    -- Move tabs
    {
        key = "LeftArrow",
        mods = "CMD|CTRL",
        action = act.MoveTabRelative(-1),
    },
    {
        key = "RightArrow",
        mods = "CMD|CTRL",
        action = act.MoveTabRelative(1),
    },

    -- Move to specific position
    {
        key = "0",
        mods = "CMD|CTRL",
        action = wezterm.action_callback(function(window, pane)
            local tab = pane:tab()
            tab:set_position(0)  -- Move to first position
        end),
    },
}
```

### Example 2: Fuzzy Tab Switcher

```lua
-- Show all tabs in fuzzy finder
{
    key = "p",
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
        local tabs = window:mux_window():tabs()
        local choices = {}

        for i, tab in ipairs(tabs) do
            local title = tab:get_title()
            table.insert(choices, {
                id = tostring(tab:tab_id()),
                label = string.format("%d: %s", i, title),
            })
        end

        window:perform_action(act.InputSelector({
            title = "Switch to Tab",
            choices = choices,
            fuzzy = true,
            action = wezterm.action_callback(function(win, pane, id, label)
                if id then
                    for _, tab in ipairs(tabs) do
                        if tostring(tab:tab_id()) == id then
                            tab:activate()
                            break
                        end
                    end
                end
            end),
        }), pane)
    end),
},
```

### Example 3: Group Indicators

```lua
-- Add group indicator to tab title
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local cwd = tab.active_pane.current_working_dir.file_path or ""
    local group_icon = ""
    local group_color = nil

    -- Detect group
    if cwd:match("api") or cwd:match("backend") then
        group_icon = wezterm.nerdfonts.dev_code .. " "
        group_color = "#A6DA95"
    elseif cwd:match("web") or cwd:match("frontend") then
        group_icon = wezterm.nerdfonts.md_monitor .. " "
        group_color = "#8AADF4"
    elseif cwd:match("infra") or cwd:match("docker") then
        group_icon = wezterm.nerdfonts.md_server .. " "
        group_color = "#F5A97F"
    end

    -- Incorporate into existing tab format
    -- ... modify your existing format-tab-title logic
end)
```


## Related Ideas

### A. Tab History Navigation
Browser-like back/forward:
```lua
{ key = "[", mods = "CMD|CTRL", action = act.ActivateTabHistoryPrev },
{ key = "]", mods = "CMD|CTRL", action = act.ActivateTabHistoryNext },
```

### B. Tab Workspaces (Sub-workspaces)
Group tabs within a workspace:
```
myproject/
  ├─ dev (group)
  │   ├─ nvim
  │   ├─ shell
  │   └─ tests
  └─ deploy (group)
      ├─ docker
      └─ kubectl
```

### C. Tab Templates
Pre-configured tab layouts:
```lua
tab_templates = {
    fullstack = {
        { title = "API", cwd = "backend", cmd = "nvim" },
        { title = "UI", cwd = "frontend", cmd = "nvim" },
        { title = "Shell", cmd = "zsh" },
    },
}
```

### D. Smart Tab Closing
Close related tabs together:
```lua
-- CMD+Shift+W: Close all tabs in current group
```

### E. Tab Overview
Show all tabs in grid:
```lua
-- CMD+Shift+O: Show tab overview (like macOS Mission Control)
```


## Dependencies

**Required:**
- None (all built into WezTerm)

**Optional:**
- Session manager plugin (for persistence)


## Success Metrics

- [ ] Can reorder tabs with keyboard shortcuts
- [ ] Visual grouping makes it easier to find tabs
- [ ] Reduces cognitive load when managing many tabs
- [ ] Tab organization persists when needed
- [ ] Works seamlessly with workspace switcher


## Notes & Decisions

**[Add your notes, decisions, and preferences here]**

Example:
```
[DECISION: Start with Option A - Tab Reordering]
Reason: Immediate value, low complexity, foundational for other features

[PREFERENCE: Automatic grouping by git repo]
Reason: Already have git repo detection, natural organization

[QUESTION: Do I often have >10 tabs open?]
Answer: [Yes/No] - influences priority

[IDEA: Combine with workspace templates]
Create workspace with pre-organized tab groups
```


## Next Steps

1. **Review this document** - Add your preferences and decisions
2. **Answer open questions** - Mark your choices with [x]
3. **Prioritize phases** - Which phase should be implemented first?
4. **Choose features** - Which specific features are most valuable?
5. **Approve for implementation** - Ready to code Phase 1?

---

**Status:** 🟡 Awaiting decisions
**Last Updated:** 2025-11-22
**Assigned To:** Claude + User collaboration
**Quick Win:** Tab reordering (Phase 1) can be implemented immediately
