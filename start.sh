#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-/root/.config}/opencode"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-llm-proxy"]
}
JSON

if [ -z "${OPENCODE_LLM_PROXY_TOKEN:-}" ]; then
  echo "OPENCODE_LLM_PROXY_TOKEN is required: the proxy refuses to bind beyond loopback without one." >&2
  exit 1
fi

export OPENCODE_LLM_PROXY_HOST="${OPENCODE_LLM_PROXY_HOST:-0.0.0.0}"
export OPENCODE_LLM_PROXY_PORT="${PORT:-4010}"

# `opencode serve` hosts the plugin; the plugin itself opens the proxy on $PORT,
# so Render's public traffic reaches the proxy and never the server API.
exec opencode serve --hostname 127.0.0.1 --port "${OPENCODE_SERVER_PORT:-4096}"
