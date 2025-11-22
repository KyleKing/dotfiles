# Related Enhancement Ideas

These are additional features inspired by the main projects that could enhance your WezTerm workflow.

---

## 1. Session Management & Restoration

**Problem:** Lose tab/pane layouts when WezTerm restarts

**Solution:** Auto-save and restore workspace layouts

### Implementation
```lua
-- Use resurrect.wezterm plugin
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

-- Auto-save every 5 minutes
resurrect.periodic_save()

-- Keybinding to restore
{
    key = "r",
    mods = "CMD|SHIFT",
    action = resurrect.workspace_state.restore_workspace()
}
```

### What it saves
- Tab layouts per workspace
- Pane splits and ratios
- Working directories
- Running processes (optional)

**Effort:** Low (plugin available)
**Impact:** Medium-High


---

## 2. Enhanced Git Integration

**Problem:** Limited git information in current setup

**Solution:** Rich git status indicators

### Features
```lua
-- Status bar additions:
local git_info = {
    branch = "main",
    ahead = 2,          -- Commits ahead of remote
    behind = 0,         -- Commits behind remote
    staged = 3,         -- Staged files
    modified = 5,       -- Modified files
    untracked = 1,      -- Untracked files
    stashed = 2,        -- Stash count
    pr_number = "123",  -- Open PR (via gh CLI)
}

-- Display:
"[main↑2] [📝5] [PR#123]"
```

### Implementation
```lua
local function get_git_status(cwd)
    -- Run git status --porcelain
    -- Parse output for file counts
    -- Check remote tracking with git rev-list
    -- Query gh pr list for open PRs
end
```

**Effort:** Medium
**Impact:** Medium


---

## 3. Time Tracking

**Problem:** Don't know where time is being spent

**Solution:** Automatic workspace time tracking

### Features
```lua
-- Track time per workspace
local time_tracker = {
    dotfiles = {
        today = 7200,      -- 2 hours today
        this_week = 18000, -- 5 hours this week
        total = 86400,     -- 24 hours total
    }
}

-- Display in status bar
"⏱️ 2h 15m"  -- Time in current workspace today
```

### Storage
```json
{
  "dotfiles": {
    "sessions": [
      {
        "start": "2025-11-22T09:00:00Z",
        "end": "2025-11-22T11:30:00Z",
        "duration": 9000
      }
    ],
    "daily_totals": {
      "2025-11-22": 9000
    }
  }
}
```

### Keybinding
```lua
-- Show time report
CMD+Shift+T -> Time breakdown by workspace
```

**Effort:** Medium-High
**Impact:** Medium


---

## 4. Workspace Templates

**Problem:** Repetitive setup for similar projects

**Solution:** Pre-configured workspace layouts

### Template Definition
```lua
local workspace_templates = {
    fullstack = {
        tabs = {
            { title = "API", cwd = "backend", cmd = "nvim .", split = nil },
            { title = "UI", cwd = "frontend", cmd = "nvim .", split = nil },
            { title = "DB", cwd = ".", cmd = "psql", split = nil },
            { title = "Tests", cwd = ".", cmd = "zsh", split = {
                -- Split horizontally, top for watch mode, bottom for shell
                { cmd = "npm run test:watch", direction = "Top", size = 0.6 },
                { cmd = "zsh", direction = "Bottom", size = 0.4 },
            }},
        },
        note = "API in backend/, UI in frontend/, tests auto-run on save",
    },

    simple = {
        tabs = {
            { title = "Editor", cmd = "nvim ." },
            { title = "Shell", cmd = "zsh" },
        },
    },

    infrastructure = {
        tabs = {
            { title = "Terraform", cwd = "terraform", cmd = "nvim ." },
            { title = "K8s", cmd = "kubectl get pods -w" },
            { title = "Logs", cmd = "stern app-name" },
        },
    },
}
```

### Usage
```bash
# Create workspace from template
$ wezterm-template fullstack myproject

# Interactive selector
CMD+Shift+T -> Select template -> Enter name -> Creates workspace
```

**Effort:** Medium
**Impact:** High (if you create similar projects frequently)


---

## 5. Command Palette Enhancements

