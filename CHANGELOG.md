# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.1] - 2026-10-13

### Added
- `ccr --update` (also `ccc --update`): updates a git install in place — follows the installed symlink to the checkout, runs `git pull --ff-only`, and prints `ccr <old> → <new>` with the CHANGELOG sections in between (or "already up to date"). A copy that isn't the root of a git checkout, or a pull that fails (e.g. local changes), prints why and how to update by hand, and exits 1.

## [0.6.0] - 2026-10-12

### Added
- Themes: `tokyonight` (new default), `catppuccin`, `kanagawa`, `gruvbox`, and `classic` (the pre-0.6 look), picked with `-t`/`--theme <name>`, `CCR_THEME`, or the theme picker `ccr --themes` (live preview; `Enter` saves to `~/.config/ccr/theme`, `Ctrl-Y` prints the export line). Precedence: `--theme` > `CCR_THEME` > saved theme > `tokyonight`. Every role (background, text, borders, labels, recency colors, process-pane highlights, …) comes from one palette table per theme; colors render in truecolor when `$COLORTERM` is `truecolor`/`24bit`, and fall back to the nearest xterm-256 color otherwise. An unknown theme name warns on stderr and falls back to `tokyonight`.
- Boxed layout on fzf ≥ 0.58: processes, search, sessions, and preview each sit in their own titled, rounded-border box, themed from the same palette. `--footer` (the key-hint line) needs fzf ≥ 0.63 (otherwise the hints are the last line of the Processes box) and `--gutter` needs ≥ 0.66; older fzf renders the pre-0.6 single-border layout instead (also themed). `CCR_LAYOUT=boxed|classic` forces either one; an unsupported combination warns and falls back, and an unparseable `fzf --version` falls back to `classic` silently.
- Section titles (the boxed layout's Processes / Search / Sessions / Preview labels, the classic border label, the Ctrl-L picker label and the preview blocks' titles) are filled pill badges — the section colour as background, the theme background as bold text — and each preview block has a faint tint of its colour (14% over the theme background). `classic` keeps plain titles and no tints.
- The Preview pane is split into titled blocks (both layouts — ccr draws them itself, so any fzf works) — Session, Artifacts, Files, Last prompt — drawn inside it: two columns when the pane is at least 100 columns wide, stacked otherwise, with CJK-aware widths so the borders line up.

### Changed
- `classic`: the 0.5.0 palette, near-identical (a few preview and process-pane tints, plus chrome text — key hints, the process-pane title, warnings — now share a role), so e.g. the hints render in grey instead of ANSI-dim and the process-pane title is no longer bold.

## [0.5.0] - 2026-10-12

### Added
- Artifacts and files written per session: the preview lists claude.ai artifacts (title, versions, last update, link, local file `✓`/`✗`) and files the session created (`+`) or changed (`~`), from Claude Code's `frame-link` records and `Write` / `Edit` calls and Codex's `FileChange` items. Sessions with any get a `✦` mark, and `Ctrl-L` opens one (browser for artifacts, default app for files; a picker when there are several). Files in temp / scratchpad dirs are skipped; everything is cached with the index.
- `tests/run.sh`: integration tests (57 checks) that run `ccr` / `ccc` under `/bin/bash` against a throwaway fixture with stub `claude`, `codex`, `fzf`, `ps`, `lsof` and `open`.
- `demo/setup.sh` / `demo/teardown.sh`: a fake, self-contained set of Claude Code, Codex, Desktop and expired sessions plus a few real dev servers, for recording demos without showing real sessions (see `demo/README.md`).

### Changed
- The process pane shows `node ./node_modules/.bin/vite --port 5173` as `vite --port 5173` (also for `bun` / `deno`), so the tool and its arguments fit in the column.
- README split into `README.md` (English) and `README.zh-TW.md` (繁體中文) with a language switch; features grouped into sections.
- The banner shows both `ccr` and `ccc` (+ Codex) and the current UI.

## [0.4.0] - 2026-10-01

