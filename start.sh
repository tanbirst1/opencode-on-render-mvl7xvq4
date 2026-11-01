#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-/root/.config}/opencode"
PLUGIN_DIR="$CONFIG_DIR/plugins"
mkdir -p "$PLUGIN_DIR"

# Load the proxy from its prebuilt, self-contained bundle as a local plugin.
# OpenCode resolves npm-named plugins with Bun, which this image does not ship.
NPM_ROOT="$(npm root -g)"
BUNDLE="$NPM_ROOT/opencode-llm-proxy/dist/llm-proxy.js"
if [ ! -f "$BUNDLE" ]; then
  echo "Proxy bundle not found at $BUNDLE" >&2
  exit 1
fi
cp "$BUNDLE" "$PLUGIN_DIR/llm-proxy.js"

printf '%s\n' '{ "$schema": "https://opencode.ai/config.json" }' > "$CONFIG_DIR/opencode.json"

if [ -z "${OPENCODE_LLM_PROXY_TOKEN:-}" ]; then
  echo "OPENCODE_LLM_PROXY_TOKEN is required: the proxy refuses to bind beyond loopback without one." >&2
  exit 1
fi

export OPENCODE_LLM_PROXY_HOST="${OPENCODE_LLM_PROXY_HOST:-0.0.0.0}"
export OPENCODE_LLM_PROXY_PORT="${PORT:-4010}"
SERVER_PORT="${OPENCODE_SERVER_PORT:-4096}"

# OpenCode loads plugins lazily, on the first session. Create one so the proxy
# binds $PORT before Render's port scan gives up and fails the deploy.
(
  for _ in $(seq 1 120); do
    if curl -fsS "http://127.0.0.1:${SERVER_PORT}/global/health" >/dev/null 2>&1; then
      curl -fsS -X POST "http://127.0.0.1:${SERVER_PORT}/session" \
        -H 'Content-Type: application/json' -d '{}' >/dev/null 2>&1 || true
      break
    fi
    sleep 1
  done
) &

exec opencode serve --hostname 127.0.0.1 --port "$SERVER_PORT"
