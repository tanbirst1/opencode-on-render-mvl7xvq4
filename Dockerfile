FROM node:24-bookworm-slim

ENV NODE_ENV=production \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/*

# OpenCode CLI (headless `opencode serve`) and the proxy plugin package.
# The proxy is loaded from its prebuilt bundle, not resolved by name: OpenCode
# resolves npm-named plugins with Bun, which this image does not ship.
RUN npm install -g opencode-ai@latest opencode-llm-proxy@latest \
    && npm cache clean --force

WORKDIR /workspace

COPY start.sh /usr/local/bin/start-opencode-llm-proxy
RUN chmod +x /usr/local/bin/start-opencode-llm-proxy

# The proxy binds to Render's $PORT; this is only the conventional default.
EXPOSE 4010

CMD ["/usr/local/bin/start-opencode-llm-proxy"]
