# Jujutsu Decision Trees: What Command Should I Use?

This document provides decision trees to help you choose the right jj command for your situation.

## Table of Contents

- [Starting New Work](#starting-new-work)
- [Making Changes](#making-changes)
- [Organizing Your Work](#organizing-your-work)
- [Fixing Mistakes](#fixing-mistakes)
- [Sharing Your Work](#sharing-your-work)
- [Syncing with Remote](#syncing-with-remote)
- [Navigating History](#navigating-history)

---

## Starting New Work

```mermaid
graph TD
    START{Want to start<br/>new work?}

    START --> WHERE{Where should it<br/>be based?}

    WHERE --> MAIN[On main branch]
    WHERE --> CURRENT[On current work]
    WHERE --> SPECIFIC[On specific change]

    MAIN --> CMD1["jj new main -m 'description'"]
    CURRENT --> CMD2["jj new -m 'description'"]
    SPECIFIC --> CMD3["jj new &lt;change-id&gt; -m 'description'"]

    CMD1 --> RESULT1[New change on main]
    CMD2 --> RESULT2[Stacked on current @]
    CMD3 --> RESULT3[Based on specific change]

    style CMD1 fill:#ccffcc
    style CMD2 fill:#ccffcc
    style CMD3 fill:#ccffcc
```

### Quick Reference

| Scenario | Command | Result |
|----------|---------|--------|
| Independent work from main | `jj new main -m "msg"` | New change based on main |
| Continue current work | `jj new -m "msg"` | Stack on current @ |
| Branch from specific change | `jj new <id> -m "msg"` | Base on that change |

---

## Making Changes

```mermaid
graph TD
    EDIT{What kind of edit?}

    EDIT --> NEW[New work<br/>in current @]
    EDIT --> OLD[Modify earlier<br/>change]
    EDIT --> MSG[Update description]

    NEW --> AUTO[Just edit files!<br/>Auto-tracked]

    OLD --> WHICH{Which change?}
    WHICH --> PARENT[Parent of @]
    WHICH --> OTHER[Specific change]

    PARENT --> CMD1["jj edit @-<br/>or: jj edit &lt;parent-id&gt;"]
    OTHER --> CMD2["jj edit &lt;change-id&gt;"]

    MSG --> CURRENT{Which description?}
    CURRENT --> CURR_MSG["jj describe -m 'new msg'"]
    CURRENT --> OLD_MSG["jj describe &lt;change-id&gt; -m 'msg'"]

    style AUTO fill:#ccffcc
    style CMD1 fill:#ccffcc
    style CMD2 fill:#ccffcc
    style CURR_MSG fill:#ccffcc
    style OLD_MSG fill:#ccffcc
```

### Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Edit files in current change | Just edit! | Auto-tracked |
| Edit parent change | `jj edit @-` | Switch @ to parent |
| Edit specific change | `jj edit <id>` | Switch @ to that change |
| Update current description | `jj describe -m "msg"` | Can run multiple times |
| Update old description | `jj describe <id> -m "msg"` | No rebase needed |

---

## Organizing Your Work

```mermaid
graph TD
    ORG{How to organize<br/>changes?}

    ORG --> COMBINE[Combine changes]
    ORG --> SPLIT[Split a change]
    ORG --> REORDER[Reorder changes]
    ORG --> BOOKMARK[Add bookmarks]

    COMBINE --> HOW{How to combine?}
    HOW --> SQUASH_PARENT["jj squash<br/>(into parent)"]
    HOW --> SQUASH_TARGET["jj squash --into &lt;id&gt;<br/>(into specific change)"]

    SPLIT --> CMD_SPLIT["jj split<br/>(interactive)"]

    REORDER --> MOVE{What to move?}
    MOVE --> SINGLE["jj rebase -s &lt;change&gt; -d &lt;dest&gt;<br/>(move one change)"]
    MOVE --> BRANCH["jj rebase -b &lt;change&gt; -d &lt;dest&gt;<br/>(move change + descendants)"]

    BOOKMARK --> WHEN{When to bookmark?}
    WHEN --> NOW["jj bookmark create name -r @"]
    WHEN --> SPECIFIC["jj bookmark create name -r &lt;id&gt;"]

    style SQUASH_PARENT fill:#ccffcc
    style SQUASH_TARGET fill:#ccffcc
    style CMD_SPLIT fill:#ccffcc
    style SINGLE fill:#ccffcc
    style BRANCH fill:#ccffcc
    style NOW fill:#ccffcc
    style SPECIFIC fill:#ccffcc
```

### Squashing Examples

```mermaid
graph LR
    subgraph "Before"
        A1[Change A]
        B1["Change B @<br/>(fix for A)"]
        A1 --> B1
    end

    subgraph "After: jj squash"
        A2["Change A<br/>(includes B)"]
    end

    style B1 fill:#ffffcc
    style A2 fill:#ccffcc
```

### Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Merge @ into parent | `jj squash` | Current → parent |
| Merge @ into specific | `jj squash --into <id>` | Current → specific |
| Split current change | `jj split` | Interactive split |
| Move single change | `jj rebase -s <id> -d <dest>` | Only that change |
| Move change + children | `jj rebase -b <id> -d <dest>` | Entire subtree |
| Bookmark current | `jj bookmark create name -r @` | On @ |
| Bookmark specific | `jj bookmark create name -r <id>` | On any change |

---

## Fixing Mistakes

```mermaid
graph TD
    MISTAKE{Made a mistake?}

    MISTAKE --> WHAT{What happened?}

    WHAT --> WRONG_CHANGE[Edited wrong change]
    WHAT --> BAD_SQUASH[Bad squash/rebase]
    WHAT --> WRONG_DESC[Wrong description]
    WHAT --> LOST[Lost work somehow]

    WRONG_CHANGE --> JUST_EDIT["jj edit &lt;correct-change&gt;<br/>Continue working"]

    BAD_SQUASH --> UNDO_HOW{How far back?}
    UNDO_HOW --> LAST["jj op undo<br/>(undo last operation)"]
    UNDO_HOW --> SPECIFIC["jj op log<br/>jj op restore &lt;op-id&gt;"]

    WRONG_DESC --> FIX_DESC["jj describe &lt;change-id&gt; -m 'correct msg'"]

    LOST --> FIND["jj op log<br/>(find state before loss)"]
    FIND --> RESTORE["jj op restore &lt;op-id&gt;"]

    style JUST_EDIT fill:#ccffcc
    style LAST fill:#ccffcc
    style SPECIFIC fill:#ccffcc
    style FIX_DESC fill:#ccffcc
    style RESTORE fill:#ccffcc
```

### Operation Log Safety Net

```mermaid
sequenceDiagram
    participant User
    participant jj
    participant OpLog as Operation Log

    User->>jj: jj squash
    jj->>OpLog: Record operation
    OpLog-->>jj: ✓ Saved

    Note over User: Oh no! Wrong change!

    User->>jj: jj op undo
    jj->>OpLog: Restore previous state
    OpLog-->>jj: State restored
    jj-->>User: ✓ Mistake undone!
```

### Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Undo last operation | `jj op undo` | Reverses last op |
| View operation history | `jj op log` | See all operations |
| Restore to specific point | `jj op restore <op-id>` | Time travel |
| Fix wrong description | `jj describe <id> -m "msg"` | Update any change |
| Switch to different change | `jj edit <id>` | Move @ |

---

## Sharing Your Work

```mermaid
graph TD
    SHARE{Ready to share?}

    SHARE --> FIRST{First time<br/>sharing this?}

    FIRST --> YES_FIRST[Yes, creating PR]
    FIRST --> NO_UPDATE[No, updating PR]

    YES_FIRST --> HAS_BOOK{Already has<br/>bookmark?}

    HAS_BOOK --> NO_BOOK["jj bookmark create name -r &lt;change&gt;"]
    HAS_BOOK --> YES_BOOK["Ready to push"]

    NO_BOOK --> PUSH1
    YES_BOOK --> PUSH1["jj git push --bookmark name"]

    PUSH1 --> USE_JST{Using jj-stack?}
    USE_JST --> JST_YES["jst submit name"]
    USE_JST --> JST_NO[Create PR on GitHub]

    NO_UPDATE --> PUSH2["jj git push"]

    style NO_BOOK fill:#ffffcc
    style PUSH1 fill:#ccffcc
    style JST_YES fill:#ccffcc
    style PUSH2 fill:#ccffcc
```

### Stacked PRs Decision

```mermaid
graph TD
    STACK{Have dependent<br/>changes?}

    STACK --> INDEPENDENT[No, independent work]
    STACK --> DEPENDENT[Yes, stacked changes]

    INDEPENDENT --> SINGLE["Create single PR<br/>jst submit bookmark"]

    DEPENDENT --> HOW_MANY{How many<br/>in stack?}

    HOW_MANY --> TWO["2-3 changes"]
    HOW_MANY --> MANY["4+ changes"]

    TWO --> BOOK_EACH["Bookmark each change<br/>jj bookmark create ..."]
    MANY --> BOOK_EACH

    BOOK_EACH --> SUBMIT["jst submit b1 b2 b3<br/>(submits whole stack)"]

    style SINGLE fill:#ccffcc
    style BOOK_EACH fill:#ffffcc
    style SUBMIT fill:#ccffcc
```

### Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Create bookmark | `jj bookmark create name -r <id>` | Needed for PRs |
| Push bookmark first time | `jj git push --bookmark name` | Or use jst |
| Update existing PR | `jj git push` | Push changes |
| Submit with jj-stack | `jst submit bookmark` | Creates/updates PR |
| Submit stack | `jst submit b1 b2 b3` | Multiple dependent PRs |

---

## Syncing with Remote

```mermaid
graph TD
    SYNC{Need to sync<br/>with remote?}

    SYNC --> DIRECTION{Which direction?}

    DIRECTION --> GET[Get updates from remote]
    DIRECTION --> SEND[Send my changes]

    GET --> FETCH["jj git fetch"]
    FETCH --> REBASE_Q{Need to rebase<br/>your work?}

    REBASE_Q --> YES_REBASE["jj rebase -d main<br/>or: jj rebase -d origin/main"]
    REBASE_Q --> NO_REBASE[Already up to date]

    SEND --> FIRST_PUSH{First time<br/>pushing?}

    FIRST_PUSH --> YES_FIRST_PUSH["jj git push --bookmark name<br/>or: jst submit name"]
    FIRST_PUSH --> NO_UPDATE_PUSH["jj git push<br/>or: jst submit name"]

    style FETCH fill:#ccffcc
    style YES_REBASE fill:#ccffcc
    style YES_FIRST_PUSH fill:#ccffcc
    style NO_UPDATE_PUSH fill:#ccffcc
```

### After PR Merge Workflow

```mermaid
graph TD
    MERGED{PR merged<br/>on GitHub?}

    MERGED --> FETCH["1. jj git fetch"]
    FETCH --> AUTO["Bookmark auto-deleted<br/>Commits marked merged"]

    AUTO --> MORE{More PRs<br/>in stack?}

    MORE --> YES_MORE["2. jj rebase -d main<br/>(rebase remaining work)"]
    MORE --> NO_MORE["Done! Clean state"]

    YES_MORE --> UPDATE["3. jst submit remaining-bookmarks<br/>(update remaining PRs)"]

    style FETCH fill:#ccffcc
    style YES_MORE fill:#ffffcc
    style UPDATE fill:#ccffcc
```

### Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Get remote updates | `jj git fetch` | Fetch all remotes |
| Rebase onto main | `jj rebase -d main` | Update your work |
| Push new bookmark | `jj git push --bookmark name` | First push |
| Update existing | `jj git push` | Subsequent pushes |
| After PR merge | `jj git fetch && jj rebase -d main` | Clean up |

---

## Navigating History

```mermaid
graph TD
    NAV{What do you<br/>need to see?}

    NAV --> VIEW[View changes]
    NAV --> FIND[Find a change]
    NAV --> COMPARE[Compare changes]

    VIEW --> VIEW_HOW{What to view?}
    VIEW_HOW --> RECENT["jj log<br/>(recent changes)"]
    VIEW_HOW --> STACK["jj log -r ::@<br/>(current stack)"]
    VIEW_HOW --> ALL["jj log -r 'all()'<br/>(everything)"]
    VIEW_HOW --> GRAPH["lazyjj<br/>(visual TUI)"]

    FIND --> FIND_HOW{How to find?}
    FIND_HOW --> BY_DESC["jj log -r 'description(pattern)'"]
    FIND_HOW --> BY_AUTHOR["jj log -r 'author(name)'"]
    FIND_HOW --> BY_BOOKMARK["jj log -r 'bookmarks()'"]

    COMPARE --> DIFF_WHAT{What to diff?}
    DIFF_WHAT --> CURRENT["jj diff<br/>(current @ vs parent)"]
    DIFF_WHAT --> SPECIFIC["jj diff -r &lt;id&gt;<br/>(specific change)"]
    DIFF_WHAT --> BETWEEN["jj diff --from &lt;id1&gt; --to &lt;id2&gt;"]

    style RECENT fill:#ccffcc
    style STACK fill:#ccffcc
    style ALL fill:#ccffcc
    style GRAPH fill:#ccffcc
    style BY_DESC fill:#ccffcc
    style BY_AUTHOR fill:#ccffcc
    style BY_BOOKMARK fill:#ccffcc
    style CURRENT fill:#ccffcc
    style SPECIFIC fill:#ccffcc
    style BETWEEN fill:#ccffcc
```

### Revset Query Examples

```mermaid
graph TB
    subgraph "Common Revset Patterns"
        R1["@ = current change"]
        R2["@- = parent of current"]
        R3["@+ = children of current"]
        R4["main.. = all changes after main"]
        R5["::@ = from root to current"]
        R6["bookmarks() = all bookmarked changes"]
        R7["mine() = my changes only"]
    end

    style R1 fill:#ccffcc
    style R2 fill:#ccffcc
    style R3 fill:#ccffcc
    style R4 fill:#ccffcc
    style R5 fill:#ccffcc
    style R6 fill:#ccffcc
    style R7 fill:#ccffcc
```

### Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| View recent changes | `jj log` | Last ~10 changes |
| View current stack | `jj log -r ::@` | Root to @ |
| View all changes | `jj log -r 'all()'` | Everything |
| Visual interface | `lazyjj` | Interactive TUI |
| Search by description | `jj log -r 'description("text")'` | Pattern match |
| Your bookmarks only | `jj log -r 'bookmarks() & mine()'` | Filter |
| Diff current | `jj diff` | @ vs parent |
| Diff specific | `jj diff -r <id>` | Change vs parent |
| Diff two changes | `jj diff --from <id1> --to <id2>` | Compare any two |

---

## Decision Matrix: Common Scenarios

### Scenario: I want to...

```mermaid
graph TD
    SCENARIO["Common Scenarios:<br/>Quick Command Lookup"]

    SCENARIO --> S1["Start new work"] --> C1["jj new main -m 'msg'"]
    SCENARIO --> S2["Continue current work"] --> C2["jj new -m 'msg'"]
    SCENARIO --> S3["Edit an old change"] --> C3["jj edit &lt;id&gt;"]
    SCENARIO --> S4["Update description"] --> C4["jj describe -m 'msg'"]
    SCENARIO --> S5["Combine two changes"] --> C5["jj squash --into &lt;id&gt;"]
    SCENARIO --> S6["Split a change"] --> C6["jj split"]
    SCENARIO --> S7["Undo a mistake"] --> C7["jj op undo"]
    SCENARIO --> S8["View my stack"] --> C8["jj log -r ::@"]
    SCENARIO --> S9["Sync with remote"] --> C9["jj git fetch"]
    SCENARIO --> S10["Push to GitHub"] --> C10["jst submit bookmark"]
    SCENARIO --> S11["Rebase on main"] --> C11["jj rebase -d main"]
    SCENARIO --> S12["Create a bookmark"] --> C12["jj bookmark create name"]

    style C1 fill:#ccffcc
    style C2 fill:#ccffcc
    style C3 fill:#ccffcc
    style C4 fill:#ccffcc
    style C5 fill:#ccffcc
    style C6 fill:#ccffcc
    style C7 fill:#ccffcc
    style C8 fill:#ccffcc
    style C9 fill:#ccffcc
    style C10 fill:#ccffcc
    style C11 fill:#ccffcc
    style C12 fill:#ccffcc
```

---

## When to Use What: Quick Guide

### Creating Changes

| Goal | Command | When |
|------|---------|------|
| New independent work | `jj new main -m "msg"` | Starting fresh feature |
| Stack on current | `jj new -m "msg"` | Building on current work |
| Branch from specific point | `jj new <id> -m "msg"` | Base on older change |

### Editing

| Goal | Command | When |
|------|---------|------|
| Edit files | Just edit! | Modifying @ |
| Switch to different change | `jj edit <id>` | Work on older change |
| Update description | `jj describe -m "msg"` | Fix commit message |

### Organizing

| Goal | Command | When |
|------|---------|------|
| Merge into parent | `jj squash` | Fix belongs in parent |
| Merge into specific | `jj squash --into <id>` | Fix belongs elsewhere |
| Split change | `jj split` | Change does too much |
| Reorder | `jj rebase -s <id> -d <dest>` | Change in wrong place |

### Sharing

| Goal | Command | When |
|------|---------|------|
| Create bookmark | `jj bookmark create name` | Preparing to push |
| Push to GitHub | `jst submit bookmark` | Create/update PR |
| Push stack | `jst submit b1 b2 b3` | Multiple dependent PRs |

### Syncing

| Goal | Command | When |
|------|---------|------|
| Get updates | `jj git fetch` | Sync with remote |
| Update your work | `jj rebase -d main` | After fetch |
| After PR merge | `jj git fetch && jj rebase -d main` | Clean up |

---

## Summary Decision Tree

```mermaid
graph TD
    START{What do you<br/>want to do?}

    START --> CREATE[Create/Edit]
    START --> ORGANIZE[Organize]
    START --> SHARE[Share]
    START --> SYNC[Sync]
    START --> FIX[Fix Mistake]

    CREATE --> C_NEW["New: jj new"]
    CREATE --> C_EDIT["Edit: jj edit"]
    CREATE --> C_DESC["Describe: jj describe"]

    ORGANIZE --> O_SQUASH["Combine: jj squash"]
    ORGANIZE --> O_SPLIT["Split: jj split"]
    ORGANIZE --> O_REBASE["Reorder: jj rebase"]
    ORGANIZE --> O_BOOKMARK["Bookmark: jj bookmark create"]

    SHARE --> SH_PUSH["Push: jj git push"]
    SHARE --> SH_JST["PR: jst submit"]

    SYNC --> SY_FETCH["Fetch: jj git fetch"]
    SYNC --> SY_REBASE["Rebase: jj rebase -d main"]

    FIX --> F_UNDO["Undo: jj op undo"]
    FIX --> F_RESTORE["Restore: jj op restore"]

    style C_NEW fill:#ccffcc
    style C_EDIT fill:#ccffcc
    style C_DESC fill:#ccffcc
    style O_SQUASH fill:#ccffcc
    style O_SPLIT fill:#ccffcc
    style O_REBASE fill:#ccffcc
    style O_BOOKMARK fill:#ccffcc
    style SH_PUSH fill:#ccffcc
    style SH_JST fill:#ccffcc
    style SY_FETCH fill:#ccffcc
    style SY_REBASE fill:#ccffcc
    style F_UNDO fill:#ccffcc
    style F_RESTORE fill:#ccffcc
```

---

## Further Reading

- [JJ_MENTAL_MODEL.md](./JJ_MENTAL_MODEL.md) - Core concepts and data structures
- [JJ_WORKFLOWS.md](./JJ_WORKFLOWS.md) - Common workflow patterns
- [JJ_STACKED_WORKFLOW.md](./JJ_STACKED_WORKFLOW.md) - jj-stack specific workflows
- [jj Official Docs](https://jj-vcs.github.io/jj/) - Command reference

**Tip**: When in doubt, remember: jj operations are tracked and can be undone with `jj op undo`!
