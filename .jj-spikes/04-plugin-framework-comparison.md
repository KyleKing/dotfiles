# Spike: Plugin Framework Comparison

## Overview

Compare three approaches for building jj nvim tooling:
1. **Extend hunk.nvim** - Existing jj diff-editor
2. **Extend jj.nvim** - Existing jj wrapper plugin
3. **Build with mini.nvim** - Composable modules
4. **Start Fresh** - New standalone plugin

## Option 1: Extend hunk.nvim

### Current State

**Repository**: https://github.com/julienvincent/hunk.nvim

**Purpose**: Diff editor for Jujutsu (alternative to `:builtin`)

**Features**:
- Split view showing left/right of each file
- Select lines from each hunk to keep
- Accept changes to modify output directory
- Designed specifically for jj diff-editing

**Current Code Structure** (estimated):
```
hunk.nvim/
├── lua/
│   └── hunk/
│       ├── init.lua          # Main entry point
│       ├── ui.lua             # UI rendering
│       ├── diff_parser.lua    # Parse jj diff output
│       └── hunks.lua          # Hunk selection logic
├── plugin/
│   └── hunk.lua              # Auto-commands
└── README.md
```

### Pros of Extending hunk.nvim

✅ **Already jj-focused**: Built specifically for jj workflows

✅ **Solves real problem**: `jj squash -i` replacement

✅ **Active development**: Recent commits, maintained

✅ **Narrow scope**: Focused on diff-editing, easy to understand

✅ **Existing users**: Has traction in jj community

### Cons of Extending hunk.nvim

❌ **Limited scope**: Only does diff-editing, not broader jj integration

❌ **May reject PRs**: Maintainer might not want feature creep

❌ **Architecture constraints**: Built for diff-editor use case, may not support timeline/canvas

❌ **Dependency risk**: Plugin could be abandoned

### What You Could Add to hunk.nvim

**1. Multi-target squashing**:
```lua
-- Current: Choose hunks to keep (binary: keep or discard)
-- Enhanced: Choose destination change per hunk

hunk.select_destination = function(hunks)
  -- Show picker: Which change should this hunk go to?
  telescope.pick_change({
    on_select = function(change_id)
      apply_hunk_to_change(hunks, change_id)
    end
  })
end
```

**2. Preview mode**:
```lua
-- Show preview of result before committing
hunk.preview_result = function()
  local selected_hunks = get_selected_hunks()
  local preview = build_file_from_hunks(selected_hunks)

  show_preview_window(preview)
end
```

**3. Better hunk navigation**:
```lua
-- Jump between hunks with ]h / [h
-- Filter hunks by pattern
-- Collapse/expand hunks
```

**4. Integration with evolution timeline**:
```lua
-- View evolution of hunks across commits
hunk.show_hunk_history = function(hunk_id)
  local evolutions = find_hunk_in_evolution(hunk_id)
  show_timeline(evolutions)
end
```

### Recommendation for hunk.nvim

**Verdict**: ⭐⭐⭐⭐ Good for `jj squash -i` replacement, but limited for broader vision

**Best Use Case**: If you ONLY want to improve the diff-editor experience

**Approach**:
1. Fork hunk.nvim
2. Add multi-target squashing
3. Add preview mode
4. Submit PRs upstream

**Don't use if**: You want evolution timeline, change canvas, or real-time integration

---

## Option 2: Extend jj.nvim

### Current State

**Repository**: https://github.com/NicolasGB/jj.nvim

**Purpose**: "Drive Jujutsu from Neovim like a pro" (vim-fugitive for jj)

**Current Features** (based on README):
- Basic jj command wrappers
- Status window
- Log viewer
- Commit/amend functionality

**Estimated Code Structure**:
```
jj.nvim/
├── lua/
│   └── jj/
│       ├── init.lua          # Setup and main API
│       ├── commands.lua       # :JJ commands
│       ├── status.lua         # Status window
│       ├── log.lua            # Log viewer
│       ├── diff.lua           # Diff functionality
│       └── utils.lua          # Helper functions
├── plugin/
│   └── jj.lua                # Command definitions
└── README.md
```

### Pros of Extending jj.nvim

✅ **Broad scope**: Aims to be comprehensive jj plugin

✅ **vim-fugitive model**: Familiar pattern for git users

✅ **Extensible**: Architecture likely supports adding features

✅ **Active development**: Recent activity

