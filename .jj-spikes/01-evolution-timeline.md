# Spike: Evolution Timeline Implementation

## Overview

Build a visual timeline interface showing how a jj change evolves through its lifecycle (obslog/evolog). Think "GitHub PR review timeline" but for a single change's evolution history.

## Core Concept

In jj, a **change** has a stable change ID but can go through many iterations (commit IDs). Each evolution event (rebase, squash, amend, describe) creates a new commit ID while preserving the change ID. The evolution log (`jj evolog`) shows this history, but there's no visual way to:
- See the timeline at a glance
- Quickly jump between evolutions
- Compare any two evolutions (interdiff)
- Understand what operation caused each evolution

## Technical Foundation

### How jj Tracks Evolution

**Operation Log (oplog)**:
- jj records every operation in an operation log
- Each operation contains a "view" snapshot of repo state
- Operations are linked like a blockchain (operation -> parent operation)
- Lock-free concurrent operations
- Stored in `.jj/repo/op_store/` and `.jj/repo/op_heads/`

**Evolution Tracking**:
```bash
# Current command
jj evolog -r <change-id>

# Sample output
@  mzvwutvl kyle@example.com 2025-01-23 10:34:56 8f3d2a1c
│  Add timeline UI
◉  mzvwutvl kyle@example.com 2025-01-23 10:15:23 7a2b5d4e
│  Add timeline UI  # After rebase
◉  mzvwutvl kyle@example.com 2025-01-23 09:45:12 5c1a8f3b
│  WIP timeline
◉  mzvwutvl kyle@example.com 2025-01-23 09:30:00 2d4e6f1a
   Initial timeline sketch
```

**Key Data Available**:
- Change ID (stable): `mzvwutvl`
- Commit IDs (changes): `8f3d2a1c`, `7a2b5d4e`, etc.
- Timestamps
- Descriptions
- Author info
- Operation metadata (what changed)

### Accessing jj Data Programmatically

**Option 1: CLI Wrapper (Simplest)**
```lua
-- Neovim example
local function get_evolutions(change_id)
  local output = vim.fn.systemlist({
    'jj', 'evolog', '-r', change_id,
    '--no-graph',
    '-T', 'commit_id ++ " " ++ description.first_line() ++ " " ++ committer.timestamp()'
  })

  local evolutions = {}
  for _, line in ipairs(output) do
    local commit_id, desc, timestamp = line:match('(%S+) (.*) (%d+)')
    table.insert(evolutions, {
      commit_id = commit_id,
      description = desc,
      timestamp = tonumber(timestamp),
    })
  end
  return evolutions
end
```

**Option 2: jj-lib Rust Crate (More Powerful)**
```rust
// Access full jj internals
use jj_lib::repo::Repo;
use jj_lib::commit::Commit;

fn get_change_evolutions(repo: &Repo, change_id: &ChangeId) -> Vec<Commit> {
    // Walk operation log
    // Filter commits with matching change_id
    // Return chronological list
}
```

**Option 3: Custom jj Command (Best for Complex Features)**
```rust
// Create a new jj subcommand: jj timeline
// Returns JSON for consumption by UI
jj timeline <change-id> --format=json

// Output:
{
  "change_id": "mzvwutvl",
  "evolutions": [
    {
      "commit_id": "8f3d2a1c",
      "timestamp": 1737625496,
      "description": "Add timeline UI",
      "operation": "describe",
      "parent_commit": "7a2b5d4e"
    },
    // ...
  ]
}
```

## Implementation Options

### Option A: Neovim Plugin (Lua + Telescope)

**Architecture**:
```
┌─────────────────────────────────────────┐
│  Telescope Picker                       │
│  ┌───────────────────────────────────┐  │
│  │ Evolution Timeline                │  │
│  │ ================================= │  │
│  │ > v4 (HEAD) - Add timeline UI     │  │
│  │   v3        - Add timeline UI     │  │
│  │   v2        - WIP timeline        │  │
│  │   v1        - Initial sketch      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Preview Window                         │
│  ┌───────────────────────────────────┐  │
│  │ Diff: v4 vs v3 (interdiff)        │  │
│  │ ================================= │  │
│  │ @@ -15,3 +15,5 @@                 │  │
│  │  function render_timeline()       │  │
│  │ +  add_timestamps()               │  │
│  │ +  add_navigation()               │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**Code Structure**:
```lua
-- lua/jj-timeline/init.lua
local M = {}