**Problem:** Hard to remember all keybindings and commands

**Solution:** Context-aware command palette

### Enhanced Palette
```lua
{
    key = "p",
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
        local workspace = window:active_workspace()
        local cwd = pane:get_current_working_dir().file_path

        local commands = {
            -- Workspace commands
            { label = "📝 Edit workspace note", action = edit_workspace_note },
            { label = "🔄 Restore workspace layout", action = restore_layout },
            { label = "💾 Save workspace layout", action = save_layout },

            -- Git commands (if in git repo)
            { label = "🌿 Switch branch", action = git_switch_branch },
            { label = "📊 Git status", action = show_git_status },
            { label = "📝 View PR", action = view_pr },

            -- Recent commands (this workspace)
            { label = "⏮️ Rerun: npm test", action = rerun_command },
            { label = "⏮️ Rerun: git status", action = rerun_command },

            -- Pane layouts
            { label = "⬜ Split horizontal", action = split_horizontal },
            { label = "⬛ Split vertical", action = split_vertical },
        }

        -- Show selector
        window:perform_action(act.InputSelector({
            title = "Command Palette: " .. workspace,
            choices = commands,
            fuzzy = true,
        }), pane)
    end)
}
```

**Effort:** Medium
**Impact:** Medium


---

## 6. Smart Tab Organization

**Problem:** Tabs become disorganized over time

**Solution:** Auto-organize tabs by criteria

### Auto-Sort Modes
```lua
local sort_modes = {
    by_git_repo = function(tabs)
        -- Group all tabs from same repo together
    end,

    by_process = function(tabs)
        -- All nvim tabs, then shell tabs, then others
    end,

    by_last_active = function(tabs)
        -- Most recently used first
    end,

    by_name = function(tabs)
        -- Alphabetically
    end,
}

-- Keybinding
{
    key = "o",
    mods = "CMD|SHIFT",
    action = show_sort_menu
}
```

**Effort:** Medium
**Impact:** Medium


---

## 7. Contextual Notifications

**Problem:** Miss important events in background panes

**Solution:** Smart notifications for key events

### Notification Triggers
```lua
-- Notify when:
local notifications = {
    -- Long-running command completes
    command_complete = {
        threshold = 10,  -- seconds
        pattern = "npm test|cargo build|pytest",
    },

    -- Build fails
    build_failed = {
        pattern = "error:|failed|ERROR",
        icon = "⚠️",
    },

    -- Git push completes
    git_complete = {
        pattern = "git push|git pull",
        icon = "🚀",
    },

    -- Background pane has new output (when zoomed)
    background_activity = {
        when_zoomed = true,
        icon = "👀",
    },
}
```

### macOS Integration
```lua
-- Show native notification
os.execute(string.format(
    "osascript -e 'display notification \"%s\" with title \"WezTerm\"'",
    message
))
```

**Effort:** Medium-High
**Impact:** Medium


---

## 8. Workspace Bookmarks

**Problem:** Frequently need to jump to specific directories/commands

**Solution:** Per-workspace bookmarks

### Bookmark Structure
```lua
local workspace_bookmarks = {
    dotfiles = {
        directories = {
            { key = "n", name = "nvim", path = "~/.config/nvim" },
            { key = "w", name = "wezterm", path = "~/.config/wezterm" },
            { key = "z", name = "zsh", path = "~/.config/zsh" },
        },
        commands = {
            { key = "a", name = "apply", cmd = "chezmoi apply" },
            { key = "d", name = "diff", cmd = "chezmoi diff" },
        },
        urls = {
            { key = "g", name = "github", url = "https://github.com/user/dotfiles" },
        },
    },
}

-- Keybinding
CMD+B -> Show bookmarks menu
  n - Jump to nvim config
  w - Jump to wezterm config
  a - Run: chezmoi apply
  g - Open GitHub repo
```

**Effort:** Medium
**Impact:** Medium


---

## 9. Tab History Navigation

**Problem:** Hard to get back to recently-viewed tabs

**Solution:** Browser-like tab history

