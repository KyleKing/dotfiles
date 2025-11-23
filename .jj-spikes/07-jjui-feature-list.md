# jjui Feature List & Enhancement Proposals

## Overview

jjui is a TUI (Text User Interface) for Jujutsu VCS built with Rust + ratatui. This document proposes features to add to jjui to make it the definitive TUI for jj workflows.

**Current jjui** (based on community feedback): Snappy, stable, good keybinds, useful log view

**Goal**: Make jjui comprehensive enough that users rarely need to drop to CLI

---

## Current jjui Features (Baseline)

Based on the description "jj TUI I like best so far":

- ✅ Log graph view
- ✅ Change navigation
- ✅ Diff preview
- ✅ Keybindings (intuitive, well-presented)
- ✅ Stable performance

---

## Proposed Feature Categories

### Category 1: Review Mode Enhancements

#### Feature 1.1: Dedicated Review Mode

**Description**: Separate mode optimized for reviewing changes

**Keybinding**: `R` to enter review mode

**UI Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│ Review Mode: @[working]                                     │
├──────────────┬──────────────────────────────────────────────┤
│ Files (5)    │ foo.rs                                       │
│              │                                              │
│ ✅ foo.rs    │ @@ -10,3 +10,5 @@                           │
│ ⬜ bar.rs    │  fn main() {                                 │
│ ⬜ baz.rs    │ +    println!("Hello");                      │
│ ⬜ test.rs   │ +    do_work();                              │
│ ⬜ mod.rs    │  }                                           │
│              │                                              │
│              │ [Next: bar.rs]                               │
├──────────────┴──────────────────────────────────────────────┤
│ <Space> Mark reviewed | n: Next file | p: Prev file        │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- Checkbox list of files
- Mark files as "reviewed" (✅)
- Auto-advance to next file
- Progress indicator (3/5 files reviewed)
- Persist review state (survive restart)

**Rationale**: Reviewing large changes is tedious without tracking progress

---

#### Feature 1.2: Evolution Timeline View

**Description**: Show evolution of a change (obslog) in timeline format

**Keybinding**: `E` on a change in log view

**UI Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│ Evolution Timeline: mzvwutvl                                │
├─────────────────────────────────────────────────────────────┤
│ v4 ● [HEAD] 10:34  Add timeline UI                         │
│     │ Operation: describe                                   │
│     │                                                       │
│ v3 ● 10:15  Add timeline UI                                 │
│     │ Operation: rebase                                     │
│     │                                                       │
│ v2 ● 09:45  WIP timeline                                    │
│     │ Operation: squash                                     │
│     │                                                       │
│ v1 ● 09:30  Initial timeline sketch                         │
│     │ Operation: new                                        │
│                                                             │
│ d: Diff this version | i: Interdiff | r: Restore           │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- Chronological list of evolutions
- Show operation type (rebase, squash, describe)
- Show timestamp
- Keybindings:
  - `d` - Show diff for selected evolution
  - `i` - Show interdiff (v4 vs v3)
  - `r` - Restore to this evolution
  - `y` - Yank commit ID

**Rationale**: Essential for understanding change history, no current TUI support

---

#### Feature 1.3: Interdiff Support

**Description**: Show difference between two evolutions

**Keybinding**: `I` (shift-i) in evolution timeline or log view

**Workflow**:
1. Select first commit (mark with `m`)
2. Navigate to second commit
3. Press `I` to see interdiff

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Interdiff: v3 → v4                                          │
├─────────────────────────────────────────────────────────────┤
│ foo.rs                                                      │
│ ── What changed between v3 and v4 ───────────────────────  │
│                                                             │
│ @@ -15,0 +15,2 @@                                           │
│ +    add_timestamps();    [NEW in v4]                       │
│ +    add_navigation();    [NEW in v4]                       │
│                                                             │
│ @@ -25,1 +27,0 @@                                           │
│ -    old_function();      [REMOVED in v4]                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Rationale**: Critical for iterative review, GitHub shows this in PR reviews

---

### Category 2: Change Organization

