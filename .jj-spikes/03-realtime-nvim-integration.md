# Spike: Real-Time Neovim Integration with Auto-Commit

## Overview

Rethink the editor-VCS relationship by embracing jj's automatic commit model. Instead of manually staging and committing, let jj capture every meaningful edit automatically, providing a granular timeline of your work that can be reviewed, reorganized, and used by AI tooling.

## The Radical Idea

**Traditional VCS**:
```
Edit files → Save → Stage → Commit → Push
```

**jj's Model**:
```
Edit files → (automatic snapshot) → Organize later
```

**What if we went further?**:
```
Edit files → Real-time change tracking → AI-assisted organization → Timeline review
```

## Core Concepts

### Concept 1: Change-Aware Editing

**Problem**: In current nvim, you edit files without the editor knowing about VCS changes

**Vision**: Editor is VCS-aware in real-time

**Example Workflow**:
1. Open nvim, start editing `foo.rs`
2. nvim detects you're in a jj repo
3. Status line shows: `@[Working] • 3 changes in 2 files`
4. As you edit, nvim tracks which "change" you're working on
5. Sidebar shows live diff of current change
6. Save file → jj automatically snapshots (it already does this!)
7. UI updates to show new snapshot in evolution timeline

**Implementation**:
```lua
-- Auto-detect jj repo
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if is_jj_repo() then
      enable_jj_integration()
    end
  end
})

function enable_jj_integration()
  -- Update statusline with change info
  vim.o.statusline = '%<%f %h%m%r %= @[%{JJGetCurrentChange()}] %{JJGetStats()}'

  -- Show live diff in sidebar
  require('jj.diff').show_live_diff()

  -- Watch for file saves
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      vim.defer_fn(function()
        refresh_jj_state()
      end, 100)
    end
  })
end
```

### Concept 2: Intent-Based Change Selection

**Problem**: You edit multiple files, jj puts them all in @ (working copy)

**Vision**: Tell nvim what change you're working on BEFORE you start editing

**Workflow**:
```vim
:JJNew "Fix auth bug"          " Creates new change, switches to it
" Now edit files - all changes go to "Fix auth bug"
:w                             " Auto-snapshot

:JJSwitch "Add feature X"      " Switch to different change
" Edit more files - go to "Add feature X"

:JJReview                      " Review all changes, organize later
```

**How it works**:
```lua
local M = {}
M.current_change = nil

function M.new_change(description)
  -- Create new jj change
  vim.fn.system({'jj', 'new', '@', '-m', description})

  M.current_change = get_current_change_id()

  -- Update UI
  vim.notify('Now working on: ' .. description, vim.log.levels.INFO)
  update_statusline()
end

function M.switch_change(change_id)
  -- Switch to existing change
  vim.fn.system({'jj', 'edit', change_id})

  M.current_change = change_id

  update_statusline()
end

return M
```

### Concept 3: Automatic Micro-Snapshots

**Problem**: jj snapshots on every command, but not during editing session

**Vision**: Snapshot more frequently WHILE EDITING, creating a granular undo history

**Implementation Strategy**:

**Option A: Time-based snapshots**
```lua
local snapshot_timer = vim.loop.new_timer()

snapshot_timer:start(0, 60000, vim.schedule_wrap(function()  -- Every 60s
  if vim.bo.modified then
    vim.cmd('silent write')  -- Triggers jj snapshot
  end
end))
```

**Option B: Event-based snapshots**
```lua
-- Snapshot after significant edits
local edit_count = 0

vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
  callback = function()
    edit_count = edit_count + 1

    if edit_count > 50 then  -- Every 50 edits
      vim.cmd('silent write')
      edit_count = 0
    end
  end
})
```

**Option C: Semantic snapshots** (advanced)
```lua
-- Snapshot on "meaningful" changes
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    if should_create_snapshot() then
      create_snapshot_with_description()
    end
  end
})

function should_create_snapshot()
  -- Heuristics:
  -- - Added/removed function
  -- - Fixed compilation error
  -- - Completed TODO
  -- - Time since last snapshot > threshold

  local changes = get_buffer_changes()

  if contains_function_definition(changes) then
    return true
  end

  if fixed_lsp_diagnostic(changes) then
    return true
  end

  return false
end
```

