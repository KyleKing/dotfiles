# Spike: Better `jj squash -i` (Neovim)

## Overview

Improve the interactive squash experience in jj by creating a rich Neovim interface that replaces the current text-based diff-editor. Make organizing changes visual, intuitive, and fast.

## Current State: `jj squash -i`

### How It Works Now

```bash
jj squash -i --from @ --into <change-id>
```

**What happens**:
1. jj launches configured diff-editor (or `:builtin`)
2. Shows hunks in text format
3. User selects hunks to squash (text-based)
4. On save/exit, jj applies selected hunks

**Problems**:
- Text-based hunk selection is slow
- Can't see full file context
- No preview of result
- Can't easily move hunks to different destinations
- Syntax highlighting is basic

### Current `:builtin` Editor

Example session:
```
# Edit the right side to apply the diff
# Lines from the left side are preceded by -
# Lines from the right side are preceded by +
# Delete lines to discard the change

- old_function()
+ new_function()
```

**Issues**:
- Confusing for beginners
- Easy to make mistakes
- No undo
- Can't switch between files easily

---

## Vision: Enhanced Squash UI

### Core Principles

1. **Visual, not textual**: See files, hunks, diffs
2. **Contextual**: Full file content always visible
3. **Flexible**: Move hunks to any destination change
4. **Previewable**: See result before committing
5. **Fast**: Keyboard-driven with shortcuts

### UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Squash: @ → <change-id>                    [?] Help         │
├──────────────────────────┬──────────────────────────────────┤
│ Files (3)                │ foo.rs                           │
│                          │                                  │
│ > foo.rs        [2 hunks]│ 1 │ fn main() {                 │
│   bar.rs        [1 hunk ]│ 2 │     println!("Hello");      │
│   baz.rs        [3 hunks]│ 3 │+    println!("World");      │
│                          │ 4 │ }                            │
│ Hunks (6 total)          │                                  │
│                          │ ─────────────────────────        │
│ ✓ Hunk 1 (foo.rs:3-4)    │                                  │
│ ✓ Hunk 2 (foo.rs:10-12)  │ 10 │ fn helper() {              │
│ ✗ Hunk 3 (bar.rs:5-7)    │ 11 │-    todo!()                │
│                          │ 12 │+    // implemented          │
│                          │ 13 │ }                            │
│                          │                                  │
├──────────────────────────┴──────────────────────────────────┤
│ <Space> Toggle | d: Diff | v: Visual | Enter: Apply        │
└─────────────────────────────────────────────────────────────┘
```

**Three Panes**:
1. **Left**: File list + hunk list
2. **Right**: File content with highlighted changes
3. **Bottom**: Help / status

---

## Implementation Approaches

### Approach A: Floating Windows (Simple)

**Architecture**: Single floating window with splits

```lua
local M = {}

function M.show_squash_ui(from_change, to_change)
  -- Create main floating window
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor(vim.o.lines * 0.05),
    col = math.floor(vim.o.columns * 0.05),
    style = 'minimal',
    border = 'rounded',
  })

  -- Split window into panes
  vim.cmd('vsplit')  -- File list | File content

  -- Populate panes
  populate_file_list(from_change)
  show_file_content(current_file)
  setup_keybindings(buf)
end

function populate_file_list(change_id)
  local files = get_modified_files(change_id)
  local hunks = get_hunks_for_files(files)

  -- Build UI
  local lines = {'Files:', ''}
  for _, file in ipairs(files) do
    table.insert(lines, string.format('  %s  [%d hunks]', file.path, #file.hunks))
  end

  table.insert(lines, '')
  table.insert(lines, 'Hunks:')
  table.insert(lines, '')

  for _, hunk in ipairs(hunks) do
    local checked = hunk.selected and '✓' or '✗'
    table.insert(lines, string.format('  %s Hunk %d (%s:%d-%d)',
      checked, hunk.id, hunk.file, hunk.start_line, hunk.end_line))
  end

  vim.api.nvim_buf_set_lines(file_list_buf, 0, -1, false, lines)
end

return M
```

**Pros**:
- Simple implementation
- Native nvim windows
- Familiar feel

**Cons**:
- Limited layout flexibility
- Managing window state is tricky
- May conflict with user's window setup

### Approach B: Full-Screen Overlay (Better)

**Architecture**: Completely take over nvim, restore on exit

```lua
local M = {}
M.saved_state = {}

function M.enter_squash_mode(from_change, to_change)
  -- Save current state
  M.saved_state = {
    buffers = vim.fn.getbufinfo({buflisted = 1}),
    windows = vim.fn.getwininfo(),
    cmdheight = vim.o.cmdheight,
    laststatus = vim.o.laststatus,
  }

  -- Clear all buffers/windows
  vim.cmd('silent! %bwipeout')

  -- Set up squash UI
  create_squash_layout()

  -- Set up autocmd to restore on exit
  vim.api.nvim_create_autocmd('QuitPre', {
    once = true,
    callback = function()
      M.exit_squash_mode()
    end
  })
end

function create_squash_layout()
  -- Create 3 buffers: file list, file content, help
  local file_list_buf = vim.api.nvim_create_buf(false, true)
  local file_content_buf = vim.api.nvim_create_buf(false, true)
  local help_buf = vim.api.nvim_create_buf(false, true)

  -- Split layout
  vim.cmd('edit file_list')
  vim.api.nvim_win_set_buf(0, file_list_buf)

  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, file_content_buf)

  vim.cmd('wincmd j')
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, help_buf)

  -- Populate buffers
  populate_file_list(file_list_buf)
  populate_file_content(file_content_buf)
  populate_help(help_buf)