✅ **Community**: Growing user base

### Cons of Extending jj.nvim

❌ **Early stage**: May have bugs, incomplete features

❌ **Maintenance risk**: Single maintainer (NicolasGB)

❌ **Architecture unknown**: Would need to study codebase

❌ **May diverge from vision**: Maintainer's roadmap might conflict

### What You Could Add to jj.nvim

**1. Evolution timeline**:
```lua
-- New module: lua/jj/evolution.lua
require('jj.evolution').show_timeline(change_id)
```

**2. Change canvas**:
```lua
-- New module: lua/jj/canvas.lua
require('jj.canvas').show()
```

**3. Real-time integration**:
```lua
-- Enhance: lua/jj/init.lua
require('jj').setup({
  auto_snapshot = true,
  watchman = true,
  live_diff = true,
})
```

**4. Better diff-editor**:
```lua
-- Enhance: lua/jj/diff.lua
-- Integrate hunk.nvim or build better squash UI
```

### Recommendation for jj.nvim

**Verdict**: ⭐⭐⭐⭐⭐ Best option for comprehensive jj integration

**Best Use Case**: If you want ALL features (timeline, canvas, real-time, diff-editor)

**Approach**:
1. Study existing codebase
2. Open issues to discuss roadmap
3. Submit PRs for evolution timeline first (smallest addition)
4. Gradually add canvas, real-time integration
5. Become co-maintainer if maintainer is receptive

**Risks**:
- Maintainer may not want all features
- May need to fork if visions diverge

---

## Option 3: Build with mini.nvim

### What is mini.nvim?

**Philosophy**: Library of 40+ independent Lua modules

**Key Characteristics**:
- Small, focused modules
- Consistent API patterns
- Minimal dependencies
- Stable interfaces

**Relevant Modules**:
- `mini.diff` - Show/manage diff hunks
- `mini.pick` - General-purpose picker (like Telescope)
- `mini.notify` - Notifications
- `mini.splitjoin` - Split/join constructs

### Pros of Using mini.nvim

✅ **Modular**: Compose exactly what you need

✅ **Stable**: Well-tested, mature codebase

✅ **Consistent patterns**: Easy to learn/use

✅ **No dependencies**: Self-contained (besides nvim)

✅ **Active maintenance**: Highly maintained by echasnovski

### Cons of Using mini.nvim

❌ **No jj-specific code**: Would start from scratch

❌ **Limited scope**: mini modules are generic, not VCS-specific

❌ **Reinventing wheel**: hunk.nvim/jj.nvim already exist

❌ **Indirection**: mini.diff is for git, would need adaptation

### How You'd Use mini.nvim

**Example**: Evolution timeline using mini.pick

```lua
local MiniPick = require('mini.pick')

local function show_evolution_timeline(change_id)
  local evolutions = get_evolutions(change_id)  -- Custom function

  MiniPick.start({
    source = {
      items = evolutions,
      name = 'Evolution Timeline',
      preview = function(item)
        return vim.fn.system({'jj', 'show', item.commit_id})
      end,
    },
  })
end
```

**Example**: Diff view using mini.diff

```lua
local MiniDiff = require('mini.diff')

-- Configure mini.diff to use jj instead of git
MiniDiff.setup({
  source = {
    attach = function(bufnr)
      -- Custom jj integration
      return {
        get_hunks = function()
          return parse_jj_diff(bufnr)
        end,
        apply_hunks = function(hunks)
          execute_jj_squash(hunks)
        end,
      }
    end,
  },
})
```

### Recommendation for mini.nvim

**Verdict**: ⭐⭐⭐ Good for learning, not ideal for production

**Best Use Case**: If you want to learn nvim plugin development, or need generic pickers/UI

**Approach**:
1. Use mini.pick for evolution timeline
2. Use mini.diff as inspiration (but not directly)
3. Build custom jj modules alongside mini.nvim

**Don't use if**: You want quick time-to-market (mini requires more custom code)

---

## Option 4: Start Fresh

### Philosophy

Build a new plugin from scratch, optimized specifically for jj's model

**Name**: `jj-flow.nvim` (or `jujutsu.nvim`, `jj-review.nvim`)

### Pros of Starting Fresh

✅ **Complete control**: No architectural constraints

✅ **Optimized for jj**: Can leverage jj-specific features fully

