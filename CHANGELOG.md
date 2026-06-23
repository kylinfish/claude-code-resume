# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/kylinfish/claude-code-resume/releases/tag/v0.1.0