#### Feature 2.1: Interactive Squash Mode

**Description**: Visual hunk selection for `jj squash -i`

**Keybinding**: `S` (shift-s) on a change

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Squash: @ → feature-x                                       │
├──────────────────────┬──────────────────────────────────────┤
│ Hunks (6)            │ Hunk 1: foo.rs:3-5                   │
│                      │                                      │
│ ✓ Hunk 1 (foo.rs)    │ @@ -3,1 +3,3 @@                      │
│ ✓ Hunk 2 (foo.rs)    │  fn main() {                         │
│ ✗ Hunk 3 (bar.rs)    │ +    println!("debug");              │
│ ✗ Hunk 4 (bar.rs)    │ +    init();                         │
│ ✓ Hunk 5 (baz.rs)    │  }                                   │
│ ✗ Hunk 6 (test.rs)   │                                      │
│                      │                                      │
├──────────────────────┴──────────────────────────────────────┤
│ <Space> Toggle | a: All | A: None | Enter: Apply           │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- List all hunks with file info
- Toggle selection with Space
- Preview hunk on right pane
- Keyboard navigation (j/k)
- Apply on Enter

**Rationale**: `jj squash -i` is text-based and slow, visual UI is faster

---

#### Feature 2.2: Change Tree View

**Description**: Visualize change parent/child relationships as tree

**Keybinding**: `T` (tree view toggle)

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Change Tree                                                 │
├─────────────────────────────────────────────────────────────┤
│ ◉ main                                                      │
│ │                                                           │
│ ├─◉ feature-a    "Add feature A"                           │
│ │ │                                                         │
│ │ ├─◉ feature-a-1    "Subfeature 1"                        │
│ │ │                                                         │
│ │ └─◉ feature-a-2    "Subfeature 2"                        │
│ │                                                           │
│ └─◉ feature-b    "Add feature B"                           │
│   │                                                         │
│   └─@ [working]    "WIP"                                   │
│                                                             │
│ Enter: Jump to change | r: Rebase | n: New child          │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- ASCII tree visualization
- Indentation shows hierarchy
- Highlight current change
- Navigate tree with j/k
- Jump to change with Enter
- Create child change with `n`

**Rationale**: jj's change model is hierarchical, but log view is linear

---

#### Feature 2.3: Split Change UI

**Description**: Interactive UI for `jj split`

**Keybinding**: `s` on a change

**Similar to**: Squash mode, but creates two changes instead

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Split Change: feature-a                                     │
├──────────────────────────────────────────────────────────────┤
│ Select hunks for FIRST change:                             │
│ (Unselected hunks go to SECOND change)                     │
│                                                             │
│ ✓ Hunk 1 (foo.rs)  Add function                            │
│ ✓ Hunk 2 (foo.rs)  Add tests                               │
│ ✗ Hunk 3 (bar.rs)  Fix bug                                 │
│                                                             │
│ First change:  "Add feature A"                              │
│ Second change: "Fix bug"                                    │
│                                                             │
│ <Space> Toggle | e: Edit descriptions | Enter: Split       │
└─────────────────────────────────────────────────────────────┘
```

**Rationale**: `jj split` is common workflow, visual UI makes it easier

---

### Category 3: Diff & File Viewing

#### Feature 3.1: Syntax-Highlighted Diffs

**Description**: Use bat or delta for syntax highlighting in diffs

**Configuration**:
```toml
[ui]
diff.tool = "delta"  # or "difftastic" or "bat"
```

**Implementation**:
- Shell out to delta/bat
- Parse ANSI colors, render in TUI
- Fallback to plain diff if tool not available

**Rationale**: Colored diffs are much easier to read

---

#### Feature 3.2: Side-by-Side Diff Mode

**Description**: Toggle between unified and side-by-side diff

**Keybinding**: `D` (shift-d) to toggle diff mode

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ foo.rs (side-by-side)                                       │
├──────────────────────────┬──────────────────────────────────┤
│ Before                   │ After                            │
├──────────────────────────┼──────────────────────────────────┤
│ fn main() {              │ fn main() {                      │
│                          │     init();                      │
│     println!("hello");   │     println!("hello");           │
│ }                        │ }                                │
└──────────────────────────┴──────────────────────────────────┘
```