### Concept 4: AI-Assisted Change Organization

**Vision**: Let AI models make incremental changes with automatic commits, then review timeline to understand what happened

**Workflow**:
```
1. You: "Add error handling to auth module"
2. AI: Makes changes, auto-commits each logical step
   - Snapshot 1: "Add Result return type to login()"
   - Snapshot 2: "Add error handling for invalid credentials"
   - Snapshot 3: "Add error handling for network failures"
   - Snapshot 4: "Update tests"
3. You: Review evolution timeline, see each step
4. You: Accept all / reject some / squash together
```

**Implementation**:
```lua
function M.ai_task(prompt, options)
  options = options or {}

  -- Create new change for AI work
  local change_id = create_change('AI: ' .. prompt)

  -- Enable auto-snapshot mode
  local original_mode = get_snapshot_mode()
  set_snapshot_mode('ai-assisted')  -- Snapshot every AI edit

  -- Call AI (pseudocode)
  local ai = require('codecompanion')
  ai.execute_task(prompt, {
    on_edit = function(file, content, reason)
      -- AI edited a file
      write_file(file, content)

      -- Create snapshot with AI's reason
      create_snapshot(reason)

      -- Update UI
      show_evolution_timeline(change_id)
    end,

    on_complete = function()
      -- Show final review
      vim.notify('AI completed ' .. prompt, vim.log.levels.INFO)
      show_ai_review_ui(change_id)
    end
  })

  -- Restore original mode
  set_snapshot_mode(original_mode)
end

-- Usage:
:JJAITask "Add comprehensive error handling"
```

**Review UI**:
```
┌─────────────────────────────────────────────────┐
│ AI Task: Add comprehensive error handling       │
├─────────────────────────────────────────────────┤
│ Evolution Timeline:                             │
│                                                 │
│ ●────●────●────● (4 snapshots in 2 minutes)     │
│ │    │    │    └─ Update tests                  │
│ │    │    └────── Add network error handling    │
│ │    └─────────── Add credential validation     │
│ └──────────────── Add Result return types       │
│                                                 │
│ [a] Accept all  [r] Reject all  [i] Review each │
└─────────────────────────────────────────────────┘
```

### Concept 5: Session-Based Changes

**Vision**: Start an "editing session" where all changes go to a new change, automatically organized

**Workflow**:
```vim
:JJSession start "Refactor auth module"
" All edits now go to this change
" ... edit multiple files ...
:JJSession end
" Review and decide to keep/squash/split

:JJSession resume "Refactor auth module"
" Continue previous session
```

**Implementation**:
```lua
local M = {}
M.active_session = nil

function M.start_session(description)
  if M.active_session then
    error('Session already active: ' .. M.active_session.description)
  end

  -- Create new change
  local change_id = vim.fn.system({'jj', 'new', '@', '-m', description}):gsub('%s+', '')

  M.active_session = {
    description = description,
    change_id = change_id,
    start_time = os.time(),
    snapshots = {},
  }

  -- Enable aggressive auto-save
  vim.o.updatetime = 2000  -- Save after 2s of inactivity
  vim.api.nvim_create_autocmd("CursorHold", {
    group = vim.api.nvim_create_augroup('JJSession', {}),
    callback = function()
      if vim.bo.modified then
        vim.cmd('silent write')
        table.insert(M.active_session.snapshots, {
          timestamp = os.time(),
          description = get_auto_description(),
        })
      end
    end
  })

  show_session_indicator()
end

function M.end_session()
  if not M.active_session then
    return
  end

  -- Clear autocmds
  vim.api.nvim_del_augroup_by_name('JJSession')

  -- Show summary
  local duration = os.time() - M.active_session.start_time
  vim.notify(string.format(
    'Session ended: %s (%d snapshots, %dm)',
    M.active_session.description,
    #M.active_session.snapshots,
    math.floor(duration / 60)
  ), vim.log.levels.INFO)

  -- Prompt for next action
  show_session_review_ui(M.active_session)

  M.active_session = nil
end

function show_session_indicator()
  -- Show in statusline
  vim.o.statusline = vim.o.statusline .. ' [SESSION: ' .. M.active_session.description .. ']'

  -- Show floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '🎯 Session Active',
    M.active_session.description,
    '',
    'All changes will be tracked',
  })

  vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    width = 40,
    height = 4,
    row = 1,
    col = vim.o.columns - 42,
    style = 'minimal',
    border = 'rounded',
  })
end

return M
```

