#!/usr/bin/env bash
# tools/smoke.sh — run the headless smoke runner and fail loudly.
#
# Wraps scripts/dev/smoke_runner.gd (see that file for what it plays). This
# wrapper exists because GDScript runtime errors don't crash the process —
# they print "SCRIPT ERROR" and carry on with broken state. So we capture all
# output and fail if EITHER the runner reports a failure (nonzero exit) OR
# any engine error line appears anywhere in the log.
#
# Usage:
#   tools/smoke.sh                          # defaults: 10 seeds × 60 weeks
#   tools/smoke.sh --seeds=3 --weeks=12     # quick pass while iterating
#   tools/smoke.sh --start-seed=99 --verbose
#
# Exit codes: 0 = clean, 1 = runner failure or engine errors detected.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$("$ROOT/tools/get_godot.sh" --quiet)"

if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
	echo "smoke: no Godot binary available (non-Linux host? see CLAUDE.md)" >&2
	exit 1
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

"$BIN" --headless --path "$ROOT" res://scenes/dev/smoke_run.tscn -- "$@" 2>&1 | tee "$LOG"
runner_exit=${PIPESTATUS[0]}

if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" "$LOG"; then
	echo ""
	echo "smoke: FAIL — engine error lines detected above."
	exit 1
fi

if [ "$runner_exit" -ne 0 ]; then
	echo ""
	echo "smoke: FAIL — runner exit code $runner_exit."
	exit 1
fi

echo "smoke: PASS"
exit 0
