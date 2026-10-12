# Themes and Boxed Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `ccr` / `ccc` a Tokyo Night default theme (plus Catppuccin, Kanagawa, Gruvbox, `classic`) and a stacked boxed fzf layout, with a single-border fallback on old fzf.

**Architecture:** One palette of semantic roles, defined per theme in a Bash `case` (`theme_palette`), is converted once by Python into SGR codes (truecolor or nearest xterm-256) and exported as `CCR_PALETTE`. Bash renderers read it through `pal <role> [style]`, embedded Python renderers through `C(role, style)`, and fzf through generated `--color` strings. The fzf layout is chosen from `fzf --version`: boxed (≥ 0.58, footer from 0.63, gutter from 0.66) or classic.

**Tech Stack:** Bash 3.2 (macOS `/bin/bash`), Python 3 stdlib, fzf ≥ 0.57 (boxed needs ≥ 0.58).

**Spec:** `docs/superpowers/specs/2026-10-12-themes-and-boxed-layout-design.md`

## Global Constraints

- `bin/ccr` stays one self-contained Bash script; must pass `/bin/bash -n` (Bash 3.2: no associative arrays, no `${var,,}`, guard empty arrays with `${a[@]+"${a[@]}"}`).
- Themes: `tokyonight` (default), `catppuccin`, `kanagawa`, `gruvbox`, `classic`; chosen by `--theme <name>` (wins) or `CCR_THEME`.
- Layout: `CCR_LAYOUT=boxed|classic`; default boxed when fzf ≥ 0.58, else classic.
- Truecolor when `COLORTERM` is `truecolor` or `24bit`; otherwise nearest xterm-256 colour, also in fzf `--color`.
- `classic` palette values are `sgr:<codes>` used verbatim (style arguments ignored); it sets no fzf `--color`.
- Boxed-layout extras are version-gated: `--footer` only on fzf ≥ 0.63, `--gutter` only on ≥ 0.66.
- Labels are localized (English per spec, Chinese via `t()`); deviations from the spec, recorded in Task 4's spec update: the Sessions label has no count (it would go stale after `^X` / `^A`; fzf's info already shows the count), and the Search label is refreshed with `transform-input-label` after a synchronous `__set_sort`.
- Colour arguments come after the layout arguments on the fzf command line, so `--style=full` can't override them.
- Every existing check in `tests/run.sh` keeps passing. Tests run with `CCR_THEME=classic`, `COLORTERM` unset and fake fzf version `0.57.0` unless a test says otherwise.
- Commits are authored as `kylinfish <kylinfish@gmail.com>` (export `GIT_AUTHOR_*` / `GIT_COMMITTER_*`) and end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **fzf 0.58–0.62** (boxed but no `--footer`): passing `--footer` would make fzf exit with an error; the key hints must move into the Processes box instead. Test in Task 3.
2. **Subcommands without a palette** (`ccr __list` / `__preview` run by an old exported env or by hand): must render coloured output, not crash on an empty `CCR_PALETTE`. Test in Task 1.
3. **`classic` theme on new fzf** (boxed layout, no `--color`): must still get boxes and must not emit boxed-only colour names. Test in Task 3.
4. **Column alignment across themes**: escape codes must not change visible widths; a row rendered with `tokyonight` and with `classic` must be identical once ANSI is stripped. Test in Task 2.
5. **Unparseable `fzf --version`** (wrappers, odd builds): must fall back to classic, not error. Test in Task 3.

---

### Task 1: Palette core and theme selection

**Files:**
- Modify: `bin/ccr` (new functions after `print_help_body`, ~line 205; i18n strings in `t()`; arg loop ~line 1168; dispatch ~line 1136)
- Test: `tests/run.sh`

**Interfaces:**
- Produces:
  - `theme_palette <name>` → prints `role=value` lines (`#rrggbb` or `sgr:<codes>`); empty for unknown names.
  - `resolve_theme <name> [warn]` → prints a valid theme name (`tokyonight` for empty/unknown; with `warn`, unknown names print `t theme_invalid` to stderr).
  - `load_palette <theme>` → sets and exports `CCR_PALETTE` (`role=params|role=params…`, params like `38;2;r;g;b`, `38;5;N`, or `!<verbatim sgr>`), and sets `FZF_COLORS`, `FZF_COLORS_BOXED`, `FZF_COLOR_FOOTER` (empty for `classic`).
  - `pal <role> [style]` → prints the escape for a role, e.g. `pal hot 1` → `\033[1;38;2;247;118;142m`; `''` for unknown roles.
  - Python helper text (inserted in later tasks): `C(role, style="")` with the same semantics.

- [ ] **Step 1: Make the test harness theme-aware**

In `tests/run.sh`, make the fake fzf answer `--version`, and pin theme / colour / fzf version defaults. Replace the fake fzf heredoc with:

```bash
cat > "$F/bin/fzf" <<'EOF'
#!/bin/sh
case "$1" in --version) echo "${FAKE_FZF_VERSION:-0.57.0} (fake)"; exit 0 ;; esac
for a in "$@"; do printf '%s\n' "$a"; done > "$FZF_ARGS"
cat > "$FZF_DUMP"
case " $* " in *--expect*) printf '%s\n' "$FAKE_KEY" ;; esac
# the main menu (--expect) picks $FAKE_PICK; a second-level picker $FAKE_PICK2
case " $* " in
  *--expect*) grep -F -- "$FAKE_PICK" "$FZF_DUMP" | head -1 ;;
  *)          grep -F -- "${FAKE_PICK2:-$FAKE_PICK}" "$FZF_DUMP" | head -1 ;;
esac
EOF
```

