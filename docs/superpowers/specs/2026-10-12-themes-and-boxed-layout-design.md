# Themes and Boxed Layout Design

## Goal

Make `ccr` / `ccc` look like a modern Neovim picker. Replace the default look with
the **Tokyo Night** palette and a **stacked, boxed layout** where each kind of
content (processes, search, sessions, preview) sits in its own titled block.
Ship a few other popular Neovim palettes behind a setting, and keep today's look
available as `classic`. Every existing feature keeps working unchanged.

## Decisions (from brainstorming)

- The new look becomes the **default** for everyone; README and demo use it.
- Default theme: **Tokyo Night**. Also shipped: Catppuccin Mocha, Kanagawa Wave,
  Gruvbox Dark, and `classic` (today's 256-colour look).
- Layout: **stacked boxes**, full width, preview below (option B).
- Themes are a built-in palette table inside `bin/ccr` (approach 1); `ccr` stays a
  single self-contained script.
- The boxed layout needs fzf ≥ 0.58; older fzf gets a single-border fallback.
- Out of scope: user theme files (`CCR_THEME_FILE`), light themes, re-recording
  the demo GIF.

## Interface

| Setting | Values | Default |
| ------- | ------ | ------- |
| `--theme <name>` / `CCR_THEME` | `tokyonight`, `catppuccin`, `kanagawa`, `gruvbox`, `classic` | `tokyonight` |
| `CCR_LAYOUT` | `boxed`, `classic` | `boxed` when fzf ≥ 0.58, else `classic` |

`--theme` wins over `CCR_THEME`. The resolved theme and layout are exported so the
fzf-spawned subcommands (`__list`, `__preview`, …) render with the same palette.

Error handling:

- Unknown theme name: print one warning to stderr
  (`ccr: unknown theme "x"; using tokyonight` / Chinese equivalent) and continue
  with `tokyonight`.
- Unknown `CCR_LAYOUT` value: same pattern, fall back to auto-detection.
- `fzf --version` can't be parsed: use the `classic` layout.
- `CCR_LAYOUT=boxed` with fzf < 0.58: warn and use `classic` (the options would
  make fzf exit with an error).

## Palette

Every theme defines the same **roles**. A value is either `#rrggbb` or, for
`classic` only, `sgr:<codes>` (raw SGR parameters, used verbatim).

| Role | Used for | Tokyo Night |
| ---- | -------- | ----------- |
| `bg` | fzf background (all boxes, preview) | `#1a1b26` |
| `fg` | normal text, session titles | `#c0caf5` |
| `dim` | secondary text, untitled sessions, key hints, info | `#565f89` |
| `sel` | selected-row background | `#283457` |
| `border` | list border, single-border fallback | `#27a1b9` |
| `sep` | `│` column separators, pane rule, scrollbar | `#3b4261` |
| `accent` | prompt `❯`, pointer `▌`, preview title `📌` (bold) | `#7aa2f7` |
| `match` | fuzzy-match highlight | `#ff9e64` |
| `t_proc` | Processes box border + label | `#ff9e64` |
| `t_search` | Search box border + label | `#7aa2f7` |
| `t_list` | Sessions box label | `#9ece6a` |
| `t_preview` | Preview box border + label | `#bb9af7` |
| `recent` / `week` / `old` | relative time: < 1 day / < 7 days / older | `#9ece6a` / `#e0af68` / `#565f89` |
| `claude` / `codex` | `ccc` tool column | `#ff9e64` / `#7dcfff` |
| `gear` / `out` | `⚙` / `✦` marks | `#e0af68` / `#bb9af7` |
| `path` / `desktop` / `expired` | path column; `Desktop ·` rows; expired rows | `#7aa2f7` / `#bb9af7` / `#545c7e` |
| `port` / `dir` / `url` / `hot` | process pane: port (bold), project, link (underline), CPU ≥ 50% (bold) | `#e0af68` / `#7dcfff` / `#9ece6a` / `#f7768e` |
| `key` | preview icons (🕒📁🔑), section headings | `#e0af68` |
| `ok` / `bad` / `warn` | `✓`, `+` / `✗` / retention warning | `#9ece6a` / `#f7768e` / `#e0af68` |

Other themes (same role order as the table above):

| Role | catppuccin (Mocha) | kanagawa (Wave) | gruvbox (Dark) |
| ---- | ------------------ | --------------- | -------------- |
| bg, fg, dim | `#1e1e2e` `#cdd6f4` `#6c7086` | `#1f1f28` `#dcd7ba` `#727169` | `#282828` `#ebdbb2` `#928374` |
| sel, border, sep | `#313244` `#b4befe` `#45475a` | `#2d4f67` `#54546d` `#363646` | `#3c3836` `#665c54` `#504945` |
| accent, match | `#cba6f7` `#fab387` | `#7e9cd8` `#ffa066` | `#fabd2f` `#fe8019` |
| t_proc, t_search, t_list, t_preview | `#fab387` `#89b4fa` `#a6e3a1` `#f5c2e7` | `#ffa066` `#7e9cd8` `#98bb6c` `#957fb8` | `#fe8019` `#83a598` `#b8bb26` `#d3869b` |
| recent, week, old | `#a6e3a1` `#f9e2af` `#6c7086` | `#98bb6c` `#e6c384` `#727169` | `#b8bb26` `#fabd2f` `#928374` |
| claude, codex | `#fab387` `#89dceb` | `#ffa066` `#7fb4ca` | `#fe8019` `#8ec07c` |
| gear, out | `#f9e2af` `#cba6f7` | `#e6c384` `#957fb8` | `#fabd2f` `#d3869b` |
| path, desktop, expired | `#89b4fa` `#f5c2e7` `#585b70` | `#7e9cd8` `#957fb8` `#54546d` | `#83a598` `#d3869b` `#665c54` |
| port, dir, url, hot | `#f9e2af` `#89dceb` `#a6e3a1` `#f38ba8` | `#e6c384` `#7fb4ca` `#98bb6c` `#e46876` | `#fabd2f` `#8ec07c` `#b8bb26` `#fb4934` |
| key, ok, bad, warn | `#f9e2af` `#a6e3a1` `#f38ba8` `#f9e2af` | `#e6c384` `#98bb6c` `#e46876` `#e6c384` | `#fabd2f` `#b8bb26` `#fb4934` `#fabd2f` |

`classic` maps each role to the SGR codes `ccr` 0.5.0 uses today, so it looks the
same. It is not byte-for-byte identical: 0.5.0 uses a few near-duplicate codes for
the same meaning (the missing-directory warning is `1;31` while `✗` is `91`; the
process-pane title is `1;97` while session titles are `38;5;253`). Each of those
pairs now shares one role, so it renders with that role's code:

| Role | classic | Role | classic |
| ---- | ------- | ---- | ------- |
| `fg` (titles) | `sgr:38;5;253` | `dim` | `sgr:38;5;244` |
| `sep` | `sgr:38;5;240` | `accent` (📌) | `sgr:1;36` |
| `recent` / `week` / `old` | `sgr:38;5;78` / `sgr:38;5;180` / `sgr:38;5;244` | `path` / `desktop` / `expired` | `sgr:38;5;110` / `sgr:38;5;176` / `sgr:38;5;240` |
| `claude` / `codex` | `sgr:38;5;173` / `sgr:38;5;80` | `gear` / `out` | `sgr:38;5;180` / `sgr:38;5;141` |
| `port` / `dir` / `url` / `hot` | `sgr:1;93` / `sgr:96` / `sgr:4;92` / `sgr:1;91` | `key` / `ok` / `bad` / `warn` | `sgr:33` / `sgr:92` / `sgr:91` / `sgr:33` |

`classic` sets no fzf `--color` (fzf defaults, terminal background), exactly as
today; `bg`, `sel`, `border`, `match` and the `t_*` roles are unused for it.

## Colour pipeline

One palette, three consumers:

1. **Palette source** — `theme_palette <name>` (Bash `case`, Bash 3.2-safe) prints
   `role=value` lines. Resolved once at startup and exported as
   `CCR_PALETTE="role=value;role=value;…"`.
2. **Escape building** — values become SGR strings:
   - `#rrggbb` + truecolor terminal → `38;2;r;g;b`
   - `#rrggbb` + no truecolor → `38;5;N`, N = nearest xterm-256 colour (6×6×6 cube
     or grey ramp, whichever is closer)
   - `sgr:…` → used verbatim
   Truecolor = `COLORTERM` is `truecolor` or `24bit`. Styles (bold, underline) are
   added by the caller, not stored in the palette.
3. **Consumers**
   - **Python** (scan rows, process pane rows, outputs preview) — a small shared
     helper parses `CCR_PALETTE` and returns escape strings by role. Replaces the
     hard-coded `col(N)` / `E + "93m"` constants.
   - **Bash** (preview header lines, header hints, retention warning) — after
     resolving the palette, set `C_<ROLE>` variables once; `do_preview` and the
     header use them instead of literal `\033[…m`.
   - **fzf** — `--color` built from the palette (hex in truecolor, 256 indices
     otherwise): `bg`, `bg+`=`sel`, `fg`, `fg+`, `hl`/`hl+`=`match`, `prompt`,
     `pointer`=`accent`, `info`/`footer`=`dim`, `border`, `scrollbar`/`separator`=`sep`,
     and (boxed only) `header-border`/`header-label`=`t_proc`,
     `input-border`/`input-label`=`t_search`, `list-border`=`border`,
     `list-label`=`t_list`, `preview-border`/`preview-label`=`t_preview`,
     `gutter`=`bg`.

## Layout

Detection: parse the first `X.Y` of `fzf --version`; `boxed` when ≥ 0.58 unless
`CCR_LAYOUT` says otherwise.

### Boxed (fzf ≥ 0.58)

Top to bottom, all full width, rounded borders, labels left-aligned (`pos=2`):

| Block | fzf option | Label | Content |
| ----- | ---------- | ----- | ------- |
| Processes | header (`--header-first`, `--header-border`) | ` ⚙ Processes · N ` (` ⚙ Processes ` when none) | process rows, or "none detected"; the retention warning as the last line when it applies |
| Search | input (`--input-border`) | ` 🔍 Search · <sort> ` (`ccc`: ` · <source>` appended) | prompt `❯ `, `--info=inline-right` |
| Sessions | list (`--list-border`) | ` Sessions · N ` | rows; `--highlight-line`; pointer `▌` on the current row only (`--gutter=' '`) |
| Key hints | footer (`--footer`, no border) | — | one dim line: `Enter resume  ^R remote  ^F fork  ^Y print  ^L open  ^X expired  ^T/^O/^G sort` (+ `^A source` in `ccc`) |
| Preview | `--preview-window=down,45%,border-rounded` | ` Preview ` | as today |

The process pane no longer needs its own title line and `─` rule (the box label
replaces them). Sort keys (`^T` / `^O` / `^G`) and `^A` update the Search label
with `change-input-label` alongside the existing `reload`. `^X` keeps its
`reload`. The `Ctrl-L` picker uses the same palette and border style
(`--list-border`, label ` Open · <session title> `, height 40%).

### Classic (fzf < 0.58)

Today's structure: one rounded `--border` labelled ` ccr ` / ` ccc `
(`--border-label`), the header holds the process pane title, rows and `─` rule,
then the key-hint lines and the retention warning; prompt `[time] ❯ `; preview
below with ` Preview ` as `--preview-label`. Colours come from the palette like
everywhere else.

Theme and layout are independent: any theme works with either layout.

## Testing

`tests/run.sh` keeps all existing checks and adds:

- **Truecolor**: `COLORTERM=truecolor`, default theme → list rows contain
  `38;2;255;158;100` for the `claude` tag (ccc) and no `38;5;`.
- **256 fallback**: `COLORTERM` unset → rows contain `38;5;` and no `38;2;`.
- **classic**: `CCR_THEME=classic` → the `claude` tag is `38;5;173`, the hot CPU is
  `1;91` (today's codes).
- **Selection**: `--theme gruvbox` beats `CCR_THEME=kanagawa`; an unknown name warns
  and renders Tokyo Night.
- **Layout detection**: the fake `fzf` answers `--version` from `$FAKE_FZF_VERSION`.
  0.74 → args contain `--style=full`, `--header-label`, `--input-label`,
  `--list-label`, `--gutter`, `change-input-label`; 0.57 → `--border-label`, no
  `--style`. `CCR_LAYOUT=classic` forces classic on 0.74; `CCR_LAYOUT=boxed` on 0.57
  warns and uses classic.
- Existing colour assertions (hot CPU red, etc.) are rewritten in terms of the
  theme roles so they don't break on palette changes.

Manual verification at the end of implementation: render both layouts in a
detached tmux pane with a temporary fzf 0.74 and with the installed fzf 0.57 and
inspect `tmux capture-pane -e`.

## Documentation and release

- README (English and 繁體中文): a "Themes" section (list, `--theme` /
  `CCR_THEME`, sample), the boxed layout and its fzf ≥ 0.58 requirement with
  `brew upgrade fzf`, `CCR_THEME` / `CCR_LAYOUT` in the environment table, updated
  sample screens.
- `demo/README.md`: how to record with another theme.
- CHANGELOG and `docs/releases/v0.6.0.md`; release as **v0.6.0**.
