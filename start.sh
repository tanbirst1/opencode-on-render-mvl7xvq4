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
log "proxy=${OPENCODE_LLM_PROXY_HOST}:${OPENCODE_LLM_PROXY_PORT} server=127.0.0.1:${SERVER_PORT} plugin=$(ls -1 "$PLUGIN_DIR")"

opencode serve --hostname 127.0.0.1 --port "$SERVER_PORT" --print-logs --log-level DEBUG &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' TERM INT

# OpenCode loads plugins lazily, on the first session. Create one so the proxy
# binds $PORT before Render's port scan gives up and fails the deploy.
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${SERVER_PORT}/global/health" >/dev/null 2>&1; then
    log "server healthy after ${i}s"
    break
  fi
  sleep 1
done
curl -s -o /dev/null -w '[start] session POST -> %{http_code}\n' \
  -X POST "http://127.0.0.1:${SERVER_PORT}/session" \
  -H 'Content-Type: application/json' -d '{}' >&2 || true
sleep 3
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${OPENCODE_LLM_PROXY_TOKEN}" \
  "http://127.0.0.1:${OPENCODE_LLM_PROXY_PORT}/v1/models" || true)
log "proxy probe -> ${code}"

wait "$SERVER_PID"