function M.show_evolution_timeline(change_id)
  local evolutions = get_evolutions(change_id or '@')

  require('telescope.pickers').new({}, {
    prompt_title = 'Evolution Timeline: ' .. change_id,
    finder = require('telescope.finders').new_table({
      results = evolutions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = format_evolution_entry(entry),
          ordinal = entry.commit_id,
        }
      end,
    }),
    sorter = require('telescope.config').values.generic_sorter({}),
    previewer = require('telescope.previewers').new_buffer_previewer({
      define_preview = function(self, entry, status)
        -- Show interdiff between this and previous evolution
        show_interdiff(entry.value.commit_id, get_previous(entry.value))
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<C-d>', function()
        -- Show full diff for this evolution
        local selection = action_state.get_selected_entry()
        show_full_diff(selection.value.commit_id)
      end)

      map('i', '<C-r>', function()
        -- Restore to this evolution (jj new <commit>)
        local selection = action_state.get_selected_entry()
        restore_evolution(selection.value.commit_id)
      end)

      return true
    end,
  }):find()
end

return M
```

**Keybindings**:
- `<CR>` - View full diff for this evolution
- `<C-d>` - Show interdiff (this vs previous)
- `<C-r>` - Restore to this evolution (`jj new`)
- `<C-s>` - Split view: show two evolutions side-by-side
- `d` - Delete this evolution from obslog (if possible)

**Advantages**:
- Leverages existing Telescope infrastructure
- Fast to implement (~200 lines)
- Familiar UX for nvim users
- Easy to extend

**Disadvantages**:
- Text-only timeline (no visual timeline)
- Limited to nvim users
- Interdiff performance for large changes

### Option B: Terminal TUI (Rust + Ratatui)

**Visual Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│ Evolution Timeline: mzvwutvl (Add timeline UI)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Timeline View                                              │
│  ────●────●────●────●──── (now)                             │
│      │    │    │    └─ v4 (HEAD) 10:34 "Add timeline UI"   │
│      │    │    └────── v3 10:15 "Add timeline UI" [rebase] │
│      │    └─────────── v2 09:45 "WIP timeline"             │
│      └──────────────── v1 09:30 "Initial sketch"           │
│                                                             │
│  Selected: v4 vs v3 (interdiff)                             │
│  ─────────────────────────────────────────────────────────  │
│  src/timeline.rs                                            │
│  @@ -15,3 +15,5 @@                                          │
│   fn render_timeline() {                                    │
│ +     add_timestamps();                                     │
│ +     add_navigation();                                     │
│   }                                                         │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ ←/→: Navigate | d: Diff | i: Interdiff | r: Restore | q: Quit │
└─────────────────────────────────────────────────────────────┘
```

**Architecture**:
```rust
// Using ratatui for TUI
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Terminal,
};
use jj_lib::repo::ReadonlyRepo;

struct TimelineApp {
    repo: ReadonlyRepo,
    change_id: ChangeId,
    evolutions: Vec<Evolution>,
    selected_idx: usize,
    comparison_idx: Option<usize>,
}

impl TimelineApp {
    fn new(repo: ReadonlyRepo, change_id: ChangeId) -> Self {
        let evolutions = fetch_evolutions(&repo, &change_id);
        Self {
            repo,
            change_id,
            evolutions,
            selected_idx: 0,
            comparison_idx: None,
        }
    }

    fn render_timeline(&self, area: Rect, buf: &mut Buffer) {
        // Draw timeline as ASCII art with dots
        // Highlight selected evolution
        // Show metadata inline
    }

    fn render_diff(&self, area: Rect, buf: &mut Buffer) {
        if let Some(cmp_idx) = self.comparison_idx {
            // Show interdiff between selected and comparison
            let diff = compute_interdiff(
                &self.evolutions[self.selected_idx],
                &self.evolutions[cmp_idx],
            );
            render_syntax_highlighted_diff(diff, area, buf);
        } else {
            // Show full diff for selected evolution
            let diff = compute_diff(&self.evolutions[self.selected_idx]);
            render_syntax_highlighted_diff(diff, area, buf);
        }
    }
}
```

**Advantages**:
- Beautiful visual timeline
- Standalone (works outside nvim)
- Can use jj-lib directly for better performance
- Rich interaction model

**Disadvantages**:
- More complex implementation (~1000+ lines)
- Separate tool to maintain
- Harder to integrate with editor workflows

### Option C: Web UI (TypeScript + React)

**Why Web?**
- Timeline scrubbing (slider)
- Animated transitions between evolutions
- Rich diff rendering (images, markdown, code)
- Shareable URLs

**Architecture**:
```typescript
// Backend: Rust server wrapping jj-lib
#[derive(Serialize)]
struct TimelineResponse {
    change_id: String,
    evolutions: Vec<Evolution>,
}

#[get("/timeline/<change_id>")]
fn get_timeline(change_id: String) -> Json<TimelineResponse> {
    let repo = open_repo();
    let evolutions = fetch_evolutions(&repo, &change_id);
    Json(TimelineResponse { change_id, evolutions })
}

// Frontend: React component
function EvolutionTimeline({ changeId }) {
  const [evolutions, setEvolutions] = useState([]);
  const [selectedIdx, setSelectedIdx] = useState(0);

  return (
    <div className="timeline">
      <TimelineSlider
        evolutions={evolutions}
        selected={selectedIdx}
        onChange={setSelectedIdx}
      />
      <DiffView
        from={evolutions[selectedIdx]}
        to={evolutions[selectedIdx - 1]}
      />
    </div>
  );
}
```

