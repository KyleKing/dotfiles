# Spike: jj-diffconflicts Extensions

## Overview

Explore how to extend jj-diffconflicts (existing nvim conflict resolution tool) to handle jj's unique conflict model, partial resolution tracking, and integration with evolution timeline.

## Current State: jj-diffconflicts

### What It Is

**Repository**: https://github.com/rafikdraoui/jj-diffconflicts

**Purpose**: A conflict resolution merge tool for Jujutsu VCS that runs in Neovim

**How It Works**:
- Two-way diff interface (vertical splits)
- Highlights changes between two sides of conflict
- Modeled after vim-conflicted (git tool)

**Basic Usage**:
```bash
# Configure jj to use jj-diffconflicts
jj config set --user merge-tools.jj-diffconflicts.program "jj-diffconflicts"
jj config set --user merge-tools.jj-diffconflicts.merge-args '["$left", "$right", "$output"]'
jj config set --user ui.merge-editor "jj-diffconflicts"

# Resolve conflicts
jj resolve
```

---

## How jj Handles Conflicts

### Key Differences from Git

**Git**:
- Conflicts block operations
- Must resolve before continuing
- Conflicts only in working directory

**jj**:
- Conflicts live in commits
- Can defer resolution indefinitely
- Can commit conflicted state
- Conflicts stored as 3-way merge data

### jj Conflict Format

When jj writes conflicts to working copy:
```rust
<<<<<<< Conflict 1 of 1
%%%%%%% Changes from base to side #1
-old line
+side 1 line
+++++++ Contents of side #2
side 2 line
>>>>>>> Conflict 1 of 1 ends
```

**What jj tracks**:
- Base (common ancestor)
- Side 1 (local changes)
- Side 2 (remote changes)

**Resolution**:
- Edit file to resolve
- jj parses conflict markers on next snapshot
- Stores resolution

**Partial resolution**:
- Can resolve some conflicts, leave others
- jj tracks which parts are resolved

---

## Vision: Enhanced jj-diffconflicts

### Core Enhancements

#### 1. 3-Way Merge View (vs current 2-way)

**Current**: Shows only left vs right

**Enhanced**: Show BASE | LOCAL | REMOTE | RESULT

```
┌────────────────────────────────────────────────────────────┐
│ Conflict Resolution: foo.rs                                │
├──────────┬──────────┬──────────┬──────────────────────────┤
│ BASE     │ LOCAL    │ REMOTE   │ RESULT                   │
│          │ (Side 1) │ (Side 2) │                          │
├──────────┼──────────┼──────────┼──────────────────────────┤
│ old_fn() │ new_fn() │ refac()  │ > refac()                │
│          │          │          │                          │
│ common   │ common   │ common   │ common                   │
│ code     │ code     │ code     │ code                     │
│          │          │          │                          │
│ return 1 │ return 2 │ return 3 │ > return 3               │
└──────────┴──────────┴──────────┴──────────────────────────┘
```

**Why 3-way**:
- See what changed from base
- Understand WHY conflict exists
- Make informed resolution decisions

**Implementation**:
```lua
function M.show_3way_merge(base_file, local_file, remote_file, output_file)
  -- Create 4 buffers
  local base_buf = read_file_to_buffer(base_file)
  local local_buf = read_file_to_buffer(local_file)
  local remote_buf = read_file_to_buffer(remote_file)
  local result_buf = vim.api.nvim_create_buf(false, false)

  -- Layout: 4 vertical splits
  vim.cmd('edit ' .. base_file)
  vim.api.nvim_win_set_buf(0, base_buf)
  vim.bo[base_buf].readonly = true

  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, local_buf)
  vim.bo[local_buf].readonly = true

  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, remote_buf)
  vim.bo[remote_buf].readonly = true

  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, result_buf)
  vim.api.nvim_buf_set_name(result_buf, output_file)

  -- Initialize result buffer with auto-merged content
  local auto_merged = compute_auto_merge(base_file, local_file, remote_file)
  vim.api.nvim_buf_set_lines(result_buf, 0, -1, false, auto_merged)

  setup_3way_keybindings()
end
```