**Rationale**: Side-by-side is better for large changes

---

#### Feature 3.3: Fuzzy File Search

**Description**: Search for files in current change

**Keybinding**: `/` (opens search)

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Search files: foo█                                          │
├─────────────────────────────────────────────────────────────┤
│ > src/foo.rs                                                │
│   src/foo_test.rs                                           │
│   lib/foobar.rs                                             │
│   README.md                                                 │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- Fuzzy matching (fzf-style)
- Show matching files as you type
- Jump to file on Enter

**Rationale**: Large changes have many files, browsing is slow

---

### Category 4: Branch & Bookmark Management

#### Feature 4.1: Bookmark List View

**Description**: Show all bookmarks (branches) with metadata

**Keybinding**: `b` (bookmarks)

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Bookmarks                                                   │
├─────────────────────────────────────────────────────────────┤
│ > main          ● ● ● ●   [local + remote]                  │
│   feature-a     ● ●       [local only]                      │
│   feature-b     ● ● ●     [ahead 1]                         │
│   old-branch      ●       [remote only]                     │
│                                                             │
│ Enter: Checkout | n: New | d: Delete | p: Push             │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- List all bookmarks
- Show local/remote status
- Show commit count (dots = commits)
- Actions: checkout, create, delete, push

**Rationale**: jj bookmarks are confusing, visual UI helps

---

#### Feature 4.2: Remote Sync Status

**Description**: Show which changes are pushed/unpushed

**UI Indicator**: In log view, show symbol next to each change

```
◉ main ↑↓  "Latest work"        [ahead 2, behind 1]
◉ feature-a ↑ "Add feature"     [ahead 1]
◉ feature-b   "Old work"        [synced]
@ working ⚠  "WIP"               [not tracked]
```

**Legend**:
- `↑` - Ahead of remote (need to push)
- `↓` - Behind remote (need to pull/fetch)
- `↑↓` - Diverged
- `⚠` - No remote tracking

**Rationale**: Hard to remember what's pushed, visual indicator helps

---

### Category 5: Conflict Resolution

#### Feature 5.1: Conflict List View

**Description**: Show all files with conflicts

**Keybinding**: `C` (shift-c) if current change has conflicts

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Conflicts (3 files)                                         │
├─────────────────────────────────────────────────────────────┤
│ ⚠️  foo.rs           2 conflicts                            │
│ ⚠️  bar.rs           1 conflict                             │
│ ⚠️  baz.rs           3 conflicts                            │
│                                                             │
│ Total: 6 conflicts in 3 files                               │
│                                                             │
│ Enter: Resolve | r: Resolve all | s: Skip                  │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- List files with conflicts
- Show conflict count per file
- Open file in $EDITOR on Enter
- Track resolution progress

**Rationale**: jj allows deferred conflicts, but need to track them

---

#### Feature 5.2: Conflict Markers Highlighting

**Description**: Highlight conflict markers in diff view

**Visual**:
```
<<<<<<< Conflict 1 of 1              [RED background]
%%%%%%% Changes from base #1         [YELLOW]
-old line
+new line from side 1                [GREEN]
+++++++ Contents of side #2          [BLUE]
new line from side 2                 [CYAN]
>>>>>>> Conflict 1 of 1 ends         [RED background]
```

**Rationale**: Easier to see conflict structure

---

### Category 6: Operation Log

#### Feature 6.1: Operation Log View

**Description**: Show operation log (`jj op log`)