### Added
- `ccc` (Claude Code + Codex): `bin/ccc` is a symlink to `ccr`; run under that name it also lists OpenAI Codex sessions from `~/.codex/state_*.sqlite` (read-only, columns looked up by name, falling back to the rollout files). `Enter` runs `codex resume`, `Ctrl-F` runs `codex fork`, a leading `claude` / `codex` column lets you filter by typing `^claude` / `^codex`, `Ctrl-A` cycles all / Claude / Codex, and `--last` considers both tools. Subagent, review, MCP and archived threads are skipped; `CODEX_HOME` is honoured. `install.sh` links both commands.

### Changed
- The process pane never lists coding agents themselves (`claude`, `codex`, including `node …/codex` shims) or the MCP servers they start.
- Messages name the command that was run (`ccr:` or `ccc:`).

## [0.3.0] - 2026-10-01

### Added
- A process pane above the session list shows processes still running under any session's directory, busiest first: listening ports (with a `http://localhost:<port>` link) and dev watchers, with CPU, memory and project, highlighted (yellow port, bright command, cyan project, green link, red when a process is at 50%+ CPU). Sessions with something running are marked `⚙`, and resuming one prints its processes first. Uses `ps` + `lsof`, cached for 5 seconds; shells, `claude` itself and the MCP servers it starts are skipped, and `$HOME` / `/` never count as a project.

## [0.2.0] - 2026-10-01

### Added
- Claude Desktop (Cowork) sessions are listed in magenta and open in the CLI as a fork of their transcript, so Desktop's copy is never written to. Override the location with `CCR_DESKTOP_DIR`.
- `Ctrl-X` and `-x`/`--expired` list sessions whose transcripts Claude has already cleaned up (from `~/.claude/history.jsonl`), greyed out with their first prompt. Override the file with `CCR_HISTORY_FILE`.
- The menu header warns when `cleanupPeriodDays` is unset or below 90 days, since Claude deletes idle transcripts after 30 days by default.
- `Ctrl-F` in the menu and `-f`/`--fork` on the command line resume into a new session id via `claude --fork-session`, leaving the original session untouched.
- `-V` / `--version` prints the version.

### Changed
- `--last` / `-n N` only pick CLI sessions, never Desktop or expired ones.
- Session titles now prefer the name set with `/rename` or `claude -n` (`custom-title`, then `agent-name`) over the AI-generated title.
- Index cache file renamed to `index-v2-*` so existing caches are rebuilt with the new titles.

## [0.1.0] - 2026-06-23

Initial release.

### Added
- Cross-project scan of `~/.claude/projects/*/*.jsonl` — every session, every folder.
- `fzf` picker with a live preview pane (AI title, time, working directory, session id, last prompt).
- One-key resume: `Enter` cd's into the project and runs `claude --resume`.
- Mobile Remote Control handoff: `Ctrl-R` resumes with `--remote-control`.
- Quick resume without the menu: `--last` and `-n|--nth <N>`.
- Live sorting by time / title / working directory (`Ctrl-T` / `Ctrl-O` / `Ctrl-G`), plus `-s|--sort`.
- Directory filtering: `ccr .` or `ccr <path>`.
- Print-only mode: `Ctrl-Y` outputs the `cd … && claude --resume …` command without running it.
- Recency-colored, CJK-width-aware aligned columns.
- Bilingual UI (English / 繁體中文), auto-detected from `$LANG`; override with `--lang` or `CCR_LANG`.
- On-disk index cache (`~/.cache/ccr`) keyed by file mtime; unchanged sessions are not re-parsed.
- Scan-path resolution: `CCR_PROJECTS_DIR` → `$CLAUDE_CONFIG_DIR/projects` → `~/.claude/projects`.
- Installer (`install.sh`, with optional `--tip` shell hint), SVG banner + logo, and a bilingual README.

[Unreleased]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.6.1...HEAD
[0.6.1]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kylinfish/coding-agent-console-resume/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kylinfish/coding-agent-console-resume/releases/tag/v0.1.0
