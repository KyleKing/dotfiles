# Spike: Change Canvas Implementation

## Overview

Build a GitButler-inspired spatial UI where you can visually organize code changes into different jj changes by dragging hunks/files between "lanes" (kanban-style columns). Each lane represents a change, and the canvas provides real-time feedback as you reorganize.

## Core Concept

**Problem**: The `jj squash -i` workflow is text-based and slow. You select hunks in a terminal editor, can't see the result until you commit, and can't easily reorganize between multiple destination changes.

**Solution**: A visual canvas where:
- Each column is a jj change
- Files/hunks are cards you can drag between columns
- Changes happen in real-time (live preview)
- Underlying `jj` commands execute automatically

**Mental Model**:
```
┌─────────────────────────────────────────────────────────────┐
│  Change Canvas                                              │
├──────────────┬──────────────┬──────────────┬───────────────┤
│ @ (Working)  │ Feature A    │ Feature B    │ Bugfix        │
├──────────────┼──────────────┼──────────────┼───────────────┤
│ ┌──────────┐ │ ┌──────────┐ │ ┌──────────┐ │ ┌───────────┐│
│ │ file1.rs │ │ │ file2.rs │ │ │ file4.rs │ │ │ file5.rs  ││
│ │  + 15    │ │ │  + 8     │ │ │  + 12    │ │ │  + 3      ││
│ │  - 3     │ │ │  - 2     │ │ │  - 5     │ │ │  - 1      ││
│ └──────────┘ │ └──────────┘ │ └──────────┘ │ └───────────┘│
│              │              │              │               │
│ ┌──────────┐ │              │ ┌──────────┐ │               │
│ │ file3.rs │ │              │ │ Hunk 2   │ │               │
│ │ Hunk 1   │ │              │ │ from     │ │               │
│ │ + 5, -2  │ │              │ │ file6.rs │ │               │
│ └──────────┘ │              │ └──────────┘ │               │
└──────────────┴──────────────┴──────────────┴───────────────┘

[Drag file1.rs from @ to Feature A]
  ↓
[Executes: jj squash --from @ --into <feature-a-id> file1.rs]
```

## How GitButler Does It

**GitButler's Virtual Branches**:
- Modifies git index to look like union of all branches
- Changes are assigned to virtual branches
- Drag-and-drop reassigns ownership
- Real-time updates to working directory

**Key Innovation**: All changes are applied simultaneously to working directory, but committed to separate branches.

**How it works (simplified)**:
1. Scan working directory for all changes
2. Parse hunks and assign to virtual branches (stored in `.git/gitbutler`)
3. When you drag hunk from Branch A → Branch B, update metadata
4. Rebuild index to reflect new assignments
5. Continue working with all changes visible

**Challenges for git**:
- Complex index manipulation
- State stored in separate database
- Requires custom git operations

**Advantages for jj**:
- jj's working copy is already a commit (@)
- `jj squash` is designed for moving changes
- `jj new` creates changes easily
- No staging area to fight with

## jj-Specific Implementation Strategy

### Core jj Primitives

**1. Create new change**:
```bash
jj new @ -m "Feature A"  # Creates new change, becomes @
jj new <commit> -m "Feature B"  # Create change at specific location
```

**2. Move hunks between changes**:
```bash
# Move entire file from @ to another change
jj squash --from @ --into <change-id> <file>

# Move specific hunks interactively
jj squash -i --from @ --into <change-id>

# Move ALL changes from @ into change
jj squash --from @ --into <change-id>
```

**3. Split working copy**:
```bash
jj split  # Interactively split @ into two changes
```

**Insight**: The canvas is essentially a visual multiplexer for these commands!

### Architecture Option A: Stateless Canvas (Safest)

**Philosophy**: Canvas is a VIEW, not SOURCE OF TRUTH. jj repo state is the source of truth.

**Flow**:
1. Scan repo state with `jj status`, `jj log`
2. Build canvas representation
3. User drags hunk
4. Execute `jj squash` command
5. Re-scan repo state
6. Rebuild canvas

**Advantages**:
- No state management
- Always in sync with jj
- Can't corrupt repo