**Advantages**:
- Best UX potential (animations, interactions)
- Shareable (run local server, open browser)
- Rich media support

**Disadvantages**:
- Requires running server
- Not integrated with editor
- Most complex implementation

## Key Features to Implement

### 1. Timeline Visualization

**Horizontal Timeline** (preferred for evolutions):
```
[Past] ●────●────●────●──── [Now]
       v1   v2   v3   v4(HEAD)
```

**Event Annotations**:
- `[rebase]` - Change was rebased
- `[squash]` - Change absorbed another change
- `[describe]` - Description edited
- `[amend]` - Content amended
- `[conflict]` - Contains conflicts

### 2. Interdiff Computation

**Challenge**: jj doesn't have built-in interdiff command

**Solution Options**:

**Option A: Manual diff-of-diffs**:
```bash
# Get diff for v4
jj diff -r v4 > /tmp/v4.diff
# Get diff for v3
jj diff -r v3 > /tmp/v3.diff
# Diff the diffs
diff /tmp/v3.diff /tmp/v4.diff
```
Problem: Shows diff of diff format, not actual code changes

**Option B: Three-way comparison**:
```bash
# What's in v4 that's not in v3?
jj diff --from v3::parent --to v4
```
Better, but still not perfect interdiff

**Option C: Export to git, use git-range-diff**:
```bash
# If git-backed repo
git range-diff v3 v4
```

**Option D: Implement proper interdiff in jj-lib**:
```rust
fn compute_interdiff(
    repo: &Repo,
    from_commit: &Commit,
    to_commit: &Commit,
) -> Diff {
    // Get tree changes for from_commit
    let from_diff = from_commit.tree_diff_to_parent();
    // Get tree changes for to_commit
    let to_diff = to_commit.tree_diff_to_parent();

    // Compare the two diffs
    interdiff(from_diff, to_diff)
}
```

### 3. Navigation & Interaction

**Keyboard Shortcuts**:
- `j/k` or `←/→` - Navigate timeline
- `d` - Show full diff for selected evolution
- `i` - Show interdiff (selected vs previous)
- `I` - Choose two evolutions to compare
- `r` - Restore to this evolution (`jj new <commit>`)
- `e` - Edit this evolution (rare, but possible with `jj edit`)
- `y` - Yank commit ID
- `?` - Show operation that created this evolution

**Mouse Support** (for TUI/GUI):
- Click on timeline dot to select
- Drag slider to scrub through evolutions
- Scroll in diff view

### 4. Performance Optimizations

**Challenges**:
- Large evolutions (hundreds of commits in obslog)
- Large diffs (thousands of lines)
- Repeated diff computation

**Solutions**:

**Lazy Loading**:
```lua
-- Only load visible evolutions + buffer
local function get_evolutions_windowed(change_id, start_idx, count)
  -- Use jj evolog with --limit and --skip
  return parse_jj_output(
    'jj', 'evolog', '-r', change_id,
    '--limit', tostring(count),
    '--skip', tostring(start_idx)
  )
end
```

**Diff Caching**:
```lua
local diff_cache = {}

local function get_cached_diff(commit_id)
  if not diff_cache[commit_id] then
    diff_cache[commit_id] = compute_diff(commit_id)
  end
  return diff_cache[commit_id]
end
```

**Background Computation**:
```lua
-- Precompute interdiffs in background
local function precompute_interdiffs(evolutions)
  vim.defer_fn(function()
    for i = 2, #evolutions do
      get_interdiff(evolutions[i], evolutions[i-1])
    end
  end, 100)
end
```

## Edge Cases & Risks

### Edge Case 1: Very Long Evolution History

**Scenario**: A long-lived change with hundreds of evolutions

**Risk**: Timeline becomes unreadable, performance degrades

**Mitigation**:
- Pagination (show last N evolutions)
- Collapsible groups (fold old evolutions)
- Filter by time range ("last week", "last month")
- Search/jump to specific date

### Edge Case 2: Abandoned Evolutions

**Scenario**: Operations create "orphan" commits that aren't in main history

**Risk**: Timeline shows confusing branches

**Mitigation**:
- Option to show/hide abandoned evolutions
- Visual indicator (grayed out)
- Ability to compare with abandoned version

### Edge Case 3: Concurrent Evolutions