and extend the exports block:

```bash
export CODEX_HOME="$F/codex" FZF_DUMP="$F/dump" FZF_ARGS="$F/args" CCR_LANG=zh
export CCR_THEME=classic FAKE_FZF_VERSION=0.57.0
unset CCR_CODEX CCR_PROJECTS_DIR CCR_HISTORY_FILE COLORTERM CCR_PALETTE CCR_LAYOUT
```

- [ ] **Step 2: Write the failing palette tests**

Append before the final `echo "pass=…"` in `tests/run.sh`:

```bash
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
```

(`#ff9e64` → `255;158;100`; nearest xterm-256 of `#ff9e64` is 215; gruvbox `claude` `#fe8019` → `254;128;25`.)

- [ ] **Step 3: Run the tests to see them fail**

Run: `/bin/bash tests/run.sh | tail -12`
Expected: the nine new checks FAIL (`ccc __list` rows still use the old `col(173)` codes; `--theme` is an unknown option); every older check passes.

- [ ] **Step 4: Add the i18n strings**

In `t()`, before the `*)               fmt="$k" ;;` line:

```bash
    zh:theme_invalid) fmt='ccr：未知的主題「%s」，改用 tokyonight（可用：tokyonight catppuccin kanagawa gruvbox classic）' ;;
    en:theme_invalid) fmt='ccr: unknown theme "%s"; using tokyonight (available: tokyonight catppuccin kanagawa gruvbox classic)' ;;
```

- [ ] **Step 5: Add the palette functions**

Insert after the closing `}` of `print_help_body()`:

```bash
# ---------------------------------------------------------------------------
# themes: one palette of semantic roles per theme (see the design spec)
#   theme_palette <name>  -> role=value lines; value is #rrggbb, or sgr:<codes>
#                            (classic only: used verbatim, style args ignored)
# ---------------------------------------------------------------------------
theme_palette() {
  local roles="bg fg dim sel border sep accent match t_proc t_search t_list t_preview recent week old claude codex gear out path desktop expired port dir url hot key ok bad warn"
  local vals=""
  case "$1" in
    tokyonight) vals="#1a1b26 #c0caf5 #565f89 #283457 #27a1b9 #3b4261 #7aa2f7 #ff9e64 #ff9e64 #7aa2f7 #9ece6a #bb9af7 #9ece6a #e0af68 #565f89 #ff9e64 #7dcfff #e0af68 #bb9af7 #7aa2f7 #bb9af7 #545c7e #e0af68 #7dcfff #9ece6a #f7768e #e0af68 #9ece6a #f7768e #e0af68" ;;
    catppuccin) vals="#1e1e2e #cdd6f4 #6c7086 #313244 #b4befe #45475a #cba6f7 #fab387 #fab387 #89b4fa #a6e3a1 #f5c2e7 #a6e3a1 #f9e2af #6c7086 #fab387 #89dceb #f9e2af #cba6f7 #89b4fa #f5c2e7 #585b70 #f9e2af #89dceb #a6e3a1 #f38ba8 #f9e2af #a6e3a1 #f38ba8 #f9e2af" ;;
    kanagawa)   vals="#1f1f28 #dcd7ba #727169 #2d4f67 #54546d #363646 #7e9cd8 #ffa066 #ffa066 #7e9cd8 #98bb6c #957fb8 #98bb6c #e6c384 #727169 #ffa066 #7fb4ca #e6c384 #957fb8 #7e9cd8 #957fb8 #54546d #e6c384 #7fb4ca #98bb6c #e46876 #e6c384 #98bb6c #e46876 #e6c384" ;;
    gruvbox)    vals="#282828 #ebdbb2 #928374 #3c3836 #665c54 #504945 #fabd2f #fe8019 #fe8019 #83a598 #b8bb26 #d3869b #b8bb26 #fabd2f #928374 #fe8019 #8ec07c #fabd2f #d3869b #83a598 #d3869b #665c54 #fabd2f #8ec07c #b8bb26 #fb4934 #fabd2f #b8bb26 #fb4934 #fabd2f" ;;
    classic)    vals="sgr:0 sgr:38;5;253 sgr:38;5;244 sgr:0 sgr:0 sgr:38;5;240 sgr:1;36 sgr:0 sgr:0 sgr:0 sgr:0 sgr:0 sgr:38;5;78 sgr:38;5;180 sgr:38;5;244 sgr:38;5;173 sgr:38;5;80 sgr:38;5;180 sgr:38;5;141 sgr:38;5;110 sgr:38;5;176 sgr:38;5;240 sgr:1;93 sgr:96 sgr:4;92 sgr:1;91 sgr:33 sgr:92 sgr:91 sgr:33" ;;
    *) return 0 ;;
  esac
  set -- $vals
  local r
  for r in $roles; do printf '%s=%s\n' "$r" "$1"; shift; done
}

# resolve_theme <name> [warn] -> a valid theme name (default tokyonight)
resolve_theme() {
  case "${1:-}" in
    tokyonight|catppuccin|kanagawa|gruvbox|classic) printf '%s' "$1" ;;
    '') printf 'tokyonight' ;;
    *) [ "${2:-}" = warn ] && echo "$(t theme_invalid "$1")" >&2; printf 'tokyonight' ;;
  esac
}

# load_palette <theme> -> CCR_PALETTE (exported), FZF_COLORS, FZF_COLORS_BOXED,
# FZF_COLOR_FOOTER. Hex becomes 38;2;r;g;b on truecolor terminals, else the
# nearest xterm-256 colour; sgr: values are kept verbatim behind a '!'.
load_palette() {
  local line
  CCR_PALETTE=''; FZF_COLORS=''; FZF_COLORS_BOXED=''; FZF_COLOR_FOOTER=''
  while IFS= read -r line; do
    case "$line" in
      PAL=*)    CCR_PALETTE="${line#PAL=}" ;;
      FZF=*)    FZF_COLORS="${line#FZF=}" ;;
      BOXED=*)  FZF_COLORS_BOXED="${line#BOXED=}" ;;
      FOOTER=*) FZF_COLOR_FOOTER="${line#FOOTER=}" ;;
    esac
  done <<EOF
$(theme_palette "$1" | python3 -c '
import sys
truecolor = sys.argv[1] in ("truecolor", "24bit")
pal = dict(l.rstrip("\n").split("=", 1) for l in sys.stdin if "=" in l)
def rgb(h): return int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)
def x256(h):
    r, g, b = rgb(h)
    q = lambda v: 0 if v < 48 else (1 if v < 115 else (v - 35) // 40)
    lv = [0, 95, 135, 175, 215, 255]
    ci, cv = 16 + 36 * q(r) + 6 * q(g) + q(b), (lv[q(r)], lv[q(g)], lv[q(b)])
    gi = max(0, min(23, round(((r + g + b) / 3 - 8) / 10))); gv = 8 + 10 * gi
    d = lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2
    return ci if d(cv) <= d((gv, gv, gv)) else 232 + gi
sgr, fz = {}, {}
for k, v in pal.items():
    if v.startswith("sgr:"):
        sgr[k] = "!" + v[4:]
    else:
        sgr[k] = "38;2;%d;%d;%d" % rgb(v) if truecolor else "38;5;%d" % x256(v)
        fz[k] = v if truecolor else str(x256(v))
print("PAL=" + "|".join(k + "=" + v for k, v in sgr.items()))
if fz:
    m = lambda d: ",".join(a + ":" + fz[r] for a, r in d.items())
    print("FZF=" + m({"bg": "bg", "bg+": "sel", "fg": "fg", "fg+": "fg", "hl": "match", "hl+": "match",
                      "prompt": "accent", "pointer": "accent", "info": "dim", "border": "border",
                      "scrollbar": "sep", "separator": "sep", "label": "accent", "preview-label": "t_preview"}))
    print("BOXED=" + m({"header-border": "t_proc", "header-label": "t_proc", "input-border": "t_search",
                        "input-label": "t_search", "list-border": "border", "list-label": "t_list",
                        "preview-border": "t_preview", "gutter": "bg"}))
    print("FOOTER=" + m({"footer": "dim"}))
' "${COLORTERM:-}")
EOF
  export CCR_PALETTE
}

# pal <role> [style] -> the escape sequence for a palette role
pal() {
  local p="|${CCR_PALETTE:-}|" v
  case "$p" in *"|$1="*) ;; *) return 0 ;; esac
  v="${p#*|$1=}"; v="${v%%|*}"
  case "$v" in
    !*) printf '\033[%sm' "${v#!}" ;;
    *)  if [ -n "${2:-}" ]; then printf '\033[%s;%sm' "$2" "$v"; else printf '\033[%sm' "$v"; fi ;;
  esac
}
```