**Disadvantages**:
- Slower (re-scan after each operation)
- Potential flickering UI
- May lose user context during re-render

**Implementation (Pseudocode)**:
```rust
struct Canvas {
    repo_path: PathBuf,
}

impl Canvas {
    fn render(&self) -> Vec<Lane> {
        let changes = run_jj_log();
        let status = run_jj_status();

        // Build lane for each change
        let mut lanes = vec![];

        // Lane 1: Working copy (@)
        let working_lane = Lane {
            title: "@".to_string(),
            change_id: get_current_change_id(),
            items: status.modified_files.iter().map(|f| {
                LaneItem::File {
                    path: f.path.clone(),
                    hunks: parse_hunks(f),
                }
            }).collect(),
        };
        lanes.push(working_lane);

        // Lane 2+: Other active changes
        for change in changes.iter().filter(|c| c.is_head) {
            lanes.push(Lane {
                title: change.description.clone(),
                change_id: change.id.clone(),
                items: get_files_in_change(change),
            });
        }

        lanes
    }

    fn move_file(&mut self, file: PathBuf, from_lane: &str, to_lane: &str) {
        // Execute jj command
        run_command(&[
            "jj", "squash",
            "--from", from_lane,
            "--into", to_lane,
            file.to_str().unwrap()
        ]);

        // Re-render (canvas rebuilds from repo state)
        self.render();
    }
}
```

### Architecture Option B: Stateful Canvas (More Complex)

**Philosophy**: Canvas maintains its own state, syncs with jj periodically.

**Flow**:
1. Initialize canvas from repo state
2. User drags hunks (update canvas state immediately)
3. Queue jj commands in background
4. Execute commands asynchronously
5. Periodically reconcile with jj state

**Advantages**:
- Faster UI (immediate feedback)
- Can batch operations
- Smoother UX

**Disadvantages**:
- State divergence risk
- Need conflict resolution between canvas and jj
- More complex implementation

**Implementation**:
```rust
struct StatefulCanvas {
    repo_path: PathBuf,
    lanes: Vec<Lane>,
    pending_operations: VecDeque<Operation>,
    jj_watcher: FileSystemWatcher,
}

impl StatefulCanvas {
    fn new(repo_path: PathBuf) -> Self {
        let lanes = Self::load_from_repo(&repo_path);
        let watcher = watch_jj_repo(&repo_path);

        Self {
            repo_path,
            lanes,
            pending_operations: VecDeque::new(),
            jj_watcher: watcher,
        }
    }

    fn move_file(&mut self, file: PathBuf, from: usize, to: usize) {
        // Update canvas state immediately
        let item = self.lanes[from].remove_file(&file);
        self.lanes[to].add_file(item);

        // Queue operation
        self.pending_operations.push_back(Operation::Squash {
            file,
            from: self.lanes[from].change_id.clone(),
            to: self.lanes[to].change_id.clone(),
        });

        // Execute in background
        self.execute_pending();
    }

    fn execute_pending(&mut self) {
        while let Some(op) = self.pending_operations.pop_front() {
            match op {
                Operation::Squash { file, from, to } => {
                    run_jj_squash(&from, &to, &file);
                }
                // other operations
            }
        }

        // Reconcile with jj state
        self.sync_with_repo();
    }

    fn sync_with_repo(&mut self) {
        let jj_state = Self::load_from_repo(&self.repo_path);

        // Merge jj_state with self.lanes
        // Handle conflicts (jj wins)
        for (idx, lane) in jj_state.iter().enumerate() {
            if self.lanes.get(idx).map(|l| &l.change_id) != Some(&lane.change_id) {
                // State diverged, reload from jj
                self.lanes = jj_state;
                return;
            }
        }
    }
}
```

### Architecture Option C: Hybrid (Recommended)

**Philosophy**: Optimistic UI updates, but validate with jj immediately.

**Flow**:
1. User drags hunk → update UI immediately (optimistic)
2. Execute `jj squash` in background
3. If success → keep UI as-is
4. If failure → revert UI, show error
5. Periodic background sync to catch external changes