**Keybinding**: `O` (shift-o)

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Operation Log                                               │
├─────────────────────────────────────────────────────────────┤
│ > 10:35  snapshot working copy                              │
│   10:34  describe                                           │
│   10:15  rebase                                             │
│   09:45  squash                                             │
│   09:30  new                                                │
│                                                             │
│ Enter: View details | r: Restore to this operation         │
└─────────────────────────────────────────────────────────────┘
```

**Features**:
- Chronological list of operations
- Show operation type and time
- View affected changes on Enter
- Restore to operation with `r` (`jj op restore`)

**Rationale**: oplog is powerful but hidden, needs UI

---

#### Feature 6.2: Undo/Redo

**Description**: Quick undo/redo keybindings

**Keybindings**:
- `u` - Undo (`jj undo`)
- `Ctrl-r` - Redo (`jj undo @-`)

**UI Feedback**:
```
┌─────────────────────────────────────────────────────────────┐
│ Undid operation: rebase                                    │
│ Press Ctrl-r to redo                                        │
└─────────────────────────────────────────────────────────────┘
```

**Rationale**: Undo is common, should be one keystroke

---

### Category 7: Performance & UX

#### Feature 7.1: Lazy Loading

**Description**: Load log entries on demand (don't load entire history)

**Implementation**:
- Initially load last 100 commits
- Load more when scrolling down (infinite scroll)
- Cache loaded commits

**Rationale**: Large repos (Mozilla scale) have millions of commits

---

#### Feature 7.2: Diff Caching

**Description**: Cache computed diffs to avoid recomputation

**Implementation**:
```rust
struct DiffCache {
    cache: HashMap<(CommitId, CommitId), Vec<String>>,
}

impl DiffCache {
    fn get_diff(&mut self, from: &CommitId, to: &CommitId) -> Vec<String> {
        let key = (from.clone(), to.clone());

        if !self.cache.contains_key(&key) {
            let diff = compute_diff(from, to);  // Expensive
            self.cache.insert(key.clone(), diff);
        }

        self.cache.get(&key).unwrap().clone()
    }
}
```

**Rationale**: Recomputing diffs is slow, cache improves responsiveness

---

#### Feature 7.3: Background Refresh

**Description**: Auto-refresh UI when repo changes (external commands)

**Implementation**:
- Watch `.jj/` directory for changes
- Refresh log/status when detected
- Show notification: "Repo updated externally"

**Rationale**: Running jj commands in parallel terminals is common

---

### Category 8: Integration & Extensibility

#### Feature 8.1: Custom Keybindings

**Description**: User-configurable keybindings

**Config File**: `~/.config/jjui/config.toml`
```toml
[keybindings]
evolution_timeline = "E"
review_mode = "R"
squash_mode = "S"
```

**Rationale**: Users have different preferences

---

#### Feature 8.2: Plugin System

**Description**: Allow Lua plugins to extend jjui

**Example Plugin**:
```lua
-- ~/.config/jjui/plugins/github.lua
function on_change_selected(change)
  -- Fetch GitHub PR status for this change
  local pr = fetch_pr_for_change(change.id)

  if pr then
    show_notification("PR #" .. pr.number .. ": " .. pr.status)
  end
end
```

**Rationale**: Community can add features without forking

---

### Category 9: GitHub Integration (via jj-stack)

#### Feature 9.1: PR Status Display

**Description**: Show GitHub PR status in log view

**UI**:
```
◉ main #123 ✅ "Merged PR"
◉ feature-a #124 🔄 "CI running"
@ working (no PR)
```

**Legend**:
- `#123` - PR number
- `✅` - Merged
- `🔄` - Open
- `❌` - Closed
- `⏸` - Draft

**Rationale**: Visibility into PR status without leaving TUI

---

#### Feature 9.2: Create PR from TUI

**Description**: Create GitHub PR directly from jjui

**Keybinding**: `P` (shift-p) on a change

**UI**:
```
┌─────────────────────────────────────────────────────────────┐
│ Create Pull Request                                         │
├─────────────────────────────────────────────────────────────┤
│ Title: █                                                    │
│                                                             │
│ Description:                                                │
│ ┌─────────────────────────────────────────────────────────┐│
│ ││                                                         ││
│ ││                                                         ││
│ │└─────────────────────────────────────────────────────────┘│
│                                                             │
│ Base: main                                                  │
│ Draft: [ ] Yes                                              │
│                                                             │
│ Enter: Create | Esc: Cancel                                 │
└─────────────────────────────────────────────────────────────┘
```

