#!/bin/bash
# PostToolUse hook: write a sha256 checksum file next to any freshly-copied
# bitstream in output_products/{local,docker}/.
# Registered in .claude/settings.json under PostToolUse, matcher "Bash"
#
# Fires after any command that touches tcl/bake_bitstream.tcl (matches
# "bitstream.tcl", same substring convention as
# check-timing-before-bitstream.sh, so this also catches the /build-docker
# flow's containerized invocation without special-casing it).
#
# Scans both output_products/*/ dirs rather than trying to parse which
# engine the command targeted — cheap, and handles either build path (or
# both, if run back to back) with one code path. Only (re)writes the
# .sha256 file when the .bit is newer than it, so this is a no-op on
# commands that didn't actually produce a new bitstream.

INPUT=$(cat)
CMD=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1)

if echo "$CMD" | grep -q "bitstream.tcl"; then
    for bit in output_products/local/*.bit output_products/docker/*.bit; do
        [ -f "$bit" ] || continue
        sha_file="${bit}.sha256"
        if [ ! -f "$sha_file" ] || [ "$bit" -nt "$sha_file" ]; then
            ( cd "$(dirname "$bit")" && sha256sum "$(basename "$bit")" > "$(basename "$sha_file")" )
            echo "Wrote $sha_file" >&2
        fi
    done
fi

exit 0