**Scenario**: Same change modified on different machines (jj's lock-free concurrency)

**Risk**: Timeline has branches/divergence

**Mitigation**:
- Show as branched timeline
- Indicate which evolution is current HEAD
- Allow comparing divergent evolutions

### Edge Case 4: No Evolution History

**Scenario**: Brand new change with only one commit

**Risk**: Empty timeline, confusing UX

**Mitigation**:
- Show helpful message: "This is the first version of this change"
- Still show full diff
- Suggest operations that would create history

### Edge Case 5: Evolution After `jj op restore`

**Scenario**: User restores old operation, creating alternate timeline

**Risk**: Timeline becomes non-linear

**Mitigation**:
- Show operation log alongside evolution log
- Visual indicator of restored operations
- "Time travel mode" showing alternate timelines

## Open Questions

### Q1: How to handle evolution metadata?

**Question**: Should we extract operation type (rebase vs amend vs squash) from operation log?

**Options**:
1. Parse operation descriptions (fragile)
2. Use operation metadata (if jj-lib exposes it)
3. Compute heuristically (compare tree changes)
4. Don't show operation type (just show diffs)

**Recommendation**: Start with option 4, add operation type later if jj-lib provides good API

### Q2: Integration with GitHub PR workflow?

**Question**: When using jj-stack, should timeline show PR iterations?

**Options**:
1. Timeline shows local evolutions only
2. Fetch PR comments/reviews via GitHub API, overlay on timeline
3. Link to GitHub PR from timeline UI

**Recommendation**: Start with 1, add 3 as enhancement

### Q3: Offline vs online operation log?

**Question**: Should timeline work without network (use local oplog only)?

**Answer**: Yes, this is a core advantage. Timeline should be purely local, using jj's oplog.

### Q4: Undo/restore from timeline?

**Question**: Should you be able to "restore" to an old evolution?

**Options**:
1. Read-only timeline (view only)
2. Allow `jj new <old-commit>` to branch from old evolution
3. Allow `jj restore` to actually revert state

**Recommendation**: Option 2 - create new change from old evolution (safe, non-destructive)

### Q5: Compare ANY two evolutions?

**Question**: Should you compare non-adjacent evolutions (e.g., v1 vs v5)?

**Answer**: Yes! This is powerful for "what changed since I started?" workflow.

**Implementation**:
- Mode 1: Navigate with arrows (always compares adjacent)
- Mode 2: "Comparison mode" - select two evolutions explicitly

## Implementation Roadmap

### Phase 1: MVP (Telescope Picker)
**Time**: 1-2 weeks

- [x] Fetch evolutions via CLI wrapper
- [x] Display in Telescope picker
- [x] Show basic diff in preview
- [x] Keybinding to view full diff
- [ ] Implement and test

### Phase 2: Interdiff Support
**Time**: 1-2 weeks

- [ ] Research interdiff computation options
- [ ] Implement interdiff algorithm
- [ ] Add "comparison mode" to picker
- [ ] Cache computed diffs

### Phase 3: Rich Timeline Visualization
**Time**: 2-3 weeks

- [ ] Design ASCII timeline art
- [ ] Add operation type annotations
- [ ] Implement timeline scrubbing
- [ ] Add filtering/search

### Phase 4: TUI or Web UI (Optional)
**Time**: 4-6 weeks

- [ ] Evaluate Rust TUI vs Web UI
- [ ] Implement standalone interface
- [ ] Add animations/rich interactions
- [ ] Integration with jj-stack

## Success Criteria

**Minimum Viable**:
- ✅ Can view evolution timeline for any change
- ✅ Can see diff for each evolution
- ✅ Can jump to any evolution quickly

**Fully Featured**:
- ✅ Interdiff between any two evolutions
- ✅ Visual timeline with metadata
- ✅ Operation type annotations
- ✅ Fast enough for large repos (Mozilla-scale)

**Exceptional**:
- ✅ Animated timeline scrubbing
- ✅ Integration with PR review workflow
- ✅ Conflict evolution tracking
- ✅ "Time travel" to explore alternate histories

## General Benefits

1. **Understand Change Evolution**: See how a change developed over time
2. **Review Iteratively**: Compare PR v2 vs v1 easily
3. **Learn from History**: "How did I solve this before?"
4. **Recover Lost Work**: Find and restore accidentally abandoned versions
5. **Debug Rebases**: See exactly what changed during rebase
6. **Explain to Others**: Share timeline to show development process

## Conclusion

**Recommendation**: Start with **Option A (Neovim Telescope)** for MVP, then evaluate TUI/Web based on adoption.

**Why**:
- Fastest to implement and validate
- Integrates with existing editor workflow
- Can iterate quickly based on feedback
- Proves core value before investing in standalone UI

**Next Steps**:
1. Prototype Telescope picker (weekend project)
2. Get feedback from jj community
3. Decide on interdiff implementation
4. Consider standalone TUI if adopted widely
