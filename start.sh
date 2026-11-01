#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-/root/.config}/opencode"
PLUGIN_DIR="$CONFIG_DIR/plugins"
mkdir -p "$PLUGIN_DIR"

# Load the proxy from its prebuilt, self-contained bundle as a local plugin.
# OpenCode resolves npm-named plugins with Bun, which this image does not ship.
NPM_ROOT="$(npm root -g)"
BUNDLE="$NPM_ROOT/opencode-llm-proxy/dist/llm-proxy.js"
echo "[start] config_dir=$CONFIG_DIR bundle=$BUNDLE"
if [ ! -f "$BUNDLE" ]; then
  echo "[start] proxy bundle not found at $BUNDLE" >&2
  exit 1
fi
cp "$BUNDLE" "$PLUGIN_DIR/llm-proxy.js"
ls -la "$PLUGIN_DIR"

printf '%s\n' '{ "$schema": "https://opencode.ai/config.json" }' > "$CONFIG_DIR/opencode.json"

if [ -z "${OPENCODE_LLM_PROXY_TOKEN:-}" ]; then
  echo "[start] OPENCODE_LLM_PROXY_TOKEN is required: the proxy refuses to bind beyond loopback without one." >&2
  exit 1
fi

export OPENCODE_LLM_PROXY_HOST="${OPENCODE_LLM_PROXY_HOST:-0.0.0.0}"
export OPENCODE_LLM_PROXY_PORT="${PORT:-4010}"
SERVER_PORT="${OPENCODE_SERVER_PORT:-4096}"
echo "[start] proxy_port=$OPENCODE_LLM_PROXY_PORT server_port=$SERVER_PORT host=$OPENCODE_LLM_PROXY_HOST"

# OpenCode loads plugins lazily, on the first session. Create one so the proxy
# binds $PORT before Render's port scan gives up and fails the deploy.
(
  for i in $(seq 1 150); do
    if curl -fsS "http://127.0.0.1:${SERVER_PORT}/global/health" >/dev/null 2>&1; then
      echo "[warmup] server healthy after ${i}s"
      code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
        "http://127.0.0.1:${SERVER_PORT}/session" \
        -H 'Content-Type: application/json' -d '{}' || true)
      echo "[warmup] session POST -> ${code}"
      break
    fi
    sleep 1
  done
  for i in $(seq 1 60); do
    if curl -s -o /dev/null "http://127.0.0.1:${OPENCODE_LLM_PROXY_PORT}/v1/models" \
        -H "Authorization: Bearer ${OPENCODE_LLM_PROXY_TOKEN}"; then
      echo "[warmup] proxy reachable after ${i}s"
      exit 0
    fi
    sleep 1
  done
  echo "[warmup] proxy never came up"
) &

exec opencode serve --hostname 127.0.0.1 --port "$SERVER_PORT"
