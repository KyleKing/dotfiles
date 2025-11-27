# Project 3: Per-Workspace Notes

## Overview

Add context-aware note-taking for each workspace, displayed in the status bar or accessible via keybinding. This solves the problem of remembering what you were working on when context-switching between projects.

## Current State

**What you have:**
- Workspace switcher (zoxide integration)
- Status bar showing workspace name, git branch, time
- Command tracking per pane

**What's missing:**
- Quick way to record "what am I doing here?"
- Persistent notes per workspace
- Todo list integration
- Visual reminder of context


## Open Questions

### 1. Note Format

**Question:** What format should notes use?

Options:
- [ ] **Plain text** - Simple, fast, no parsing
- [ ] **Markdown** - Rich formatting, links, code blocks
- [ ] **Structured YAML** - Frontmatter + content (tasks, links, notes)
- [ ] **JSON** - Fully structured (metadata + content)
- [ ] **Custom format** - Key-value pairs for specific fields

**[YOUR PREFERENCE:]**


### 2. Storage Location

**Question:** Where should notes be stored?

Options:
- [ ] **Centralized** - `~/.local/share/wezterm/workspace-notes/`
  - Pros: One location, easy to backup, workspace-agnostic
  - Cons: Not in git, not portable with project

- [ ] **Per-project** - `.wezterm/notes.md` in each repository
  - Pros: Git-tracked, portable, project-specific
  - Cons: Clutters repo, might need .gitignore

- [ ] **Hybrid** - Centralized index + per-project files
  - Pros: Best of both worlds
  - Cons: More complex

- [ ] **Cloud sync** - Synced across machines (Dropbox/iCloud)
  - Pros: Available everywhere
  - Cons: Dependency, privacy concerns

**[YOUR PREFERENCE:]**


### 3. Display Method

**Question:** How/when should notes be displayed?

Options:
- [ ] **Status bar only** - Truncated note (30-50 chars)
- [ ] **Popup on workspace switch** - Show full note for 3 seconds
- [ ] **Keybinding popup** - CMD+Shift+N to view/edit
- [ ] **Sidebar panel** - Persistent panel (advanced)
- [ ] **Hover tooltip** - Hover workspace name in status bar
- [ ] **Multiple** - Status bar + keybinding

**[YOUR PREFERENCE:]**


### 4. Editing Workflow

**Question:** How should notes be edited?

Options:
- [ ] **Quick inline** - Modal text input (simple, fast)
- [ ] **External editor** - Opens $EDITOR (full features)
- [ ] **WezTerm overlay** - Text editor in WezTerm overlay
- [ ] **CLI tool** - `wnote edit` command
- [ ] **Multiple methods** - Quick edit + full editor option

**[YOUR PREFERENCE:]**


### 5. Note Scope & Features

**Question:** What additional features should notes support?

Options:
- [ ] **Simple notes only** - Just free-form text
- [ ] **Todo lists** - Checkable items
- [ ] **Links** - URLs, file paths
- [ ] **Tags** - Categorization
- [ ] **Timestamps** - Last updated, created
- [ ] **History** - Track changes over time
- [ ] **Templates** - Pre-filled notes for project types
- [ ] **All of the above** - Full-featured

**[YOUR PREFERENCE:]**


## Technical Proposal

### Option A: Simple Notes (MVP) ✅

**Approach:** Plain text notes with status bar display + CLI tool

**Architecture:**
```
┌─────────────────────────────────────┐
│ WezTerm Status Bar                  │
│  📝 "Working on API auth fix"       │
└───────────┬─────────────────────────┘
            │
┌───────────▼─────────────────────────┐
│ wnote (CLI Tool)                    │
│  - wnote set "message"              │
│  - wnote get                        │
│  - wnote edit                       │
│  - wnote clear                      │
└───────────┬─────────────────────────┘
            │
┌───────────▼─────────────────────────┐
│ Storage                             │
│  ~/.local/share/wezterm/            │
│    workspace-notes/                 │
│      dotfiles.txt                   │
│      myproject.txt                  │
│      .index.json (metadata)         │
└─────────────────────────────────────┘
```

**Implementation:**