### Concept 6: Never Lose Work (Infinite Undo)

**Vision**: Use jj's obslog as infinite undo history

**Problem with nvim undo**:
- Lost when you close file
- Limited undo levels
- No cross-file undo

**jj Solution**:
- Every snapshot is permanent
- Can undo across file close/reopen
- Can see "parallel universes" (divergent edits)

**Implementation**:
```lua
function M.time_travel_undo()
  local current_change = get_current_change_id()
  local evolutions = get_evolutions(current_change)

  -- Show timeline picker
  require('telescope.pickers').new({}, {
    prompt_title = 'Time Travel Undo',
    finder = require('telescope.finders').new_table({
      results = evolutions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = format_evolution(entry),
          ordinal = entry.timestamp,
        }
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = require('telescope.actions.state').get_selected_entry()

        -- Create new change from this evolution
        vim.fn.system({'jj', 'new', selection.value.commit_id})

        vim.notify('Time traveled to: ' .. selection.value.description)
        vim.cmd('edit!')  -- Reload buffer
      end)
      return true
    end
  }):find()
end

-- Keybinding
vim.keymap.set('n', '<leader>ju', require('jj').time_travel_undo, { desc = 'jj Time Travel Undo' })
```

## Freeing from Git's Restrictions

### What Git Forces:
1. **Manual staging**: Must explicitly `git add`
2. **Commit anxiety**: "Is this the right time to commit?"
3. **Linear history**: Difficult to explore alternatives
4. **Coarse granularity**: Commits are snapshots, not continuous
5. **Lost work**: Uncommitted changes can be lost

### What jj Enables:
1. **Automatic tracking**: Everything is always committed
2. **Commit freedom**: Organize commits after the fact
3. **Mutable history**: Change IDs separate from commits
4. **Fine granularity**: Snapshot as often as you want
5. **Never lose work**: Everything in obslog

### New Possibilities with nvim + jj:

**1. Continuous Diffing**
```
Show live diff as you type (not just on save)

┌─────────────────────────────────────┐
│ foo.rs                              │
│                                     │
│ fn login(user: &str) -> bool {     │
│     // Your code                    │
│ }                                   │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ Live Diff (vs last snapshot)        │
│                                     │
│ @@ -1,3 +1,5 @@                     │
│  fn login(user: &str) -> bool {    │
│ +    if user.is_empty() {          │
│ +        return false;             │
│ +    }                              │
│      // Your code                   │
│  }                                  │
└─────────────────────────────────────┘
```

**2. Parallel Editing**
```
Work on multiple approaches simultaneously

:JJBranch "approach-A" "Try recursive algorithm"
" ... edit ...

:JJBranch "approach-B" "Try iterative algorithm"
" ... edit ...

:JJCompare "approach-A" "approach-B"
" See both side-by-side, choose best parts
```

**3. Annotation with Context**
```
Automatically annotate changes with LSP context

Snapshot: "Add error handling"
Context:
  - Fixed diagnostic: "Result must be handled"
  - Modified function: login()
  - Test status: 3 tests passing
  - Time: 2:34 PM
  - Duration: 12 minutes since last snapshot
```

**4. Collaborative Real-Time**
```
Share your evolution timeline with others

:JJShareEvolution <change-id>
" Generates shareable link

Teammate can:
  - Watch your changes in real-time
  - See your thought process
  - Learn from your approach
```

