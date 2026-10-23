# opencode on Render

Run opencode as a hosted AI coding agent with the browser UI and `opencode attach`.

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy-template/api/github/start?template_repo=opencode-on-render)

## What you get

- A single Render Web Service running `opencode web`
- The built-in opencode web UI on your Render URL
- Remote TUI access with `opencode attach`
- A `standard` instance to avoid OOM loops on startup and active agent sessions
- A 1 GB persistent disk for opencode state and your working tree
- Optional repo cloning into `/root/project-data/workspace` on first boot
- The Render OpenCode plugin installed by default

## How to use it

### From your browser

Deploy the template, then open the Render service URL.

Log in with:

- Username: `opencode`
- Password: the generated `OPENCODE_SERVER_PASSWORD` value in the Render Dashboard

### From your terminal

Install opencode locally:

```bash
npm install -g opencode-ai
```

Attach to your hosted backend:

```bash
opencode attach https://your-service.onrender.com
```

Use the generated password when prompted. You can also pass it directly:

```bash
opencode attach https://your-service.onrender.com \
  --username opencode \
  --password "$OPENCODE_SERVER_PASSWORD"
```

## Bring your own repo

Set `REPO_URL` during deploy to clone a working tree into `/root/project-data/workspace` on first boot.

For a public repo:

```txt
REPO_URL=https://github.com/your-org/your-repo.git
```

For a specific branch:

```txt
REPO_URL=https://github.com/your-org/your-repo.git
REPO_BRANCH=main
```

For a private GitHub repo, also set `GITHUB_TOKEN` to a token that can read the repo.

The startup script only clones when `/root/project-data/workspace` is empty. If `/root/project-data/workspace` already has files, it leaves them alone.

If you do not set `REPO_URL`, the service creates a small default Git project in `/root/project-data/workspace` so the web UI has a project to open.

## Server command

The template defaults to:

```txt
OPENCODE_SERVER_COMMAND=web
```

That starts opencode's web UI and API on the same Render URL.

If `opencode attach` returns HTML instead of API responses, switch to the headless server:

```txt
OPENCODE_SERVER_COMMAND=serve
```

## Configured providers

Set one or more provider keys in Render:

- `ANTHROPIC_API_KEY` unlocks Anthropic models.
- `OPENROUTER_API_KEY` unlocks OpenRouter models.
- `RENDER_API_KEY` unlocks Render MCP tools.

The service writes these keys into `/root/project-data/opencode/auth.json` using opencode's API-key auth format.

Anthropic OAuth is not supported in this hosted setup. Use `ANTHROPIC_API_KEY`.

## Security notes

This template gives you a remote coding agent, not a hardened sandbox.

The agent can read and write files in its workspace, run shell commands, and use the environment variables you provide. Treat it like a single-tenant development box that can act with your credentials.

Be careful with `RENDER_API_KEY`. Render API keys are broad credentials today. If you set one, opencode can use Render MCP tools with whatever access that key has. Leave `RENDER_API_KEY` unset unless you want the agent to manage Render resources from this service. Remove it when you do not need Render MCP, and rotate it if you expose logs, transcripts, or the service password.

Do not use this template with untrusted users, untrusted prompts, or repos you do not want an AI agent to execute code from.

## Instance size

The template uses Render's `standard` plan by default.

opencode can exceed the memory available on `starter`, especially with the web UI, provider metadata, plugins, MCP tools, and active coding sessions.

## What's pre-wired

The image installs the Render OpenCode plugin from GitHub. It adds:

- `render_validate_blueprint`
- automatic validation when an agent edits `render.yaml` or `render.yml`
- `/deploy-to-render`
- `/check-render-status`
- the `@render` subagent
- bundled Render skills

The startup script also merges the Render MCP server into `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "render": {
      "type": "remote",
      "url": "https://mcp.render.com/mcp",
      "enabled": true,
      "oauth": false,
      "headers": {
        "Authorization": "Bearer {env:RENDER_API_KEY}"
      }
    }
  }
}
```

Set `RENDER_API_KEY` in Render before asking opencode to manage Render resources.

## Disk size

The template starts with a 1 GB persistent disk mounted at:

```txt
/root/project-data
```

The startup script uses that disk for:

- `/root/project-data/opencode` for opencode auth, sessions, and SQLite state
- `/root/project-data/workspace` for the repo or project files the agent edits

To resize it, edit `render.yaml`:

```yaml
disk:
  name: opencode-data
  mountPath: /root/project-data
  sizeGB: 5
```

Then deploy the updated Blueprint.

## Known limitations

- Anthropic OAuth login does not work for hosted opencode. Use `ANTHROPIC_API_KEY`.
- The opencode web UI fetches assets from opencode's CDN at runtime.
- This is single-tenant. Do not share one deployment with multiple users.
- `/root/project-data/workspace` persists across restarts and deploys, but you should still commit and push important work back to your repo.
- The image preinstalls TypeScript language server only. Other language servers can be installed in your repo or a fork of this template.

## Learn more

- [opencode docs](https://opencode.ai/docs)
- [opencode CLI docs](https://opencode.ai/docs/cli/)
- [opencode MCP docs](https://opencode.ai/docs/mcp-servers/)
- [Render OpenCode plugin](https://github.com/render-oss/render-opencode-plugin)