- [ ] **Step 6: Load the palette for subcommands and for the menu**

Just before the dispatch `case "${1:-}" in` (the line after the `# dispatch (internal subcommands …` comment block), add:

```bash
# fzf-spawned subcommands inherit CCR_PALETTE; build it if they were run without
case "${1:-}" in
  __*) [ -n "${CCR_PALETTE:-}" ] || load_palette "$(resolve_theme "${CCR_THEME:-}")" ;;
esac
```

In the argument loop add, next to `-x|--expired`:

```bash
    --theme)   THEME_OVERRIDE="${2:-}"; shift 2 ;;
    --theme=*) THEME_OVERRIDE="${1#*=}"; shift ;;
```

with `THEME_OVERRIDE=""` initialised beside `EXPIRED=0`. After the `case "$SORT"` validation block, add:

```bash
THEME="$(resolve_theme "${THEME_OVERRIDE:-${CCR_THEME:-}}" warn)"
export CCR_THEME="$THEME"
load_palette "$THEME"
```

- [ ] **Step 7: Add `--theme` to the help text**

In `print_help_body` (both languages) and the header comment, after the `-l|--lang` line:

```
  ccr -t|--theme <name>    主題：tokyonight(預設) catppuccin kanagawa gruvbox classic
```
```
  ccr -t|--theme <name>    Theme: tokyonight (default) catppuccin kanagawa gruvbox classic
```
and accept `-t` in the arg loop alongside `--theme`. Add `CCR_THEME=<name>` / `CCR_LAYOUT=boxed|classic` lines to both Environment sections.

- [ ] **Step 8: Run the tests**

Run: `/bin/bash tests/run.sh | tail -12`
Expected: the palette checks that only need `load_palette` / `--theme` now pass (`unknown theme warns`); the row-colour checks (`tokyonight truecolor`, `256 fallback`, `classic codes`, `default is tokyonight`, `--theme beats env`, `subcommand w/o palette`) still FAIL until Task 2 wires the renderers. Older checks pass.

- [ ] **Step 9: Commit**