**5. Automatic Change Splitting**
```
Heuristically split changes based on semantics

AI detects:
  - These 3 files are related (same feature)
  - These 2 files are unrelated (different bug fixes)

Suggests:
  Split into:
    Change A: "Fix auth bug"
    Change B: "Update logging"
```

## Technical Implementation

### Watchman Integration

jj already supports Watchman for filesystem monitoring. We can use this:

```lua
-- Enable Watchman auto-snapshots
function M.enable_watchman()
  -- Check if Watchman is available
  local status = vim.fn.system({'jj', 'debug', 'watchman', 'status'})

  if status:match('Watchman is enabled') then
    vim.notify('jj Watchman enabled - auto-snapshots active')

    -- Configure aggressive snapshotting
    vim.fn.system({
      'jj', 'config', 'set',
      'fsmonitor.watchman.register-snapshot-trigger', 'true'
    })
  else
    vim.notify('Watchman not available, install for best experience', vim.log.levels.WARN)
  end
end
```

### Buffer-Level Change Tracking

```lua
local M = {}
M.buffer_states = {}

function M.track_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  M.buffer_states[bufnr] = {
    last_snapshot = get_current_commit_id(),
    last_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    change_count = 0,
  }

  -- Track changes
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, first_line, last_line, new_last_line)
      local state = M.buffer_states[buf]
      state.change_count = state.change_count + 1

      -- Check if we should snapshot
      if state.change_count > 100 then
        M.snapshot_buffer(buf, 'Auto snapshot (100 changes)')
      end
    end
  })
end

function M.snapshot_buffer(bufnr, description)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd('silent write')
  end)

  -- Optionally update change description
  if description then
    vim.fn.system({'jj', 'describe', '-m', description})
  end

  M.buffer_states[bufnr].last_snapshot = get_current_commit_id()
  M.buffer_states[bufnr].change_count = 0
end

return M
```

### Live Diff Sidebar

```lua
function M.show_live_diff()
  -- Create split window for diff
  vim.cmd('vsplit')
  local diff_win = vim.api.nvim_get_current_win()
  local diff_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(diff_win, diff_buf)

  -- Set buffer options
  vim.bo[diff_buf].filetype = 'diff'
  vim.bo[diff_buf].buftype = 'nofile'

  -- Update diff on cursor hold
  vim.api.nvim_create_autocmd({"CursorHold", "CursorHoldI"}, {
    callback = function()
      local current_file = vim.api.nvim_buf_get_name(0)
      local diff = vim.fn.system({'jj', 'diff', current_file})

      vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, vim.split(diff, '\n'))
    end
  })

  -- Return to original window
  vim.cmd('wincmd p')
end
```

## Edge Cases & Risks

### Edge Case 1: Too Many Snapshots

**Risk**: Obslog becomes huge, performance degrades

**Mitigation**:
- Configurable snapshot frequency
- Auto-squash old snapshots (keep hourly after 1 day, daily after 1 week)
- Option to disable auto-snapshot per repo

### Edge Case 2: Conflicts with Manual Workflow

**Risk**: User runs jj commands outside nvim, state diverges

**Mitigation**:
- Filesystem watcher detects external changes
- Reload buffers automatically
- Show notification of external changes

### Edge Case 3: Battery/Performance Impact

**Risk**: Constant file writes drain battery, slow down editor

**Mitigation**:
- Adaptive snapshot frequency (slow down if battery low)
- Only snapshot modified buffers
- Debounce snapshot triggers

### Edge Case 4: Accidental Work Loss

**Risk**: User thinks work is saved but it's only in obslog

**Mitigation**:
- Clear visual indicators (status line, notifications)
- Warn before closing nvim with uncommitted snapshots
- Tutorial/onboarding

### Edge Case 5: Large Files

**Risk**: Snapshotting large files is slow

**Mitigation**:
- Skip auto-snapshot for files >1MB
- Use Watchman which is optimized for large repos
- Allow per-file snapshot configuration

## Open Questions

### Q1: Should snapshots be visible in `jj log`?

