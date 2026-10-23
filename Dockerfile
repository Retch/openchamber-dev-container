FROM fedora:44

# Systemabhängigkeiten
RUN dnf update -y && dnf install -y \
    curl \
    git \
    tar \
    gzip \
    bzip2 \
    procps-ng \
    && dnf clean all

ENV NVM_DIR="/usr/local/nvm"
ENV NODE_VERSION=24

RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash

RUN bash -c 'source $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path'

RUN bash -c 'source $NVM_DIR/nvm.sh && nvm use default && \
    npm install -g @openchamber/web'

ENV PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin:/root/.opencode/bin:$PATH"
ENV OPENCODE_BINARY="/root/.opencode/bin/opencode"
ENV OPENCHAMBER_HOST=0.0.0.0

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /projects
EXPOSE 3000

CMD ["/usr/local/bin/entrypoint.sh"]