```bash
git add bin/ccr tests/run.sh
git commit -m "feat: add themes and a palette of semantic colour roles" -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Render rows, process pane and previews from the palette

**Files:**
- Modify: `bin/ccr` — `outputs_for` Python (~lines 364–366), `do_preview` (~406–433), scan Python palette block (~479–494) and `add_row`, `runtime_lines` (~1105–1130), classic header assembly (~1240–1264)
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: `CCR_PALETTE`, `pal <role> [style]` from Task 1.
- Produces: Python `C(role, style="")` in the scan and `outputs_for` heredocs; Bash header pieces `PANE_ROWS` (process rows or the "none" line, no title/rule), `PANE_COUNT` (number of processes), `RETENTION` (coloured warning line or empty) used by Task 3.

- [ ] **Step 1: Write the failing renderer tests**

Append to the themes section of `tests/run.sh`:

```bash
strip_row() { strip | sed 's/[[:space:]]*$//'; }
same() { if [ "$2" = "$3" ]; then ok; else bad "$1" "$3" "$2"; fi; }   # exact match, multi-line safe
same "same layout any theme" "$(CCR_THEME=classic "$SH" "$CCC" __list time | cut -f1 | strip_row)" "$(CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCC" __list time | cut -f1 | strip_row)"
has  "preview uses theme"    "$(CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "")" $'\033[1;38;2;122;162;247m📌'
has  "outputs use theme"     "$(CCR_THEME=tokyonight COLORTERM=truecolor "$SH" "$CCR" __preview t w r "$P" "" aaaa-live cli "" "")" $'\033[38;2;158;206;106m✓'
fresh; COLORTERM=truecolor CCR_THEME=tokyonight run ctrl-y aaaa-live "$CCR" >/dev/null
has  "pane uses theme"       "$(awk '/PID 102/' "$F/args")" $'\033[1;38;2;247;118;142m 75.0% CPU'
has  "pane port bold yellow" "$(awk '/PID 102/' "$F/args")" $'\033[1;38;2;224;175;104m:5173'
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `/bin/bash tests/run.sh | tail -16`
Expected: the five new checks and Task 1's row-colour checks FAIL; older checks pass.

- [ ] **Step 3: Palette in the scan renderer**

In the scan heredoc replace the block from `# --- ANSI palette (256-color) ---` through `C_OUT      = col(141) …` with:

```python
# --- colours: semantic roles from CCR_PALETTE (see load_palette) ---
PAL = dict(kv.split("=", 1) for kv in os.environ.get("CCR_PALETTE", "").split("|") if "=" in kv)
def C(role, style=""):
    v = PAL.get(role)
    if not v:
        return ""
    if v.startswith("!"):           # classic: verbatim SGR, style ignored
        return "\x1b[" + v[1:] + "m"
    return "\x1b[" + (style + ";" if style else "") + v + "m"
ESC = "\x1b"
R   = ESC + "[0m"
SEP        = C("sep") + "│" + R
C_RECENT   = C("recent")
C_MID      = C("week")
C_OLD      = C("old")
C_TITLE    = C("fg")
C_TITLE_LO = C("dim")
C_PATH     = C("path")
C_DESKTOP  = C("desktop")
C_EXPIRED  = C("expired")
C_CODEX    = C("codex")
C_CLAUDE   = C("claude")
C_OUT      = C("out")
C_GEAR     = C("gear")
```

and in `add_row` change `f"{C_MID}{mark}{R}…"` to `f"{C_GEAR}{mark}{R}…"`.

- [ ] **Step 4: Palette in the outputs preview**

In the `outputs_for` heredoc replace the three lines starting `E = "\x1b["; R = E + "0m"` with:

```python
PAL = dict(kv.split("=", 1) for kv in os.environ.get("CCR_PALETTE", "").split("|") if "=" in kv)
def C(role, style=""):
    v = PAL.get(role)
    if not v:
        return ""
    if v.startswith("!"):
        return "\x1b[" + v[1:] + "m"
    return "\x1b[" + (style + ";" if style else "") + v + "m"
R = "\x1b[0m"
KEY, TTL, URL, OK, GONE, DIM = C("key"), C("fg", "1"), C("url", "4"), C("ok"), C("bad"), C("dim")
KIND = {"+": C("ok") + "+", "~": C("key") + "~", "-": C("bad") + "-"}
```

- [ ] **Step 5: Palette in `do_preview`**

Replace the two `local C_…` lines with:

```bash
  local C_RESET=$'\033[0m' C_TITLE C_DIM C_WARN C_KEY C_DESK C_CODEX
  C_TITLE="$(pal accent 1)"; C_DIM="$(pal dim)"; C_WARN="$(pal bad 1)"
  C_KEY="$(pal key)"; C_DESK="$(pal desktop)"; C_CODEX="$(pal codex)"
```

and change `printf '%s%s%s\n' $'\033[36m' "$(t pv_codex)" "$C_RESET"` to `printf '%s%s%s\n' "$C_CODEX" "$(t pv_codex)" "$C_RESET"`.

- [ ] **Step 6: Palette in the process pane**

In `runtime_lines` replace the two lines that set `c0 … cHot` inside `if [ "${1:-}" = --pane ]` with:

```bash
    c0=$'\033[0m' cP="$(pal port 1)" cN="$(pal fg)" cC="$(pal fg 1)"
    cD="$(pal dir)" cU="$(pal url 4)" cHot="$(pal hot 1)"
```

- [ ] **Step 7: Split the header into pieces**

Replace the block from `PANE_MAX=8` through the retention `fi` with:

