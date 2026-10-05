FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:latest

USER 0

ARG SIGNAL_CLI_VERSION=0.14.8
ENV SIGNAL_CLI_CONFIG_DIR=/var/lib/signal-cli \
    HOME=/var/lib/signal-cli

RUN microdnf install -y tar gzip && \
    microdnf clean all && \
    curl -fsSL "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz" \
    | tar -xz -C /opt && \
    ln -s /opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli /usr/local/bin/signal-cli && \
    mkdir -p /var/lib/signal-cli && \
    chgrp -R 0 /var/lib/signal-cli /opt/signal-cli-${SIGNAL_CLI_VERSION} && \
    chmod -R g+rwX /var/lib/signal-cli /opt/signal-cli-${SIGNAL_CLI_VERSION}

WORKDIR /var/lib/signal-cli

# Switch back to standard UBI non-root user (UID 185)
USER 185

EXPOSE 8080

ENTRYPOINT ["signal-cli", "--config", "/var/lib/signal-cli", "daemon", "--http", "0.0.0.0:8080"]
