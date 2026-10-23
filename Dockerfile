FROM node:24-bookworm-slim

ENV NODE_ENV=production
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_FUND=false
ENV NPM_CONFIG_AUDIT=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
        opencode-ai@latest \
        typescript-language-server@latest \
        typescript@latest \
    && npm cache clean --force

RUN curl -fsSL https://raw.githubusercontent.com/render-oss/render-opencode-plugin/main/install.sh \
    | bash -s -- --force

WORKDIR /workspace

COPY start.sh /usr/local/bin/start-opencode
RUN chmod +x /usr/local/bin/start-opencode

EXPOSE 10000

CMD ["/usr/local/bin/start-opencode"]