**1. CLI Tool (`~/.local/bin/wnote`):**
```bash
#!/usr/bin/env bash
# wnote - Workspace Note tool

NOTES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wezterm/workspace-notes"
mkdir -p "$NOTES_DIR"

# Get workspace name (from wezterm or cwd)
get_workspace() {
    # Try to get from wezterm
    if command -v wezterm &>/dev/null; then
        local ws=$(wezterm cli list --format json 2>/dev/null | \
            jq -r '.[] | select(.is_active) | .workspace' 2>/dev/null)
        if [[ -n "$ws" ]]; then
            echo "$ws"
            return
        fi
    fi

    # Fallback to directory name
    basename "$(pwd)"
}

WORKSPACE=$(get_workspace)
NOTE_FILE="$NOTES_DIR/${WORKSPACE}.txt"
INDEX_FILE="$NOTES_DIR/.index.json"

case "${1:-get}" in
    set)
        shift
        echo "$*" > "$NOTE_FILE"
        update_index "$WORKSPACE"
        echo "✓ Note saved for workspace: $WORKSPACE"
        ;;
    get)
        if [[ -f "$NOTE_FILE" ]]; then
            cat "$NOTE_FILE"
        fi
        ;;
    edit)
        ${EDITOR:-vim} "$NOTE_FILE"
        update_index "$WORKSPACE"
        ;;
    clear)
        rm -f "$NOTE_FILE"
        echo "✓ Note cleared for workspace: $WORKSPACE"
        ;;
    list)
        echo "Workspace notes:"
        for note in "$NOTES_DIR"/*.txt; do
            if [[ -f "$note" ]]; then
                local ws=$(basename "$note" .txt)
                local preview=$(head -1 "$note" | cut -c1-60)
                printf "  %-20s %s\n" "$ws:" "$preview"
            fi
        done
        ;;
    *)
        cat <<EOF
Usage: wnote <command>

Commands:
  set <message>   Set note for current workspace
  get             Get note for current workspace
  edit            Edit note in \$EDITOR
  clear           Clear note for current workspace
  list            List all workspace notes

Examples:
  wnote set "Working on API authentication bug"
  wnote get
  wnote edit
EOF
        ;;
esac

update_index() {
    local ws="$1"
    # Update .index.json with metadata (timestamp, etc.)
    # (optional, for advanced features)
}
```

**2. WezTerm Integration (`dot_wezterm.lua`):**
```lua
-- Function to read workspace note
local function get_workspace_note(workspace)
    local notes_dir = os.getenv("HOME") .. "/.local/share/wezterm/workspace-notes"
    local note_file = notes_dir .. "/" .. workspace .. ".txt"

    local file = io.open(note_file, "r")
    if not file then
        return nil
    end

    local content = file:read("*all")
    file:close()

    return content:gsub("^%s*(.-)%s*$", "%1")  -- trim whitespace
end

-- Add to status bar (in update-right-status event)
local note = get_workspace_note(workspace)
if note and note ~= "" then
    -- Truncate to 40 chars
    local preview = note:sub(1, 40)
    if #note > 40 then
        preview = preview .. "..."
    end

    table.insert(status_items, { Foreground = { Color = "#C6A0F6" } })
    table.insert(status_items, { Text = " " .. wezterm.nerdfonts.md_note_text .. " " .. preview })
end

-- Keybinding to view/edit note
{
    key = "n",
    mods = "CMD|SHIFT",
    action = wezterm.action_callback(function(window, pane)
        local workspace = window:active_workspace()
        local note = get_workspace_note(workspace) or "[No note set]"

        window:perform_action(act.InputSelector({
            title = "Workspace Note: " .. workspace,
            choices = {
                { id = "view", label = note },
                { id = "edit", label = "✏️  Edit note" },
                { id = "clear", label = "🗑️  Clear note" },
            },
            action = wezterm.action_callback(function(win, pane, id, label)
                if id == "edit" then
                    pane:send_text("wnote edit\n")
                elseif id == "clear" then
                    pane:send_text("wnote clear\n")
                end
            end),
        }), pane)
    end),
},
```

**Complexity:** Low-Medium
**Impact:** High
**Recommendation:** Start here


