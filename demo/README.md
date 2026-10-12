# Demo data for recording

`setup.sh` builds a fake, self-contained world so you can record `ccr` / `ccc`
without showing your real sessions. Nothing touches `~/.claude` or `~/.codex`:
everything lives in `~/ccr-demo` (override with `CCR_DEMO_DIR`) and is picked up
through environment variables.

```sh
demo/setup.sh                 # build the data, start the demo processes (~2 s)
source ~/ccr-demo/env.sh      # point ccr / ccc and a fake claude / codex at it
ccc                           # record
demo/teardown.sh              # stop the processes, delete ~/ccr-demo
```

Open a new terminal after `teardown.sh` (or `unset CLAUDE_CONFIG_DIR CODEX_HOME
CCR_DESKTOP_DIR CCR_CACHE`) to get your real sessions back.

Use `CCR_THEME=catppuccin ccc` (or `--theme`) to record another theme; the
boxed layout needs fzf ≥ 0.58.

## What's in it

| Kind | Count | Notes |
| ---- | ----- | ----- |
| Claude Code sessions | 8 | 7 projects, from "just now" to 18 days ago; English and Chinese titles; one renamed with `/rename` (`webhook-refactor`) |
| Codex threads | 4 | branch, model and token count in the preview; one hidden subagent thread |
| Claude Desktop (Cowork) | 2 | magenta `Desktop · <folder>` rows |
| Expired sessions | 3 | only in the prompt history; shown with `Ctrl-X` |
| Artifacts & files | 2 artifacts, 12 files | on 3 Claude sessions and 2 Codex threads (`✦`); one file is missing on purpose so a `✗` shows |
| Demo processes | 5 | `vite :5173`, `next dev :3000`, `python -m http.server :8000`, `tsc --watch`, and a `webpack --watch` that uses ~60% of a core so the CPU shows in red |

`cleanupPeriodDays` is left unset on purpose, so the retention warning appears in
the header. `claude` and `codex` are replaced by stubs that only print what they
would run, so pressing `Enter` ends the recording cleanly. The demo processes need
`node` (the python server works without it); ports move up if 5173 / 3000 / 8000
are taken.

## Suggested recording (~40 s)

1. `ccr` — the process pane on top, `⚙` marks, the red `webpack` CPU.
2. Type `jwt` — fuzzy search narrows to the gateway session; read the preview.
3. `Ctrl-X` — expired sessions appear greyed out at the bottom; `Ctrl-X` again.
4. `Ctrl-T` / `Ctrl-O` / `Ctrl-G` — sort by time, title, directory.
5. `Esc`, then `ccc` — the `claude` / `codex` column.
6. Type `^codex` — only Codex threads; clear it, `Ctrl-A` to cycle sources.
7. Highlight `Add JWT auth to the API gateway` — the preview lists its artifact and
   files written; press `Ctrl-L` to pick one to open.
8. Run `ccc` again, pick the same session and press `Enter` — the processes still
   running in that project are printed, then the (stub) resume command.

---

# 錄影用的 demo 資料

`setup.sh` 會建立一組假的、獨立的資料，讓你錄 `ccr`／`ccc` 時不會露出真正的 session。
不會動到 `~/.claude` 或 `~/.codex`：所有東西都放在 `~/ccr-demo`（可用 `CCR_DEMO_DIR` 改位置），
透過環境變數讀取。

1. `demo/setup.sh`：建立資料並啟動 demo process，約 2 秒。
2. `source ~/ccr-demo/env.sh`：讓 `ccr`／`ccc` 與假的 `claude`／`codex` 指向 demo 資料。
3. 執行 `ccc` 開始錄影，可照上方「Suggested recording」的 8 個步驟操作。
4. `demo/teardown.sh`：關掉 demo process 並刪除 `~/ccr-demo`；之後開新的終端機，就會回到你真正的 session。

用 `CCR_THEME=catppuccin ccc`（或 `--theme`）可以錄另一種主題；分框版面需要 fzf ≥ 0.58。