**Question**: Do auto-snapshots clutter the log?

**Options**:
1. Yes, show all (current jj behavior)
2. Hide auto-snapshots by default (add tag?)
3. Separate "snapshot log" from "commit log"

**Recommendation**: Add tag `nvim-auto` to auto-snapshots, filter in log UI

### Q2: How to handle multiple nvim instances?

**Question**: Two nvim windows editing same repo

**Answer**: jj's lock-free concurrency handles this! Each snapshot is independent.

### Q3: Integration with LSP?

**Question**: Should we snapshot when LSP diagnostics clear?

**Answer**: Yes! Semantic snapshots are powerful:
```lua
vim.lsp.handlers['textDocument/publishDiagnostics'] = function(_, result, ctx)
  -- Check if diagnostics cleared
  if #result.diagnostics == 0 and had_diagnostics then
    snapshot_buffer(ctx.bufnr, 'Fixed LSP diagnostics')
  end
end
```

### Q4: Snapshot on test pass?

**Question**: Auto-snapshot when tests pass?

**Answer**: YES! Integration with test runners:
```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "TestSuccess",
  callback = function()
    snapshot_buffer(0, 'Tests passing')
  end
})
```

### Q5: Privacy/security?

**Question**: Sensitive data in obslog?

**Answer**: Same risk as jj already has. Recommend:
- `.jj/config` with filters for sensitive files
- Encryption for sensitive repos
- Auto-expire old snapshots

## Implementation Roadmap

### Phase 1: Basic Integration
**Time**: 1 week

- [ ] Detect jj repo
- [ ] Show current change in statusline
- [ ] Refresh on `:w`
- [ ] Basic :JJNew, :JJSwitch commands

### Phase 2: Auto-Snapshots
**Time**: 1-2 weeks

- [ ] Watchman integration
- [ ] Configurable snapshot triggers
- [ ] Buffer-level change tracking
- [ ] Auto-snapshot on semantic events

### Phase 3: Live Diff
**Time**: 1 week

- [ ] Live diff sidebar
- [ ] Syntax highlighting in diff
- [ ] Jump to changes in diff

### Phase 4: Session Mode
**Time**: 1-2 weeks

- [ ] :JJSession start/end
- [ ] Session indicator UI
- [ ] Session review workflow
- [ ] Session analytics

### Phase 5: AI Integration
**Time**: 2-3 weeks

- [ ] AI task execution framework
- [ ] Snapshot per AI edit
- [ ] Evolution timeline review
- [ ] Accept/reject AI changes

### Phase 6: Advanced Features
**Time**: 2-3 weeks

- [ ] Time travel undo
- [ ] Parallel editing mode
- [ ] Automatic change splitting
- [ ] Collaborative sharing

## Success Criteria

**Minimum Viable**:
- ✅ jj repo detection
- ✅ Change-aware statusline
- ✅ Auto-refresh on save
- ✅ Basic :JJ commands

**Fully Featured**:
- ✅ Auto-snapshots with Watchman
- ✅ Live diff sidebar
- ✅ Session mode
- ✅ Semantic snapshot triggers

**Exceptional**:
- ✅ AI-assisted editing with timeline
- ✅ Time travel undo
- ✅ Parallel editing
- ✅ Real-time collaboration

## General Benefits

1. **Never Lose Work**: Every edit captured
2. **Freedom to Experiment**: Easy to try and revert
3. **Learning from History**: Understand your own process
4. **AI Transparency**: See exactly what AI changed
5. **Rethinking VCS**: Break free from git mental models

## Conclusion

**Recommendation**: Start with **Phase 1 & 2** (basic integration + auto-snapshots) as MVP, then expand based on user feedback.

**Why**:
- Validates core idea quickly
- Low risk (doesn't change jj fundamentals)
- Provides immediate value
- Opens door for more radical ideas

**The Big Vision**: Create an editor-VCS symbiosis where the line between "editing" and "version control" disappears. You just work, and the system captures everything intelligently.

**This is only possible with jj's architecture**. Git could never support this model.
