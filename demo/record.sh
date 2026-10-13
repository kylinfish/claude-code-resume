#!/usr/bin/env bash
#
# demo/record.sh — re-record the README GIFs with vhs (https://github.com/charmbracelet/vhs)
# against the fake demo data from demo/setup.sh.
#
#   demo/record.sh               -> assets/demo.gif (English) + assets/demo-zh.gif (中文)
#   CCR_DEMO_SHOTS=dir demo/record.sh   also save PNG screenshots of key frames into dir
#
# Needs: vhs (brew install vhs), fzf >= 0.58 on PATH for the boxed layout.
# The demo data lives in ~/ccr-demo and is removed again afterwards.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEMO="${CCR_DEMO_DIR:-$HOME/ccr-demo}"
SHOTS="${CCR_DEMO_SHOTS:-}"
command -v vhs >/dev/null 2>&1 || { echo "record: vhs is required (brew install vhs)" >&2; exit 1; }

"$HERE/setup.sh"
trap '"$HERE/teardown.sh" >/dev/null' EXIT
[ -n "$SHOTS" ] && mkdir -p "$SHOTS"

# shot <name> -> a vhs Screenshot line when CCR_DEMO_SHOTS is set
shot() { [ -n "$SHOTS" ] && printf 'Screenshot "%s/%s-%s.png"\n' "$SHOTS" "$LANG_TAG" "$1"; true; }

record() {  # record <en|zh> <output gif>
  LANG_TAG="$1"
  local out="$2" tape
  tape="$(mktemp "${TMPDIR:-/tmp}/ccr-demo.XXXXXX").tape"
  cat > "$tape" <<EOF
Output "$out"
Set Shell "bash"
Set FontSize 15
Set Width 1400
Set Height 860
Set Padding 16
Set Theme "TokyoNight"
Set TypingSpeed 70ms
Set CursorBlink false

Hide
Type \`source "$DEMO/env.sh"; export PATH="\$HOME/.fzf/bin:$ROOT/bin:\$PATH" COLORTERM=truecolor CCR_LANG=$1 CCR_THEME=tokyonight PS1='\$ '; clear\`
Enter
Sleep 1s
Show

# 1. the boxed layout: process pane, pill labels, marks, tool column
Type "ccc"
Sleep 400ms
Enter
Sleep 3s
$(shot 1-open)

# 2. search -> preview blocks with artifacts and files written
Type "jwt"
Sleep 3s
$(shot 2-preview)

# 3. filter by tool, then cycle the source
Ctrl+U
Type "^codex"
Sleep 2.5s
$(shot 3-codex)
Ctrl+U
Ctrl+A
Sleep 1.5s
Ctrl+A
Sleep 1.5s
Ctrl+A
Sleep 1s

# 4. sessions Claude already cleaned up
Ctrl+X
Sleep 1s
Down@150ms 15
Sleep 2s
$(shot 4-expired)
Ctrl+X
Sleep 1s
Escape
Sleep 800ms

# 5. the theme picker with a live preview
Type "ccr --themes"
Sleep 400ms
Enter
Sleep 2.5s
$(shot 5-themes)
Down
Sleep 2s
Down
Sleep 2s
Down
Sleep 2.5s
$(shot 6-gruvbox)
Escape
Sleep 800ms

# 6. pick a session: its running processes, then the resume command
Type "ccc"
Sleep 400ms
Enter
Sleep 2.5s
Type "jwt"
Sleep 1.5s
Enter
Sleep 3.5s
$(shot 7-resume)
EOF
  echo "record: $out"
  vhs "$tape" >/dev/null
  rm -f "$tape"
}

record en "$ROOT/assets/demo.gif"
record zh "$ROOT/assets/demo-zh.gif"
ls -la "$ROOT/assets/demo.gif" "$ROOT/assets/demo-zh.gif"
