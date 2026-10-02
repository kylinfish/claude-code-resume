#!/usr/bin/env bash
#
# demo/teardown.sh — stop the demo processes started by demo/setup.sh and
# delete the demo directory. Only touches $CCR_DEMO_DIR (default ~/ccr-demo).
#
set -euo pipefail

DEMO="${CCR_DEMO_DIR:-$HOME/ccr-demo}"
[ -d "$DEMO" ] || { echo "demo: nothing to clean up ($DEMO not found)"; exit 0; }
[ -f "$DEMO/env.sh" ] || { echo "demo: $DEMO doesn't look like a demo dir; leaving it alone" >&2; exit 1; }

if [ -f "$DEMO/pids" ]; then
  while read -r pid; do
    [ -n "$pid" ] || continue
    # only stop processes that still run from inside the demo dir
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
    case "$cwd" in
      "$DEMO"/*) kill "$pid" 2>/dev/null && echo "demo: stopped PID $pid" ;;
    esac
  done < "$DEMO/pids"
fi

rm -rf "$DEMO"
echo "demo: removed $DEMO"
echo "demo: open a new shell (or unset CLAUDE_CONFIG_DIR CODEX_HOME CCR_DESKTOP_DIR CCR_CACHE) to use your real sessions again"