#### 2. Conflict Markers Parsing & Highlighting

**Parse jj conflict markers**:
```lua
function M.parse_jj_conflicts(lines)
  local conflicts = {}
  local in_conflict = false
  local current_conflict = nil

  for i, line in ipairs(lines) do
    if line:match('^<<<<<<< Conflict %d+ of %d+') then
      in_conflict = true
      current_conflict = {
        start_line = i,
        base_to_side1 = {},
        side2 = {},
      }
    elseif line:match('^%%%%%%% Changes from base to side #1') then
      current_conflict.mode = 'base_to_side1'
    elseif line:match('^%+%+%+%+%+%+%+ Contents of side #2') then
      current_conflict.mode = 'side2'
    elseif line:match('^>>>>>>> Conflict %d+ of %d+ ends') then
      current_conflict.end_line = i
      table.insert(conflicts, current_conflict)
      in_conflict = false
      current_conflict = nil
    elseif in_conflict and current_conflict.mode then
      if current_conflict.mode == 'base_to_side1' then
        table.insert(current_conflict.base_to_side1, line)
      else
        table.insert(current_conflict.side2, line)
      end
    end
  end

  return conflicts
end
```

**Highlight conflicts visually**:
```lua
function M.highlight_conflicts(bufnr, conflicts)
  local ns_id = vim.api.nvim_create_namespace('jj_conflicts')

  for _, conflict in ipairs(conflicts) do
    -- Highlight conflict region
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'DiffDelete',
      conflict.start_line - 1, 0, -1)

    -- Highlight base->side1 changes
    for i, _ in ipairs(conflict.base_to_side1) do
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'DiffChange',
        conflict.start_line + i, 0, -1)
    end

    -- Highlight side2 content
    for i, _ in ipairs(conflict.side2) do
      vim.api.nvim_buf_add_highlight(bufnr, ns_id, 'DiffAdd',
        conflict.start_line + #conflict.base_to_side1 + i, 0, -1)
    end
  end
end
```

#### 3. Partial Resolution Tracking

**Problem**: jj allows partial conflict resolution, but no visual indicator

**Solution**: Track which conflicts are resolved, which aren't

```lua
local M = {}
M.resolution_state = {}

function M.mark_conflict_resolved(conflict_id)
  M.resolution_state[conflict_id] = {
    resolved = true,
    resolution_time = os.time(),
  }

  update_conflict_ui()
end

function M.show_resolution_progress()
  local total = #M.conflicts
  local resolved = vim.tbl_count(vim.tbl_filter(function(s)
    return s.resolved
  end, M.resolution_state))

  vim.notify(string.format('Conflicts: %d/%d resolved', resolved, total))
end
```

**UI Indicator**:
```
Conflicts in foo.rs:
  ✅ Conflict 1: function signature
  ⚠️  Conflict 2: return type          [current]
  ⬜ Conflict 3: error handling
```

#### 4. Conflict Navigation

**Keybindings**:
- `]x` - Next conflict
- `[x` - Previous conflict
- `]X` - Next unresolved conflict
- `[X` - Previous unresolved conflict

**Implementation**:
```lua
function M.jump_to_next_conflict()
  local conflicts = M.conflicts
  local current_line = vim.fn.line('.')

  for _, conflict in ipairs(conflicts) do
    if conflict.start_line > current_line then
      vim.fn.cursor(conflict.start_line, 0)
      return
    end
  end

  -- Wrap to first conflict
  if #conflicts > 0 then
    vim.fn.cursor(conflicts[1].start_line, 0)
  end
end

function M.jump_to_next_unresolved()
  local current_line = vim.fn.line('.')

  for _, conflict in ipairs(M.conflicts) do
    if not M.resolution_state[conflict.id].resolved and
       conflict.start_line > current_line then
      vim.fn.cursor(conflict.start_line, 0)
      return
    end
  end
end
```

