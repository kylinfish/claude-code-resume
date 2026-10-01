<p align="center">
  <img src="assets/banner.svg" width="860" alt="ccr / ccc：Claude Code Resume，支援 Codex">
</p>

<p align="center">
  <code>ccr</code>：跨專案搜尋並 resume Claude Code session 的模糊搜尋選單。<br>
  <code>ccc</code>：同一個選單，再加上 OpenAI Codex 的 session。
</p>

<p align="center">
  <a href="README.md">English</a> · <b>繁體中文</b>
</p>

---

`ccr` 讓你在一個模糊搜尋選單裡瀏覽**所有專案、所有 Claude Code 歷史對話**，
看到每個 session 的摘要預覽，選定後自動 `cd` 到該專案目錄並 `claude --resume`，
不必再手動記哪段對話在哪個資料夾。

除了 CLI 本身的 session，也會列出 **Claude Desktop（Cowork）** 的對話與已被 Claude
**清理**的 session，顯示 **agent 留在背景的 port 與 watcher**，並可一鍵開啟**手機遠端控制**。
用 **`ccc`** 可以把 **Claude Code + Codex** 放在同一個列表。

<p align="center">
  <img src="assets/demo.gif" width="820" alt="ccr 操作示範：模糊搜尋、預覽、resume">
</p>

```
⚙ 背後正在跑的 process（所有 session 專案，依 CPU 排序）
  :5173   PID 4242    12.5% CPU   200 MB  vite                        ~/code/acme-api  → http://localhost:5173
  -       PID 6060     1.0% CPU    80 MB  tsc --watch                 ~/code/acme-api
────────────────────────────────────────────────────────────────────────
Enter 開啟  ^R +手機遠端  ^F 分支  ^Y 只印指令  │  排序 ^T 時間 ^O 標題 ^G 目錄  │  Esc 取消
^X 顯示／隱藏已清理的 session  │  Desktop 對話以 fork 在 CLI 開啟
[time] ❯
     剛剛 │ ⚙ Add JWT auth to the API gateway          │ ~/code/acme-api
 2 分鐘前 │   修 checkout 不穩定的整合測試             │ ~/code/storefront
   1 天前 │   教團隊用 Claude Desktop                  │ Desktop · ~/code/handbook
  11 天前 │   建立 CI release pipeline                 │ ~/code/infra
```