**Advantages**:
- Fast UI (feels instant)
- Safe (validates with jj)
- Handles external changes (other terminals)

**Implementation**:
```rust
struct HybridCanvas {
    lanes: Vec<Lane>,
    optimistic_state: HashMap<String, LaneItem>,
    jj_executor: JJCommandExecutor,
}

impl HybridCanvas {
    fn move_file(&mut self, file: PathBuf, from_idx: usize, to_idx: usize) {
        // Store current state for rollback
        let backup = self.lanes.clone();

        // Optimistic update
        let item = self.lanes[from_idx].remove_file(&file);
        self.lanes[to_idx].add_file(item.clone());
        self.optimistic_state.insert(file.to_string(), item);

        // Execute jj command asynchronously
        let from_id = self.lanes[from_idx].change_id.clone();
        let to_id = self.lanes[to_idx].change_id.clone();

        self.jj_executor.execute(
            JJCommand::Squash {
                file: file.clone(),
                from: from_id,
                to: to_id,
            },
            move |result| {
                match result {
                    Ok(_) => {
                        // Success! Remove from optimistic state
                        self.optimistic_state.remove(&file.to_string());
                    }
                    Err(e) => {
                        // Rollback optimistic update
                        self.lanes = backup;
                        self.show_error(format!("Failed to move file: {}", e));
                    }
                }
            }
        );
    }
}
```

## UI Implementation Options

### Option 1: Terminal TUI (Ratatui)

**Can you do drag-and-drop in terminal?**

**Answer**: Yes, but limited!

**Approaches**:

**A. Keyboard-driven "dragging"**:
```
1. Select file/hunk (Enter)
2. Navigate to destination lane (←/→)
3. Confirm move (Enter)
```

**B. Mouse support** (via crossterm):
```rust
use crossterm::event::{Event, MouseEvent, MouseEventKind};

match event::read()? {
    Event::Mouse(MouseEvent {
        kind: MouseEventKind::Down(_),
        column,
        row,
        ..
    }) => {
        // Check if clicked on a hunk
        if let Some(item) = find_item_at(column, row) {
            selected_item = Some(item);
        }
    }
    Event::Mouse(MouseEvent {
        kind: MouseEventKind::Drag(_),
        column,
        row,
        ..
    }) => {
        // Update drag indicator
        drag_position = (column, row);
    }
    Event::Mouse(MouseEvent {
        kind: MouseEventKind::Up(_),
        column,
        row,
        ..
    }) => {
        // Drop item at new location
        if let Some(item) = selected_item.take() {
            if let Some(target_lane) = find_lane_at(column, row) {
                move_item(item, target_lane);
            }
        }
    }
}
```

**Visual Example**:
```
┌─────────────────────────────────────────────────────────┐
│ Change Canvas                          [?] Help         │
├──────────────┬──────────────┬──────────────┬────────────┤
│ @ (Working)  │ Feature A ✓  │ Feature B    │ Bugfix     │
├──────────────┼──────────────┼──────────────┼────────────┤
│ > file1.rs   │ file2.rs     │ file4.rs     │ file5.rs   │
│   +15  -3    │ +8  -2       │ +12  -5      │ +3  -1     │
│   [SELECTED] │              │              │            │
│              │              │              │            │
│ file3.rs     │              │ file6.rs     │            │
│ +5  -2       │              │ Hunk 1       │            │
│              │              │ +3  -1       │            │
└──────────────┴──────────────┴──────────────┴────────────┘
Keys: ↑↓ Navigate | Enter Select | ←→ Move lane | m Move here | n New lane | q Quit
```

**Pros**:
- Works in terminal
- No GUI dependencies
- Fast

**Cons**:
- Less intuitive than GUI drag-and-drop
- Mouse support varies by terminal
- Limited visual polish

### Option 2: Native GUI (egui / iced)

**Why egui**:
- Pure Rust
- Immediate mode (simple state management)
- Great for prototyping

