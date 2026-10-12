#!/usr/bin/env bash
#
# tests/run.sh — integration tests for ccr / ccc against a throwaway fixture.
# Builds fake Claude / Codex / Desktop data plus stub claude, codex, fzf, ps
# and lsof in a temp dir, then runs bin/ccr and bin/ccc under /bin/bash (3.2
# on macOS) and checks their output. Never reads your real ~/.claude or
# ~/.codex.
#
#   tests/run.sh          run everything; exit 1 if any check fails
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CCR="$ROOT/bin/ccr"
CCC="$ROOT/bin/ccc"
SH=/bin/bash
[ -x "$SH" ] || SH=bash
# inside the repo, not $TMPDIR: ccr deliberately ignores files written under
# temp dirs, which would hide the "files written" fixtures
mkdir -p "$ROOT/tests/.tmp"
F="$(cd "$(mktemp -d "$ROOT/tests/.tmp/run.XXXXXX")" && pwd -P)"
trap 'rm -rf "$F"' EXIT
P="$F/work/proj"; CP="$F/work/cproj"; U="$(id -u)"
mkdir -p "$F/bin" "$F/cfg/projects/-w-proj" "$P/docs" "$CP/src" "$F/codex" "$F/codex-roll/sessions/2026/09/30"

# ---------------------------------------------------------------------------
# fixture data
# ---------------------------------------------------------------------------
echo '<h1>report</h1>' > "$P/docs/report.html"; echo x > "$P/notes.md"; echo y > "$CP/src/limiter.ts"
python3 - "$F" "$P" "$CP" <<'EOF'
import json, os, sqlite3, sys, time
F, P, CP = sys.argv[1:]
now = time.time()
def w(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write("\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n")

# Claude CLI session with a /rename name, an artifact (2 publishes) and files written
w(f"{F}/cfg/projects/-w-proj/aaaa-live.jsonl", [
    {"type": "user", "cwd": P, "message": {"content": "hello live"}},
    {"type": "custom-title", "customTitle": "live-session"},
    {"type": "frame-link", "path": f"{P}/docs/report.html", "frameUrl": "https://claude.ai/code/artifact/1111-demo",
     "title": "Q3 報告", "artifactCount": 1, "timestamp": "2026-10-01T10:00:00Z"},
    {"type": "frame-link", "path": f"{P}/docs/report.html", "frameUrl": "https://claude.ai/code/artifact/1111-demo",
     "title": "Q3 報告", "artifactCount": 1, "timestamp": "2026-10-02T10:00:00Z"},
    {"type": "frame-link", "artifactCount": 1, "timestamp": "2026-10-02T10:05:00Z"},
    {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Write", "input": {"file_path": f"{P}/notes.md"}}]}},
    {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": f"{P}/notes.md"}}]}},
    {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Edit", "input": {"file_path": f"{P}/gone.py"}}]}},
    {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Write", "input": {"file_path": "/private/tmp/x/scratchpad/t.html"}}]}},
])
os.utime(f"{F}/cfg/projects/-w-proj/aaaa-live.jsonl", (now - 2 * 86400, now - 2 * 86400))
# history: the live session plus one whose transcript is gone
w(f"{F}/cfg/history.jsonl", [
    {"display": "/clear", "timestamp": int((now - 40 * 86400) * 1000), "project": P, "sessionId": "bbbb-gone"},
    {"display": "修 checkout 的 bug", "timestamp": int((now - 40 * 86400) * 1000), "project": P, "sessionId": "bbbb-gone"},
    {"display": "hello live", "timestamp": int(now * 1000), "project": P, "sessionId": "aaaa-live"},
])
json.dump({"cleanupPeriodDays": 14}, open(f"{F}/cfg/settings.json", "w"))
# Claude Desktop (Cowork): one live, one archived
d = f"{F}/desk/acct/org"
os.makedirs(d, exist_ok=True)
json.dump({"cliSessionId": "cccc-desk", "title": "Cowork 任務", "lastActivityAt": int(now * 1000) - 86400000,
           "isArchived": False, "userSelectedFolders": [P]}, open(f"{d}/local_abc.json", "w"))
w(f"{d}/local_abc/.claude/projects/-x/cccc-desk.jsonl", [{"type": "user", "cwd": "x", "message": {"content": "desk first"}}])
os.makedirs(f"{d}/local_abc/outputs", exist_ok=True)
json.dump({"cliSessionId": "dddd-arch", "title": "archived", "isArchived": True}, open(f"{d}/local_arch.json", "w"))
w(f"{d}/local_arch/.claude/projects/-x/dddd-arch.jsonl", [{}])
# Codex: index DB (cli thread with a rollout, a subagent and an archived thread)
w(f"{F}/codex/rollout-eeee.jsonl", [
    {"type": "session_meta", "payload": {"id": "eeee-codex", "cwd": CP, "source": "cli"}},
    {"type": "event_msg", "payload": {"type": "item_completed", "item": {"type": "FileChange",
        "changes": str({f"{CP}/src/limiter.ts": {"type": "add"}, f"{CP}/README.md": {"type": "update"}})}}},
])
db = sqlite3.connect(f"{F}/codex/state_5.sqlite")
db.execute("create table threads(id text, rollout_path text, updated_at int, source text, cwd text, title text,"
           " archived int, git_branch text, model text, tokens_used int, name text, preview text)")
db.executemany("insert into threads values (?,?,?,?,?,?,?,?,?,?,?,?)", [
    ("eeee-codex", f"{F}/codex/rollout-eeee.jsonl", int(now - 60), "cli", CP, "first msg", 0, "main", "gpt-6-astra", 123456, "Codex 修 API", "first msg"),
    ("ffff-sub", "", int(now - 50), '{"subagent":"review"}', CP, "", 0, "main", "m", 1, "", ""),
    ("gggg-arch", "", int(now - 40), "cli", CP, "", 1, "main", "m", 1, "archived one", ""),
])
db.commit()
# Codex without an index: rollout files + session_index.jsonl only
w(f"{F}/codex-roll/sessions/2026/09/30/rollout-2026-09-30T10-00-00-hhhh-roll.jsonl", [
    {"type": "session_meta", "payload": {"id": "hhhh-roll", "cwd": CP, "source": "cli", "git": {"branch": "dev"}}},
    {"type": "event_msg", "payload": {"type": "user_message", "message": "從 rollout 讀到的第一句"}},
])
w(f"{F}/codex-roll/session_index.jsonl", [{"id": "hhhh-roll", "thread_name": "rollout 命名"}])
EOF
mkdir -p "$F/codex-bad"; cp -R "$F/codex-roll/." "$F/codex-bad/"; echo junk > "$F/codex-bad/state_5.sqlite"

# ---------------------------------------------------------------------------
# stub commands
# ---------------------------------------------------------------------------
cat > "$F/bin/claude" <<'EOF'
#!/bin/sh
echo "FAKE claude $*  (pwd=$(pwd))"
EOF
cat > "$F/bin/codex" <<'EOF'
#!/bin/sh
echo "FAKE codex $*  (pwd=$(pwd))"
EOF
cat > "$F/bin/open" <<'EOF'
#!/bin/sh
echo "FAKE open $*"
EOF
# fzf: record args + input; answer with $FAKE_KEY and the first row matching $FAKE_PICK
cat > "$F/bin/fzf" <<'EOF'
#!/bin/sh
case "$1" in --version)
  case "${FAKE_FZF_VERSION:-0.57.0}" in fail) exit 1 ;; esac
  echo "${FAKE_FZF_VERSION:-0.57.0} (fake)"; exit 0 ;;
esac
for a in "$@"; do printf '%s\n' "$a"; done > "$FZF_ARGS"
cat > "$FZF_DUMP"
case " $* " in *--expect*) printf '%s\n' "$FAKE_KEY" ;; esac
# the main menu (--expect) picks $FAKE_PICK; a second-level picker $FAKE_PICK2
case " $* " in
  *--expect*) grep -F -- "$FAKE_PICK" "$FZF_DUMP" | head -1 ;;
  *)          grep -F -- "${FAKE_PICK2:-$FAKE_PICK}" "$FZF_DUMP" | head -1 ;;
