---
description: "Manage and run mise tasks"
argument-hint: "[task-name] [args...]"
allowed-tools: ["Bash", "Read", "Glob"]
---

# Mise Task Manager

Execute and manage mise tasks defined in the project's mise.toml file.

**Task name and arguments:** "$ARGUMENTS"

## Workflow:

1. **Parse Arguments**
   - If no arguments: List all available tasks
   - If first argument is "help" or "--help": Show this help
   - If first argument is "list" or "ls": List all tasks with descriptions
   - Otherwise: Execute the specified task with remaining arguments

2. **List Available Tasks**
   - Run `mise tasks --no-header` to get all tasks
   - Parse the output to show task names and descriptions
   - Format as a clean, readable list

3. **Execute Task**
   - Validate task exists in mise.toml
   - Show task description before running
   - Execute with `mise run <task-name> [args...]`
   - Display output in real-time
   - Report success or failure

4. **Handle Arguments**
   - Pass all additional arguments to the mise task
   - For tasks with usage specifications, validate arguments
   - Show usage hint if arguments are invalid

## Usage Examples:

**List all tasks:**
```
/mise
# or
/mise list
```

**Show task details:**
```
/mise <task-name> --help
```

**Run a task:**
```
/mise test-telescope
```

**Run task with arguments:**
```
/mise test-telescope /path/to/project
```

**Run with environment variables:**
```
PROJECT=/custom/path /mise test-mini
```

## Implementation Details:

**Step 1: Check if mise is available**
```bash
mise --version
```

**Step 2: List tasks (if no args or list command)**
```bash
mise tasks --no-header
```

**Step 3: Execute task**
```bash
mise run <task-name> [args...]
```

## Error Handling:

- **mise not installed**: Provide installation instructions
- **No mise.toml found**: Check for mise.toml in current directory
- **Task not found**: List available tasks
- **Task execution fails**: Show error output and exit code

## Tips:

- **Discover tasks**: Run `/mise` without arguments
- **Check task args**: Tasks with usage specifications show help with `--help`
- **Environment variables**: Mise automatically loads env vars from mise.toml
- **Project detection**: Mise searches parent directories for mise.toml

## Common Tasks:

Based on typical mise.toml configurations:
- `test`: Run test suite
- `lint`: Run linters
- `format`: Format code
- `build`: Build project
- `dev`: Start development server
- `clean`: Clean build artifacts

## Notes:

- Tasks are defined in `mise.toml` in the project root
- Task arguments are passed positionally or via environment variables
- Mise automatically handles dependencies between tasks
- Tasks can define their own usage specifications with arg validation