**Example Layout**:
```rust
use eframe::egui;

struct ChangeCanvas {
    lanes: Vec<Lane>,
    dragging: Option<DragState>,
}

impl eframe::App for ChangeCanvas {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.horizontal(|ui| {
                for (lane_idx, lane) in self.lanes.iter_mut().enumerate() {
                    ui.vertical(|ui| {
                        ui.heading(&lane.title);
                        ui.separator();

                        for item in &lane.items {
                            let response = ui.add(
                                egui::Button::new(format!("{} (+{} -{})",
                                    item.path, item.additions, item.deletions))
                            );

                            // Drag source
                            if response.drag_started() {
                                self.dragging = Some(DragState {
                                    item: item.clone(),
                                    from_lane: lane_idx,
                                });
                            }

                            // Drop target
                            if let Some(ref drag) = self.dragging {
                                if response.hovered() && drag.from_lane != lane_idx {
                                    if response.drag_released() {
                                        self.move_item(drag.item.clone(), lane_idx);
                                        self.dragging = None;
                                    }
                                }
                            }
                        }
                    });
                }
            });
        });
    }
}
```

**Pros**:
- True drag-and-drop
- Beautiful UI
- Rich interactions

**Cons**:
- Separate GUI app (not integrated with editor)
- Requires running GUI
- Cross-platform complexity

### Option 3: Web UI (Tauri + React)

**Why Tauri**:
- Rust backend (can use jj-lib directly)
- Web frontend (rich UI)
- Native app packaging

**Architecture**:
```
┌─────────────────────────────────────────┐
│  Tauri App                              │
│  ┌─────────────────────────────────┐    │
│  │ Frontend (React + DnD Kit)      │    │
│  │ - Drag-and-drop kanban          │    │
│  │ - Real-time updates             │    │
│  │ - Syntax-highlighted diffs      │    │
│  └─────────────────────────────────┘    │
│               ↕ IPC                     │
│  ┌─────────────────────────────────┐    │
│  │ Backend (Rust + jj-lib)         │    │
│  │ - Execute jj commands           │    │
│  │ - Watch filesystem              │    │
│  │ - Parse diffs                   │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

**Backend (Rust)**:
```rust
#[tauri::command]
fn move_file(from_change: String, to_change: String, file_path: String) -> Result<(), String> {
    let repo = open_repo()?;

    // Execute jj squash
    run_jj_command(&[
        "squash",
        "--from", &from_change,
        "--into", &to_change,
        &file_path
    ])?;

    Ok(())
}

#[tauri::command]
fn get_canvas_state() -> Result<CanvasState, String> {
    let repo = open_repo()?;
    let changes = list_changes(&repo)?;
    let status = get_status(&repo)?;

    Ok(CanvasState { changes, status })
}
```

**Frontend (React + DnD Kit)**:
```typescript
import { DndContext, DragEndEvent } from '@dnd-kit/core';
import { invoke } from '@tauri-apps/api/tauri';

function ChangeCanvas() {
  const [lanes, setLanes] = useState<Lane[]>([]);

  useEffect(() => {
    invoke('get_canvas_state').then((state) => setLanes(state.changes));
  }, []);

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;

    if (over && active.id !== over.id) {
      const fromLane = lanes.find(l => l.items.some(i => i.id === active.id));
      const toLane = lanes.find(l => l.id === over.id);

      invoke('move_file', {
        fromChange: fromLane.changeId,
        toChange: toLane.changeId,
        filePath: active.data.current.path,
      });
    }
  };

  return (
    <DndContext onDragEnd={handleDragEnd}>
      <div className="canvas">
        {lanes.map(lane => (
          <Lane key={lane.id} lane={lane} />
        ))}
      </div>
    </DndContext>
  );
}
```

**Pros**:
- Best UX (smooth drag-and-drop)
- Rich visualizations
- Can show syntax-highlighted diffs inline

**Cons**:
- Most complex implementation
- Requires running separate app
- Not integrated with editor workflow

### Option 4: Neovim Floating Windows (Lua)

**Can you do kanban in nvim?**

**Answer**: Sort of!

**Approach**: Use floating windows as "lanes"

```lua
local M = {}

