#!/bin/bash
# PreToolUse hook: timing check before write_bitstream
# Registered in .claude/settings.json under PreToolUse, matcher "Bash"
#
# STRICT_TIMING=1 blocks write_bitstream on negative WNS (hard gate).
# STRICT_TIMING unset/0 just warns and lets it through — useful in early
# development when the design isn't fully wired up yet.

INPUT=$(cat)
CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1)

if echo "$CMD" | grep -q "write_bitstream\|build_bitstream.tcl"; then
    REPORT="build/reports/timing_summary.rpt"
    if [ -f "$REPORT" ]; then
        WNS=$(grep -m1 "WNS" "$REPORT" | awk '{print $2}')
        if [ -n "$WNS" ] && (( $(echo "$WNS < 0" | bc -l 2>/dev/null || echo 0) )); then
            if [ "${STRICT_TIMING:-0}" = "1" ]; then
                echo "Blocked: WNS=$WNS (negative). Timing is not closed, write_bitstream refused." >&2
                exit 2
            else
                echo "Warning: WNS=$WNS (negative). Proceeding anyway — set STRICT_TIMING=1 to enforce a hard gate." >&2
                exit 1
            fi
        fi
    fi
fi

exit 0