```bash
PANE_MAX=8
PANE_COUNT=0
if [ ${#DIRS[@]} -gt 0 ]; then PROCS="$(runtime_lines --pane "${DIRS[@]}")"; else PROCS=""; fi
if [ -n "$PROCS" ]; then
  PANE_COUNT="$(printf '%s\n' "$PROCS" | wc -l | tr -d ' ')"
  PANE_ROWS="$(printf '%s\n' "$PROCS" | sed -n "1,${PANE_MAX}p")"
  [ "$PANE_COUNT" -gt "$PANE_MAX" ] && PANE_ROWS="$PANE_ROWS"$'\n'"$(t pane_more "$((PANE_COUNT - PANE_MAX))")"
  # mark sessions that have something running, then rebuild the rows
  CCR_BUSY="$(runtime_procs "${DIRS[@]}" | cut -d"$TAB" -f6 | sort -u)"
  export CCR_BUSY
  DATA="$(scan "$FILTER" "$SORT" "$EXPIRED")"
else
  PANE_ROWS="$(pal dim)$(t pane_none)"$'\033[0m'
fi
RETENTION=""
read -r KEEP_DAYS KEEP_SET <<EOF
$(retention_days)
EOF
if [ "$KEEP_SET" = 0 ] || [ "$KEEP_DAYS" -lt 90 ]; then
  RETENTION="$(pal warn)$(t retention "$KEEP_DAYS" "$CONFIG_DIR/settings.json")"$'\033[0m'
fi
HINTS="$(pal dim)$(t header)"$'\n'"$(t header2)"
[ "$CODEX_MODE" = 1 ] && HINTS="$HINTS"$'\n'"$(t header3)"
HINTS="$HINTS"$'\033[0m'
# classic layout: one header with title, rows, rule, hints and the warning
HEADER="$(pal fg 1)$(t pane_title)"$'\033[0m\n'"$PANE_ROWS"
HEADER="$HEADER"$'\n'"$(pal sep)$(printf '─%.0s' $(seq 1 72))"$'\033[0m\n'"$HINTS"
[ -n "$RETENTION" ] && HEADER="$HEADER"$'\n'"$RETENTION"
SOURCE_BIND=()
[ "$CODEX_MODE" = 1 ] && SOURCE_BIND=(--bind 'ctrl-a:execute-silent("$CCR_SELF" __cycle_source)+reload("$CCR_SELF" __list)')
```

- [ ] **Step 8: Run the tests**

Run: `/bin/bash tests/run.sh | tail -5`
Expected: `pass=N fail=0` (all Task 1 and Task 2 checks, plus every older check).

- [ ] **Step 9: Commit**