> **0.4 新功能**：`ccc` 同時列出 Claude Code 與 Codex 的 session。
> 0.3 加入 process 區，0.2 加入 Desktop／已清理的 session 與分支續接。
> 詳見 [版本紀錄](#版本紀錄)。

## 功能

- [Session](#session)：列表裡會出現什麼
- [Resume](#resume)：選定之後會做什麼
- [Process 區](#process-區)：session 留在背景的 process
- [Codex（`ccc`）](#codexccc)：Claude Code 與 Codex 放在同一個列表
- [日常使用](#日常使用)：排序、顏色、語言、速度

### Session

| 功能 | 說明 |
| ---- | ---- |
| 跨專案掃描 | 掃 `~/.claude/projects/*/*.jsonl` 全部 session |
| 你取的名字優先 | 標題優先用 `/rename`、`claude -n` 取的名字，其次是 AI 標題、舊版 `summary`、第一句 prompt |
| Desktop 對話 | Claude Desktop 的 Cowork 對話以洋紅色顯示（`Desktop · <資料夾>`），以 `--fork-session` 在 CLI 開啟，Desktop 原對話不受影響 |
| 已清理的 session | Claude 會刪除超過 `cleanupPeriodDays`（預設 30 天）沒活動的對話；`Ctrl-X`／`ccr --expired` 以灰色列出仍留在 prompt 歷史裡的 session 和第一句 prompt，但無法 resume |
| 保留天數提醒 | `cleanupPeriodDays` 沒設定或小於 90 天時，選單標頭會提醒 |
| 預覽 | 標題、時間、工作目錄、session id、最後一次 prompt |

### Resume

| 功能 | 說明 |
| ---- | ---- |
| 一鍵 resume | `Enter` 直接切目錄並 `claude --resume` |
| 分支續接 | `Ctrl-F`（或 `ccr --fork`）以 `--fork-session` 開新 session id，原對話不受影響 |
| 手機接手 | `Ctrl-R` 加 `--remote-control`，用 Claude 手機 app／網頁繼續 |
| 快速 resume | `ccr --last`／`ccr -n N` 不開選單直接續 |
| 只印指令 | `Ctrl-Y` 印出 `cd … && claude --resume …`，不執行 |

### Process 區

| 功能 | 說明 |
| ---- | ---- |
| 背後還在跑什麼 | 列表上方獨立一區，依 CPU 排序列出所有 session 目錄底下還在跑的 process：agent 開來 demo 的 port（附 `http://localhost:<port>`）和 `tsc --watch` 這類 watcher，含 CPU、記憶體與所屬專案 |
| 高亮 | port 黃色、指令亮白、專案青色、連結綠色，CPU 達 50% 以上顯示紅色 |
| 標記 session | 有 process 的 session 標 `⚙`，resume 前也會印出 |
| 不列雜訊 | 不列 shell、coding agent 本身（`claude`、`codex`）與它們啟動的 MCP server；同一個 process tree 只列一筆 |

### Codex（`ccc`）

| 功能 | 說明 |
| ---- | ---- |
| 一個列表看兩種工具 | Claude Code 與 Codex 的 session 放在一起排序 |
| 工具欄篩選 | 最前面一欄是 `claude`／`codex`，搜尋時輸入 `^codex`、`^claude` 就能篩選；`Ctrl-A` 切換來源 |

完整說明見下方 [`ccc`：Claude Code + Codex](#cccclaude-code--codex)。

### 日常使用

| 功能 | 說明 |
| ---- | ---- |
| 即時排序 | 時間／標題／目錄，選單內直接切換 |
| 彩色 + 對齊 | 時間依新舊上色，正確計算全形字寬度，中英混排也對齊 |
| 中英雙語 | 依 `$LANG` 自動偵測，可用 `--lang` 或 `CCR_LANG` 覆寫 |
| 快取加速 | 依檔案修改時間快取索引，沒變動的 session 不重複解析 |
| 零設定 | 單一 Bash 腳本，無背景程式 |

## 需求

- `bash`（3.2+，macOS 內建版本即可）
- [`fzf`](https://github.com/junegunn/fzf)
- `python3`
- `claude` CLI（實際 resume 時需要）
- `lsof`（選用，macOS 內建，用於 process 區）
- [`codex`](https://github.com/openai/codex) CLI（選用，只有用 `ccc` resume Codex session 時需要）

## 安裝

```sh
git clone https://github.com/kylinfish/claude-code-resume.git
cd claude-code-resume
./install.sh          # 連結 bin/ccr 與 bin/ccc 到 ~/.local/bin
./install.sh --tip    # 另外在 shell 啟動時加一行提示
```

也可以直接把 `bin/ccr` 放到任何 `PATH` 目錄下（有用 Codex 的話再建一個指向它的 `ccc` symlink）。

## 用法

| 指令 | 作用 |
| ---- | ---- |
| `ccr` | 列出所有 session，最新在上 |
| `ccr .` | 只看當前目錄（含子目錄）的 session |
| `ccr <path>` | 只看指定目錄（含子目錄）的 session |
| `ccr --last` | 不開選單，直接續最近一個 session |
| `ccr -n N` | 不開選單，直接續第 N 新的 session |
| `ccr --last --fork` | 把最近一個 session 分支成新的 session id |
| `ccr --expired` | 一併列出已被 Claude 清理的 session |
| `ccr -s title` | 依標題排序（`time`｜`title`｜`dir`） |
| `ccr --lang zh` | 強制中文介面（預設依 `$LANG` 自動偵測） |
| `ccr --version` | 顯示版本 |
| `ccr --help` | 顯示說明 |

### 選單內快捷鍵

| 按鍵 | 行為 |
| ---- | ---- |
| `Enter` | 開啟選定的 session |
| `Ctrl-R` | 開啟 **+ 手機遠端控制**（`--remote-control`） |
| `Ctrl-F` | 分支：以新的 session id 續接（`--fork-session`） |
| `Ctrl-Y` | 只印出 `cd … && claude --resume …` 指令，不執行 |
| `Ctrl-X` | 顯示／隱藏已清理的 session |
| `Ctrl-A` | 僅 `ccc`：來源切換，全部 → Claude → Codex |
| `Ctrl-T` | 依時間排序 |
| `Ctrl-O` | 依標題排序 |
| `Ctrl-G` | 依工作目錄排序 |
| `Esc` | 取消 |

> 手機遠端控制需 Claude Pro/Max/Team/Enterprise 訂閱，且本機需持續開著並連網
>（手機只是視窗，運算仍跑在你電腦）。

## `ccc`：Claude Code + Codex

`ccr` 只看 Claude Code。`ccc` 是同一支腳本換個名字執行：`ccr` 的所有功能，再加上
[OpenAI Codex](https://github.com/openai/codex) 的 session，放在同一個列表。

```sh
ccc                      # Claude Code + Codex 的 session，最新在上
ccc --last               # 續兩邊之中最近的一個 session
ccc --version            # ccc 0.4.0
```

```
codex  │   9 分鐘前 │   修 rate limiter                          │ ~/code/acme-api
claude │       剛剛 │ ⚙ Add JWT auth to the API gateway          │ ~/code/acme-api
claude │     1 天前 │   教團隊用 Claude Desktop                  │ Desktop · ~/code/handbook
```

| 項目 | 說明 |
| ---- | ---- |
| 工具欄 | 列表最前面一欄是 `claude` 或 `codex`；因為在行首，搜尋時輸入 `^codex` 或 `^claude` 就能依工具篩選（Desktop 與已清理的 session 算 `claude`）。Codex 的預覽顯示 branch、model、token 用量 |
| 動作 | `Enter` 執行 `codex resume <id>`，`Ctrl-F` 執行 `codex fork <id>`，`Ctrl-Y` 印出指令；Codex 沒有 Remote Control，`Ctrl-R` 會提示並取消 |
| 來源切換 | `Ctrl-A`：全部 → Claude → Codex |
| 過濾 | 只列互動式 thread（`cli`／`vscode` 來源、未封存），不列 subagent、review、MCP thread |
| 資料來源 | 以唯讀方式讀 `~/.codex/state_*.sqlite`；這是 Codex 內部、會改版的格式，所以依欄位名稱讀取，讀不到時改讀 `~/.codex/sessions/**/rollout-*.jsonl`；可用 `CODEX_HOME` 指定其他位置 |
| Process 區 | 也涵蓋 Codex 專案，且不會列出 `codex` 本身與它啟動的 MCP server |

## 環境變數

| 變數 | 用途 |
| ---- | ---- |
| `CCR_LANG` | `zh` 或 `en`，覆寫介面語言 |
| `CCR_PROJECTS_DIR` | 直接覆寫掃描路徑 |
| `CLAUDE_CONFIG_DIR` | Claude 設定目錄；`ccr` 會掃 `$CLAUDE_CONFIG_DIR/projects` |
| `CCR_CACHE` | 覆寫索引快取目錄（預設 `~/.cache/ccr`） |
| `CCR_DESKTOP_DIR` | 覆寫 Claude Desktop Cowork 對話的路徑 |
| `CCR_HISTORY_FILE` | 覆寫 prompt 歷史檔（預設 `~/.claude/history.jsonl`） |
| `CODEX_HOME` | `ccc`：Codex 的目錄（預設 `~/.codex`） |
| `CCR_CODEX` | 設為 `1` 時，以 `ccr` 執行也會列出 Codex session |

> 掃描路徑優先序：`CCR_PROJECTS_DIR` → `$CLAUDE_CONFIG_DIR/projects` → `~/.claude/projects`。

## 運作原理

- **CLI session**：每個 Claude Code session 是 `~/.claude/projects/<slug>/` 底下的一個 `.jsonl`。`ccr` 讀出標題（你 `/rename` 的名字優先，其次 `ai-title`、`summary`、第一句 prompt）、最後一句 prompt、工作目錄與修改時間，交給 `fzf` 顯示；選定後執行 `cd "$cwd" && claude --resume "$sessionId"`。
- **Desktop 對話**：Cowork 對話在 `~/Library/Application Support/Claude/local-agent-mode-sessions/`，`local_<id>.json` 存標題、最後活動時間與授權資料夾，旁邊的沙盒資料夾存對話紀錄。`ccr` 以對話檔路徑加 `--fork-session` 開啟，新對話存成一般 CLI session，Desktop 的原檔不會被寫入。
- **已清理的 session**：Claude Code 預設會刪除 30 天沒活動的對話紀錄，但 prompt 仍留在 `~/.claude/history.jsonl`，已清理的列就是從這裡來的。想保留更久，在 `~/.claude/settings.json` 加上：

  ```json
  { "cleanupPeriodDays": 365 }
  ```

- **Process 區**：一次 `ps`，加上 `lsof` 取得 listen 的 TCP port 與工作目錄，快取 5 秒。有 listen port 或執行已知開發指令（vite、next、tsc、nodemon、python…），且工作目錄在某個 session 目錄底下的 process 才會列出（以最深的目錄為準；`$HOME` 與 `/` 不算）。不列 shell、coding agent 與它們啟動的 MCP server，同一個 process tree 只留一筆，有 port 的優先。
- **排序與快取**：排序在掃描時完成，選單內切換排序只是重新載入列表。依檔案修改時間快取索引（`~/.cache/ccr`），沒變動的 session 不重複解析，數百個 session 也能快速啟動。

## 版本紀錄

| 版本 | 重點 |
| ---- | ---- |
| [0.4.0](docs/releases/v0.4.0.md) | `ccc`：Claude Code 與 Codex 的 session 放在同一個選單，含 `claude`／`codex` 工具欄與 `Ctrl-A` 來源切換 |
| [0.3.0](docs/releases/v0.3.0.md) | Process 區：列出 session 專案底下仍在跑的 port 與 watcher，高亮顯示並以 `⚙` 標記 session |
| [0.2.0](docs/releases/v0.2.0.md) | 不只 CLI：Claude Desktop 與已清理的 session、保留天數提醒、`/rename` 標題、分支續接、`--version` |
| 0.1.0 | 初版 |

完整內容請見 [CHANGELOG](CHANGELOG.md)（英文）。

## 授權

[MIT](./LICENSE) © 2026 kylinfish
