# Stacked Diffs Workflow with jj-stack

This document visualizes how jj-stack manages stacked pull requests on GitHub.

## Table of Contents

- [What are Stacked Diffs?](#what-are-stacked-diffs)
- [jj-stack Architecture](#jj-stack-architecture)
- [Creating a Stack](#creating-a-stack)
- [jj-stack PR Creation Logic](#jj-stack-pr-creation-logic)
- [Managing Stack Updates](#managing-stack-updates)
- [After PR Merges](#after-pr-merges)
- [Advanced Stack Patterns](#advanced-stack-patterns)

---

## What are Stacked Diffs?

### Traditional Git Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant PR1 as PR #123
    participant PR2 as PR #124
    participant Main as main branch

    Dev->>PR1: Create Feature A
    Note over PR1: Wait for review...
    Note over PR1: Wait for approval...
    Note over PR1: Wait for merge...
    PR1->>Main: Merged!

    Note over Dev: Only NOW can start dependent work

    Dev->>PR2: Create Feature B (depends on A)
    Note over PR2: Review, approve, merge...
    PR2->>Main: Merged!
```

**Problem**: Sequential development. Feature B must wait for Feature A to merge.

### Stacked Diffs Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant PR1 as PR #123: A→main
    participant PR2 as PR #124: B→A
    participant PR3 as PR #125: C→B
    participant Main as main branch

    Dev->>PR1: Create A
    Dev->>PR2: Create B (stacked on A)
    Dev->>PR3: Create C (stacked on B)

    Note over PR1,PR3: All under review simultaneously!

    PR1->>Main: Merge A
    Note over PR2: Auto-rebases to main!
    PR2->>Main: Merge B
    Note over PR3: Auto-rebases to main!
    PR3->>Main: Merge C

    Note over Dev,Main: Much faster! Parallel review.
```

**Benefit**: Parallel development and review of dependent changes.

> "Stacked PRs are straight-up easy with jj. When someone requests changes to the first link in a chain of PRs, you can make changes, fix any conflicts higher up, and when you push, all PRs are updated."
>
> — [Community Discussion](https://github.com/jj-vcs/jj/discussions/5509)

---

## jj-stack Architecture

### How jj-stack Works

```mermaid
graph TB
    subgraph "Local Repository (jj)"
        M[main]
        A["Change A<br/>kmkuslsw<br/>📌 refactor-utils"]
        B["Change B<br/>rpqostuw<br/>📌 add-feature"]
        C["Change C<br/>zxnmqwer<br/>📌 add-tests"]

        M --> A
        A --> B
        B --> C
    end

    subgraph "jj-stack Analysis"
        JST[jj-stack CLI]

        JST --> GRAPH[Analyze bookmark graph]
        GRAPH --> DEPS[Determine dependencies]
        DEPS --> BASES[Calculate base branches]
    end

    subgraph "GitHub"
        PR1["PR #123<br/>refactor-utils → main"]
        PR2["PR #124<br/>add-feature → refactor-utils"]
        PR3["PR #125<br/>add-tests → add-feature"]

        NAV[Navigation comments<br/>showing stack structure]
    end

    A --> JST
    B --> JST
    C --> JST

    JST --> PR1
    JST --> PR2
    JST --> PR3
    JST --> NAV

    style JST fill:#ffffcc
    style GRAPH fill:#ccffcc
    style DEPS fill:#ccffcc
    style BASES fill:#ccffcc
```

### Key Components

1. **Local Changes**: Regular jj changes with bookmarks
2. **jj-stack**: Analyzes bookmark relationships
3. **GitHub PRs**: Created with correct base branches
4. **Navigation**: Comments added to show stack hierarchy

---

## Creating a Stack

### Step-by-Step Visual

```mermaid
graph TB
    subgraph "Step 1: Create First Change"
        M1[main]
        A1["@ Change A<br/>Refactor utils"]
        M1 --> A1

        CMD1["jj new main -m 'Refactor utils'<br/># make changes...<br/>jj bookmark create refactor-utils"]
    end

    subgraph "Step 2: Stack Second Change"
        M2[main]
        A2["Change A<br/>📌 refactor-utils"]
        B2["@ Change B<br/>Add feature"]
        M2 --> A2
        A2 --> B2

        CMD2["jj new -m 'Add feature using utils'<br/># make changes...<br/>jj bookmark create add-feature"]
    end

    subgraph "Step 3: Stack Third Change"
        M3[main]
        A3["Change A<br/>📌 refactor-utils"]
        B3["Change B<br/>📌 add-feature"]
        C3["@ Change C<br/>Add tests"]
        M3 --> A3
        A3 --> B3
        B3 --> C3

        CMD3["jj new -m 'Add tests'<br/># make changes...<br/>jj bookmark create add-tests"]
    end

    style A1 fill:#ccffcc
    style B2 fill:#ccffcc
    style C3 fill:#ccffcc
```

### Commands

```bash
# 1. Create first change
jj new main -m "Refactor utility functions"
# ... edit files ...
jj bookmark create refactor-utils -r @

# 2. Stack second change
jj new -m "Add feature using refactored utils"
# ... edit files ...
jj bookmark create add-feature -r @

# 3. Stack third change
jj new -m "Add comprehensive tests"
# ... edit files ...
jj bookmark create add-tests -r @

# View your stack
jj log -r ::@
```

**Output**:

```
@  zxnmqwer kyle 2m add-tests abc123de
│  Add comprehensive tests
○  rpqostuw kyle 15m add-feature def456gh
│  Add feature using refactored utils
○  kmkuslsw kyle 1h refactor-utils ghi789jk
│  Refactor utility functions
○  main
```

---

## jj-stack PR Creation Logic

### How jj-stack Determines Base Branches

```mermaid
graph TD
    START[jst submit b1 b2 b3]

    START --> ANALYZE[Analyze bookmarks]

    ANALYZE --> B1{Bookmark: b1}
    B1 --> B1_PARENT{Has parent<br/>bookmark?}
    B1_PARENT --> B1_NO["No → Base: main"]
    B1_PARENT --> B1_YES["Yes → Base: parent bookmark"]

    ANALYZE --> B2{Bookmark: b2}
    B2 --> B2_PARENT{Has parent<br/>bookmark?}
    B2_PARENT --> B2_NO["No → Base: main"]
    B2_PARENT --> B2_YES["Yes → Base: b1"]

    ANALYZE --> B3{Bookmark: b3}
    B3 --> B3_PARENT{Has parent<br/>bookmark?}
    B3_PARENT --> B3_NO["No → Base: main"]
    B3_PARENT --> B3_YES["Yes → Base: b2"]

    B1_NO --> PR1["PR: b1 → main"]
    B1_YES --> PR1

    B2_NO --> PR2["PR: b2 → main"]
    B2_YES --> PR2["PR: b2 → b1"]

    B3_NO --> PR3["PR: b3 → main"]
    B3_YES --> PR3["PR: b3 → b2"]

    style ANALYZE fill:#ffffcc
    style PR1 fill:#ccffcc
    style PR2 fill:#ccffcc
    style PR3 fill:#ccffcc
```

### Example: Submit Command

```bash
jst submit refactor-utils add-feature add-tests
```

**jj-stack's logic**:

```mermaid
sequenceDiagram
    participant User
    participant jst as jj-stack
    participant jj
    participant GitHub

    User->>jst: jst submit refactor-utils add-feature add-tests

    jst->>jj: Analyze bookmark graph
    jj-->>jst: Graph data

    Note over jst: refactor-utils parent: main<br/>add-feature parent: refactor-utils<br/>add-tests parent: add-feature

    jst->>GitHub: Create PR #123: refactor-utils → main
    GitHub-->>jst: ✓ Created

    jst->>GitHub: Create PR #124: add-feature → refactor-utils
    GitHub-->>jst: ✓ Created

    jst->>GitHub: Create PR #125: add-tests → add-feature
    GitHub-->>jst: ✓ Created

    jst->>GitHub: Add navigation comments to each PR
    GitHub-->>jst: ✓ Added

    jst-->>User: ✓ Submitted 3 PRs
```

### GitHub PR Structure

```mermaid
graph TB
    subgraph "GitHub PRs"
        MAIN[main branch]

        PR1["PR #123<br/>refactor-utils → main<br/><br/>📝 This is the base of the stack"]
        PR2["PR #124<br/>add-feature → refactor-utils<br/><br/>📝 Depends on: PR #123<br/>📝 Required by: PR #125"]
        PR3["PR #125<br/>add-tests → add-feature<br/><br/>📝 Depends on: PR #124"]

        MAIN -.-> PR1
        PR1 -.-> PR2
        PR2 -.-> PR3
    end

    style PR1 fill:#ccffff
    style PR2 fill:#ccffff
    style PR3 fill:#ccffff
```

**Navigation comments** help reviewers understand the stack structure.

---

## Managing Stack Updates

### Scenario: Update Middle of Stack

```mermaid
graph TB
    subgraph "Before: Update Change A"
        M1[main]
        A1["Change A<br/>📌 refactor-utils<br/>❌ Review comments"]
        B1["Change B<br/>📌 add-feature"]
        C1["Change C<br/>📌 add-tests"]

        M1 --> A1
        A1 --> B1
        B1 --> C1
    end

    subgraph "Edit Change A"
        CMD["jj edit &lt;change-A-id&gt;<br/># make changes...<br/># Changes auto-tracked"]
    end

    subgraph "After: Automatically Rebased"
        M2[main]
        A2["Change A ✓<br/>📌 refactor-utils<br/>(updated)"]
        B2["Change B ✓<br/>📌 add-feature<br/>(auto-rebased)"]
        C2["Change C ✓<br/>📌 add-tests<br/>(auto-rebased)"]

        M2 --> A2
        A2 --> B2
        B2 --> C2
    end

    subgraph "Push Updates"
        PUSH["jst submit refactor-utils add-feature add-tests"]
    end

    style A1 fill:#ffcccc
    style A2 fill:#ccffcc
    style B2 fill:#ccffcc
    style C2 fill:#ccffcc
```

### Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant jj
    participant jst as jj-stack
    participant GitHub

    Note over Dev: Review comment on Change A

    Dev->>jj: jj edit <change-A-id>
    jj-->>Dev: @ now at Change A

    Dev->>jj: Make changes (auto-tracked)
    Note over jj: Changes B and C<br/>automatically rebased!

    Dev->>jst: jst submit refactor-utils add-feature add-tests
    jst->>GitHub: Update PR #123 (new commits)
    jst->>GitHub: Update PR #124 (rebased)
    jst->>GitHub: Update PR #125 (rebased)

    GitHub-->>Dev: ✓ All PRs updated!
```

**Commands**:

```bash
# 1. Edit the change that needs updates
jj edit <change-A-id>
# or: jj edit refactor-utils~  (bookmark's change)

# 2. Make your changes
# Files are auto-tracked

# 3. Update all PRs
jst submit refactor-utils add-feature add-tests

# Or update just one PR (others will update automatically if needed)
jst submit refactor-utils
```

---

## After PR Merges

### Bottom PR Merges First

```mermaid
graph TB
    subgraph "Before: PR #123 Merges"
        M1[main]
        A1["refactor-utils<br/>PR #123"]
        B1["add-feature<br/>PR #124 → refactor-utils"]
        C1["add-tests<br/>PR #125 → add-feature"]

        M1 -.-> A1
        A1 -.-> B1
        B1 -.-> C1
    end

    subgraph "On GitHub: Merge PR #123"
        GH[GitHub merges refactor-utils into main]
    end

    subgraph "After: jj git fetch"
        M2["main<br/>(includes refactor-utils)"]
        B2["add-feature<br/>PR #124 → refactor-utils ❌"]
        C2["add-tests<br/>PR #125 → add-feature"]

        M2 -.-> B2
        B2 -.-> C2

        NOTE["refactor-utils bookmark<br/>auto-deleted locally"]
    end

    subgraph "After: jj rebase -d main"
        M3["main"]
        B3["add-feature ✓<br/>PR #124 → main (updated)"]
        C3["add-tests ✓<br/>PR #125 → add-feature"]

        M3 --> B3
        B3 --> C3
    end

    style A1 fill:#ffffcc
    style B2 fill:#ffcccc
    style B3 fill:#ccffcc
    style C3 fill:#ccffcc
```

### Workflow After Merge

```mermaid
sequenceDiagram
    participant GitHub
    participant Dev as Developer
    participant jj
    participant jst as jj-stack

    Note over GitHub: PR #123 merged!

    Dev->>jj: jj git fetch
    jj-->>Dev: ✓ refactor-utils bookmark deleted<br/>✓ main updated

    Dev->>jj: jj rebase -d main
    Note over jj: Rebase remaining changes<br/>onto updated main

    jj-->>Dev: ✓ add-feature rebased onto main<br/>✓ add-tests rebased onto add-feature

    Dev->>jst: jst submit add-feature add-tests
    jst->>GitHub: Update PR #124: add-feature → main
    jst->>GitHub: Update PR #125: add-tests → add-feature

    GitHub-->>Dev: ✓ Stack updated!
```

**Commands**:

```bash
# 1. After PR #123 merges on GitHub
jj git fetch
# Bookmark 'refactor-utils' is auto-deleted
# main is updated

# 2. Rebase remaining work onto main
jj rebase -d main
# add-feature now based on main
# add-tests still based on add-feature

# 3. Update remaining PRs
jst submit add-feature add-tests
# PR #124 now targets main instead of refactor-utils
# PR #125 still targets add-feature
```

### Helper Function

Use the `jclean-merged` helper:

```bash
# Does all three steps
jclean-merged

# Equivalent to:
# jj git fetch && jj rebase -d main
```

---

## Advanced Stack Patterns

### Pattern: Parallel Stacks

```mermaid
graph TB
    M[main]

    A1["Feature A-1<br/>📌 feature-a"]
    A2["Feature A-2<br/>📌 feature-a-tests"]

    B1["Feature B<br/>📌 feature-b"]

    C1["Bugfix<br/>📌 fix-123"]

    M --> A1
    A1 --> A2

    M --> B1

    M --> C1

    style A1 fill:#ccffff
    style A2 fill:#ccffff
    style B1 fill:#ccffcc
    style C1 fill:#ffffcc
```

**Multiple independent stacks**:

- Stack 1: feature-a, feature-a-tests
- Independent: feature-b
- Independent: fix-123

**Submit separately**:

```bash
jst submit feature-a feature-a-tests  # Stack 1
jst submit feature-b                   # Independent
jst submit fix-123                     # Independent
```

### Pattern: Diamond Dependency

```mermaid
graph TB
    M[main]

    BASE["base-refactor<br/>📌 base"]

    A["feature-a<br/>📌 feat-a"]
    B["feature-b<br/>📌 feat-b"]

    MERGE["merge-features<br/>📌 merge-ab"]

    M --> BASE
    BASE --> A
    BASE --> B
    A --> MERGE
    B --> MERGE

    style BASE fill:#ccffff
    style A fill:#ccffcc
    style B fill:#ccffcc
    style MERGE fill:#ffffcc
```

**Complex dependency**:

- base-refactor: Base change
- feature-a & feature-b: Both depend on base
- merge-features: Depends on both A and B

**Note**: jj-stack works best with linear stacks. For diamond dependencies, you may need to submit as:

```bash
jst submit base           # PR #1: base → main
jst submit feat-a         # PR #2: feat-a → base
jst submit feat-b         # PR #3: feat-b → base
# merge-ab would need manual handling
```

### Pattern: Incremental Feature Development

```mermaid
timeline
    title Feature Development Over Time
    section Week 1
        Core Implementation : refactor-utils
    section Week 2
        Basic Feature : add-basic-feature
        Tests : add-basic-tests
    section Week 3
        Advanced Feature : add-advanced-feature
        More Tests : add-advanced-tests
    section Week 4
        Documentation : add-docs
        Polish : final-polish
```

**All as one stack**:

```mermaid
graph TB
    M[main]
    M --> R[refactor-utils]
    R --> BF[add-basic-feature]
    BF --> BT[add-basic-tests]
    BT --> AF[add-advanced-feature]
    AF --> AT[add-advanced-tests]
    AT --> D[add-docs]
    D --> P[final-polish]

    style R fill:#ccffff
    style BF fill:#ccffff
    style BT fill:#ccffff
    style AF fill:#ccffcc
    style AT fill:#ccffcc
    style D fill:#ffffcc
    style P fill:#ffffcc
```

**Submit incrementally**:

```bash
# Week 1
jst submit refactor-utils

# Week 2
jst submit refactor-utils add-basic-feature add-basic-tests

# Week 3
jst submit refactor-utils add-basic-feature add-basic-tests \
           add-advanced-feature add-advanced-tests

# Week 4
jst submit refactor-utils add-basic-feature add-basic-tests \
           add-advanced-feature add-advanced-tests add-docs final-polish
```

As bottom PRs merge, rebase and re-submit remaining stack.

---

## Best Practices for Stacked Diffs

### 1. Keep Changes Focused

```mermaid
graph LR
    subgraph "❌ Bad: Large Changes"
        B1["Huge change<br/>10,000 lines<br/>Multiple features"]
    end

    subgraph "✓ Good: Small Focused Changes"
        G1["Refactor: 200 lines"]
        G2["Feature: 300 lines"]
        G3["Tests: 150 lines"]
        G4["Docs: 50 lines"]

        G1 --> G2
        G2 --> G3
        G3 --> G4
    end

    style B1 fill:#ffcccc
    style G1 fill:#ccffcc
    style G2 fill:#ccffcc
    style G3 fill:#ccffcc
    style G4 fill:#ccffcc
```

**Why**: Smaller changes are easier to review and merge faster.

### 2. Logical Ordering

```mermaid
graph TB
    M[main]

    M --> STEP1["1. Refactor/Prep<br/>(Foundation)"]
    STEP1 --> STEP2["2. Core Feature<br/>(Main work)"]
    STEP2 --> STEP3["3. Tests<br/>(Verification)"]
    STEP3 --> STEP4["4. Documentation<br/>(Polish)"]

    style STEP1 fill:#ccffff
    style STEP2 fill:#ccffcc
    style STEP3 fill:#ffffcc
    style STEP4 fill:#ffccff
```

**Order**: Foundation → Feature → Tests → Docs

### 3. Meaningful Bookmark Names

```bash
# ❌ Bad
jj bookmark create fix
jj bookmark create stuff
jj bookmark create tmp

# ✓ Good
jj bookmark create refactor-user-service
jj bookmark create add-user-authentication
jj bookmark create add-auth-tests
```

### 4. Update Entire Stack

```bash
# ❌ Partial update (may cause issues)
jst submit refactor-utils

# ✓ Update entire stack
jst submit refactor-utils add-feature add-tests
```

---

## Troubleshooting Stacks

### Issue: PR Has Wrong Base

```mermaid
graph TB
    PROBLEM["PR #124: add-feature → main<br/>❌ Should target refactor-utils"]

    PROBLEM --> FIX[Fix the bookmark graph]

    FIX --> CHECK["jj log -r 'bookmarks()'<br/>(verify relationships)"]

    CHECK --> REBASE["jj rebase -b add-feature -d refactor-utils"]

    REBASE --> UPDATE["jst submit add-feature"]

    style PROBLEM fill:#ffcccc
    style REBASE fill:#ffffcc
    style UPDATE fill:#ccffcc
```

**Commands**:

```bash
# Check current structure
jj log -r 'bookmarks()'

# Fix: rebase add-feature onto refactor-utils
jj rebase -b add-feature -d refactor-utils

# Re-submit
jst submit add-feature
```

### Issue: Lost Track of Stack

```bash
# View all your bookmarks and their relationships
jj log -r 'bookmarks() & mine()'

# Or use lazyjj for visual exploration
lazyjj
```

### Issue: Conflict in Middle of Stack

```mermaid
sequenceDiagram
    participant jj
    participant Dev

    Dev->>jj: jj rebase -d main
    jj-->>Dev: ⚠️ Change B conflicted

    Note over Dev: Option 1: Fix now

    Dev->>jj: jj edit <change-B>
    Dev->>jj: Resolve conflicts
    jj-->>Dev: ✓ Resolved (children auto-updated)

    Note over Dev: Option 2: Fix later

    Dev->>jj: jj new main -m "Other work"
    Note over Dev: Work on something else
    Dev->>jj: jj edit <change-B> (later)
    Dev->>jj: Resolve conflicts
```

**Conflicts don't block**: Resolve when convenient.

---

## Summary: Stacked Workflow

```mermaid
mindmap
    root((Stacked Diffs))
        Create Stack
            jj new for each change
            Bookmark each change
            View with jj log -r ::@
        Submit to GitHub
            jst submit b1 b2 b3
            Auto-determines bases
            Creates linked PRs
            Adds navigation
        Update Stack
            Edit any change
            Auto-rebases children
            Re-submit entire stack
        After Merge
            jj git fetch
            jj rebase -d main
            Submit remaining PRs
        Benefits
            Parallel review
            Faster iteration
            Logical separation
            Easy to update
```

### Key Principles

1. **Build incrementally**: Stack changes as you work
2. **Bookmark before submitting**: jj-stack needs bookmarks
3. **Submit entire stack**: Use `jst submit` with all bookmarks
4. **Update atomically**: Re-submit whole stack after changes
5. **Rebase after merges**: Keep remaining PRs up to date

> "This is already an enormous upgrade compared to Git with its manual git rebase --ontos for every child PR."
>
> — [GitHub Discussion](https://github.com/jj-vcs/jj/discussions/5509)

---

## Further Reading

- [JJ_MENTAL_MODEL.md](./JJ_MENTAL_MODEL.md) - Core concepts
- [JJ_WORKFLOWS.md](./JJ_WORKFLOWS.md) - General workflows
- [JJ_DECISION_TREES.md](./JJ_DECISION_TREES.md) - Command selection guide
- [jj-stack GitHub](https://github.com/keanemind/jj-stack) - Tool documentation
- [Getting Started Guide](./JJ_GETTING_STARTED.md) - Quick start tutorial