### Option B: Structured Notes (Advanced)

**Approach:** Rich markdown notes with frontmatter

**File Format:**
```yaml
---
workspace: dotfiles
created: 2025-11-22T10:30:00
updated: 2025-11-22T14:15:00
tags: [config, wezterm, nvim]
status: in-progress
---

# Current Work

Working on adding workspace notes feature to WezTerm.

## Todo
- [ ] Implement CLI tool
- [ ] Add status bar integration
- [x] Design file format

## Links
- [WezTerm Docs](https://wezfurlong.org/wezterm/)
- API authentication issue: #1234

## Notes
Need to decide on storage location - centralized vs per-project.
```

**CLI Support:**
```bash
wnote todo add "Implement CLI tool"
wnote todo list
wnote todo done 1
wnote tag add "wezterm"
wnote link add "https://example.com"
```

**Complexity:** High
**Impact:** Very High


### Option C: Per-Project Notes

**Approach:** Store notes in project root

**Structure:**
```
myproject/
├── .wezterm/
│   ├── note.md
│   ├── todos.md
│   └── links.txt
├── src/
└── README.md
```

**Pros:**
- Git-tracked with project
- Portable across machines
- Project-specific context

**Cons:**
- Clutters project root
- Not available for non-git directories


### Option D: Smart Notes Integration

**Approach:** Integrate with existing tools

**Options:**
- Obsidian integration - Create/link daily notes
- Notion API - Sync to Notion database
- GitHub Issues - Link to project issues
- Jira - Show current sprint tasks

**Complexity:** Very High
**Impact:** High (if you use these tools)


## Recommended Implementation Plan

### Phase 1: MVP (Immediate Value)

**Goal:** Basic note-taking with status bar display

1. **Create CLI tool** (`wnote`)
   - `wnote set "message"`
   - `wnote get`
   - `wnote edit`
   - `wnote clear`

2. **WezTerm status bar integration**
   - Show truncated note in status bar
   - Only show if note exists

3. **Keybinding for quick access**
   - `CMD+Shift+N` to view/edit note
   - Shows popup with options

**Estimated effort:** 3-4 hours
**Files changed:** New file `~/.local/bin/wnote`, `dot_wezterm.lua`

### Phase 2: Enhanced Features

**Goal:** Better UX and additional features

1. **Quick edit modal**
   - Inline text input (no external editor)
   - Fast note updates

2. **Note history**
   - Track last 10 changes
   - Rollback capability

3. **Templates**
   - Default note templates by project type
   - Variables: {{project}}, {{date}}, {{branch}}

**Estimated effort:** 4-6 hours

### Phase 3: Advanced Features

**Goal:** Rich notes and integrations

1. **Markdown support** with frontmatter
2. **Todo list integration**
3. **Link extraction** (show URLs in note)
4. **Tag support**
5. **Search across notes**

**Estimated effort:** 8-10 hours


## Implementation Examples

### Example 1: Quick Note Update

```bash
# Set note for current workspace
$ wnote set "Debugging authentication issue - check JWT expiry"
✓ Note saved for workspace: myapi

# View in terminal
$ wnote get
Debugging authentication issue - check JWT expiry

# See in status bar
[myapi] [main] [📝 Debugging authentication issue - c...] [14:30]
```

### Example 2: Multi-line Notes

```bash
# Edit in $EDITOR
$ wnote edit

# Content:
Working on API authentication

Current issue: JWT tokens expiring too quickly
Next steps:
1. Check token configuration
2. Review refresh token logic
3. Test with longer expiry

Blocked by: Need access to prod logs
```

### Example 3: Workspace Switcher Integration

```lua
-- Show note when switching workspaces
wezterm.on("workspace-switched", function(workspace_name)
    local note = get_workspace_note(workspace_name)
    if note then
        wezterm.log_info("Workspace note: " .. note)
        -- Could show temporary overlay
    end
end)
```

### Example 4: Todo Integration (Advanced)

