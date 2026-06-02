# Writing Guide Skill

Claude skill for creating well-structured technical documents with consistent voice, tone, and formatting.

## Installation

```bash
claude plugins add writing-guide@local-plugins
```

## Usage

```
/write-doc [document-type] [topic]
```

Examples:
```
/write-doc guide "API authentication"
/write-doc architecture "payment service"
/write-doc decision "database selection"
```

## What It Provides

- **Voice guidance**: Conversational technical tone, opinionated with context
- **Format selection**: When to use prose, lists, tables, diagrams
- **Structure templates**: BLUF and Problem-Solution patterns
- **Diagram conventions**: C4 levels, flowcharts, comparison diagrams
- **Anti-patterns**: Filler phrases, over-hedging, passive voice