```bash
git add bin/ccr tests/run.sh
git commit -m "feat: render rows, process pane and previews from the theme palette" -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Layout detection and the boxed layout

**Files:**
- Modify: `bin/ccr` — i18n strings; new `ver_ge` / `choose_layout` after `pal`; dispatch (`__set_sort`, `__label`); the main `fzf` call (~1266–1286); the `Ctrl-L` picker (~1304–1307)
- Test: `tests/run.sh`

**Interfaces:**
- Consumes: `FZF_COLORS`, `FZF_COLORS_BOXED`, `FZF_COLOR_FOOTER`, `PANE_ROWS`, `PANE_COUNT`, `RETENTION`, `HINTS`, `HEADER`, `SOURCE_BIND` from Tasks 1–2.
- Produces: `LAYOUT` (`boxed` | `classic`), `FZF_HAS_FOOTER` / `FZF_HAS_GUTTER` (`0` | `1`), subcommands `__set_sort <key>` and `__label`.

- [ ] **Step 1: Write the failing layout tests**

Append to `tests/run.sh`:

```bash
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
has   "boxed gutter"         "$A" "--gutter= "
has   "boxed label refresh"  "$A" "transform-input-label"
hasnt "boxed: no pane title" "$A" "背後正在跑的 process"
A="$(args_for 0.60.0 "$CCR")"
has   "0.60 boxed"           "$A" "--style=full"
hasnt "0.60 no footer"       "$A" "--footer"
hasnt "0.60 no gutter"       "$A" "--gutter"
has   "0.60 hints in header" "$A" "Enter 開啟"
A="$(args_for 0.57.0 "$CCR")"
has   "classic on 0.57"      "$A" "--border-label= ccr "
hasnt "classic no style"     "$A" "--style"
has   "ccc border label"     "$(args_for 0.57.0 "$CCC")" "--border-label= ccc "
has   "CCR_LAYOUT=classic"   "$(CCR_LAYOUT=classic args_for 0.74.4 "$CCR")" "--border-label"
has   "boxed on old fzf warns" "$(CCR_LAYOUT=boxed FAKE_FZF_VERSION=0.57.0 run ctrl-y aaaa-live "$CCR" 2>&1)" "需要 fzf 0.58"
has   "odd fzf version"      "$(args_for weird "$CCR")" "--border-label"
has   "bad CCR_LAYOUT warns" "$(CCR_LAYOUT=bogus FAKE_FZF_VERSION=0.74.4 run ctrl-y aaaa-live "$CCR" 2>&1)" "CCR_LAYOUT 只接受 boxed|classic"
FAKE_FZF_VERSION=0.74.4 FAKE_PICK2="1111-demo" run ctrl-l aaaa-live "$CCR" >/dev/null 2>&1
has   "boxed picker label"   "$(cat "$F/args")" "--list-label= 開啟 · live-session "
A="$(CCR_THEME=classic args_for 0.74.4 "$CCR")"
has   "classic theme boxed"  "$A" "--style=full"
hasnt "classic no colors"    "$A" "--color="
A="$(CCR_THEME=tokyonight COLORTERM=truecolor args_for 0.74.4 "$CCC")"
has   "boxed colors"         "$A" "header-border:#ff9e64"
has   "ccc source in label"  "$A" "--input-label= 🔍 搜尋 · time · all "
S="$(mktemp)"; printf 'sort=title\nsource=codex\n' > "$S"
has   "__label"              "$(CCR_STATE="$S" CCR_CODEX=1 "$SH" "$CCC" __label)" " 🔍 搜尋 · title · codex "
CCR_STATE="$S" "$SH" "$CCR" __set_sort dir
has   "__set_sort"           "$(cat "$S")" "sort=dir"; rm -f "$S"
```

(The fixture's process pane has three entries: vite, http.server, tsc.)

- [ ] **Step 2: Run the tests to see them fail**

Run: `/bin/bash tests/run.sh | tail -30`
Expected: the new layout checks FAIL; earlier checks pass.

- [ ] **Step 3: i18n strings**

Add to `t()`:

```bash
    zh:proc_label)   fmt=' ⚙ 背景 process · %s ' ;;
    en:proc_label)   fmt=' ⚙ Processes · %s ' ;;
    zh:proc_label0)  fmt=' ⚙ 背景 process ' ;;
    en:proc_label0)  fmt=' ⚙ Processes ' ;;
    zh:search_label) fmt=' 🔍 搜尋 · %s ' ;;
    en:search_label) fmt=' 🔍 Search · %s ' ;;
    zh:list_label)   fmt=' Session 列表 ' ;;
    en:list_label)   fmt=' Sessions ' ;;
    zh:preview_label) fmt=' 預覽 ' ;;
    en:preview_label) fmt=' Preview ' ;;
    zh:open_label)   fmt=' 開啟 · %s ' ;;
    en:open_label)   fmt=' Open · %s ' ;;
    zh:footer)       fmt='Enter 開啟  ^R 遠端  ^F 分支  ^Y 只印  ^L 開啟產出  ^X 已清理  ^T/^O/^G 排序' ;;
    en:footer)       fmt='Enter resume  ^R remote  ^F fork  ^Y print  ^L open  ^X expired  ^T/^O/^G sort' ;;
    zh:footer_ccc)   fmt='  ^A 來源' ;;
    en:footer_ccc)   fmt='  ^A source' ;;
    zh:layout_invalid) fmt='ccr：CCR_LAYOUT 只接受 boxed|classic，改為自動偵測' ;;
    en:layout_invalid) fmt='ccr: CCR_LAYOUT accepts boxed|classic; detecting instead' ;;
    zh:layout_old_fzf) fmt='ccr：分框版面需要 fzf 0.58 以上（目前 %s），改用 classic；可執行 brew upgrade fzf' ;;
    en:layout_old_fzf) fmt='ccr: the boxed layout needs fzf 0.58+ (found %s); using classic. Try: brew upgrade fzf' ;;
```

- [ ] **Step 4: Version detection and layout choice**

Insert after `pal()`:

```bash
# ver_ge <version> <major.minor> -> success when version >= major.minor
ver_ge() {
  awk -v h="$1" -v w="$2" 'BEGIN { if (h !~ /^[0-9]+\.[0-9]+/) exit 1
    split(h, a, "."); split(w, b, ".")
    exit !((a[1] + 0 > b[1] + 0) || (a[1] + 0 == b[1] + 0 && a[2] + 0 >= b[2] + 0)) }'
}

# choose_layout -> sets LAYOUT, FZF_HAS_FOOTER, FZF_HAS_GUTTER from fzf --version
choose_layout() {
  local v want="${CCR_LAYOUT:-}"
  v="$(fzf --version 2>/dev/null | awk '{ print $1; exit }')"
  FZF_HAS_FOOTER=0; FZF_HAS_GUTTER=0
  ver_ge "$v" 0.63 && FZF_HAS_FOOTER=1
  ver_ge "$v" 0.66 && FZF_HAS_GUTTER=1
  case "$want" in
    ''|boxed|classic) ;;
    *) echo "$(t layout_invalid)" >&2; want='' ;;
  esac
  if ver_ge "$v" 0.58; then
    LAYOUT="${want:-boxed}"
  else
    [ "$want" = boxed ] && echo "$(t layout_old_fzf "${v:-?}")" >&2
    LAYOUT=classic
  fi
}
```

- [ ] **Step 5: `__set_sort` and `__label` subcommands**

In the dispatch `case`, after `__toggle_expired)`:

```bash
  __set_sort) state_set sort "${2:-time}"; exit 0 ;;
  __label)    # the boxed layout's Search label: sort (+ source in ccc)
    if [ "${CCR_CODEX:-0}" = 1 ]; then
      t search_label "$(state_get sort time) · $(state_get source all)"
    else
      t search_label "$(state_get sort time)"
    fi
    exit 0 ;;
