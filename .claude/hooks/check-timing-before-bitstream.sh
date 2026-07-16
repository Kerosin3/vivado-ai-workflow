#!/bin/bash
# PreToolUse hook: timing check before write_bitstream
# Registered in .claude/settings.json under PreToolUse, matcher "Bash"
#
# STRICT_TIMING=1 blocks write_bitstream on negative WNS (hard gate).
# STRICT_TIMING unset/0 just warns and lets it through — useful in early
# development when the design isn't fully wired up yet.
#
# Matches "bitstream.tcl" — the actual stage file is tcl/bake_bitstream.tcl,
# and "bitstream.tcl" is a substring of that, so this also catches the
# /build-docker flow's `docker run ... vivado -source tcl/bake_bitstream.tcl`
# invocation without needing to special-case it.
# Report path follows whatever BUILD_DIR the command set (e.g. -e
# BUILD_DIR=./build-docker), defaulting to ./build like the tcl scripts do.

INPUT=$(cat)
# Use jq, not a regex, to pull the command out — a "[^"]*" pattern breaks
# on any command containing an embedded escaped quote (e.g. "$(pwd)"),
# silently truncating the match before it ever reaches "bitstream.tcl".
# Confirmed live: the real /build-docker command (which quotes "$(pwd)")
# never matched under the old regex.
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$CMD" | grep -q "write_bitstream\|bitstream.tcl"; then
    BUILD_DIR=$(echo "$CMD" | grep -o 'BUILD_DIR=[^ "]*' | head -1 | cut -d= -f2)
    REPORT="${BUILD_DIR:-build}/reports/timing_summary.rpt"
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