end

function M.exit_squash_mode()
  -- Restore state
  vim.cmd('silent! %bwipeout')

  for _, buf_info in ipairs(M.saved_state.buffers) do
    vim.cmd('edit ' .. buf_info.name)
  end

  vim.o.cmdheight = M.saved_state.cmdheight
  vim.o.laststatus = M.saved_state.laststatus
end

return M
```

**Pros**:
- Complete control over layout
- No conflicts with user setup
- Can design custom UI

**Cons**:
- More complex state management
- Need to handle edge cases (user hits Ctrl-C, etc.)

### Approach C: Use Telescope Preview (Hybrid)

**Architecture**: Leverage Telescope's picker + preview

```lua
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

function M.squash_picker(from_change, to_change)
  local hunks = get_all_hunks(from_change)

  pickers.new({}, {
    prompt_title = string.format('Squash: %s → %s', from_change, to_change),

    finder = finders.new_table({
      results = hunks,
      entry_maker = function(hunk)
        return {
          value = hunk,
          display = string.format('%s Hunk %d (%s:%d-%d)',
            hunk.selected and '✓' or '✗',
            hunk.id, hunk.file, hunk.start_line, hunk.end_line),
          ordinal = hunk.file .. ':' .. hunk.id,
        }
      end
    }),

    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry, status)
        -- Show hunk diff in preview
        local lines = format_hunk_diff(entry.value)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

        -- Apply syntax highlighting
        vim.bo[self.state.bufnr].syntax = 'diff'
      end
    }),

    attach_mappings = function(prompt_bufnr, map)
      -- Space: Toggle hunk selection
      map('i', '<Space>', function()
        local selection = action_state.get_selected_entry()
        selection.value.selected = not selection.value.selected

        -- Refresh picker
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        current_picker:refresh(finders.new_table({ results = hunks }))
      end)

      -- Enter: Apply selections
      map('i', '<CR>', function()
        actions.close(prompt_bufnr)

        local selected_hunks = vim.tbl_filter(function(h)
          return h.selected
        end, hunks)

        apply_squash(selected_hunks, from_change, to_change)
      end)

      return true
    end
  }):find()
end
```

**Pros**:
- Leverages Telescope (familiar, powerful)
- Less custom code
- Great fuzzy search built-in
- Mature preview system

**Cons**:
- Limited layout (picker + preview only)
- Can't show file list + hunk list + content simultaneously
- Telescope dependency

### Approach D: Integrate hunk.nvim

**Architecture**: Use hunk.nvim as base, enhance it

```lua
-- Wrapper around hunk.nvim
local hunk = require('hunk')

function M.enhanced_squash(from_change, to_change)
  -- Use hunk.nvim's diff editor
  hunk.start({
    from = from_change,
    to = to_change,
    on_complete = function(selected_hunks)
      -- Add multi-target support
      select_destination_for_hunks(selected_hunks)
    end
  })
end

function select_destination_for_hunks(hunks)
  local changes = get_all_changes()

  -- Show picker: where should these hunks go?
  require('telescope.pickers').new({}, {
    prompt_title = 'Move hunks to...',
    finder = require('telescope.finders').new_table({
      results = changes,
      entry_maker = function(change)
        return {
          value = change,
          display = change.description,
          ordinal = change.id,
        }
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)

        apply_hunks(hunks, selection.value.id)
      end)
      return true
    end
  }):find()