#### 5. Quick Resolution Actions

**Keybindings**:
- `<leader>cl` - Choose LOCAL (side 1)
- `<leader>cr` - Choose REMOTE (side 2)
- `<leader>cb` - Choose BASE
- `<leader>ca` - Choose ALL (both changes)
- `<leader>cn` - Choose NONE (delete both)

**Implementation**:
```lua
function M.choose_side(side)
  local conflict = get_conflict_at_cursor()

  if not conflict then
    vim.notify('Not in a conflict', vim.log.levels.WARN)
    return
  end

  local resolution = nil

  if side == 'local' then
    resolution = conflict.side1_lines
  elseif side == 'remote' then
    resolution = conflict.side2_lines
  elseif side == 'base' then
    resolution = conflict.base_lines
  elseif side == 'both' then
    resolution = vim.list_extend(conflict.side1_lines, conflict.side2_lines)
  elseif side == 'none' then
    resolution = {}
  end

  -- Replace conflict with resolution
  vim.api.nvim_buf_set_lines(0,
    conflict.start_line - 1,
    conflict.end_line,
    false,
    resolution)

  M.mark_conflict_resolved(conflict.id)
end
```

#### 6. Evolution Timeline Integration

**Show conflict history across evolutions**:

**Use Case**: "How was this conflict created? What changed across rebases?"

```lua
function M.show_conflict_evolution(conflict_id)
  local change_id = get_current_change_id()
  local evolutions = get_evolutions(change_id)

  -- Find when conflict was introduced
  local conflict_history = {}

  for _, evolution in ipairs(evolutions) do
    local conflicts_at_evolution = get_conflicts_in_commit(evolution.commit_id)

    if vim.tbl_contains(conflicts_at_evolution, conflict_id) then
      table.insert(conflict_history, {
        evolution = evolution,
        conflict_state = get_conflict_state(evolution.commit_id, conflict_id),
      })
    end
  end

  -- Show timeline
  require('telescope.pickers').new({}, {
    prompt_title = 'Conflict Evolution',
    finder = require('telescope.finders').new_table({
      results = conflict_history,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format('%s - %s (%s)',
            entry.evolution.description,
            entry.conflict_state.resolved and 'Resolved' or 'Unresolved',
            entry.evolution.timestamp),
          ordinal = entry.evolution.timestamp,
        }
      end
    }),
    previewer = require('telescope.previewers').new_buffer_previewer({
      define_preview = function(self, entry, status)
        -- Show conflict state at this evolution
        local lines = format_conflict_state(entry.value.conflict_state)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end
    }),
  }):find()
end
```

#### 7. Semantic Conflict Detection

**Use Treesitter to understand conflicts semantically**:

**Example**: Detect if conflict is:
- Function signature change
- Variable rename
- Block reordering
- Formatting only

```lua
function M.analyze_conflict_semantic(conflict)
  local base_ast = parse_with_treesitter(conflict.base_content)
  local side1_ast = parse_with_treesitter(conflict.side1_content)
  local side2_ast = parse_with_treesitter(conflict.side2_content)

  -- Compare ASTs
  local base_to_side1 = diff_asts(base_ast, side1_ast)
  local base_to_side2 = diff_asts(base_ast, side2_ast)

  -- Classify conflict
  if is_formatting_only(base_to_side1, base_to_side2) then
    return 'formatting'
  elseif is_rename(base_to_side1, base_to_side2) then
    return 'rename'
  elseif is_signature_change(base_to_side1, base_to_side2) then
    return 'signature'
  else
    return 'logic'
  end
end
```

