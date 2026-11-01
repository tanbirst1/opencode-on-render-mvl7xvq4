FROM node:24-bookworm-slim

ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/*

# OpenCode CLI (headless `opencode serve`) + the proxy plugin it loads.
RUN npm install -g opencode-ai@latest opencode-llm-proxy@latest \
    && npm cache clean --force

WORKDIR /workspace

COPY start.sh /usr/local/bin/start-opencode-llm-proxy
RUN chmod +x /usr/local/bin/start-opencode-llm-proxy

# The proxy binds to Render's $PORT; this is only the conventional default.
EXPOSE 4010

CMD ["/usr/local/bin/start-opencode-llm-proxy"]
