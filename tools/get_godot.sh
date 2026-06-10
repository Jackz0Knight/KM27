#!/usr/bin/env bash
# tools/get_godot.sh — fetch + cache a headless Linux Godot for cloud sessions.
#
# Cloud/CI containers don't have Jack's desktop binary, so this script makes
# any Linux session self-sufficient: download the official 4.6.1 build into
# ~/.cache/godot (once), rebuild the class cache if .godot/ is missing
# (gitignored, so every fresh clone needs it), and print the binary path as
# the last line of output so callers can do BIN="$(tools/get_godot.sh --quiet)".
#
# Flags:
#   --quiet   only print the binary path (for scripts / the SessionStart hook)
#   --check   also run a boot check (--quit-after 30) and fail on engine errors
#
# Exits 0 silently on non-Linux hosts (Jack's Windows desktop has its own
# binary; see CLAUDE.md "Local Validation").

set -euo pipefail

VERSION="4.6.1-stable"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/godot}"
BIN="$CACHE_DIR/Godot_v${VERSION}_linux.x86_64"
URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

QUIET=0
CHECK=0
for arg in "$@"; do
	case "$arg" in
		--quiet) QUIET=1 ;;
		--check) CHECK=1 ;;
	esac
done

log() { [ "$QUIET" -eq 1 ] || echo "$@" >&2; }

if [ "$(uname -s)" != "Linux" ]; then
	log "get_godot: non-Linux host — skipping (use the desktop binary)."
	exit 0
fi

if [ ! -x "$BIN" ]; then
	log "get_godot: downloading Godot ${VERSION} (~60 MB)…"
	mkdir -p "$CACHE_DIR"
	tmp="$(mktemp -d)"
	curl -sL --max-time 600 -o "$tmp/godot.zip" "$URL"
	unzip -o -q "$tmp/godot.zip" -d "$CACHE_DIR"
	rm -rf "$tmp"
	chmod +x "$BIN"
	log "get_godot: cached at $BIN"
fi

# Fresh clones lack .godot/ (gitignored) — without the class cache, headless
# runs fail with "Could not find type"-style errors. One editor pass fixes it.
if [ ! -f "$ROOT/.godot/global_script_class_cache.cfg" ]; then
	log "get_godot: rebuilding class cache (.godot/ missing)…"
	"$BIN" --headless --path "$ROOT" --editor --quit >/dev/null 2>&1 || true
fi

if [ "$CHECK" -eq 1 ]; then
	log "get_godot: boot check…"
	out="$("$BIN" --headless --path "$ROOT" --quit-after 30 2>&1 || true)"
	log "$out"
	if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
		log "get_godot: boot check FAILED"
		exit 1
	fi
	if ! echo "$out" | grep -q "\[KM27\] Title ready\."; then
		log "get_godot: boot check FAILED — title never reported ready"
		exit 1
	fi
	log "get_godot: boot check OK"
fi

echo "$BIN"
