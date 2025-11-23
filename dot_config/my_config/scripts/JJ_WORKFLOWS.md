# Jujutsu Workflows: Visual Guide

This document shows common jj workflows and operations through visual diagrams.

## Table of Contents

- [Basic Operations](#basic-operations)
- [Stacked Changes Workflow](#stacked-changes-workflow)
- [Editing History](#editing-history)
- [Conflict Resolution](#conflict-resolution)
- [Working with Multiple Changes](#working-with-multiple-changes)
- [Integration with Git](#integration-with-git)

---

## Basic Operations

### Creating a New Change

```mermaid
sequenceDiagram
    participant User
    participant jj
    participant Repo

    Note over User,Repo: Starting State: @ on main

    User->>jj: jj new -m "Add feature X"
    jj->>Repo: Create new change on top of current
    Repo-->>jj: New change @ created
    jj-->>User: Working copy now @ (new change)

    Note over User: Edit files...

    User->>jj: Files are auto-tracked
    jj->>Repo: Snapshot changes automatically
    Repo-->>User: ✓ Changes saved to @
```

**Result**:

```mermaid
graph TB
    M[main] --> C1["@ New change<br/>(working copy)"]

    style M fill:#ccccff
    style C1 fill:#ccffcc
```

### Describing Your Work

```mermaid
sequenceDiagram
    participant User
    participant jj

    User->>jj: jj describe -m "Implemented feature X"
    Note over jj: Updates description of @
    jj-->>User: ✓ Description updated

    Note over User,jj: Can describe multiple times!

    User->>jj: jj describe -m "Add feature X with tests"
    jj-->>User: ✓ Description updated again
```

> "You can describe a change that is still 'in progress'. Describing and committing are separate operations."
>
> — [Chris Krycho](https://v5.chriskrycho.com/essays/jj-init/)

### Moving to Next Change

```mermaid
graph TB
    subgraph "Before: jj new"
        M1[main]
        C1["@ Current work"]
        M1 --> C1
    end

    subgraph "After: jj new -m 'Next feature'"
        M2[main]
        C2["Previous work<br/>(now described)"]
        C3["@ Next feature<br/>(new working copy)"]
        M2 --> C2
        C2 --> C3
    end

    style C1 fill:#ccffcc
    style C3 fill:#ccffcc
```

**Command**: `jj new -m "Next feature"`

**Effect**: Current work is frozen, new working copy created on top.

---

## Stacked Changes Workflow

### Building a Stack

```mermaid
graph TB
    subgraph "Step 1: First Change"
        M1[main]
        A1["@ Refactor utils"]
        M1 --> A1
    end

    subgraph "Step 2: Stack Second Change"
        M2[main]
        A2["Refactor utils"]
        B2["@ Add feature using utils"]
        M2 --> A2
        A2 --> B2
    end

    subgraph "Step 3: Stack Third Change"
        M3[main]
        A3["Refactor utils"]
        B3["Add feature using utils"]
        C3["@ Add tests"]
        M3 --> A3
        A3 --> B3
        B3 --> C3
    end

    style A1 fill:#ccffcc
    style B2 fill:#ccffcc
    style C3 fill:#ccffcc
```

**Commands**:

```bash
# Step 1
jj new main -m "Refactor utils"
# ... edit files ...

# Step 2
jj new -m "Add feature using utils"
# ... edit files ...

# Step 3
jj new -m "Add tests"
# ... edit files ...
```

### Adding Bookmarks to Stack

```mermaid
graph TB
    M[main] --> A["Change A<br/>kmkuslsw<br/>📌 refactor-utils"]
    A --> B["Change B<br/>rpqostuw<br/>📌 add-feature"]
    B --> C["Change C @ <br/>zxnmqwer<br/>📌 add-tests"]

    style A fill:#ffffcc
    style B fill:#ffffcc
    style C fill:#ccffcc
```

**Commands**:

```bash
jj bookmark create refactor-utils -r kmkuslsw
jj bookmark create add-feature -r rpqostuw
jj bookmark create add-tests -r @
```

### Viewing Your Stack

```mermaid
sequenceDiagram
    participant User
    participant jj

    User->>jj: jj log -r ::@
    jj-->>User: Shows from root to @

    Note over User,jj: Output shows parent→child relationships

    User->>jj: jj log
    jj-->>User: Shows recent changes with graph
```

**Example Output**:

```
@  zxnmqwer kyle 2m add-tests
│  Add comprehensive tests
○  rpqostuw kyle 15m add-feature
│  Implement new feature using refactored code
○  kmkuslsw kyle 1h refactor-utils
│  Extract common utilities
○  pqrswxyz kyle 2h main
│  Previous work
```

---

## Editing History

### Editing a Change in the Middle of Stack

```mermaid
graph TB
    subgraph "Initial Stack"
        M1[main] --> A1[Change A]
        A1 --> B1[Change B]
        B1 --> C1["Change C @"]

        style C1 fill:#ccffcc
    end

    subgraph "After: jj edit <change-A>"
        M2[main] --> A2["Change A @<br/>(editing)"]
        A2 --> B2[Change B]
        B2 --> C2[Change C]

        style A2 fill:#ccffcc
    end

    subgraph "After Making Changes"
        M3[main] --> A3["Change A @<br/>(modified)"]
        A3 --> B3["Change B<br/>(rebased)"]
        B3 --> C3["Change C<br/>(rebased)"]

        style A3 fill:#ccffcc
    end
```

**Workflow**:

```bash
# View the stack
jj log -r ::@

# Edit change A
jj edit <change-A-id>

# Make your changes
# Files are auto-tracked

# Return to top of stack
jj edit <change-C-id>
# Or: jj new <change-C-id>
```

**What happens**: Changes B and C are automatically rebased on the modified A.

### Squashing Changes

```mermaid
graph LR
    subgraph "Before Squash"
        M1[main] --> A1[Change A]
        A1 --> B1["Change B @<br/>(fix for A)"]
    end

    subgraph "After: jj squash"
        M2[main] --> AB2["Change A<br/>(includes B's changes)"]
    end

    style B1 fill:#ccffcc
    style AB2 fill:#ccffcc
```

**Command**: `jj squash`

**Effect**: Current change (@) is squashed into its parent.

**Use case**: You made a fix that should be part of the previous change.

### Describing Any Change

```mermaid
sequenceDiagram
    participant User
    participant jj

    Note over User: Want to update description of old change

    User->>jj: jj describe <change-id> -m "Better description"
    jj-->>User: ✓ Description updated

    Note over User,jj: No rebase needed! Unlike git.
```

> "Rewording a message earlier in history does not involve some kind of rebase operation; you just call describe with a specific revision target."
>
> — [Chris Krycho](https://v5.chriskrycho.com/essays/jj-init/)

---

## Conflict Resolution

One of jj's unique features: conflicts don't stop your workflow.

### Git's Conflict Handling

```mermaid
stateDiagram-v2
    [*] --> Working: Making changes
    Working --> Conflict: git rebase/merge
    Conflict --> Blocked: ❌ Can't continue
    Blocked --> Resolving: Fix conflicts
    Resolving --> Complete: git add, commit
    Complete --> [*]

    note right of Blocked
        Must resolve before
        doing anything else
    end note
```

### jj's Conflict Handling

```mermaid
stateDiagram-v2
    [*] --> Working: Making changes
    Working --> Conflict: jj rebase
    Conflict --> Marked: Change marked "conflicted"
    Marked --> Continue: Keep working elsewhere
    Marked --> Resolve: Or resolve now
    Continue --> [*]: Work continues
    Resolve --> Complete: Conflicts auto-propagate
    Complete --> [*]

    note right of Marked
        Conflicts don't block you!
        Resolve when convenient
    end note
```

### Conflict Workflow

```mermaid
graph TB
    subgraph "Step 1: Conflict Occurs"
        M1[main - Updated]
        A1["Your change<br/>⚠️ CONFLICT"]

        M1 -.->|"jj rebase"| A1

        style A1 fill:#ffcccc
    end

    subgraph "Step 2: Work Elsewhere (Optional)"
        M2[main - Updated]
        A2["Your change<br/>⚠️ CONFLICT"]
        B2["@ New work<br/>✓ No conflict"]

        M2 --> A2
        M2 --> B2

        style A2 fill:#ffcccc
        style B2 fill:#ccffcc
    end

    subgraph "Step 3: Resolve When Ready"
        M3[main - Updated]
        A3["Your change @<br/>✓ Resolved"]
        B3["New work<br/>✓ Auto-updated"]

        M3 --> A3
        M3 --> B3

        style A3 fill:#ccffcc
        style B3 fill:#ccffcc
    end
```

**Commands**:

```bash
# Conflict occurs during rebase
jj rebase -d main
# ⚠️ Change marked as conflicted

# Option 1: Resolve now
jj edit <conflicted-change>
# Edit files to resolve
# Auto-saved when done

# Option 2: Work elsewhere
jj new main -m "Other work"
# ... work on something else ...

# Come back later
jj edit <conflicted-change>
# Resolve conflicts
```

> "Conflicts don't halt workflow. Jujutsu marks a commit as conflicted but allows continuing work elsewhere, then returning to resolve them later with automatic cascading updates."
>
> — [Stavros](https://www.stavros.io/posts/switch-to-jujutsu-already-a-tutorial/)

---

## Working with Multiple Changes

### Parallel Work Streams

```mermaid
graph TB
    M[main]

    A[Feature A]
    B[Feature B]
    C["Bug Fix @"]

    M --> A
    M --> B
    M --> C

    style C fill:#ccffcc
```

**Workflow**:

```bash
# Start feature A
jj new main -m "Feature A"
# ... work ...

# Start feature B (from main, not A)
jj new main -m "Feature B"
# ... work ...

# Start bug fix
jj new main -m "Bug fix"
# ... work ...
```

**No interference**: Each change is independent.

### Switching Between Changes

```mermaid
sequenceDiagram
    participant User
    participant jj

    Note over User: Working on Feature A

    User->>jj: jj edit <feature-B-id>
    Note over jj: Switch working copy to Feature B
    jj-->>User: @ now at Feature B

    Note over User: Work on Feature B...

    User->>jj: jj edit <feature-A-id>
    Note over jj: Switch back to Feature A
    jj-->>User: @ now at Feature A
```

**No stashing needed**: Each change preserves its state.

### Visualizing Multiple Streams

```mermaid
gitGraph
    commit id: "main"
    branch feature-a
    commit id: "A1"
    commit id: "A2"

    checkout main
    branch feature-b
    commit id: "B1"

    checkout main
    branch bugfix
    commit id: "Fix1"
    commit id: "Fix2"

    checkout feature-a
    commit id: "A3"
```

**Command to see this**: `jj log` or `lazyjj`

---

## Integration with Git

### Colocated Repository Model

```mermaid
graph TB
    subgraph "Your Disk"
        WC[Working Copy]

        subgraph "jj Repository"
            JC[jj Changes]
            JO[jj Operation Log]
        end

        subgraph "Git Repository"
            GC[Git Commits]
            GB[Git Branches]
        end

        WC --> JC
        JC <--> |"Bidirectional Sync"| GC
        JO --> JC
    end

    subgraph "GitHub"
        GH[Remote Repository]
    end

    GC <--> |"jj git push/fetch"| GH
```

**Key Point**: jj and git coexist. Changes sync to git commits automatically.

### Push/Pull Workflow

```mermaid
sequenceDiagram
    participant User
    participant jj
    participant Git
    participant GitHub

    Note over User,GitHub: Fetch Updates

    User->>jj: jj git fetch
    jj->>Git: Fetch from remote
    Git->>GitHub: git fetch
    GitHub-->>Git: New commits
    Git-->>jj: Update local refs
    jj-->>User: Remote bookmarks updated

    Note over User,GitHub: Push Changes

    User->>jj: jj git push -c @
    jj->>Git: Convert change to commit
    Git->>GitHub: git push
    GitHub-->>Git: ✓ Pushed
    Git-->>jj: Update tracking
    jj-->>User: ✓ Change pushed
```

### Bookmark Synchronization

```mermaid
stateDiagram-v2
    [*] --> Local: jj bookmark create feature-x
    Local --> GitBranch: jj git push --bookmark feature-x
    GitBranch --> Remote: Push to GitHub
    Remote --> PR: Create Pull Request
    PR --> Merged: PR merged on GitHub
    Merged --> Deleted: jj git fetch (auto-deletes local)
    Deleted --> [*]
```

**Automatic cleanup**: When a PR is merged on GitHub, `jj git fetch` automatically removes the local bookmark.

---

## Common Patterns

### Pattern: Incremental Development

```mermaid
graph LR
    subgraph "Day 1"
        M1[main] --> W1["@ Work in progress"]
    end

    subgraph "Day 2"
        M2[main] --> W2["Work v1<br/>(described)"]
        W2 --> W2B["@ More work"]
    end

    subgraph "Day 3"
        M3[main] --> W3A["Work v1"]
        W3A --> W3B["Work v2<br/>(described)"]
        W3B --> W3C["@ Final touches"]
    end

    style W1 fill:#ccffcc
    style W2B fill:#ccffcc
    style W3C fill:#ccffcc
```

**Workflow**:

```bash
# Day 1
jj new main -m "WIP: New feature"
# ... work ...

# Day 2
jj describe -m "Implement core logic"
jj new -m "Add tests"
# ... work ...

# Day 3
jj describe -m "Add comprehensive tests"
jj new -m "Add documentation"
# ... work ...

# Ready to submit
jj bookmark create feature-x -r <first-change>
jj bookmark create feature-x-tests -r <second-change>
jj bookmark create feature-x-docs -r @
```

### Pattern: Fix Earlier Change

```mermaid
graph TB
    subgraph "Discovered Bug in Change A"
        M1[main] --> A1[Change A<br/>Has bug]
        A1 --> B1[Change B]
        B1 --> C1["Change C @"]
    end

    subgraph "Create Fix"
        M2[main] --> A2[Change A]
        A2 --> B2[Change B]
        B2 --> C2[Change C]
        C2 --> F2["@ Fix for A"]
    end

    subgraph "Squash Fix into A"
        M3[main] --> A3["Change A<br/>(with fix)"]
        A3 --> B3["Change B<br/>(rebased)"]
        B3 --> C3["Change C<br/>(rebased)"]
    end

    style C1 fill:#ccffcc
    style F2 fill:#ffffcc
    style A3 fill:#ccffcc
```

**Commands**:

```bash
# Create fix based on A
jj new <change-A> -m "Fix bug in A"
# ... make fix ...

# Squash fix into A
jj squash --into <change-A>

# Or use interactive squash
jj squash -i
```

### Pattern: Reordering Changes

```mermaid
graph LR
    subgraph "Before"
        M1[main] --> A1[A]
        A1 --> B1[B]
        B1 --> C1[C]
    end

    subgraph "After: Move C to be after main"
        M2[main] --> C2[C]
        C2 --> A2[A]
        A2 --> B2[B]
    end
```

**Commands**:

```bash
# Move change C to be on top of main
jj rebase -s <change-C> -d main

# Move change A to be on top of C (bringing B with it)
jj rebase -b <change-A> -d <change-C>
```

---

## Summary: Key Workflows

```mermaid
mindmap
    root((jj Workflows))
        Basic Operations
            jj new: Create change
            jj describe: Add message
            jj edit: Switch to change
            jj log: View history
        Stacking
            Build incrementally
            Add bookmarks for PRs
            View with jj log -r ::@
        Editing History
            jj edit: Modify any change
            jj squash: Combine changes
            jj describe: Update messages
            Auto-rebase children
        Conflicts
            Non-blocking
            Marked, not fatal
            Resolve when convenient
            Auto-propagate fixes
        Multiple Changes
            Parallel work streams
            No stashing needed
            Switch with jj edit
            Independent changes
        Git Integration
            Colocated repos
            jj git fetch/push
            Auto-sync bookmarks
            Bidirectional
```

### Workflow Principles

1. **Work incrementally**: Create small, focused changes
2. **Describe as you go**: Use `jj describe` to document intent
3. **Edit freely**: History is mutable - fix mistakes anywhere
4. **Don't fear conflicts**: They won't block you
5. **Stack naturally**: Build changes on top of each other
6. **Bookmark for PRs**: Only create bookmarks when sharing

---

## Further Reading

- [Steve's Jujutsu Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/) - Hands-on workflows
- [Stavros: Switch to Jujutsu Already](https://www.stavros.io/posts/switch-to-jujutsu-already-a-tutorial/) - Practical patterns
- [jj Official Docs](https://jj-vcs.github.io/jj/) - Comprehensive reference

**Next**: See [JJ_DECISION_TREES.md](./JJ_DECISION_TREES.md) for decision-making guides and [JJ_STACKED_WORKFLOW.md](./JJ_STACKED_WORKFLOW.md) for jj-stack specific workflows.
