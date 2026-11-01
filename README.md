# opencode-llm-proxy on Render (free plan)

Deploys [KochC/opencode-llm-proxy](https://github.com/KochC/opencode-llm-proxy) as a public
OpenAI/Anthropic/Gemini-compatible gateway on Render's free plan.

## How it works

Upstream is an **OpenCode plugin, not a standalone server**, and it has no `npm start`. This
image installs the `opencode` CLI plus the plugin package and runs headless `opencode serve`.
Two OpenCode behaviours drive the setup:

1. Plugins are loaded **lazily, on the first session** — the server alone never opens the proxy
   port. `start.sh` therefore creates one session on boot so the proxy binds `$PORT` before
   Render's port scan gives up.
2. OpenCode resolves npm-named plugins with **Bun**, which this image does not ship. `start.sh`
   copies the plugin's prebuilt, self-contained bundle into the plugin directory instead.

`opencode serve` itself listens on loopback only; the plugin opens the proxy on
`0.0.0.0:$PORT`, which is what Render routes public traffic to.

## Required environment variables

| Variable | Purpose |
|---|---|
| `OPENCODE_LLM_PROXY_TOKEN` | Bearer token. Required: the proxy refuses to bind beyond loopback without one. |
| `OPENCODE_LLM_PROXY_HOST` | `0.0.0.0` to accept Render's traffic. |
| `OPENROUTER_API_KEY` / `ANTHROPIC_API_KEY` / ... | Any provider key OpenCode supports, so the proxy has models to serve. |

`OPENCODE_SERVER_PASSWORD` may also be set to protect the OpenCode server API on `:4096`.
The warm-up authenticates with it automatically.

## Call it

```bash
curl https://<service>.onrender.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENCODE_LLM_PROXY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"openrouter/anthropic/claude-sonnet-4.5","messages":[{"role":"user","content":"hi"}]}'
```

`GET /v1/models` lists what is available.

## Free-plan caveats

- The service spins down after 15 minutes idle and takes about a minute to wake.
- The filesystem is ephemeral, so OpenCode state resets on every restart. Provider keys come
  from environment variables, so this is harmless.
- A health check path must not be set: the proxy is token-protected and answers `401` without
  credentials, which Render reads as unhealthy.
- OpenCode's free Zen models enforce a usage cap upstream; use your own provider keys for
  sustained traffic.
