# Mise Skill Plugin

A Claude Code skill for managing and running mise tasks directly from your conversation.

## Installation

The plugin is located at `~/.claude/plugins/repos/mise-skill/`.

To enable it, restart Claude Code or run:
```bash
claude plugins reload
```

## Usage

### List all available tasks:
```
/mise
```
or
```
/mise list
```

### Run a task:
```
/mise <task-name>
```

### Run a task with arguments:
```
/mise <task-name> arg1 arg2
```

### Examples:

```
/mise test-telescope
/mise test-telescope /path/to/project
/mise deps
/mise format
```

## Features

- Lists all available mise tasks with descriptions
- Executes tasks with argument support
- Handles environment variables
- Shows helpful error messages
- Validates task existence before running

## Requirements

- `mise` must be installed and available in PATH
- Project must have a `mise.toml` file

## Plugin Structure

```
~/.claude/plugins/repos/mise-skill/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── commands/
│   └── mise.md              # Skill definition
└── README.md                # This file
```

## Development

To modify the skill:

1. Edit `commands/mise.md` to change behavior
2. Edit `.claude-plugin/plugin.json` to update metadata
3. Reload plugins in Claude Code

## Notes

- The skill uses the `Bash`, `Read`, and `Glob` tools
- Task output is displayed in real-time
- Supports all mise.toml task configurations