### Implementation
```lua
-- Track tab navigation history
local tab_history = {}

wezterm.on("tab-activated", function(tab_id)
    table.insert(tab_history, tab_id)
    if #tab_history > 50 then
        table.remove(tab_history, 1)
    end
end)

-- Navigate history
{
    key = "[",
    mods = "CMD|CTRL",
    action = act.ActivateTabHistoryPrev
},
{
    key = "]",
    mods = "CMD|CTRL",
    action = act.ActivateTabHistoryNext
},
```

**Effort:** Low-Medium
**Impact:** Low-Medium


---

## 10. Workspace Sidebar

**Problem:** Status bar is too small for all information

**Solution:** Optional persistent sidebar

### Sidebar Content
```
╔════════════════════════════╗
║ Workspace: myproject       ║
║ Branch: feature/auth-fix   ║
╟────────────────────────────╢
║ 📝 Note:                   ║
║ Debugging JWT expiry       ║
║ issue with refresh tokens  ║
╟────────────────────────────╢
║ ✓ Todo (2/5):              ║
║ ☑ Fix auth bug             ║
║ ☑ Update docs              ║
║ ☐ Review PR #123           ║
║ ☐ Write tests              ║
║ ☐ Deploy to staging        ║
╟────────────────────────────╢
║ ⏱️ Time: 2h 15m            ║
║ 📊 Git: ↑2 ↓0 ~5          ║
║ 🔗 PR: #456                ║
╟────────────────────────────╢
║ Recent Commands:           ║
║ • npm test                 ║
║ • git status               ║
║ • curl localhost:3000      ║
╚════════════════════════════╝
```

### Toggle
```lua
{ key = "b", mods = "CMD|SHIFT", action = act.ToggleSidebar }
```

**Effort:** Very High (WezTerm doesn't natively support sidebars)
**Impact:** High


---

## 11. Multi-Workspace Dashboard

**Problem:** Hard to see all workspaces at once

**Solution:** Dashboard view of all workspaces

### Dashboard Display
```
╔═══════════════════════════════════════════════════════════╗
║                    Workspace Dashboard                    ║
╟───────────────────────────────────────────────────────────╢
║ dotfiles          [main]    📝 Wezterm config  ⏱️ 2h      ║
║ myproject         [feat/*]  📝 Auth fix        ⏱️ 5h      ║
║ api-service       [main]    📝 Deploy prep     ⏱️ 1h      ║
║ infrastructure    [dev]     -                  ⏱️ 30m     ║
╟───────────────────────────────────────────────────────────╢
║ Press 1-4 to switch, n to create new, q to close         ║
╚═══════════════════════════════════════════════════════════╝
```

**Effort:** High
**Impact:** Medium


---

## Priority Matrix

Based on effort vs. impact:

```
High Impact  │ ⭐ Workspace Templates
             │ ⭐ Session Restoration
             │ ⭐ Workspace Notes (Project 3)
             │
             ├─────────────────────────────────
Medium       │ Enhanced Git Integration
Impact       │ Time Tracking
             │ Command Palette
             │ Smart Tab Organization
             │
             ├─────────────────────────────────
Low Impact   │ Tab History
             │
             └─────────────────────────────────
                Low ← Effort → High
```

---

## Recommended Next Steps

1. **Immediate (this week):**
   - Project 2: Tab reordering (Phase 1)
   - Project 3: Workspace notes (MVP)

2. **Short-term (this month):**
   - Session restoration (use existing plugin)
   - Workspace templates (if needed)

3. **Medium-term (next month):**
   - Enhanced git integration
   - Command palette enhancements

4. **Long-term (future):**
   - Time tracking
   - Workspace sidebar (if needed)

---

## Integration Opportunities

Many of these ideas work well together:

- **Workspace Notes + Templates** → Pre-populate notes for new workspaces
- **Tab Grouping + Session Restoration** → Restore organized layouts
- **Time Tracking + Status Bar** → See time at a glance
- **Git Integration + Notifications** → Alert on push/pull complete
- **Command Palette + Bookmarks** → Quick access to everything

---

**Last Updated:** 2025-11-22
**Status:** 📋 Reference document
**Usage:** Pick features to add to main projects or implement standalone
