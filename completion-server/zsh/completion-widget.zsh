#!/usr/bin/env zsh
# WezTerm IDE-like completion widget
# Auto-triggers completions as you type with intelligent ranking

# Configuration
typeset -g COMPLETION_SERVER_SOCKET="${COMPLETION_SERVER_SOCKET:-/tmp/completion-server-$USER.sock}"
typeset -g COMPLETION_DELAY="${COMPLETION_DELAY:-200}"  # ms delay before triggering
typeset -g COMPLETION_MAX_RESULTS="${COMPLETION_MAX_RESULTS:-5}"

# State
typeset -g _completion_active=0
typeset -g _completion_position="below"  # "above" or "below"
typeset -g _completion_timer_id=""
typeset -g _completion_selected_index=0
typeset -g _completion_results=()

# Query completions from daemon
_completion_query() {
    local command_line="$BUFFER"
    local cursor_pos="$CURSOR"

    # Build JSON request
    local request="{\"command\":\"$command_line\",\"cursor\":$cursor_pos,\"max\":$COMPLETION_MAX_RESULTS}"

    # Send request to daemon via socket
    local response
    if [[ -S "$COMPLETION_SERVER_SOCKET" ]]; then
        response=$(echo "$request" | nc -U "$COMPLETION_SERVER_SOCKET" 2>/dev/null)
        if [[ $? -eq 0 && -n "$response" ]]; then
            echo "$response"
            return 0
        fi
    fi

    return 1
}

# Parse JSON response and extract completions
_completion_parse_response() {
    local response="$1"

    # Simple JSON parsing (would use jq in production)
    # For now, just extract values from response
    # Response format: {"completions":[{"value":"--hidden","description":"..."}],"error":""}

    # Extract completion count and values
    # This is a simplified parser - in production, use jq or similar
    echo "$response"
}

# Display completions UI
_completion_display() {
    local response="$1"

    if [[ -z "$response" ]]; then
        _completion_hide
        return
    fi

    # TODO: Render using completion-server show command or direct rendering
    # For now, display simple list

    # Save cursor position
    echo -n "\e[s"

    # Move based on position
    if [[ "$_completion_position" == "above" ]]; then
        echo -n "\e[5A"  # Move up 5 lines
    else
        echo -n "\n"     # Move down
    fi

    # Display response (simplified for now)
    echo "$response"

    # Restore cursor
    echo -n "\e[u"

    _completion_active=1
}

# Hide completions UI
_completion_hide() {
    if [[ $_completion_active -eq 1 ]]; then
        # Clear displayed content
        _completion_active=0
        zle -R  # Redraw prompt
    fi
}

# Toggle position (above/below)
_completion_toggle_position() {
    if [[ "$_completion_position" == "above" ]]; then
        _completion_position="below"
    else
        _completion_position="above"
    fi

    # Redisplay if active
    if [[ $_completion_active -eq 1 ]]; then
        _completion_trigger
    fi
}

# Navigate completions
_completion_next() {
    if [[ $_completion_active -eq 1 ]]; then
        (( _completion_selected_index++ ))
        _completion_trigger
    fi
}

_completion_prev() {
    if [[ $_completion_active -eq 1 ]]; then
        (( _completion_selected_index-- ))
        if [[ $_completion_selected_index -lt 0 ]]; then
            _completion_selected_index=0
        fi
        _completion_trigger
    fi
}

# Accept selected completion
_completion_accept() {
    if [[ $_completion_active -eq 1 ]]; then
        # TODO: Insert selected completion into BUFFER
        _completion_hide
    fi
}

# Cancel completions
_completion_cancel() {
    if [[ $_completion_active -eq 1 ]]; then
        _completion_hide
    fi
}

# Trigger completion query
_completion_trigger() {
    local response
    response=$(_completion_query)

    if [[ $? -eq 0 ]]; then
        _completion_display "$response"
    else
        _completion_hide
    fi
}

