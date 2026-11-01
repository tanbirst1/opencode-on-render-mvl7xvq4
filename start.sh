#!/usr/bin/env bash
set -euo pipefail

log() { echo "[start] $*" >&2; }

CONFIG_DIR="${XDG_CONFIG_HOME:-/root/.config}/opencode"
PLUGIN_DIR="$CONFIG_DIR/plugins"
mkdir -p "$PLUGIN_DIR"

# Load the proxy from its prebuilt, self-contained bundle as a local plugin.
# OpenCode resolves npm-named plugins with Bun, which this image does not ship.
BUNDLE="$(npm root -g)/opencode-llm-proxy/dist/llm-proxy.js"
if [ ! -f "$BUNDLE" ]; then
  log "proxy bundle not found at $BUNDLE"
  exit 1
fi
cp "$BUNDLE" "$PLUGIN_DIR/llm-proxy.js"
printf '%s\n' '{ "$schema": "https://opencode.ai/config.json" }' > "$CONFIG_DIR/opencode.json"

if [ -z "${OPENCODE_LLM_PROXY_TOKEN:-}" ]; then
  log "OPENCODE_LLM_PROXY_TOKEN is required: the proxy refuses to bind beyond loopback without one."
  exit 1
fi

export OPENCODE_LLM_PROXY_HOST="${OPENCODE_LLM_PROXY_HOST:-0.0.0.0}"
export OPENCODE_LLM_PROXY_PORT="${PORT:-4010}"
SERVER_PORT="${OPENCODE_SERVER_PORT:-4096}"
log "proxy=${OPENCODE_LLM_PROXY_HOST}:${OPENCODE_LLM_PROXY_PORT} server=${SERVER_PORT}"

opencode serve --hostname 127.0.0.1 --port "$SERVER_PORT" --print-logs --log-level DEBUG &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' TERM INT

# OpenCode loads plugins lazily, on the first session. Create one so the proxy
# binds $PORT before Render's port scan gives up and fails the deploy.
node - "$SERVER_PORT" "$OPENCODE_LLM_PROXY_PORT" "$OPENCODE_LLM_PROXY_TOKEN" <<'NODE' >&2 || true
const [serverPort, proxyPort, token] = process.argv.slice(2)
const user = process.env.OPENCODE_SERVER_USERNAME || "opencode"
const pass = process.env.OPENCODE_SERVER_PASSWORD || ""
const auth = pass ? { authorization: `Basic ${Buffer.from(`${user}:${pass}`).toString("base64")}` } : {}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
async function hit(url, opts = {}, timeoutMs = 5000) {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    return (await fetch(url, { ...opts, signal: ctrl.signal })).status
  } catch {
    return 0
  } finally {
    clearTimeout(timer)
  }
}
;(async () => {
  let health = 0
  for (let i = 0; i < 90; i++) {
    health = await hit(`http://127.0.0.1:${serverPort}/global/health`, { headers: auth })
    if (health === 200) {
      console.log(`[warmup] server healthy after ${i}s`)
      break
    }
    await sleep(1000)
  }
  if (health !== 200) {
    console.log(`[warmup] server never became healthy (last status ${health})`)
    return
  }
  const session = await hit(
    `http://127.0.0.1:${serverPort}/session`,
    { method: "POST", headers: { "content-type": "application/json", ...auth }, body: "{}" },
    30000,
  )
  console.log(`[warmup] session POST -> ${session}`)
  for (let i = 0; i < 60; i++) {
    const status = await hit(`http://127.0.0.1:${proxyPort}/v1/models`, {
      headers: { authorization: `Bearer ${token}` },
    })
    if (status !== 0) {
      console.log(`[warmup] proxy reachable after ${i}s -> ${status}`)
      return
    }
    await sleep(1000)
  }
  console.log("[warmup] proxy never came up")
})()
NODE

wait "$SERVER_PID"
