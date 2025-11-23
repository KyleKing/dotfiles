# Jujutsu Mental Model: Core Concepts

This document explains the fundamental concepts and data structures in Jujutsu (jj) through visual diagrams.

## Table of Contents

- [Changes vs Commits](#changes-vs-commits)
- [Git vs jj Mental Models](#git-vs-jj-mental-models)
- [The Working Copy](#the-working-copy)
- [Identifiers: Change ID vs Commit ID](#identifiers-change-id-vs-commit-id)
- [The Operation Log](#the-operation-log)
- [Bookmarks vs Branches](#bookmarks-vs-branches)

---

## Changes vs Commits

> "The biggest difference between jj and git is that git revolves around commits as the main unit of change, while jj revolves around changesets."
>
> — [Jujutsu VCS Overview](https://levelup.gitconnected.com/jujutsu-vcs-a-git-compatible-revolution-in-version-control-620f9d3306fe)

### Key Distinction

```mermaid
graph TB
    subgraph "Git Model"
        GC1[Commit SHA abc123]
        GC2[Commit SHA def456]
        GC3[Commit SHA ghi789]

        GC1 --> |"Amend = New SHA"| GC2
        GC2 --> |"Modify = New SHA"| GC3

        style GC1 fill:#ffcccc
        style GC2 fill:#ffcccc
        style GC3 fill:#ffcccc
    end

    subgraph "jj Model"
        JC1["Change ID: kmkuslsw<br/>Commit: abc123"]
        JC2["Change ID: kmkuslsw<br/>Commit: def456"]
        JC3["Change ID: kmkuslsw<br/>Commit: ghi789"]

        JC1 --> |"Amend = Same ID"| JC2
        JC2 --> |"Modify = Same ID"| JC3

        style JC1 fill:#ccffcc
        style JC2 fill:#ccffcc
        style JC3 fill:#ccffcc
    end
```

**Git**: Commits are immutable. Any modification creates a new commit with a new SHA.

**jj**: Changes are mutable. The Change ID stays constant while the underlying commit SHA evolves.

### What This Means

| Concept | Git | Jujutsu |
|---------|-----|---------|
| **Fundamental Unit** | Commit (immutable snapshot) | Change (mutable logical unit) |
| **Identity** | SHA hash (content-based) | Change ID (stable across edits) |
| **Modification** | Creates new commit | Updates existing change |
| **History Tracking** | Compare commit SHAs | Track evolution via `jj evolog` |

> "A change, not a commit, is the fundamental element of the mental and working model. That means that you can describe a change that is still 'in progress' as it were."
>
> — [Chris Krycho: jj init](https://v5.chriskrycho.com/essays/jj-init/)

---

## Git vs jj Mental Models

### Git's Three-Stage Architecture

```mermaid
graph LR
    WD[Working Directory]
    SA[Staging Area<br/>git index]
    LR[Local Repository<br/>commits]
    RR[Remote Repository]

    WD --> |"git add"| SA
    SA --> |"git commit"| LR
    LR --> |"git push"| RR
    RR --> |"git fetch"| LR
    LR --> |"git checkout"| WD

    style SA fill:#ffffcc
    style WD fill:#ccffff
    style LR fill:#ffcccc
    style RR fill:#ccccff
```

### jj's Unified Model

```mermaid
graph LR
    WC["Working Copy<br/>@ (always a change)"]
    CH[Changes<br/>Immutable history]
    RM[Remote<br/>origin/*]

    WC --> |"Auto-snapshot"| CH
    CH --> |"jj git push"| RM
    RM --> |"jj git fetch"| CH
    CH --> |"jj edit"| WC

    style WC fill:#ccffcc
    style CH fill:#ccffff
    style RM fill:#ccccff
```

### Key Differences

| Aspect | Git | Jujutsu |
|--------|-----|---------|
| **Staging** | Explicit `git add` required | No staging - changes auto-tracked |
| **Working State** | Outside version control until added | Always inside a change (`@`) |
| **Stash** | Separate `git stash` mechanism | No stash needed - just switch changes |
| **Amend** | Special operation (`--amend`) | Natural operation (`jj describe`) |
| **Uncommitted Work** | Fragile, can be lost | Protected by operation log |

> "You are always inside a commit. Nothing exists outside commits—this eliminates stashing entirely and enables seamless context switching."
>
> — [Stavros: Switch to Jujutsu Already](https://www.stavros.io/posts/switch-to-jujutsu-already-a-tutorial/)

---

## The Working Copy

### Git's Working Directory

```mermaid
graph TB
    subgraph "Git Working State"
        WD[Working Directory]
        UT[Untracked Files]
        UN[Unstaged Changes]
        ST[Staged Changes]
        CM[Committed]

        UT --> |"git add"| ST
        UN --> |"git add"| ST
        ST --> |"git commit"| CM

        style UT fill:#ffcccc
        style UN fill:#ffffcc
        style ST fill:#ccffcc
        style CM fill:#ccccff
    end
```

### jj's Working Copy (`@`)

```mermaid
graph TB
    subgraph "jj Working Copy"
        WC["@ (Current Change)<br/>Always a valid change"]

        WC --> |"Automatic"| SNAP[Snapshot on every operation]
        SNAP --> |"jj describe"| DESC[Add description]
        DESC --> |"jj new"| NEW[Create next change]

        style WC fill:#ccffcc
        style SNAP fill:#ccffff
        style DESC fill:#ccffcc
        style NEW fill:#ccffff
    end
```

**Key Insight**: In jj, you're always working inside a change. The symbol `@` represents your current working copy change.

> "The basic jj workflow goes something like this: You create a new change, You modify files in your working tree, There is no step 3."
>
> — [Getting Started with Jujutsu](https://jj-tutorial.github.io/tutorial/core-concepts/changes-commits-and-revisions.html)

### Workflow Comparison

```mermaid
sequenceDiagram
    participant User
    participant Git
    participant jj

    Note over User,Git: Git Workflow
    User->>Git: Edit files
    User->>Git: git add .
    User->>Git: git commit -m "msg"

    Note over User,jj: jj Workflow
    User->>jj: jj new -m "msg"
    User->>jj: Edit files
    Note over jj: Done! Auto-tracked
```

---

## Identifiers: Change ID vs Commit ID

Every change in jj has TWO identifiers:

```mermaid
graph TB
    subgraph "Single Change in jj"
        CHG["Change: Feature X"]

        CID["Change ID: kmkuslsw<br/>(Stable, alphabetic)"]
        COM["Commit ID: a1b2c3d4<br/>(Git SHA, changes on edit)"]

        CHG --> CID
        CHG --> COM

        style CID fill:#ccffcc
        style COM fill:#ccccff
    end
```

### How They Work

```mermaid
timeline
    title Evolution of a Single Change
    section Initial
        Create change : Change ID kmkuslsw : Commit abc123
    section First Edit
        Add feature : Change ID kmkuslsw : Commit def456
    section Second Edit
        Address review : Change ID kmkuslsw : Commit ghi789
    section Final
        Ready to merge : Change ID kmkuslsw : Commit jkl012
```

### Viewing IDs

When you run `jj log`:

```
@  kmkuslsw kyle@example.com 2025-01-23 10:23:45 feature-x abc123de
│  Add new feature X
○  rpqostuw kyle@example.com 2025-01-22 15:10:32 main def456gh
│  Previous work
```

**Left side** (kmkuslsw): Change ID - stays constant

**Right side** (abc123de): Commit ID - changes with edits

> "When you run `jj st`, you see both identifiers: Left side: change IDs (purely letters, excluding a-f), Right side: commit IDs (hexadecimal)"
>
> — [Getting Started with Jujutsu](https://jj-tutorial.github.io/tutorial/core-concepts/changes-commits-and-revisions.html)

### Why Two IDs?

```mermaid
graph LR
    subgraph "Purpose"
        CID[Change ID]
        COM[Commit ID]

        CID --> |"Track logical work"| WORK[Feature/Fix]
        CID --> |"jj evolog"| HIST[View evolution]

        COM --> |"Git compatibility"| GIT[Git interop]
        COM --> |"Content-based"| HASH[SHA hash]
    end
```

**Change ID**: For tracking your work through iterations

**Commit ID**: For Git compatibility and content verification

---

## The Operation Log

One of jj's most powerful features is tracking **every operation**, not just commits.

### Git's Reflog

```mermaid
graph LR
    subgraph "Git Reflog"
        RC1[Commit abc]
        RC2[Commit def]
        RC3[Commit ghi]

        RC1 --> RC2
        RC2 --> RC3

        style RC1 fill:#ffcccc
        style RC2 fill:#ffcccc
        style RC3 fill:#ffcccc
    end
```

Only tracks commit operations on branches.

### jj's Operation Log

```mermaid
graph TB
    subgraph "jj Operation Log"
        OP1[Op: jj init]
        OP2[Op: jj new]
        OP3[Op: jj describe]
        OP4[Op: jj edit]
        OP5[Op: jj git fetch]
        OP6[Op: jj rebase]
        OP7[Op: jj squash]

        OP1 --> OP2
        OP2 --> OP3
        OP3 --> OP4
        OP4 --> OP5
        OP5 --> OP6
        OP6 --> OP7

        style OP1 fill:#ccffcc
        style OP2 fill:#ccffcc
        style OP3 fill:#ccffcc
        style OP4 fill:#ccffcc
        style OP5 fill:#ccffcc
        style OP6 fill:#ccffcc
        style OP7 fill:#ccffcc
    end
```

Tracks **every operation** including fetches, status checks, and failed operations.

### Why This Matters

```mermaid
graph TB
    subgraph "Recovery Scenarios"
        ERR[Made a mistake?]

        ERR --> VIEW[jj op log]
        VIEW --> FIND[Find state before mistake]
        FIND --> UNDO[jj op undo]

        UNDO --> RESTORE[Repository restored!]

        style ERR fill:#ffcccc
        style RESTORE fill:#ccffcc
    end
```

**Example**: Accidentally squashed the wrong commit?

```bash
jj op log              # See all operations
jj op undo             # Undo last operation
# Or restore to specific operation
jj op restore <op-id>
```

> "jj op log is much more useful and powerful than git reflog because it captures every action including status checks and fetches. This creates a comprehensive audit trail."
>
> — [Chris Krycho: jj init](https://v5.chriskrycho.com/essays/jj-init/)

### Operation Log Structure

```mermaid
graph LR
    subgraph "Each Operation Contains"
        OP[Operation]

        OP --> TIME[Timestamp]
        OP --> USER[User]
        OP --> CMD[Command run]
        OP --> BEFORE[State before]
        OP --> AFTER[State after]

        style OP fill:#ccffcc
    end
```

---

## Bookmarks vs Branches

In jj, what Git calls "branches" are called "bookmarks" to emphasize their role as movable pointers.

### Git Branches

```mermaid
gitGraph
    commit id: "main"
    branch feature
    commit id: "work 1"
    commit id: "work 2"
    checkout main
    commit id: "other work"
    checkout feature
    commit id: "work 3"
```

Branches are central to Git workflows.

### jj Bookmarks

```mermaid
graph TB
    subgraph "jj Repository"
        C1[Change 1<br/>main]
        C2[Change 2]
        C3[Change 3]
        C4[Change 4<br/>feature-x]

        C1 --> C2
        C2 --> C3
        C3 --> C4

        BM1[📌 main]
        BM2[📌 feature-x]

        BM1 -.- C1
        BM2 -.- C4

        style BM1 fill:#ffffcc
        style BM2 fill:#ffffcc
    end
```

### Key Differences

| Concept | Git | Jujutsu |
|---------|-----|---------|
| **Name** | Branches | Bookmarks |
| **Required?** | Often required | Optional - changes exist independently |
| **Creation** | `git checkout -b` | `jj bookmark create` |
| **Anonymous Work** | Detached HEAD state | Natural - work without bookmark |
| **Primary Unit** | Branch | Change |

> "Branches require no explicit naming in Jujutsu. Creating multiple commit paths happens naturally."
>
> — [Stavros: Switch to Jujutsu Already](https://www.stavros.io/posts/switch-to-jujutsu-already-a-tutorial/)

### Anonymous Changes

In jj, you can create entire workflows without bookmarks:

```mermaid
graph LR
    M[main] --> C1[Change 1]
    C1 --> C2[Change 2]
    C2 --> C3[Change 3]
    C3 --> C4["Change 4 (@)"]

    style M fill:#ccccff
    style C4 fill:#ccffcc
```

No bookmarks needed! Create them only when pushing to GitHub.

### Bookmark Lifecycle

```mermaid
stateDiagram-v2
    [*] --> NoBookmark: jj new
    NoBookmark --> HasBookmark: jj bookmark create
    HasBookmark --> Pushed: jj git push
    Pushed --> Merged: PR merged on GitHub
    Merged --> Deleted: jj git fetch (auto-deletes)
    Deleted --> [*]
```

---

## Summary: The jj Mental Model

```mermaid
mindmap
    root((jj Mental Model))
        Changes
            Mutable by default
            Stable Change ID
            Evolving Commit ID
            Track with evolog
        Working Copy
            Always @ symbol
            Always a valid change
            No staging area
            Auto-snapshotted
        Operation Log
            Every operation tracked
            Comprehensive undo
            Better than reflog
            Safety net
        Bookmarks
            Optional markers
            Like git branches
            Auto-deleted after merge
            Create only for PRs
        No Staging
            Files auto-tracked
            No git add
            No stash needed
            Simple workflow
```

### Core Principles

1. **Everything is a change**: Not just commits, but work-in-progress too
2. **Changes are mutable**: Edit, describe, squash freely
3. **No staging area**: Files are automatically tracked
4. **Always in a change**: Working copy is always `@`
5. **Operation log safety**: Every operation can be undone
6. **Bookmarks are optional**: Use them only for PRs/sharing

### Philosophical Shift

> "While Git treats commits as immutable objects frozen after creation, Jujutsu embraces a 'Play-Doh' approach where commits themselves are also the object of manipulation."
>
> — [Stavros: Switch to Jujutsu Already](https://www.stavros.io/posts/switch-to-jujutsu-already-a-tutorial/)

---

## Further Reading

- [Getting Started with Jujutsu](https://jj-tutorial.github.io/tutorial/core-concepts/changes-commits-and-revisions.html) - Core concepts explained
- [Steve's Jujutsu Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/) - Beginner-friendly guide
- [Chris Krycho: jj init](https://v5.chriskrycho.com/essays/jj-init/) - Deep dive into mental models
- [Stavros: Switch to Jujutsu Already](https://www.stavros.io/posts/switch-to-jujutsu-already-a-tutorial/) - Practical workflow guide

**Next**: See [JJ_WORKFLOWS.md](./JJ_WORKFLOWS.md) for visual workflow diagrams and [JJ_DECISION_TREES.md](./JJ_DECISION_TREES.md) for decision-making guides.