✅ **Modern best practices**: Apply 2025 nvim plugin patterns from day 1

✅ **Focused vision**: Exactly what you want, no compromises

✅ **Learning opportunity**: Deep understanding of nvim + jj

### Cons of Starting Fresh

❌ **Most work**: Build everything from scratch

❌ **Reinventing wheel**: hunk.nvim/jj.nvim already exist

❌ **Slower to market**: Takes longer to get usable plugin

❌ **Maintenance burden**: You're the maintainer

❌ **User adoption**: Harder to gain users (unknown plugin)

### Recommended Architecture for Fresh Plugin

```
jj-flow.nvim/
├── lua/
│   └── jj-flow/
│       ├── init.lua           # Setup and public API
│       ├── config.lua          # Configuration
│       ├── jj.lua              # jj command wrappers
│       │
│       ├── evolution/
│       │   ├── init.lua        # Evolution timeline
│       │   ├── timeline.lua    # Timeline UI
│       │   └── interdiff.lua   # Interdiff computation
│       │
│       ├── canvas/
│       │   ├── init.lua        # Change canvas
│       │   ├── lanes.lua       # Lane management
│       │   └── drag.lua        # Drag-and-drop logic
│       │
│       ├── realtime/
│       │   ├── init.lua        # Real-time integration
│       │   ├── snapshot.lua    # Auto-snapshot logic
│       │   ├── session.lua     # Session mode
│       │   └── watchman.lua    # Watchman integration
│       │
│       ├── diff/
│       │   ├── init.lua        # Diff-editor
│       │   ├── squash.lua      # Enhanced squash UI
│       │   └── hunks.lua       # Hunk selection
│       │
│       └── ui/
│           ├── telescope.lua   # Telescope pickers
│           ├── float.lua       # Floating windows
│           └── statusline.lua  # Statusline integration
│
├── plugin/
│   └── jj-flow.lua            # Auto-commands and :JJ commands
│
├── doc/
│   └── jj-flow.txt            # Vim help documentation
│
└── README.md
```

**Key Design Decisions**:

1. **Modular architecture**: Each feature is independent module
2. **Lazy loading**: Only load what's needed
3. **Configuration-driven**: Sensible defaults, highly customizable
4. **Test coverage**: Unit tests for core logic
5. **Documentation**: Comprehensive help docs

### Recommendation for Starting Fresh

**Verdict**: ⭐⭐⭐⭐ Best if you want complete control and have time

**Best Use Case**: Long-term investment in building the "definitive" jj nvim plugin

**Approach**:
1. Start with MVP (evolution timeline only)
2. Release early, get feedback
3. Iteratively add canvas, real-time, diff-editor
4. Build community, get contributors

**Timeline**:
- MVP (evolution timeline): 2-3 weeks
- Canvas: +3-4 weeks
- Real-time: +2-3 weeks
- Diff-editor: +2-3 weeks
- **Total**: ~3 months to feature parity with combined hunk.nvim + jj.nvim

---

## Feature Matrix Comparison

| Feature | hunk.nvim | jj.nvim | mini.nvim | Fresh |
|---------|-----------|---------|-----------|-------|
| **Diff-editor** | ✅ Excellent | ⚠️ Basic | ❌ DIY | ✅ Custom |
| **Evolution timeline** | ❌ No | ❌ No | ✅ DIY | ✅ Custom |
| **Change canvas** | ❌ No | ❌ No | ⚠️ Hard | ✅ Custom |
| **Real-time integration** | ❌ No | ❌ No | ❌ No | ✅ Custom |
| **Time to MVP** | ⭐⭐⭐⭐⭐ Fast (fork) | ⭐⭐⭐⭐ Fast (extend) | ⭐⭐⭐ Medium (DIY) | ⭐⭐ Slow (build) |
| **Maintenance risk** | ⚠️ Single maintainer | ⚠️ Single maintainer | ✅ Very stable | ❌ You maintain |
| **Extensibility** | ⚠️ Limited scope | ✅ Broad scope | ✅ Modular | ✅ Total control |
| **Community** | ⭐⭐ Small | ⭐⭐⭐ Growing | ⭐⭐⭐⭐⭐ Large | ❌ None (yet) |
| **Learning curve** | ⭐⭐⭐⭐ Easy | ⭐⭐⭐ Easy | ⭐⭐⭐ Medium | ⭐ Hard |

---

## Decision Matrix

