FROM fedora:44

RUN dnf update -y && dnf install -y \
    curl \
    git \
    tar \
    gzip \
    bzip2 \
    procps-ng \
    libatomic \
    && dnf clean all

ENV NVM_DIR="/usr/local/nvm"

ARG NODE_VERSION=24
ENV NODE_VERSION=${NODE_VERSION}

ARG EXTRA_NODE_VERSIONS=""

ARG ARTCRAFT_APPS=""

RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash

RUN bash -c 'source $NVM_DIR/nvm.sh && \
    for v in $EXTRA_NODE_VERSIONS; do \
        nvm install "$v"; \
    done && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path'

RUN bash -c 'source $NVM_DIR/nvm.sh && nvm use default && \
    npm install -g @openchamber/web'

RUN bash -c 'source $NVM_DIR/nvm.sh && \
    ln -sf "$(nvm which default)" /usr/local/bin/node && \
    ln -sf "$(dirname "$(nvm which default)")/npm" /usr/local/bin/npm && \
    ln -sf "$(dirname "$(nvm which default)")/npx" /usr/local/bin/npx'

RUN printf '#!/usr/bin/env bash\nexport NVM_DIR="/usr/local/nvm"\n. "$NVM_DIR/nvm.sh" --no-use\nnvm "$@"\n' > /usr/local/bin/nvm && \
    chmod +x /usr/local/bin/nvm

ENV PATH="/root/.opencode/bin:$PATH"
ENV OPENCODE_BINARY="/root/.opencode/bin/opencode"
ENV OPENCHAMBER_HOST=0.0.0.0

ENV BASH_ENV=/root/.bashrc

ENV ENV=/etc/profile.d/nvm.sh

RUN printf 'export NVM_DIR="/usr/local/nvm"\n[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"\n\nnvm_use_cd() {\n    if [ -f "$PWD/.nvmrc" ]; then\n        nvm use --silent "$(cat "$PWD/.nvmrc")" >/dev/null 2>&1\n    else\n        nvm use --silent default >/dev/null 2>&1\n    fi\n}\ncd() { builtin cd "$@" && nvm_use_cd; }\nnvm_use_cd\n' > /etc/profile.d/nvm.sh && \
    chmod +x /etc/profile.d/nvm.sh && \
    cat /etc/profile.d/nvm.sh >> /root/.bashrc

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY artcraft_mcp_templates/ /usr/local/share/artcraft_mcp_templates/

COPY install-artcraft-apps.sh /usr/local/bin/install-artcraft-apps.sh
RUN chmod +x /usr/local/bin/install-artcraft-apps.sh

RUN /usr/local/bin/install-artcraft-apps.sh && rm /usr/local/bin/install-artcraft-apps.sh

WORKDIR /projects
EXPOSE 3000

CMD ["/usr/local/bin/entrypoint.sh"]