**Auto-resolve formatting conflicts**:
```lua
function M.auto_resolve_formatting()
  for _, conflict in ipairs(M.conflicts) do
    if M.analyze_conflict_semantic(conflict) == 'formatting' then
      -- Run formatter, use that as resolution
      local formatted = run_formatter(conflict.base_content)
      M.resolve_conflict(conflict.id, formatted)
    end
  end
end
```

#### 8. Conflict Diff View

**Show interdiff of how each side changed from base**:

```
BASE → LOCAL:
  +function signature changed
  +added error handling

BASE → REMOTE:
  +function refactored
  +return type changed

CONFLICT:
  Both changed function signature
  Both changed return logic
```

**Implementation**:
```lua
function M.show_conflict_diffs(conflict)
  local base_to_local = compute_diff(conflict.base_content, conflict.side1_content)
  local base_to_remote = compute_diff(conflict.base_content, conflict.side2_content)

  -- Show in split windows
  show_diff_comparison({
    title = 'BASE → LOCAL vs BASE → REMOTE',
    left = base_to_local,
    right = base_to_remote,
  })
end
```

---

## Edge Cases & Risks

### Edge Case 1: Nested Conflicts

**Scenario**: Conflict contains another conflict (rare but possible)

**Risk**: Parser breaks

**Mitigation**:
- Robust parsing with proper nesting detection
- Validate parse result

### Edge Case 2: Very Large Conflicts

**Scenario**: Conflict spans thousands of lines

**Risk**: UI becomes slow

**Mitigation**:
- Virtualized scrolling
- Collapse large unchanged sections
- Allow focusing on specific regions

### Edge Case 3: Binary File Conflicts

**Scenario**: Conflict in binary file

**Risk**: Can't show meaningful diff

**Mitigation**:
- Show hex diff
- Allow choosing side without editing
- Integrate external merge tools

### Edge Case 4: Conflict During Resolution

**Scenario**: External change creates new conflicts while resolving

**Risk**: User's work lost

**Mitigation**:
- Lock working copy during resolution
- Detect external changes, warn user
- Auto-save resolution progress

### Edge Case 5: Invalid Resolution

**Scenario**: User creates syntactically invalid resolution

**Risk**: Code doesn't compile

**Mitigation**:
- Run LSP, show diagnostics
- Warn before saving invalid code
- Allow saving anyway (with confirmation)

---

## Integration with Other Tools

### Integration 1: mergiraf

**Use mergiraf for semantic merging, fall back to jj-diffconflicts for conflicts**

```lua
function M.resolve_with_mergiraf()
  -- Try mergiraf first (AST-based)
  local result = vim.fn.system({
    'mergiraf', 'merge',
    '--base', base_file,
    '--left', local_file,
    '--right', remote_file,
    '--output', output_file,
  })

  if vim.v.shell_error == 0 then
    -- mergiraf succeeded, no conflicts!
    vim.notify('Merged successfully with mergiraf')
    return
  else
    -- mergiraf found conflicts, use jj-diffconflicts
    vim.notify('Conflicts found, opening jj-diffconflicts')
    M.show_3way_merge(base_file, local_file, remote_file, output_file)
  end
end
```

### Integration 2: difftastic

**Use difftastic for better conflict diffs**:

```lua
function M.show_conflict_with_difftastic(conflict)
  local base_to_local = vim.fn.system({
    'difft',
    '--color', 'never',
    base_file,
    local_file,
  })

  local base_to_remote = vim.fn.system({
    'difft',
    '--color', 'never',
    base_file,
    remote_file,
  })

  show_diff_comparison(base_to_local, base_to_remote)
end
```

### Integration 3: delta

**Use delta for syntax-highlighted conflict diffs**:

```lua
function M.preview_resolution(conflict, resolution)
  local before = get_original_content()
  local after = apply_resolution(conflict, resolution)

  local diff = vim.fn.system({
    'delta',
    '--side-by-side',
    '--paging', 'never',
  }, before .. '\n---\n' .. after)

  show_preview(diff)
end
```