```

- [ ] **Step 6: Build the fzf arguments per layout**

Replace the whole `RESULT="$( … )" || { … }` block with:

```bash
choose_layout
COLOR_ARGS=()
[ -n "$FZF_COLORS" ] && COLOR_ARGS=(--color="$FZF_COLORS")
LAYOUT_ARGS=()
if [ "$LAYOUT" = boxed ]; then
  [ -n "$FZF_COLORS_BOXED" ] && COLOR_ARGS+=(--color="$FZF_COLORS_BOXED")
  BOX_HEADER="$PANE_ROWS"
  [ -n "$RETENTION" ] && BOX_HEADER="$BOX_HEADER"$'\n'"$RETENTION"
  FOOTER="$(t footer)"; [ "$CODEX_MODE" = 1 ] && FOOTER="$FOOTER$(t footer_ccc)"
  if [ "$FZF_HAS_FOOTER" = 1 ]; then
    LAYOUT_ARGS+=(--footer="$FOOTER")
    [ -n "$FZF_COLOR_FOOTER" ] && COLOR_ARGS+=(--color="$FZF_COLOR_FOOTER")
  else
    BOX_HEADER="$BOX_HEADER"$'\n'"$(pal dim)$FOOTER"$'\033[0m'
  fi
  [ "$FZF_HAS_GUTTER" = 1 ] && LAYOUT_ARGS+=(--gutter=' ')
  if [ "$PANE_COUNT" -gt 0 ]; then PLABEL="$(t proc_label "$PANE_COUNT")"; else PLABEL="$(t proc_label0)"; fi
  if [ "$CODEX_MODE" = 1 ]; then SLABEL="$(t search_label "$SORT · all")"; else SLABEL="$(t search_label "$SORT")"; fi
  LAYOUT_ARGS+=(--style=full --header-first --header="$BOX_HEADER"
    --header-border=rounded --input-border=rounded --list-border=rounded
    --header-label="$PLABEL" --header-label-pos=2
    --input-label="$SLABEL" --input-label-pos=2
    --list-label="$(t list_label)" --list-label-pos=2
    --preview-label="$(t preview_label)" --preview-label-pos=2
    --prompt='❯ ' --pointer='▌' --highlight-line --info=inline-right
    --preview-window='down,45%,wrap,border-rounded'
    --bind 'ctrl-t:execute-silent("$CCR_SELF" __set_sort time)+reload("$CCR_SELF" __list)+transform-input-label("$CCR_SELF" __label)'
    --bind 'ctrl-o:execute-silent("$CCR_SELF" __set_sort title)+reload("$CCR_SELF" __list)+transform-input-label("$CCR_SELF" __label)'
    --bind 'ctrl-g:execute-silent("$CCR_SELF" __set_sort dir)+reload("$CCR_SELF" __list)+transform-input-label("$CCR_SELF" __label)')
  [ "$CODEX_MODE" = 1 ] && SOURCE_BIND=(--bind 'ctrl-a:execute-silent("$CCR_SELF" __cycle_source)+reload("$CCR_SELF" __list)+transform-input-label("$CCR_SELF" __label)')
else
  LAYOUT_ARGS+=(--border=rounded --border-label=" $PROG " --border-label-pos=3
    --header-first --header="$HEADER" --prompt="[$SORT] ❯ "
    --preview-label="$(t preview_label)" --preview-window='down,45%,wrap,border-top'
    --bind 'ctrl-t:reload("$CCR_SELF" __list time)+change-prompt([time] ❯ )'
    --bind 'ctrl-o:reload("$CCR_SELF" __list title)+change-prompt([title] ❯ )'
    --bind 'ctrl-g:reload("$CCR_SELF" __list dir)+change-prompt([dir] ❯ )')
fi

# Show only column 1 (DISPLAY); preview/sort use the hidden columns.
RESULT="$(
  printf '%s\n' "$DATA" | fzf \
    --ansi \
    --delimiter="$TAB" \
    --with-nth=1 \
    --no-hscroll \
    --reverse \
    "${LAYOUT_ARGS[@]}" \
    ${COLOR_ARGS[@]+"${COLOR_ARGS[@]}"} \
    --expect=ctrl-r,ctrl-f,ctrl-y,ctrl-l \
    --bind 'ctrl-x:execute-silent("$CCR_SELF" __toggle_expired)+reload("$CCR_SELF" __list)' \
    ${SOURCE_BIND[@]+"${SOURCE_BIND[@]}"} \
    --preview="\"\$CCR_SELF\" __preview {6} {4} {5} {3} {7} {2} {8} {9} {10}"
)" || { echo "$(t cancelled)"; exit 0; }
```

- [ ] **Step 7: Themed `Ctrl-L` picker**

Replace the picker's `fzf …` call with:

```bash
    PICK_ARGS=(--delimiter="$TAB" --with-nth=2 --reverse --height=40% --prompt="$(t pick_output)")
    if [ "$LAYOUT" = boxed ]; then
      PICK_ARGS+=(--list-border=rounded --list-label="$(t open_label "$TITLE_PICK")" --list-label-pos=2
        --input-border=rounded --pointer='▌' --highlight-line)
      [ -n "$FZF_COLORS_BOXED" ] && PICK_ARGS+=(--color="$FZF_COLORS_BOXED")
    else
      PICK_ARGS+=(--border=rounded --header="$TITLE_PICK")
    fi
    [ -n "$FZF_COLORS" ] && PICK_ARGS+=(--color="$FZF_COLORS")
    ITEMS="$(printf '%s\n' "$ITEMS" | fzf "${PICK_ARGS[@]}")" || { echo "$(t cancelled)"; exit 0; }