# Auto-trigger on buffer change (with delay)
_completion_on_change() {
    # Cancel existing timer
    if [[ -n "$_completion_timer_id" ]]; then
        # ZSH doesn't have built-in timers, so we use a background job
        # In production, this would use zsh/sched module
        kill "$_completion_timer_id" 2>/dev/null
    fi

    # Schedule new trigger after delay
    # Simplified: trigger immediately for now
    # TODO: Add proper delay mechanism
    _completion_trigger
}

# ZLE widget: handle self-insert (typing)
_completion_self_insert() {
    zle self-insert
    _completion_on_change
}

# ZLE widget: arrow down
_completion_down_line_or_next() {
    if [[ $_completion_active -eq 1 ]]; then
        _completion_next
    else
        zle down-line-or-history
    fi
}

# ZLE widget: arrow up
_completion_up_line_or_prev() {
    if [[ $_completion_active -eq 1 ]]; then
        _completion_prev
    else
        zle up-line-or-history
    fi
}

# ZLE widget: accept completion or accept line
_completion_accept_or_line() {
    if [[ $_completion_active -eq 1 ]]; then
        _completion_accept
    else
        zle accept-line
    fi
}

# ZLE widget: cancel completion or default
_completion_cancel_or_default() {
    if [[ $_completion_active -eq 1 ]]; then
        _completion_cancel
    else
        # Default behavior (send-break)
        zle send-break
    fi
}

# ZLE widget: toggle position
_completion_toggle_position_widget() {
    _completion_toggle_position
}

# Register ZLE widgets
zle -N _completion_self_insert
zle -N _completion_down_line_or_next
zle -N _completion_up_line_or_next
zle -N _completion_accept_or_line
zle -N _completion_cancel_or_default
zle -N _completion_toggle_position_widget

# Key bindings (configurable)
# These match mini.completion defaults where applicable
# Note: ZSH uses different syntax than Vim

# Auto-trigger on typing (intercept self-insert)
# Uncomment to enable auto-trigger:
# for key in {a..z} {A..Z} {0..9} - _ . /; do
#     bindkey "$key" _completion_self_insert
# done

# Navigation
bindkey '^N' _completion_down_line_or_next    # Ctrl-N: next (or Down arrow)
bindkey '^P' _completion_up_line_or_prev      # Ctrl-P: prev (or Up arrow)
bindkey '^[[A' _completion_up_line_or_prev    # Up arrow
bindkey '^[[B' _completion_down_line_or_next  # Down arrow

# Accept/Cancel
bindkey '^M' _completion_accept_or_line       # Enter
bindkey '^[' _completion_cancel_or_default    # Escape
bindkey '^C' _completion_cancel_or_default    # Ctrl-C

# Toggle position (Shift-Tab approximation - Tab with Shift modifier)
bindkey '^[[Z' _completion_toggle_position_widget  # Shift-Tab

# Manual trigger
bindkey '^X^C' _completion_trigger  # Ctrl-X Ctrl-C to manually trigger

# Cleanup on exit
_completion_cleanup() {
    _completion_hide
}

# Register cleanup hook
zshexit_functions+=(_completion_cleanup)

# Enable completions
# _completion_enable() {
#     # This would enable auto-triggering
#     # For now, use manual trigger (Ctrl-X Ctrl-C)
# }

# Print status
echo "WezTerm IDE completion widget loaded"
echo "  Socket: $COMPLETION_SERVER_SOCKET"
echo "  Delay: ${COMPLETION_DELAY}ms"
echo "  Max results: $COMPLETION_MAX_RESULTS"
echo ""
echo "Key bindings:"
echo "  Ctrl-X Ctrl-C: Trigger completions"
echo "  Up/Down or Ctrl-P/N: Navigate"
echo "  Enter: Accept"
echo "  Escape/Ctrl-C: Cancel"
echo "  Shift-Tab: Toggle position (above/below)"
echo ""
echo "To enable auto-trigger, uncomment the bindkey loop in completion-widget.zsh"
