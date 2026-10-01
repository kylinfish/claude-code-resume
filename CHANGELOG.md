# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/kylinfish/claude-code-resume/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/kylinfish/claude-code-resume/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kylinfish/claude-code-resume/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kylinfish/claude-code-resume/releases/tag/v0.1.0
