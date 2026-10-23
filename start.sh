#!/usr/bin/env bash
set -euo pipefail

export XDG_DATA_HOME="${XDG_DATA_HOME:-/root/project-data}"

WORKSPACE_DIR="${WORKSPACE_DIR:-/root/project-data/workspace}"
OPENCODE_SERVER_COMMAND="${OPENCODE_SERVER_COMMAND:-web}"
OPENCODE_DATA_DIR="${XDG_DATA_HOME}/opencode"
OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-/root/.config}/opencode"
AUTH_FILE="${OPENCODE_DATA_DIR}/auth.json"
GLOBAL_CONFIG_FILE="${OPENCODE_CONFIG_DIR}/opencode.json"

mkdir -p "$WORKSPACE_DIR" "$OPENCODE_DATA_DIR" "$OPENCODE_CONFIG_DIR"

directory_is_empty() {
  [ -z "$(ls -A "$1" 2>/dev/null)" ]
}

normalize_repo_url() {
  case "$1" in
    git@github.com:*)
      printf 'https://github.com/%s\n' "${1#git@github.com:}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

clone_repo() {
  local repo_url
  repo_url="$(normalize_repo_url "$REPO_URL")"

  local askpass=""
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    askpass="$(mktemp)"
    cat > "$askpass" <<'ASKPASS'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf 'x-access-token\n' ;;
  *Password*) printf '%s\n' "$GITHUB_TOKEN" ;;
  *) printf '\n' ;;
esac
ASKPASS
    chmod 700 "$askpass"
    export GIT_ASKPASS="$askpass"
    export GIT_TERMINAL_PROMPT=0
  fi

  if [ -n "${REPO_BRANCH:-}" ]; then
    git clone --depth 1 --branch "$REPO_BRANCH" "$repo_url" "$WORKSPACE_DIR"
  else
    git clone --depth 1 "$repo_url" "$WORKSPACE_DIR"
  fi

  if [ -n "$askpass" ]; then
    rm -f "$askpass"
  fi
}

configure_git_defaults() {
  git config --global user.name "${GIT_AUTHOR_NAME:-opencode on Render}"
  git config --global user.email "${GIT_AUTHOR_EMAIL:-opencode@render.example}"
  git config --global --add safe.directory "$WORKSPACE_DIR"
}

ensure_workspace_project() {
  if directory_is_empty "$WORKSPACE_DIR"; then
    cat > "$WORKSPACE_DIR/README.md" <<'MD'
# opencode workspace

This is the persisted workspace for your hosted opencode agent.

Clone a repo here, create files from scratch, or redeploy with `REPO_URL` set.
MD

    cat > "$WORKSPACE_DIR/AGENTS.md" <<'MD'
# Agent notes

Work in this directory. Commit and push important changes to a remote Git repo.
MD
  fi

  if [ ! -d "$WORKSPACE_DIR/.git" ]; then
    git -C "$WORKSPACE_DIR" init -b main
  fi
}

write_auth_file() {
  AUTH_FILE="$AUTH_FILE" node <<'NODE'
const fs = require("node:fs");
const path = process.env.AUTH_FILE;

let auth = {};
try {
  auth = JSON.parse(fs.readFileSync(path, "utf8"));
} catch {
  auth = {};
}

const providers = {
  anthropic: process.env.ANTHROPIC_API_KEY,
  openrouter: process.env.OPENROUTER_API_KEY,
};

for (const [provider, key] of Object.entries(providers)) {
  if (key) auth[provider] = { type: "api", key };
}

fs.mkdirSync(require("node:path").dirname(path), { recursive: true });
fs.writeFileSync(path, `${JSON.stringify(auth, null, 2)}\n`, { mode: 0o600 });
NODE
}

write_global_config() {
  GLOBAL_CONFIG_FILE="$GLOBAL_CONFIG_FILE" node <<'NODE'
const fs = require("node:fs");
const path = process.env.GLOBAL_CONFIG_FILE;

let config = {};
try {
  config = JSON.parse(fs.readFileSync(path, "utf8"));
} catch {
  config = {};
}

if (!config || typeof config !== "object" || Array.isArray(config)) {
  config = {};
}

config.$schema = config.$schema || "https://opencode.ai/config.json";
config.mcp = config.mcp && typeof config.mcp === "object" && !Array.isArray(config.mcp)
  ? config.mcp
  : {};
config.mcp.render = {
  type: "remote",
  url: "https://mcp.render.com/mcp",
  enabled: true,
  oauth: false,
  headers: {
    Authorization: "Bearer {env:RENDER_API_KEY}",
  },
};

fs.mkdirSync(require("node:path").dirname(path), { recursive: true });
fs.writeFileSync(path, `${JSON.stringify(config, null, 2)}\n`);
NODE
}

write_project_config_if_missing() {
  if [ -f "$WORKSPACE_DIR/opencode.json" ]; then
    return
  fi

  cat > "$WORKSPACE_DIR/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "mode": "primary",
      "permission": {
        "read": "allow",
        "edit": "ask",
        "bash": "ask",
        "glob": "allow",
        "grep": "allow",
        "webfetch": "allow",
        "websearch": "allow",
        "lsp": "allow"
      }
    }
  }
}
JSON
}

configure_git_defaults

if [ -n "${REPO_URL:-}" ] && directory_is_empty "$WORKSPACE_DIR"; then
  clone_repo
fi

ensure_workspace_project
write_auth_file
write_global_config
write_project_config_if_missing

case "$OPENCODE_SERVER_COMMAND" in
  web|serve)
    ;;
  *)
    echo "OPENCODE_SERVER_COMMAND must be either web or serve." >&2
    exit 1
    ;;
esac

cd "$WORKSPACE_DIR"
exec opencode "$OPENCODE_SERVER_COMMAND" --hostname 0.0.0.0 --port "${PORT:-10000}"