end
```

**Pros**:
- Build on proven code (hunk.nvim)
- Just adds multi-target feature
- Minimal new code

**Cons**:
- Dependent on hunk.nvim architecture
- May not support all enhancements
- Need to coordinate with maintainer

---

## Key Features to Implement

### Feature 1: Visual Hunk Selection

**UI**: Checkbox-style list

```
✓ Hunk 1 (foo.rs:3-4)   Add println
✗ Hunk 2 (foo.rs:10-12) Fix typo
✓ Hunk 3 (bar.rs:5-7)   Add error handling
```

**Keybindings**:
- `<Space>` - Toggle current hunk
- `v` - Visual mode (select multiple hunks)
- `a` - Select all
- `A` - Deselect all
- `i` - Invert selection

**Implementation**:
```lua
local M = {}
M.hunks = {}  -- Global hunk state

function M.toggle_hunk(hunk_id)
  for _, hunk in ipairs(M.hunks) do
    if hunk.id == hunk_id then
      hunk.selected = not hunk.selected
      break
    end
  end

  M.refresh_ui()
end

function M.select_all()
  for _, hunk in ipairs(M.hunks) do
    hunk.selected = true
  end
  M.refresh_ui()
end

return M
```

### Feature 2: Live Diff Preview

**Show**:
- Original file (left)
- With hunks applied (right)
- Side-by-side or unified diff

```lua
function M.show_preview(selected_hunks)
  local original = read_file_from_change(from_change, current_file)
  local modified = apply_hunks_to_content(original, selected_hunks)

  -- Show side-by-side
  show_diff(original, modified, {
    mode = 'side-by-side',
    syntax = get_filetype(current_file),
  })
end
```

### Feature 3: Multi-Target Squashing

**Workflow**:
1. Select hunks as usual
2. Press `m` (move)
3. Pick destination change from list
4. Hunks move to that change

**Implementation**:
```lua
function M.move_hunks_to_change()
  local selected_hunks = get_selected_hunks()

  if #selected_hunks == 0 then
    vim.notify('No hunks selected', vim.log.levels.WARN)
    return
  end

  -- Show change picker
  local changes = get_all_changes()

  require('telescope.pickers').new({}, {
    prompt_title = string.format('Move %d hunks to...', #selected_hunks),
    finder = require('telescope.finders').new_table({
      results = changes,
      entry_maker = function(change)
        return {
          value = change,
          display = string.format('%s - %s', change.id, change.description),
          ordinal = change.description,
        }
      end
    }),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)

        -- Execute jj squash command
        for _, hunk in ipairs(selected_hunks) do
          apply_hunk_to_change(hunk, selection.value.id)
        end

        vim.notify(string.format('Moved %d hunks to %s', #selected_hunks, selection.value.description))
      end)
      return true
    end
  }):find()
end
```

### Feature 4: Hunk Editing

**Allow**: Fine-grained editing of hunks

**UI**: Open hunk in editable buffer, let user modify

```lua
function M.edit_hunk(hunk)
  -- Create scratch buffer with hunk content
  local buf = vim.api.nvim_create_buf(false, true)
  local hunk_lines = format_hunk_as_patch(hunk)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, hunk_lines)
  vim.bo[buf].filetype = 'diff'

  -- Open in floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = 80,
    height = 20,
    row = 5,
    col = 10,
    border = 'rounded',
  })

  -- On save, update hunk
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', {
    callback = function()
      local modified_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      hunk.content = parse_hunk_from_patch(modified_lines)

      vim.api.nvim_win_close(win, true)
      M.refresh_ui()
    end
  })
end
```

### Feature 5: Smart Hunk Suggestions

**Heuristics**: Suggest which hunks to squash based on patterns

**Examples**:
- Group hunks in same file
- Group hunks with same commit message pattern
- Group hunks touching same function

```lua
function M.suggest_groupings(hunks)
  local groups = {}

  -- Group by file
  local by_file = {}
  for _, hunk in ipairs(hunks) do
    by_file[hunk.file] = by_file[hunk.file] or {}
    table.insert(by_file[hunk.file], hunk)
  end

  for file, file_hunks in pairs(by_file) do
    table.insert(groups, {
      name = 'All changes in ' .. file,
      hunks = file_hunks,
    })
  end

  -- Group by function (using Treesitter)
  local by_function = group_by_function(hunks)
  for func, func_hunks in pairs(by_function) do
    table.insert(groups, {
      name = 'Changes in ' .. func,
      hunks = func_hunks,
    })
  end

  -- Show suggestions
  show_grouping_suggestions(groups)