esac
EOF
cat > "$F/bin/ps" <<EOF
#!/bin/sh
cat <<'T'
  100     1  0.0   2048 $U -zsh
  101   100  0.1  40960 $U npm run dev
  102   101 75.0 204800 $U node $P/node_modules/.bin/vite --port 5173
  200     1  3.0 409600 $U claude
  201   200  0.2  51200 $U node /opt/mcp/server.js
  203   200  0.0   2048 $U /bin/zsh -c python3 -m http.server 8000
  202   203  0.0  20480 $U python3 -m http.server 8000
  204     1  1.0  81920 $U node $P/node_modules/.bin/tsc --watch
  300     1  0.5 102400 $U /Applications/Spotify.app/Contents/MacOS/Spotify
  400     1  0.0  10240 $U node /elsewhere/app.js
  500     1  0.0  10240 9999 node $P/other-user.js
  600     1  2.0  61440 $U node /opt/homebrew/bin/codex resume
  601   600  0.1  30720 $U node /opt/mcp/codex-mcp.js
T
EOF
cat > "$F/bin/lsof" <<EOF
#!/bin/sh
case "\$*" in
  *-iTCP*) printf 'p102\nn127.0.0.1:5173\np202\nn*:8000\np300\nn*:7000\n' ;;
  *cwd*)   printf 'p100\nn$P\np101\nn$P\np102\nn$P\np201\nn$P\np202\nn$P\np203\nn$P\np204\nn$P/sub\np300\nn/\np400\nn/elsewhere\np600\nn$P\np601\nn$P\n' ;;