function M.show_change_canvas()
  local width = vim.o.columns
  local height = vim.o.lines

  local lane_width = math.floor(width / 4)

  -- Create 4 floating windows (4 lanes)
  local lanes = {}
  for i = 1, 4 do
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
      relative = 'editor',
      width = lane_width - 2,
      height = height - 4,
      col = (i - 1) * lane_width,
      row = 2,
      style = 'minimal',
      border = 'rounded',
    })
    table.insert(lanes, { buf = buf, win = win })
  end

  -- Populate lanes
  populate_lane(lanes[1], '@', get_working_copy_files())
  populate_lane(lanes[2], 'Feature A', get_change_files('feature-a'))
  -- ...

  -- Set up keybindings
  vim.keymap.set('n', 'm', function()
    -- Move selected file to next lane
    move_file_to_lane()
  end, { buffer = lanes[1].buf })
end

return M
```

**Interaction Model**:
- `j/k` - Navigate files in current lane
- `l/h` - Switch between lanes
- `m` - Move selected file to current lane
- `v` - Visual mode to select multiple files
- `q` - Close canvas

**Pros**:
- Integrated with nvim
- No separate app needed
- Familiar keybindings

**Cons**:
- Not true drag-and-drop
- Limited visual polish
- Complex floating window management

## Key Features

### 1. Lane Management

**Create new lane**:
```bash
jj new @ -m "New Feature"
```

**Delete lane**:
```bash
jj abandon <change-id>
```

**Rename lane**:
```bash
jj describe <change-id> -m "New Description"
```

**Reorder lanes**: Visual only (doesn't change jj structure)

### 2. Item Granularity

**File-level** (easier):
- Drag entire files between changes
- Execute `jj squash --from X --into Y file.rs`

**Hunk-level** (harder):
- Drag individual hunks
- Requires parsing diffs
- Execute `jj squash -i` with automated hunk selection

**Line-level** (hardest):
- Drag individual lines
- Very complex diff manipulation
- Maybe not worth it (diminishing returns)

**Recommendation**: Start with file-level, add hunk-level in v2

### 3. Visual Indicators

**File states**:
- 🟢 New file
- 🟡 Modified
- 🔴 Deleted
- ⚠️ Conflicted

**Change states**:
- ✅ Clean (no conflicts)
- ⚠️ Has conflicts
- 📝 Has description
- 🔗 Pushed to remote

**Diff previews**:
- Hover over file → show mini-diff
- Click file → expand full diff inline

### 4. Real-time Sync

**Challenge**: Multiple terminals/editors might modify repo

**Solution**: Watch filesystem for changes

```rust
use notify::{Watcher, RecursiveMode, Event};

let (tx, rx) = std::sync::mpsc::channel();
let mut watcher = notify::recommended_watcher(tx)?;

watcher.watch(repo_path.join(".jj"), RecursiveMode::Recursive)?;

