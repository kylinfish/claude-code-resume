#!/usr/bin/env bash
#
# demo/setup.sh — build a fake, self-contained world for recording a ccr / ccc
# demo: Claude Code sessions, Codex threads, Claude Desktop (Cowork) sessions,
# expired sessions, and a few real dev servers / watchers for the process pane.
#
# Nothing touches your real ~/.claude or ~/.codex: everything lives under
# $CCR_DEMO_DIR (default ~/ccr-demo) and is selected through env vars.
#
#   demo/setup.sh            build the data and start the demo processes
#   source ~/ccr-demo/env.sh point ccr / ccc (and fake claude / codex) at it
#   ccr   |   ccc            record away
#   demo/teardown.sh         stop the processes and delete the demo dir
#
set -euo pipefail

DEMO="${CCR_DEMO_DIR:-$HOME/ccr-demo}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -e "$DEMO" ]; then
  echo "demo: $DEMO already exists — run demo/teardown.sh first" >&2
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "demo: python3 is required" >&2; exit 1; }

mkdir -p "$DEMO"/{bin,claude,codex,desktop,cache}
echo "demo: building fake sessions in $DEMO"

# ---------------------------------------------------------------------------
# 1. data: projects, Claude transcripts, history, Desktop, Codex
# ---------------------------------------------------------------------------
python3 - "$DEMO" <<'PY'
import json, os, sqlite3, sys, time, uuid

demo = sys.argv[1]
now = time.time()
M, H, D = 60, 3600, 86400

projects = ["acme-api", "storefront", "payments-svc", "infra",
            "mobile-app", "data-pipeline", "handbook", "roadmap"]
for p in projects:
    os.makedirs(os.path.join(demo, p), exist_ok=True)
def proj(p): return os.path.join(demo, p)

def sid(n): return str(uuid.UUID(int=0x0a1b2c3d4e5f67890000000000000000 + n))

# --- Claude Code sessions --------------------------------------------------
# (project, age, ai-title, custom name or None, first prompt, last prompt)
claude = [
    ("acme-api", 30, "Add JWT auth to the API gateway", None,
     "Add JWT auth to the gateway routes", "extract the token check into middleware"),
    ("storefront", 2*M, "Fix flaky checkout integration test", None,
     "The checkout e2e test fails one run in five", "retry only the payment step, not the whole test"),
    ("payments-svc", 1*H, "重構付款 webhook 處理流程", "webhook-refactor",
     "把 webhook handler 拆成驗簽、去重、處理三段", "補上重送時的 idempotency key 測試"),
    ("infra", 1*D, "Set up the CI release pipeline", None,
     "Build and publish a release when a tag is pushed", "sign the artifacts before uploading"),
    ("mobile-app", 3*D, "Add offline mode to the mobile app", None,
     "Cache the last 50 orders for offline viewing", "show a banner when we're serving cached data"),
    ("data-pipeline", 6*D, "Backfill the orders table", None,
     "Backfill orders from the 2025 export", "run it in batches of 10k with a progress log"),
    ("handbook", 11*D, "Write the onboarding guide", None,
     "Draft a first-week onboarding guide for new engineers", "add a section on our code review norms"),
    ("storefront", 18*D, "優化首頁載入速度", None,
     "首頁 LCP 超過 4 秒，幫我找原因", "把 hero 圖改成 AVIF 並加上 preload"),
]
cfg = os.path.join(demo, "claude")
for i, (p, age, title, custom, first, last) in enumerate(claude):
    s = sid(i + 1)
    cwd = proj(p)
    slug = cwd.replace("/", "-").replace(".", "-")
    d = os.path.join(cfg, "projects", slug)
    os.makedirs(d, exist_ok=True)
    f = os.path.join(d, s + ".jsonl")
    lines = [
        {"type": "user", "sessionId": s, "cwd": cwd, "gitBranch": "main", "version": "2.1.281",
         "message": {"role": "user", "content": first}},
        {"type": "assistant", "sessionId": s, "cwd": cwd,
         "message": {"role": "assistant", "content": [{"type": "text", "text": "On it."}]}},
        {"type": "user", "sessionId": s, "cwd": cwd, "message": {"role": "user", "content": last}},
        {"type": "ai-title", "aiTitle": title, "sessionId": s},
        {"type": "last-prompt", "lastPrompt": last, "sessionId": s},
    ]
    if custom:
        lines.append({"type": "custom-title", "customTitle": custom, "sessionId": s})
    with open(f, "w", encoding="utf-8") as fh:
        fh.write("\n".join(json.dumps(l, ensure_ascii=False) for l in lines) + "\n")
    os.utime(f, (now - age, now - age))