esac
EOF
chmod +x "$F"/bin/*

export PATH="$F/bin:$PATH" CLAUDE_CONFIG_DIR="$F/cfg" CCR_DESKTOP_DIR="$F/desk" CCR_CACHE="$F/cache"
export CODEX_HOME="$F/codex" FZF_DUMP="$F/dump" FZF_ARGS="$F/args" CCR_LANG=zh
export CCR_THEME=classic FAKE_FZF_VERSION=0.57.0
unset CCR_CODEX CCR_PROJECTS_DIR CCR_HISTORY_FILE COLORTERM CCR_PALETTE CCR_LAYOUT

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
pass=0; fail=0
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n  expected: %s\n  got:      %s\n' "$1" "$2" "$(printf '%s' "$3" | head -3)"; }
has()  { if printf '%s' "$2" | grep -qF -- "$3"; then ok; else bad "$1" "$3" "$2"; fi; }
hasnt(){ if printf '%s' "$2" | grep -qF -- "$3"; then bad "$1" "(not) $3" "$2"; else ok; fi; }
run()  { FAKE_KEY="$1" FAKE_PICK="$2" "$SH" "${@:3}" 2>&1; }   # run <key> <pick> <script> [args]
header() { awk '/^--header=/{p=1} /^--header-first/{p=0} p' "$F/args" | strip; }
fresh()  { rm -f "$F/cache/runtime.json"; }

# ---------------------------------------------------------------------------
# ccr: sessions and resuming
# ---------------------------------------------------------------------------
has  "syntax"            "$("$SH" -n "$CCR" && echo ok)" "ok"
has  "version"           "$("$SH" "$CCR" --version)" "ccr 0."
has  "help zh"           "$("$SH" "$CCR" --help)" "Ctrl-L  開啟 session 的 artifact"
has  "rename title"      "$("$SH" "$CCR" __list time | grep aaaa-live | cut -f6)" "live-session"
has  "enter resumes"     "$(run '' aaaa-live "$CCR" | tail -1)" "FAKE claude --resume aaaa-live  (pwd=$P)"
has  "ctrl-f forks"      "$(run ctrl-f aaaa-live "$CCR" | tail -1)" "--resume aaaa-live --fork-session"
has  "ctrl-r remote"     "$(run ctrl-r aaaa-live "$CCR" | tail -1)" "--resume aaaa-live --remote-control"
has  "ctrl-y prints"     "$(run ctrl-y aaaa-live "$CCR" | tail -1)" "&& claude --resume aaaa-live"
has  "--last"            "$("$SH" "$CCR" --last 2>&1 | tail -1)" "FAKE claude --resume aaaa-live"
has  "-n out of range"   "$("$SH" "$CCR" -n 2 2>&1)" "ccr：沒有第 2 個 session"
has  "desktop as fork"   "$(run '' cccc-desk "$CCR" | tail -1)" "cccc-desk.jsonl --fork-session  (pwd=$F/desk/acct/org/local_abc/outputs)"
hasnt "archived hidden"  "$("$SH" "$CCR" __list time | cut -f2)" "dddd-arch"
has  "expired listed"    "$(run '' bbbb-gone "$CCR" --expired)" "第一句 prompt：修 checkout 的 bug"
hasnt "expired default"  "$("$SH" "$CCR" __list time | cut -f2)" "bbbb-gone"
S="$(mktemp)"; echo expired=0 > "$S"
CCR_STATE="$S" "$SH" "$CCR" __toggle_expired
has  "ctrl-x toggles"    "$(CCR_STATE="$S" "$SH" "$CCR" __list | cut -f8)" "expired"; rm -f "$S"
run ctrl-y aaaa-live "$CCR" >/dev/null
has  "retention warning" "$(header)" "刪除 14 天"
hasnt "no ccc header"    "$(header)" "來源切換"

# ---------------------------------------------------------------------------
# process pane
# ---------------------------------------------------------------------------
fresh; run ctrl-y aaaa-live "$CCR" >/dev/null; H="$(header)"
has  "pane: vite by name"   "$H" ":5173   PID 102"
has  "pane: tool not node"  "$H" "vite --port 5173"
has  "pane: http link"      "$H" "→ http://localhost:8000"
has  "pane: watcher"        "$H" "tsc --watch"
hasnt "pane: npm parent"    "$H" "npm run"
hasnt "pane: mcp"           "$H" "mcp"
hasnt "pane: codex agent"   "$H" "codex resume"
hasnt "pane: other dirs"    "$H" "Spotify"
has  "pane: hot cpu red"    "$(awk '/PID 102/' "$F/args")" $'\033[1;91m 75.0% CPU'
has  "pane: busy mark"      "$(grep aaaa-live "$F/dump" | cut -f1 | strip)" "⚙"
has  "resume prints procs"  "$(fresh; run '' aaaa-live "$CCR" | strip)" "可能佔用資源的 process："

# ---------------------------------------------------------------------------
# outputs: artifacts and files written
# ---------------------------------------------------------------------------
"$SH" "$CCR" __list time >/dev/null
PV="$("$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "" | strip)"
has  "outputs mark"          "$(grep aaaa-live "$F/dump" | cut -f1 | strip)" "⚙✦"
has  "artifact title+count"  "$PV" "Q3 報告  2 版 · 2026-10-02"
has  "artifact url"          "$PV" "https://claude.ai/code/artifact/1111-demo"
has  "artifact local file"   "$PV" "./docs/report.html ✓"
has  "files header"          "$PV" "📄 產生的檔案 · 2"
has  "write then edit = +"   "$PV" "+ ./notes.md ✓"
has  "missing file ✗"        "$PV" "~ ./gone.py ✗"
hasnt "temp files skipped"   "$PV" "scratchpad"
hasnt "no outputs on desktop" "$("$SH" "$CCR" __preview t w r x "" cccc-desk desktop "" "" | strip)" "Artifacts"
FAKE_PICK2="1111-demo" run ctrl-l aaaa-live "$CCR" > "$F/out" 2>&1
has  "ctrl-l picks + opens"  "$(cat "$F/out")" "FAKE open https://claude.ai/code/artifact/1111-demo"
has  "ctrl-l picker items"   "$(cat "$F/dump")" "+ ./notes.md"
hasnt "ctrl-l skips missing" "$(cat "$F/dump")" "gone.py"
has  "ctrl-l none"           "$(run ctrl-l cccc-desk "$CCR")" "沒有 artifact 或產生的檔案"

# ---------------------------------------------------------------------------
# ccc: Codex
# ---------------------------------------------------------------------------
has  "ccc version"        "$("$SH" "$CCC" --version)" "ccc 0."
hasnt "ccr has no codex"  "$("$SH" "$CCR" __list time | cut -f8)" "codex"
has  "ccc lists codex"    "$("$SH" "$CCC" __list time | grep eeee | cut -f6,10)" "Codex 修 API	main · gpt-6-astra · 123,456 tokens"
hasnt "ccc skips sub/arch" "$("$SH" "$CCC" __list time | cut -f2)" "ffff-sub"
has  "tool column"        "$("$SH" "$CCC" __list time | grep eeee | cut -f1 | strip)" "codex  │"
has  "ccc enter"          "$(run '' eeee-codex "$CCC" | tail -1)" "FAKE codex resume eeee-codex  (pwd=$CP)"
has  "ccc fork"           "$(run ctrl-f eeee-codex "$CCC" | tail -1)" "FAKE codex fork eeee-codex"
has  "ccc no remote"      "$(run ctrl-r eeee-codex "$CCC")" "ccc：Codex 沒有 Remote Control"
has  "ccc --last"         "$("$SH" "$CCC" --last | tail -1)" "FAKE codex resume eeee-codex"
"$SH" "$CCC" __list time >/dev/null
PVC="$("$SH" "$CCC" __preview t w r "$CP" "" eeee-codex codex "" "main" | strip)"
has  "codex files"        "$PVC" "+ ./src/limiter.ts ✓"
has  "codex update ✗"     "$PVC" "~ ./README.md ✗"
has  "codex outputs mark" "$("$SH" "$CCC" __list time | grep eeee | cut -f1 | strip)" "✦"
has  "rollout fallback"   "$(CODEX_HOME="$F/codex-roll" "$SH" "$CCC" __list time | grep hhhh | cut -f6,10)" "rollout 命名	dev"
has  "bad db fallback"    "$(CODEX_HOME="$F/codex-bad" "$SH" "$CCC" __list time | grep -c hhhh)" "1"
S="$(mktemp)"; echo source=all > "$S"
CCR_STATE="$S" "$SH" "$CCC" __cycle_source
hasnt "source: claude"    "$(CCR_STATE="$S" "$SH" "$CCC" __list | cut -f8)" "codex"
CCR_STATE="$S" "$SH" "$CCC" __cycle_source
has  "source: codex"      "$(CCR_STATE="$S" "$SH" "$CCC" __list | cut -f8 | sort -u | tr '\n' ' ')" "codex "; rm -f "$S"

# ---------------------------------------------------------------------------
# themes
# ---------------------------------------------------------------------------
claude_tag() { CCR_THEME="$1" COLORTERM="${2:-}" "$SH" "$CCC" __list time | grep aaaa-live | cut -f1; }
has   "tokyonight truecolor"  "$(claude_tag tokyonight truecolor)" $'\033[38;2;255;158;100mclaude'
hasnt "truecolor has no 256"  "$(claude_tag tokyonight truecolor)" $'\033[38;5;'
has   "256 fallback"          "$(claude_tag tokyonight)" $'\033[38;5;215mclaude'
hasnt "256 has no truecolor"  "$(claude_tag tokyonight)" $'\033[38;2;'
has   "classic codes"         "$(claude_tag classic truecolor)" $'\033[38;5;173mclaude'
has   "default is tokyonight" "$(CCR_THEME= COLORTERM=truecolor "$SH" "$CCC" __list time | grep aaaa-live | cut -f1)" $'\033[38;2;255;158;100m'
has   "--theme beats env"     "$(CCR_THEME=kanagawa COLORTERM=truecolor run ctrl-y aaaa-live "$CCC" --theme gruvbox >/dev/null; grep aaaa-live "$F/dump" | cut -f1)" $'\033[38;2;254;128;25mclaude'
has   "unknown theme warns"   "$(CCR_THEME=nope run ctrl-y aaaa-live "$CCR" 2>&1)" "未知的主題「nope」"
has   "subcommand w/o palette" "$(CCR_PALETTE= CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCR" __list time | grep aaaa-live | cut -f1)" $'\033[38;2;'
strip_row() { strip | sed 's/[[:space:]]*$//'; }
same() { if [ "$2" = "$3" ]; then ok; else bad "$1" "$3" "$2"; fi; }   # exact match, multi-line safe
same "same layout any theme" "$(CCR_THEME=classic "$SH" "$CCC" __list time | cut -f1 | strip_row)" "$(CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCC" __list time | cut -f1 | strip_row)"
has  "preview uses theme"    "$(CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "")" $'\033[1;38;2;122;162;247m📌'
has  "outputs use theme"     "$(CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "")" $'\033[38;2;158;206;106m✓'
fresh; COLORTERM=truecolor CCR_THEME=tokyonight run ctrl-y aaaa-live "$CCR" >/dev/null
has  "pane uses theme"       "$(awk '/PID 102/' "$F/args")" $'\033[1;38;2;247;118;142m 75.0% CPU'
has  "pane port bold yellow" "$(awk '/PID 102/' "$F/args")" $'\033[1;38;2;224;175;104m:5173'

# ---------------------------------------------------------------------------
# layout
# ---------------------------------------------------------------------------
args_for() { FAKE_FZF_VERSION="$1" run ctrl-y aaaa-live "${@:2}" >/dev/null 2>&1; cat "$F/args"; }
A="$(args_for 0.74.4 "$CCR")"
has   "boxed on 0.74"        "$A" "--style=full"
has   "boxed header label"   "$A" "--header-label= ⚙ 背景 process · 3 "
has   "boxed input label"    "$A" "--input-label= 🔍 搜尋 · time "
has   "boxed list label"     "$A" "--list-label= Session 列表 "
has   "boxed footer"         "$A" "--footer="
has   "boxed footer no border" "$A" "--footer-border=none"
has   "boxed gutter"         "$A" "--gutter= "
has   "boxed label refresh"  "$A" "transform-input-label"
hasnt "boxed: no pane title" "$A" "背後正在跑的 process"
has   "boxed retention in header" "$A" "刪除 14 天"
A="$(args_for 0.60.0 "$CCR")"
has   "0.60 boxed"           "$A" "--style=full"
hasnt "0.60 no footer"       "$A" "--footer"
hasnt "0.60 no footer border" "$A" "--footer-border"
hasnt "0.60 no gutter"       "$A" "--gutter"
has   "0.60 hints in header" "$A" "Enter 開啟"
A="$(args_for 0.57.0 "$CCR")"
has   "classic on 0.57"      "$A" "--border-label= ccr "
hasnt "classic no style"     "$A" "--style"
has   "ccc border label"     "$(args_for 0.57.0 "$CCC")" "--border-label= ccc "
has   "CCR_LAYOUT=classic"   "$(CCR_LAYOUT=classic args_for 0.74.4 "$CCR")" "--border-label"
has   "boxed on old fzf warns" "$(CCR_LAYOUT=boxed FAKE_FZF_VERSION=0.57.0 run ctrl-y aaaa-live "$CCR" 2>&1)" "需要 fzf 0.58"
has   "odd fzf version"      "$(args_for weird "$CCR")" "--border-label"
has   "fzf --version fails"  "$(args_for fail "$CCR")" "--border-label"
has   "bad CCR_LAYOUT warns" "$(CCR_LAYOUT=bogus FAKE_FZF_VERSION=0.74.4 run ctrl-y aaaa-live "$CCR" 2>&1)" "CCR_LAYOUT 只接受 boxed|classic"
FAKE_FZF_VERSION=0.74.4 FAKE_PICK2="1111-demo" run ctrl-l aaaa-live "$CCR" >/dev/null 2>&1
has   "boxed picker label"   "$(cat "$F/args")" "--list-label= 開啟 · live-session "
A="$(CCR_THEME=classic args_for 0.74.4 "$CCR")"
has   "classic theme boxed"  "$A" "--style=full"
hasnt "classic no colors"    "$A" "--color="
A="$(CCR_THEME=tokyonight COLORTERM=truecolor args_for 0.74.4 "$CCC")"
has   "boxed colors"         "$A" "header-border:#ff9e64"
has   "ccc source in label"  "$A" "--input-label= 🔍 搜尋 · time · all "
STYLE_N="$(grep -n '^--style=full$' "$F/args" | head -1 | cut -d: -f1)"
COLOR_N="$(grep -n '^--color=' "$F/args" | head -1 | cut -d: -f1)"
if [ -n "$STYLE_N" ] && [ -n "$COLOR_N" ] && [ "$COLOR_N" -gt "$STYLE_N" ]; then ok
else bad "colour args after layout args" "--color= after --style=full" "style@$STYLE_N color@$COLOR_N"; fi
has   "boxed -s workdir -> dir" "$(args_for 0.74.4 "$CCR" -s workdir)" "--input-label= 🔍 搜尋 · dir "
S="$(mktemp)"; printf 'sort=title\nsource=codex\n' > "$S"
has   "__label"              "$(CCR_STATE="$S" CCR_CODEX=1 "$SH" "$CCC" __label)" " 🔍 搜尋 · title · codex "
CCR_STATE="$S" "$SH" "$CCR" __set_sort dir
has   "__set_sort"           "$(cat "$S")" "sort=dir"; rm -f "$S"

# ---------------------------------------------------------------------------
# boxed preview: content blocks drawn inside the preview pane
# ---------------------------------------------------------------------------
# widest visible line (ANSI stripped, CJK / emoji = 2 columns)
maxw() { strip | python3 -c 'import sys, unicodedata
print(max((sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in l.rstrip("\n")) for l in sys.stdin), default=0))'; }
bpv() { CCR_LAYOUT_ACTIVE=boxed FZF_PREVIEW_COLUMNS="$1" "$SH" "$CCR" __preview "${@:2}"; }
"$SH" "$CCR" __list time >/dev/null
PV="$(bpv 120 live-session "2026-10-10 11:00" "2 天前" "$P" "hello live" aaaa-live cli "" "" | strip)"
has   "boxed pv: session box"   "$PV" "╭ 📌 對話 "
has   "boxed pv: two columns"   "$(printf '%s\n' "$PV" | grep '╭ 📌 對話')" "╭ 🎨 Artifacts · 1 "
has   "boxed pv: files box"     "$PV" "╭ 📄 產生的檔案 · 2 "
has   "boxed pv: prompt box"    "$PV" "╭ 💬 最後的 prompt "
has   "boxed pv: file row"      "$PV" "+ ./notes.md ✓"
same  "boxed pv: fits 120"      "$(bpv 120 live-session w r "$P" "hello live" aaaa-live cli "" "" | maxw)" "120"
PV="$(bpv 70 live-session w r "$P" "hello live" aaaa-live cli "" "" | strip)"
hasnt "boxed pv narrow: stacked" "$(printf '%s\n' "$PV" | grep '╭ 📌 對話')" "Artifacts"
same  "boxed pv: fits 70"       "$(bpv 70 live-session w r "$P" "hello live" aaaa-live cli "" "" | maxw)" "70"
LONG="$(printf 'word %.0s' $(seq 1 30))"   # 30 x "word" in a 46-column box -> 9+9+9+3 words
same  "boxed pv: long prompt wraps" "$(bpv 50 t w r "$P" "$LONG" aaaa-live cli "" "" | strip | grep -c 'word word')" "4"
same  "boxed pv: fits 50"       "$(bpv 50 t w r "$P" "$LONG" aaaa-live cli "" "" | maxw)" "50"
PV="$(bpv 100 "修 checkout 的 bug" w r "$P" "" bbbb-gone expired "" "修 checkout 的 bug" | strip)"
has   "boxed pv: expired first prompt" "$PV" "╭ 💬 第一句 prompt "
has   "boxed pv: expired warning"      "$PV" "對話紀錄已被清理"
same  "boxed pv: CJK fits"      "$(bpv 100 "修 checkout 的 bug" w r "$P" "" bbbb-gone expired "" "修 checkout 的 bug" | maxw)" "100"
has   "classic layout pv boxed" "$(CCR_LAYOUT_ACTIVE=classic FZF_PREVIEW_COLUMNS=80 "$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "" | strip)" "╭ 📌 對話 "
has   "pv boxed w/o layout env"  "$(FZF_PREVIEW_COLUMNS=80 "$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "" | strip)" "╭ 📌 對話 "
A="$(args_for 0.57.0 "$CCR")"
hasnt "classic preview no wrap" "$(grep '^--preview-window=' "$F/args")" "wrap"
A="$(args_for 0.74.4 "$CCR")"
hasnt "boxed preview no wrap"   "$(grep '^--preview-window=' "$F/args")" "wrap"

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