```bash
$ wnote todo add "Fix authentication bug"
$ wnote todo add "Update API documentation"
$ wnote todo add "Review PR #123"

$ wnote todo list
1. [ ] Fix authentication bug
2. [ ] Update API documentation
3. [ ] Review PR #123

$ wnote todo done 1
✓ Marked task 1 as done

# Show in status bar
[myapi] [main] [📝 2 tasks] [14:30]
```


## Related Ideas

### A. Daily Notes
Create daily note linked to workspace:
```bash
wnote daily  # Opens today's note for this workspace
# ~/.local/share/wezterm/workspace-notes/myproject/2025-11-22.md
```

### B. Workspace Dashboard
Show comprehensive workspace info:
```
Workspace: myproject
Branch: feature/auth-fix
Note: Debugging JWT expiry issue

Recent commands:
  - npm test
  - git log
  - curl localhost:3000/api/auth

Open todos:
  - [ ] Fix authentication bug
  - [ ] Update documentation

Last accessed: 2 hours ago
```

### C. Context Switching Helper
Show note + recent state when switching:
```
Switching to workspace: myproject

📝 Note: Debugging JWT expiry issue
🌿 Branch: feature/auth-fix
📂 Last directory: src/auth/
⏱️  Last active: 2h ago

Press Enter to continue...
```

### D. Workspace Templates with Notes
Pre-populate notes for new workspaces:
```bash
$ wezterm-workspace new fullstack-app
Created workspace: fullstack-app

Default note:
- API in backend/
- UI in frontend/
- Tests in __tests__/
```

### E. Note Sharing
Export/import notes:
```bash
$ wnote export > myproject-notes.md
$ wnote import < myproject-notes.md
```


## Dependencies

**Required:**
- `jq` (for JSON parsing in CLI tool): `brew install jq`

**Optional:**
- Git (for per-project notes)
- ripgrep (for searching notes)


## Success Metrics

- [ ] Can quickly set/view notes from keyboard
- [ ] Never forget what I was working on
- [ ] Status bar shows relevant context at a glance
- [ ] Notes persist across sessions
- [ ] Integration feels natural in workflow


## File Structure Example

```
~/.local/share/wezterm/workspace-notes/
├── .index.json                    # Metadata (timestamps, tags)
├── dotfiles.txt                   # Simple text notes
├── myproject.txt
├── api-service.txt
└── advanced/                      # Optional: structured notes
    ├── dotfiles.md
    └── myproject.md
```

**Index format (`.index.json`):**
```json
{
  "dotfiles": {
    "created": "2025-11-22T10:00:00Z",
    "updated": "2025-11-22T14:30:00Z",
    "type": "text",
    "tags": ["config", "wezterm"]
  },
  "myproject": {
    "created": "2025-11-20T09:00:00Z",
    "updated": "2025-11-22T15:45:00Z",
    "type": "markdown",
    "tags": ["api", "auth"],
    "todos": 3,
    "links": ["https://github.com/user/myproject"]
  }
}
```


## Notes & Decisions

**[Add your notes, decisions, and preferences here]**

Example:
```
[DECISION: Start with Option A - Simple Notes]
Reason: Get value quickly, can enhance later

[PREFERENCE: Centralized storage]
Reason: Don't want to clutter project repos, easier to backup

[PREFERENCE: Status bar + keybinding]
Reason: Always visible, but can view full note when needed

[QUESTION: Should notes be per-workspace or per-directory?]
Consideration: Same workspace might work on different features

[IDEA: Integration with zoxide]
Show note when using zoxide workspace switcher

[DECISION: Plain text initially, markdown later]
Reason: Simple to implement, can migrate later if needed
```


## Next Steps

1. **Review this document** - Add your preferences and decisions
2. **Answer open questions** - Mark your choices with [x]
3. **Choose implementation option** - A (MVP), B (Advanced), C (Per-project), D (Smart)?
4. **Design note format** - What fields/structure do you want?
5. **Create CLI tool** - Implement `wnote` script
6. **Integrate with WezTerm** - Status bar + keybinding
7. **Test workflow** - Use for a week, iterate

---

**Status:** 🟡 Awaiting decisions
**Last Updated:** 2025-11-22
**Assigned To:** Claude + User collaboration
**Priority:** High - Solves immediate pain point
**Quick Win:** MVP can be implemented in one session