# --- prompt history: the live sessions plus three that Claude cleaned up ----
expired = [
    ("infra", 42*D, "Upgrade the main database to Postgres 16"),
    ("storefront", 55*D, "Spike: edge caching for product pages"),
    ("acme-api", 71*D, "整理 API 錯誤碼與對應的 HTTP status"),
]
hist = []
for i, (p, age, *_rest) in enumerate(claude):
    hist.append({"display": _rest[2], "timestamp": int((now - age) * 1000),
                 "project": proj(p), "sessionId": sid(i + 1)})
for j, (p, age, prompt) in enumerate(expired):
    hist.append({"display": prompt, "timestamp": int((now - age) * 1000),
                 "project": proj(p), "sessionId": sid(100 + j)})
hist.sort(key=lambda h: h["timestamp"])
with open(os.path.join(cfg, "history.jsonl"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(json.dumps(h, ensure_ascii=False) for h in hist) + "\n")

# no cleanupPeriodDays on purpose, so the retention warning shows up
with open(os.path.join(cfg, "settings.json"), "w") as fh:
    json.dump({}, fh)

# --- Claude Desktop (Cowork) sessions ---------------------------------------
desk = os.path.join(demo, "desktop", "demo-account", "demo-org")
cowork = [
    ("Teach the team Claude Desktop features", 1*D, ["handbook"],
     "Show the team what Cowork can do with our handbook folder"),
    ("Draft the Q4 roadmap", 4*D, ["roadmap"],
     "Turn these meeting notes into a Q4 roadmap"),
]
for k, (title, age, folders, prompt) in enumerate(cowork):
    local = f"local_demo{k}"
    cli = sid(200 + k)
    sandbox = os.path.join(desk, local)
    out = os.path.join(sandbox, "outputs")
    tdir = os.path.join(sandbox, ".claude", "projects", out.replace("/", "-"))
    os.makedirs(tdir, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    t = os.path.join(tdir, cli + ".jsonl")
    with open(t, "w", encoding="utf-8") as fh:
        for l in [{"type": "user", "sessionId": cli, "cwd": out, "entrypoint": "local-agent",
                   "message": {"role": "user", "content": prompt}},
                  {"type": "ai-title", "aiTitle": title, "sessionId": cli},
                  {"type": "last-prompt", "lastPrompt": prompt, "sessionId": cli}]:
            fh.write(json.dumps(l, ensure_ascii=False) + "\n")
    os.utime(t, (now - age, now - age))
    with open(os.path.join(desk, local + ".json"), "w", encoding="utf-8") as fh:
        json.dump({"sessionId": local, "cliSessionId": cli, "title": title,
                   "cwd": sandbox, "userSelectedFolders": [proj(f) for f in folders],
                   "createdAt": int((now - age - H) * 1000), "lastActivityAt": int((now - age) * 1000),
                   "isArchived": False, "initialMessage": prompt}, fh, ensure_ascii=False)

# --- Codex threads (state_5.sqlite, the same shape Codex uses) ---------------
codex = [
    ("acme-api", 9*M, "Fix the rate limiter", "feat/rate-limit", "gpt-5.5-codex", 184_220, "cli"),
    ("payments-svc", 5*H, "Migrate payments to Stripe API v2", "chore/stripe-v2", "gpt-5.5-codex", 912_400, "cli"),
    ("infra", 2*D, "為 CLI 加上 --json 輸出", "main", "gpt-5.5", 61_310, "cli"),
    ("storefront", 8*D, "Review the GraphQL schema", "main", "gpt-5.5", 240_015, "vscode"),
    ("acme-api", 1*H, "", "feat/rate-limit", "gpt-5.5-codex", 3_100, '{"subagent":"review"}'),
]
db = sqlite3.connect(os.path.join(demo, "codex", "state_5.sqlite"))
db.execute("""create table threads (id text primary key, rollout_path text, created_at integer,
  updated_at integer, updated_at_ms integer, source text, cwd text, title text, preview text,
  first_user_message text, name text, git_branch text, model text, tokens_used integer,
  archived integer default 0)""")
for n, (p, age, name, branch, model, tokens, source) in enumerate(codex):
    upd = int(now - age)
    db.execute("insert into threads values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,0)",
               (str(uuid.UUID(int=0x019e0000000070000000000000000000 + n)), "", upd - H, upd, upd * 1000,
                source, proj(p), name, name, name, name, branch, model, tokens))
db.commit(); db.close()
print(f"demo: {len(claude)} Claude, {len(codex) - 1} Codex, {len(cowork)} Desktop, {len(expired)} expired sessions")
PY

# ---------------------------------------------------------------------------
# 2. fake claude / codex so pressing Enter during the recording is harmless
# ---------------------------------------------------------------------------
for tool in claude codex; do
  cat > "$DEMO/bin/$tool" <<EOF
#!/bin/sh
printf '\\n  \\033[1;32m✔ (demo)\\033[0m would now run: \\033[1m$tool %s\\033[0m\\n  in %s\\n\\n' "\$*" "\$(pwd)"
EOF
  chmod +x "$DEMO/bin/$tool"
done

cat > "$DEMO/env.sh" <<EOF
# source this file before recording: points ccr / ccc at the demo data
export CLAUDE_CONFIG_DIR="$DEMO/claude"
export CODEX_HOME="$DEMO/codex"
export CCR_DESKTOP_DIR="$DEMO/desktop"
export CCR_CACHE="$DEMO/cache"
export PATH="$DEMO/bin:$HERE/../bin:\$PATH"
EOF

# ---------------------------------------------------------------------------
# 3. demo processes for the process pane (real, but harmless)
# ---------------------------------------------------------------------------
free_port() {  # free_port <preferred> -> first free port from there
  local p="$1"
  while lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; do p=$((p + 1)); done
  echo "$p"
}

start() {  # start <project> <cmd...> — run in the project dir, remember the PID
  local dir="$DEMO/$1"; shift
  # exec so the recorded PID is the server itself, and detach every std fd so
  # nothing keeps this script's stdout pipe open
  ( cd "$dir" && exec nohup "$@" </dev/null >/dev/null 2>&1 ) &
  echo $! >> "$DEMO/pids"
}

if command -v node >/dev/null 2>&1; then
  # node "bins" so the pane shows `node ./node_modules/.bin/vite` like a real project
  bin_script() {  # bin_script <project> <name> <js>
    mkdir -p "$DEMO/$1/node_modules/.bin"
    printf '#!/usr/bin/env node\n%s\n' "$3" > "$DEMO/$1/node_modules/.bin/$2"
    chmod +x "$DEMO/$1/node_modules/.bin/$2"
  }
  SERVE='const p=+process.argv[process.argv.indexOf("--port")+1];require("http").createServer((q,r)=>r.end("demo "+p+"\n")).listen(p,"127.0.0.1")'
  IDLE='setInterval(()=>{},1<<30)'
  # ~60% of one core, so the pane shows a red CPU figure
  BUSY='setInterval(()=>{const t=Date.now();while(Date.now()-t<60);},100)'
  bin_script acme-api vite "$SERVE";   start acme-api ./node_modules/.bin/vite --port "$(free_port 5173)"
  bin_script acme-api tsc "$IDLE";     start acme-api ./node_modules/.bin/tsc --watch
  bin_script storefront next "$SERVE"; start storefront ./node_modules/.bin/next dev --port "$(free_port 3000)"
  bin_script payments-svc webpack "$BUSY"; start payments-svc ./node_modules/.bin/webpack --watch
else
  echo "demo: node not found — starting only the python demo server"
fi
start data-pipeline python3 -m http.server "$(free_port 8000)" --bind 127.0.0.1

sleep 1
echo "demo: started $(wc -l < "$DEMO/pids" | tr -d ' ') demo processes"
echo
echo "next:"
echo "  source $DEMO/env.sh"
echo "  ccr        # or: ccc"
echo "  $HERE/teardown.sh   # when you're done"
