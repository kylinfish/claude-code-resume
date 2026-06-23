#!/usr/bin/env bash
#
# ccr installer — symlinks bin/ccr into a directory on your PATH
# (default: ~/.local/bin) and optionally adds a one-line shell startup tip.
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SRC_DIR/bin/ccr"
DEST_DIR="${CCR_INSTALL_DIR:-$HOME/.local/bin}"
DEST="$DEST_DIR/ccr"

echo "ccr installer"
echo "  source : $SRC"
echo "  target : $DEST"

[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

# dependency check (warn only)
for dep in fzf python3; do
  command -v "$dep" >/dev/null 2>&1 || echo "warning: '$dep' not found on PATH (required at runtime)"
done
command -v claude >/dev/null 2>&1 || echo "warning: 'claude' CLI not found on PATH (required to resume)"

mkdir -p "$DEST_DIR"
ln -sf "$SRC" "$DEST"
chmod +x "$SRC"
echo "linked: $DEST -> $SRC"

case ":$PATH:" in
  *":$DEST_DIR:"*) ;;
  *) echo "note: $DEST_DIR is not on your PATH; add it, e.g.:"
     echo "      export PATH=\"$DEST_DIR:\$PATH\"" ;;
esac

# optional shell startup tip
if [ "${1:-}" = "--tip" ]; then
  RC="${ZDOTDIR:-$HOME}/.zshrc"
  [ -f "$RC" ] || RC="$HOME/.bashrc"
  if grep -q '>>> ccr tip >>>' "$RC" 2>/dev/null; then
    echo "tip already present in $RC"
  else
    {
      printf '\n# >>> ccr tip >>>\n'
      printf '[ -n "$PS1" ] && printf "\\033[38;5;244m\xf0\x9f\x92\xa1 run \\140ccr\\140 to resume a Claude Code session\\033[0m\\n"\n'
      printf '# <<< ccr tip <<<\n'
    } >> "$RC"
    echo "added startup tip to $RC"
  fi
fi

echo "done. Run: ccr --help"