```

- [ ] **Step 8: Run the tests**

Run: `/bin/bash tests/run.sh | tail -5`
Expected: `pass=N fail=0`.

- [ ] **Step 9: Render both layouts for real**

With the temporary fzf 0.74.4 at `~/.cache/ccr-fzf-probe/fzf/0.74.4/bin/fzf` (from brainstorming; re-extract with `brew fetch fzf` and `tar -xzf "$(brew --cache fzf)" -C ~/.cache/ccr-fzf-probe` if missing) and the demo data:

```bash
demo/setup.sh && source ~/ccr-demo/env.sh
P=~/.cache/ccr-fzf-probe/fzf/0.74.4/bin
for v in new old; do
  tmux kill-session -t ccrshot 2>/dev/null
  if [ $v = new ]; then tmux new-session -d -s ccrshot -x 140 -y 42 "PATH=$P:\$PATH COLORTERM=truecolor ccc; sleep 30"
  else tmux new-session -d -s ccrshot -x 140 -y 42 "COLORTERM=truecolor ccc; sleep 30"; fi
  sleep 3; tmux capture-pane -t ccrshot -p > /tmp/ccr-shot-$v.txt; tmux kill-session -t ccrshot
  cat /tmp/ccr-shot-$v.txt
done
demo/teardown.sh
```

Expected: `new` shows four rounded boxes in order Processes / Search / Sessions / Preview with left-aligned labels and the footer line; `old` shows one rounded border labelled ` ccc `. Fix and re-run Step 8 if not.

- [ ] **Step 10: Commit**

```bash
git add bin/ccr tests/run.sh
git commit -m "feat: boxed layout on fzf 0.58+, themed classic fallback" -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Documentation and v0.6.0

**Files:**
- Modify: `README.md`, `README.zh-TW.md`, `demo/README.md`, `CHANGELOG.md`, `docs/superpowers/specs/2026-10-12-themes-and-boxed-layout-design.md`, `bin/ccr` (`VERSION`)
- Create: `docs/releases/v0.6.0.md`

- [ ] **Step 1: Record the plan's deviations in the spec**

In the spec's Boxed table change the Sessions label to ` Sessions ` (no count; fzf's info shows it), replace `change-input-label` with "`execute-silent(__set_sort …)+reload+transform-input-label(__label)`", and add a line under Detection: "`--footer` needs fzf ≥ 0.63 (else the hints are the last line of the Processes box); `--gutter` needs ≥ 0.66." Also note the labels are localized (Chinese: ` ⚙ 背景 process · N `, ` 🔍 搜尋 · <sort> `, ` Session 列表 `, ` 預覽 `).

- [ ] **Step 2: README (both languages)**

Add a `### Themes` / `### 主題` subsection under Features (after Everyday / 日常使用) with: the five theme names, `ccr --theme gruvbox`, `CCR_THEME=catppuccin`, truecolor vs 256 note, and the boxed layout note ("needs fzf ≥ 0.58 — `brew upgrade fzf`; older fzf shows a single border; `CCR_LAYOUT=classic` forces it"). Add `CCR_THEME` and `CCR_LAYOUT` rows to the environment tables, `ccr --theme <name>` to Usage, and replace the top sample screen with the boxed layout:

```
╭─ ⚙ Processes · 2 ───────────────────────────────────────────────────────────────────────╮
│  -       PID 4242    59.1% CPU    45 MB  webpack --watch            ~/code/payments       │
│  :5173   PID 6060     0.0% CPU    38 MB  vite --port 5173           ~/code/acme-api  → http://localhost:5173 │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
╭─ 🔍 Search · time ───────────────────────────────────────────────────────────────────────╮
│ ❯ jwt                                                                             3/14 │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Sessions ───────────────────────────────────────────────────────────────────────────────╮
│▌ just now │ ⚙✦ Add JWT auth to the API gateway         │ ~/code/acme-api                  │
│    2m ago │    Fix flaky checkout integration test     │ ~/code/storefront                │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
 Enter resume  ^R remote  ^F fork  ^Y print  ^L open  ^X expired  ^T/^O/^G sort
╭─ Preview ────────────────────────────────────────────────────────────────────────────────╮
│ 📌 Add JWT auth to the API gateway                                                       │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
```

(Use the Chinese labels in `README.zh-TW.md`.) Update "What's new" to 0.6.

- [ ] **Step 3: demo/README.md**

Add under the setup commands: "`CCR_THEME=catppuccin ccc` (or `--theme`) to record another theme; the boxed layout needs fzf ≥ 0.58."

- [ ] **Step 4: Release notes, CHANGELOG, version**

Create `docs/releases/v0.6.0.md` (English then 繁體中文, same structure as `v0.5.0.md`): highlights = Tokyo Night default, five themes + `--theme` / `CCR_THEME`, boxed layout on fzf ≥ 0.58 with the version gates, truecolor / 256 fallback, `classic`; notes = `brew upgrade fzf`, `CCR_LAYOUT`. In `CHANGELOG.md` add `## [0.6.0] - <today>` with those Added / Changed lines, move `[Unreleased]` compare link to `v0.6.0...HEAD` and add `[0.6.0]: …/compare/v0.5.0...v0.6.0`. Add the 0.6.0 row to both README Releases tables. Set `VERSION="0.6.0"` in `bin/ccr`.

- [ ] **Step 5: Verify and commit**

Run: `/bin/bash tests/run.sh | tail -1` → `pass=N fail=0`; run the README anchor/link check used for 0.5.0. Then:

```bash
git add README.md README.zh-TW.md demo/README.md CHANGELOG.md docs/releases/v0.6.0.md docs/superpowers/specs/2026-10-12-themes-and-boxed-layout-design.md bin/ccr
git commit -m "chore(release): v0.6.0" -m "Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git tag -a v0.6.0 -m "v0.6.0 — themes and boxed layout"
```