---

## Implementation Roadmap

### Phase 1: Enhanced Conflict Parsing
**Time**: 1 week

- [ ] Robust jj conflict marker parser
- [ ] Syntax highlighting for conflicts
- [ ] Conflict navigation (]x, [x)
- [ ] Resolution state tracking

### Phase 2: 3-Way Merge View
**Time**: 1-2 weeks

- [ ] BASE | LOCAL | REMOTE | RESULT layout
- [ ] Quick resolution actions (choose side)
- [ ] Live preview of resolution

### Phase 3: Partial Resolution
**Time**: 1 week

- [ ] Track resolved vs unresolved conflicts
- [ ] Progress indicator
- [ ] Jump to next unresolved

### Phase 4: Evolution Integration
**Time**: 1-2 weeks

- [ ] Show conflict evolution timeline
- [ ] Compare conflict states across evolutions
- [ ] Restore previous resolution attempts

### Phase 5: Semantic Analysis
**Time**: 2-3 weeks

- [ ] Treesitter-based conflict analysis
- [ ] Auto-resolve formatting conflicts
- [ ] Suggest likely resolutions
- [ ] Integration with mergiraf

### Phase 6: Polish
**Time**: 1 week

- [ ] Documentation
- [ ] Screencasts
- [ ] Test on complex conflicts
- [ ] Submit PRs to jj-diffconflicts upstream

---

## Success Criteria

**Minimum Viable**:
- ✅ Better than `:builtin` conflict resolution
- ✅ 3-way merge view
- ✅ Quick resolution actions
- ✅ Conflict navigation

**Fully Featured**:
- ✅ Partial resolution tracking
- ✅ Evolution timeline integration
- ✅ Semantic conflict detection
- ✅ Integration with mergiraf/difftastic

**Exceptional**:
- ✅ Auto-resolve formatting conflicts
- ✅ AI-suggested resolutions
- ✅ Conflict heat map (visual density)
- ✅ Real-time collaboration (see teammate's resolutions)

---

## Comparison to Other Conflict Tools

### vs vim-conflicted (git)

**Similarities**:
- 2-way diff interface
- Quick resolution keybindings

**Our Advantages**:
- ✅ jj-specific conflict format
- ✅ 3-way merge view (BASE visible)
- ✅ Partial resolution tracking
- ✅ Evolution timeline integration

### vs P4Merge

**Similarities**:
- 4-pane view (BASE | LOCAL | REMOTE | RESULT)

**Our Advantages**:
- ✅ Works in terminal (no GUI needed)
- ✅ Integration with nvim workflow
- ✅ jj-aware (understands evolution)

**Their Advantages**:
- ❌ Rich GUI features
- ❌ Visual merge (drag-and-drop)

### vs VS Code Merge Editor

**Similarities**:
- Visual conflict resolution
- Inline conflict markers

**Our Advantages**:
- ✅ Terminal-based (faster, scriptable)
- ✅ jj-specific features
- ✅ Deeper nvim integration

**Their Advantages**:
- ❌ More intuitive for beginners
- ❌ Better mouse support

---

## Conclusion

**Recommendation**: **Extend jj-diffconflicts** with 3-way merge view and partial resolution tracking as Phase 1

**Why**:
- Builds on proven tool
- Fills clear gap (2-way → 3-way)
- Can contribute upstream
- Quick time to value

**Approach**:
1. Fork jj-diffconflicts
2. Add 3-way merge view option
3. Add partial resolution tracking
4. Submit PRs upstream
5. If accepted, continue adding evolution integration
6. If rejected, maintain fork

**Timeline**:
- Phase 1-3: 4-6 weeks
- Phase 4-5: 3-4 weeks (if upstream accepts)
- **Total**: 2-3 months to fully-featured tool

**Next Step**: Study jj-diffconflicts codebase, prototype 3-way merge view, share with maintainer for feedback.
