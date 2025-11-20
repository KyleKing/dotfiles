#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320
#
# Usage Analytics for Shell Configuration

# Analyze command usage from history
analyze-commands() {
    echo "📊 Top 20 Most Used Commands (from history):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # Extract command usage statistics from history
    history | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' \
        | grep -v "./" | column -c3 -s " " -t | sort -nr | nl | head -n20
    echo ""
}

# Find potentially unused aliases
analyze-aliases() {
    echo "🔍 Checking for Unused Aliases..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get all aliases
    alias | cut -d'=' -f1 > /tmp/all_aliases.txt

    local unused_count=0
    local total_count=0

    # Search history for usage
    while IFS= read -r a; do
        total_count=$((total_count + 1))
        # Check if alias appears in recent history (last 1000 commands)
        if ! history -1000 | grep -q "^[[:space:]]*[0-9]*[[:space:]]*$a"; then
            echo "  ⚠️  $a"
            unused_count=$((unused_count + 1))
        fi
    done < /tmp/all_aliases.txt

    echo ""
    echo "Summary: $unused_count/$total_count aliases not found in last 1000 commands"
    echo "Note: Aliases may still be useful even if not in recent history"
    echo ""
    rm /tmp/all_aliases.txt
}

# Analyze function usage
analyze-functions() {
    echo "🔧 Checking for Unused Functions..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get all functions
    functions | grep -E '^\w+' | awk '{print $1}' > /tmp/all_functions.txt

    local unused_count=0
    local total_count=0

    while IFS= read -r func; do
        # Skip internal/private functions (starting with _)
        if [[ $func != _* ]]; then
            total_count=$((total_count + 1))
            if ! history -1000 | grep -q "$func"; then
                echo "  ⚠️  $func"
                unused_count=$((unused_count + 1))
            fi
        fi
    done < /tmp/all_functions.txt

    echo ""
    echo "Summary: $unused_count/$total_count functions not found in last 1000 commands"
    echo ""
    rm /tmp/all_functions.txt
}

# Show tool installation sources
analyze-tool-sources() {
    echo "📦 Tool Installation Analysis:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "Brew packages:"
    brew leaves | wc -l | xargs echo "  Total:"

    echo ""
    echo "mise tools:"
    mise list 2>/dev/null | wc -l | xargs echo "  Total:"

    echo ""
    echo "uv tools:"
    uv tool list 2>/dev/null | grep -c '^' | xargs echo "  Total:"

    echo ""
    echo "npm global packages:"
    npm list -g --depth=0 2>/dev/null | grep -c '^' | xargs echo "  Total:"

    echo ""
}

# Comprehensive usage report
analyze-all() {
    echo "═══════════════════════════════════════════════════════"
    echo "  Shell Configuration Usage Analysis"
    echo "  Generated: $(date)"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    analyze-commands
    echo ""
    analyze-tool-sources
    echo ""
    analyze-aliases
    echo ""
    analyze-functions

    echo "═══════════════════════════════════════════════════════"
    echo "💡 Tip: Run 'analyze-commands' for quick command stats"
    echo "═══════════════════════════════════════════════════════"
}