**Implementation**: Use `jj-stack` or `gh` CLI

**Rationale**: Avoid context switch to browser

---

## Implementation Priority

### P0 (Essential - MVP)
1. Evolution Timeline View
2. Interdiff Support
3. Review Mode
4. Interactive Squash Mode

### P1 (High Value)
5. Change Tree View
6. Syntax-Highlighted Diffs
7. Operation Log View
8. Undo/Redo keybindings

### P2 (Nice to Have)
9. Conflict List View
10. Bookmark Management
11. Side-by-Side Diff
12. Fuzzy File Search

### P3 (Future)
13. GitHub Integration
14. Plugin System
15. Background Refresh
16. Split Change UI

---

## Contribution Strategy

### Approach 1: Incremental PRs

**Plan**:
1. Start with P0 features (one PR each)
2. Get feedback from maintainer (idursun)
3. Iterate based on feedback
4. Move to P1 features

**Pros**: Low risk, builds relationship with maintainer

**Cons**: Slower progress, may get rejected

---

### Approach 2: Fork with Features

**Plan**:
1. Fork jjui
2. Implement all P0 features in fork
3. Release as `jjui-enhanced`
4. Offer to merge back upstream

**Pros**: Complete control, faster iteration

**Cons**: Maintenance burden, may fragment community

---

### Approach 3: Hybrid

**Plan**:
1. Implement Evolution Timeline (P0.1) in fork
2. Submit PR to upstream
3. If accepted → continue with PRs
4. If rejected → continue in fork

**Recommendation**: **Approach 3 (Hybrid)**

**Why**: Validates maintainer receptiveness early, provides fallback

---

## Technical Implementation Notes

### Using jj-lib

jjui already uses `jj-lib` (Rust crate). New features can leverage:

```rust
use jj_lib::repo::Repo;
use jj_lib::commit::Commit;
use jj_lib::op_store::OperationStore;

// Get evolutions
fn get_evolutions(repo: &Repo, change_id: &ChangeId) -> Vec<Commit> {
    // Walk operation log
    // Filter commits with matching change ID
    // Return chronological list
}

// Compute interdiff
fn compute_interdiff(repo: &Repo, from: &Commit, to: &Commit) -> Diff {
    let from_diff = from.tree_diff();
    let to_diff = to.tree_diff();

    interdiff(from_diff, to_diff)
}
```

### UI Framework: ratatui

jjui uses `ratatui`. Features will use widgets:

```rust
use ratatui::{
    widgets::{Block, Borders, List, ListItem, Paragraph},
    layout::{Layout, Constraint, Direction},
};

fn render_evolution_timeline(frame: &mut Frame, area: Rect, evolutions: &[Evolution]) {
    let items: Vec<ListItem> = evolutions
        .iter()
        .map(|e| ListItem::new(format!("v{} - {}", e.version, e.description)))
        .collect();

    let list = List::new(items)
        .block(Block::default().title("Evolution Timeline").borders(Borders::ALL));

    frame.render_widget(list, area);
}
```

---

## Success Metrics

**Adoption**:
- ✅ 500+ GitHub stars
- ✅ Mentioned in jj official docs
- ✅ Used by jj core contributors

**Features**:
- ✅ All P0 features implemented
- ✅ 50% of P1 features implemented

**Community**:
- ✅ 3+ external contributors
- ✅ Featured on Hacker News / r/rust

---

## Conclusion

**Recommendation**: Implement **P0 features** (Evolution Timeline, Interdiff, Review Mode, Squash Mode) in 2-3 months

**Approach**: Hybrid (PR first feature, fork if rejected)

**Timeline**:
- Month 1: Evolution Timeline + Interdiff
- Month 2: Review Mode + Squash Mode
- Month 3: Polish, documentation, release

**Next Step**: Study jjui codebase, prototype Evolution Timeline, submit PR to test waters.