// In event loop
for event in rx {
    match event {
        Event::Modify(_) => {
            // Repo changed, re-sync canvas
            self.sync_with_repo();
        }
    }
}
```

## Edge Cases & Risks

### Edge Case 1: Circular Dependencies

**Scenario**: Change A depends on Change B, you try to move file from B to A

**Risk**: Creates circular dependency or invalid state

**Mitigation**:
- Check dependencies before move
- Warn user
- Suggest `jj rebase` to restructure

### Edge Case 2: Conflicted Files

**Scenario**: File has unresolved conflicts

**Risk**: Moving conflicts between changes might create worse state

**Mitigation**:
- Visual indicator (⚠️)
- Require conflict resolution before move
- OR allow move but propagate conflict markers

### Edge Case 3: Partial Hunks

**Scenario**: User wants to move only part of a hunk

**Risk**: Requires manual diff editing

**Mitigation**:
- Support hunk-level moves
- For finer granularity, fall back to `jj squash -i`

### Edge Case 4: External Changes

**Scenario**: Another process modifies repo while canvas is open

**Risk**: Canvas state diverges from jj

**Mitigation**:
- Filesystem watcher detects changes
- Show warning: "Repo modified externally"
- Option to reload or diff changes

### Edge Case 5: Large Repos

**Scenario**: Repo with thousands of files

**Risk**: Canvas becomes cluttered

**Mitigation**:
- Virtual scrolling (only render visible items)
- Search/filter files
- Collapse unchanged files

## Open Questions

### Q1: How many lanes to show?

**Options**:
1. Fixed 4 lanes
2. Dynamic (1 lane per active change)
3. User configurable

**Recommendation**: Dynamic, max 6 visible, scroll for more

### Q2: Should canvas modify @ (working copy)?

**Question**: When you move file from @ to another change, does it disappear from working directory?

**Options**:
1. Yes - `jj squash` removes from @ (current jj behavior)
2. No - keep in @ but marked as "committed elsewhere" (GitButler style)

**Recommendation**: Option 1 (follow jj semantics), but show undo button

### Q3: Integration with jj-stack?

**Question**: Should canvas be aware of GitHub PRs?

**Answer**: Not initially. Keep canvas focused on local workflow.

### Q4: Conflict resolution in canvas?

**Question**: Should you be able to resolve conflicts visually?

**Answer**: No, too complex. Delegate to dedicated conflict tool (jj-diffconflicts).

### Q5: Nested changes?

**Question**: jj supports change trees (child changes). How to visualize?

**Options**:
1. Flat lanes (ignore hierarchy)
2. Nested lanes (sub-columns)
3. Tree view sidebar + flat lanes

**Recommendation**: Start with option 1, add tree view in v2

## Implementation Roadmap

### Phase 1: Proof of Concept (TUI)
**Time**: 2-3 weeks

- [ ] Basic ratatui layout (3 lanes)
- [ ] List files in each lane
- [ ] Keyboard-driven file moving
- [ ] Execute `jj squash` commands
- [ ] Re-sync after each move

### Phase 2: Enhanced TUI
**Time**: 2-3 weeks

- [ ] Mouse support for dragging
- [ ] Hunk-level granularity
- [ ] Diff previews
- [ ] Create/delete lanes
- [ ] Filesystem watcher

### Phase 3: GUI (Optional)
**Time**: 4-6 weeks

- [ ] Choose framework (egui vs Tauri)
- [ ] Implement true drag-and-drop
- [ ] Rich diff rendering
- [ ] Animations
- [ ] Polish UX

### Phase 4: Integration
**Time**: 2 weeks

- [ ] nvim integration (`:JJCanvas`)
- [ ] Config file support
- [ ] Documentation
- [ ] Screencasts

## Success Criteria

**Minimum Viable**:
- ✅ View all changes as lanes
- ✅ Move files between changes
- ✅ Executes `jj squash` correctly
- ✅ Stays in sync with repo

**Fully Featured**:
- ✅ Hunk-level moves
- ✅ Diff previews
- ✅ Real-time sync
- ✅ Mouse drag-and-drop

**Exceptional**:
- ✅ Beautiful GUI
- ✅ Conflict visualization
- ✅ Undo/redo stack
- ✅ Integration with Evolution Timeline

## General Benefits

1. **Visual Organization**: See all your changes at once
2. **Faster Workflow**: Drag-and-drop is faster than `jj squash -i`
3. **Experimentation**: Easy to try different organizations
4. **Learning**: Makes jj's change model more intuitive
5. **Multi-change Workflows**: Managing stacked changes becomes trivial

## Risks

1. **Complexity**: State synchronization with jj is non-trivial
2. **UX Limitations**: Terminal drag-and-drop is clunky
3. **Scope Creep**: Easy to over-engineer
4. **jj API Changes**: If jj internals change, may break
5. **Adoption**: Requires learning new tool

## Conclusion

**Recommendation**: Start with **TUI proof-of-concept** to validate idea, then evaluate GUI based on feedback.

**Why**:
- TUI is faster to implement
- Validates core workflow
- Can test with real users quickly
- Easier to integrate with terminal-based workflows

**Alternative**: If TUI proves too limiting, pivot to **Tauri web UI** for richer interactions.

**Next Steps**:
1. Build basic TUI (weekend project)
2. Test with real jj workflow
3. Gather feedback on UX
4. Decide GUI vs enhanced TUI
