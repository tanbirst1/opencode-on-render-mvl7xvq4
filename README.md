# opencode-llm-proxy on Render (free plan)

Deploys [KochC/opencode-llm-proxy](https://github.com/KochC/opencode-llm-proxy) to Render.

Upstream is an **OpenCode plugin, not a standalone server**. This image installs the `opencode`
CLI and the plugin, then runs headless `opencode serve`. The plugin opens the OpenAI/Anthropic/
Gemini-compatible proxy on Render's `$PORT`, so public traffic reaches the proxy.

## Deploy

- Runtime: Docker, plan: free, region: singapore
- `OPENCODE_LLM_PROXY_TOKEN` is required (the proxy refuses to bind beyond loopback without one).
  `render.yaml` generates it; read the value in the Render dashboard.
- Set at least one provider key (`OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, ...)
  so the proxy has a model to serve.

## Call it

```bash
curl https://<service>.onrender.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENCODE_LLM_PROXY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"openrouter/anthropic/claude-sonnet-4.5","messages":[{"role":"user","content":"hi"}]}'
```

## Free-plan caveats

- The service spins down after 15 minutes idle and takes ~1 minute to wake.
- The filesystem is ephemeral; OpenCode state and provider auth reset on every restart.
  Provider keys are supplied as env vars on each boot, so this is fine.
- Only one writer per account at a time on the free plan.