end
```

### Feature 6: Undo/Redo

**Allow**: Undo hunk selections, preview changes

```lua
local M = {}
M.history = {}
M.history_index = 0

function M.record_state()
  local state = vim.deepcopy(M.hunks)
  table.insert(M.history, state)
  M.history_index = #M.history
end

function M.undo()
  if M.history_index > 1 then
    M.history_index = M.history_index - 1
    M.hunks = vim.deepcopy(M.history[M.history_index])
    M.refresh_ui()
  end
end

function M.redo()
  if M.history_index < #M.history then
    M.history_index = M.history_index + 1
    M.hunks = vim.deepcopy(M.history[M.history_index])
    M.refresh_ui()
  end
end

return M
```

---

## Edge Cases & Risks

### Edge Case 1: Overlapping Hunks

**Scenario**: Two hunks modify same lines

**Risk**: Can't select both (conflict)

**Mitigation**:
- Detect overlaps
- Show warning
- Force user to choose one
- OR merge hunks automatically

### Edge Case 2: Very Large Diffs

**Scenario**: Thousands of hunks

**Risk**: UI becomes slow, overwhelming

**Mitigation**:
- Pagination (show 50 hunks at a time)
- Virtual scrolling
- File-level filtering

### Edge Case 3: Binary Files

**Scenario**: Hunk is in binary file

**Risk**: Can't show meaningful preview

**Mitigation**:
- Show hex diff
- OR just show "binary file changed"
- Allow inclusion/exclusion only

### Edge Case 4: Syntax Errors in Result

**Scenario**: Selected hunks create invalid code

**Risk**: User doesn't notice until compile

**Mitigation**:
- Run LSP on preview
- Show diagnostics inline
- Warn before applying

### Edge Case 5: External Changes During Squash

**Scenario**: Repo modified while squash UI open

**Risk**: Hunks become stale

**Mitigation**:
- Lock repo (if possible)
- Detect changes, show warning
- Offer to reload hunks

---

## Comparison to `git add -p`

### What git does well:
- Simple text interface (works anywhere)
- Familiar workflow
- Hunk splitting (`s` command)

### What we can do better:
- ✅ Visual interface (not text-based)
- ✅ Multi-target squashing (git: stage or not; jj: choose destination)
- ✅ Full file context (git: only shows hunks)
- ✅ Undo/redo (git: no undo in staging)
- ✅ Live preview (git: no preview)

---

## Implementation Roadmap

### Phase 1: MVP (Telescope Picker)
**Time**: 1 week

- [x] Parse hunks from `jj diff`
- [x] Show hunks in Telescope picker
- [x] Toggle selection with Space
- [x] Apply selected hunks with Enter
- [ ] Test and iterate

### Phase 2: Enhanced UI
**Time**: 1-2 weeks

- [ ] Add file context preview
- [ ] Add syntax highlighting
- [ ] Add visual mode selection
- [ ] Add hunk grouping suggestions

### Phase 3: Multi-Target Support
**Time**: 1 week

- [ ] Show change picker
- [ ] Move hunks to different changes
- [ ] Handle multiple destinations

### Phase 4: Advanced Features
**Time**: 2 weeks

- [ ] Hunk editing
- [ ] Live diff preview
- [ ] Undo/redo
- [ ] LSP integration

### Phase 5: Polish
**Time**: 1 week

- [ ] Documentation
- [ ] Screencasts
- [ ] Testing on large repos
- [ ] Submit to plugin manager

---

## Success Criteria

**Minimum Viable**:
- ✅ Visual hunk selection
- ✅ Better than `:builtin` diff-editor
- ✅ Works with `jj squash -i`

**Fully Featured**:
- ✅ Multi-target squashing
- ✅ Live preview
- ✅ Undo/redo
- ✅ Fast on large diffs

**Exceptional**:
- ✅ Hunk editing
- ✅ Smart grouping suggestions
- ✅ LSP integration
- ✅ Mentioned in jj docs

---

## Conclusion

**Recommendation**: **Approach C (Telescope) for MVP**, then migrate to **Approach B (Full-Screen)** for v2

**Why**:
- Telescope gets us to MVP fastest
- Validates UI/UX concepts
- Can iterate based on feedback
- Full-screen overlay for better UX in v2

**Timeline**:
- Week 1-2: Telescope MVP
- Week 3-4: Enhanced features
- Week 5+: Full-screen overlay (if validated)

**Next Step**: Prototype Telescope picker this weekend, share with jj community for feedback.