### If you want to...

**Improve `jj squash -i` ONLY**:
→ **Extend hunk.nvim** ⭐ Fastest path

**Build comprehensive jj nvim plugin**:
→ **Extend jj.nvim** or **Start Fresh**
- Extend jj.nvim if maintainer is receptive ⭐ Lower risk
- Start Fresh if you want complete control ⭐ Higher reward

**Learn nvim plugin development**:
→ **Start Fresh** with **mini.nvim** as reference ⭐ Best learning

**Minimize maintenance burden**:
→ **Extend jj.nvim** (share maintenance) ⭐ Safest

**Ship fastest**:
→ **Extend hunk.nvim** for diff-editor ⭐ Quickest

**Long-term investment**:
→ **Start Fresh** ⭐ Most sustainable

---

## Hybrid Approach (Recommended)

**Phase 1**: Extend hunk.nvim for diff-editor improvements
- Fork hunk.nvim
- Add multi-target squashing
- Add preview mode
- Submit PRs upstream
- **Timeline**: 1-2 weeks

**Phase 2**: Build fresh plugin for evolution timeline
- Create `jj-timeline.nvim` (small, focused plugin)
- Just evolution timeline, nothing else
- Use mini.pick or Telescope
- **Timeline**: 2-3 weeks

**Phase 3**: Evaluate jj.nvim
- Study jj.nvim codebase
- Open PR for canvas feature
- If accepted → continue contributing
- If rejected → merge jj-timeline into standalone plugin
- **Timeline**: 1 week evaluation

**Phase 4**: Decide final architecture
- If jj.nvim accepted canvas → continue there
- If not → build `jj-flow.nvim` combining timeline + canvas + real-time
- **Timeline**: Ongoing

### Why Hybrid?

✅ **Low risk**: Start small, validate ideas

✅ **Fast feedback**: Ship diff-editor improvements immediately

✅ **Community engagement**: Contribute to existing tools first

✅ **Flexibility**: Can pivot based on maintainer receptiveness

✅ **Incremental value**: Each phase delivers value independently

---

## Technical Recommendations

### Use Telescope for Pickers

**Why**: Industry standard, familiar, powerful

```lua
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')

-- Evolution timeline picker
function show_evolution_timeline(change_id)
  pickers.new({}, {
    prompt_title = 'Evolution Timeline',
    finder = finders.new_table({
      results = get_evolutions(change_id),
    }),
  }):find()
end
```

**Alternative**: mini.pick if you want no dependencies

### Use Treesitter for Syntax Highlighting

**Why**: Better than regex, fast, built into nvim

```lua
-- In diff view
local parser = vim.treesitter.get_parser(bufnr, 'rust')
local tree = parser:parse()[1]

-- Highlight diff with Treesitter
apply_treesitter_highlights(bufnr, tree)
```

### Use plenary.nvim for Utilities

**Why**: Standard library for nvim plugins

```lua
local Job = require('plenary.job')

-- Execute jj command asynchronously
Job:new({
  command = 'jj',
  args = {'evolog', '-r', change_id},
  on_exit = function(j, return_val)
    local result = j:result()
    callback(result)
  end,
}):start()
```

### Use LuaCATS for Type Annotations

**Why**: Catch bugs early, better LSP support

```lua
---@class Evolution
---@field commit_id string
---@field timestamp number
---@field description string

---Get evolutions for a change
---@param change_id string
---@return Evolution[]
function M.get_evolutions(change_id)
  -- ...
end
```

---

## Conclusion

**Recommendation**: **Hybrid Approach**

**Phase 1**: Fork/extend hunk.nvim (diff-editor)
**Phase 2**: Build jj-timeline.nvim (evolution timeline)
**Phase 3**: Contribute to jj.nvim (canvas, real-time)
**Phase 4**: If needed, consolidate into `jj-flow.nvim`

**Why**: Balances speed, risk, and long-term goals

**Timeline**:
- Week 1-2: Enhanced hunk.nvim
- Week 3-5: jj-timeline.nvim
- Week 6: Evaluate jj.nvim
- Week 7+: Iterate based on feedback

**Final Form** (12 months):
Either:
- Strong contributions to jj.nvim (if maintainer receptive)
- OR comprehensive `jj-flow.nvim` (if building standalone)

**Next Step**: Prototype evolution timeline picker (weekend project) to validate idea before committing to approach.
