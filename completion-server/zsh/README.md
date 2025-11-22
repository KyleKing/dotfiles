# ZSH Widget Integration

This directory contains the ZSH widget for WezTerm IDE-like completions.

## Quick Start

1. **Start the daemon:**
   ```bash
   completion-server daemon &
   ```

2. **Load the widget in your `.zshrc`:**
   ```bash
   source /path/to/completion-server/zsh/completion-widget.zsh
   ```

3. **Use the completions:**
   - Manual trigger: `Ctrl-X Ctrl-C`
   - Navigate: `Up/Down` or `Ctrl-P/N`
   - Accept: `Enter`
   - Cancel: `Escape` or `Ctrl-C`
   - Toggle position: `Shift-Tab`

## Configuration

Set these environment variables before sourcing the widget:

```bash
# Socket path (default: /tmp/completion-server-$USER.sock)
export COMPLETION_SERVER_SOCKET="/tmp/completion-server-$USER.sock"

# Delay before triggering (ms, default: 200)
export COMPLETION_DELAY=200

# Max results to show (default: 5)
export COMPLETION_MAX_RESULTS=5
```

## Auto-Trigger Mode

To enable auto-triggering as you type, uncomment the `bindkey` loop in `completion-widget.zsh`:

```bash
# Auto-trigger on typing (intercept self-insert)
for key in {a..z} {A..Z} {0..9} - _ . /; do
    bindkey "$key" _completion_self_insert
done
```

**Note:** This intercepts every keystroke, which may affect performance. Start with manual trigger mode and enable auto-trigger once you've tested the daemon performance.

## Key Bindings

| Key | Action |
|-----|--------|
| `Ctrl-X Ctrl-C` | Trigger completions manually |
| `Up` / `Ctrl-P` | Previous completion |
| `Down` / `Ctrl-N` | Next completion |
| `Enter` | Accept selected completion |
| `Escape` / `Ctrl-C` | Cancel completions |
| `Shift-Tab` | Toggle position (above/below prompt) |

## Architecture

```
ZSH Widget → Unix Socket → Daemon → Engine → Sources
                                    ↓
                                  Ranker (with history)
                                    ↓
                                UI Renderer
                                    ↓
                              ANSI Output
```

## Troubleshooting

**Completions not appearing?**
- Check daemon is running: `ps aux | grep completion-server`
- Check socket exists: `ls -la /tmp/completion-server-$USER.sock`
- Test manually: `completion-server show "fd "`

**Slow performance?**
- Increase `COMPLETION_DELAY`
- Reduce `COMPLETION_MAX_RESULTS`
- Check daemon logs

**Display issues?**
- Verify terminal supports ANSI escape codes
- Check `$TERM` is set correctly
- Try toggling position with `Shift-Tab`

## Development

To test changes to the widget:

```bash
# Reload in current shell
source completion-server/zsh/completion-widget.zsh

# Test with show command
completion-server show "git checkout "

# Test daemon connection
echo '{"command":"fd ","cursor":3,"max":5}' | nc -U /tmp/completion-server-$USER.sock
```

## Future Enhancements

- [ ] Proper timer/delay implementation using `zsh/sched`
- [ ] Better JSON parsing (use `jq` or pure ZSH)
- [ ] Caching of results for better performance
- [ ] Context-aware filtering
- [ ] Integration with existing ZSH completion system
- [ ] Fuzzy matching for partial completions
