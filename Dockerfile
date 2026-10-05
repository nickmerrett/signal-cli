FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

USER 0

ARG SIGNAL_CLI_VERSION=0.14.8
ENV SIGNAL_CLI_CONFIG_DIR=/var/lib/signal-cli \
    HOME=/var/lib/signal-cli

# 1. Install tar and gzip to extract native binary package
# 2. Download and extract AsamK/signal-cli Linux-native package (archive contains just the single binary 'signal-cli')
# 3. Configure GID 0 permissions for OpenShift arbitrary UID compatibility
RUN microdnf install -y tar gzip && \
    microdnf clean all && \
    mkdir -p /opt/signal-cli/bin /var/lib/signal-cli && \
    curl -fsSL "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    | tar -xz -C /opt/signal-cli/bin && \
    ln -s /opt/signal-cli/bin/signal-cli /usr/local/bin/signal-cli && \
    chgrp -R 0 /var/lib/signal-cli /opt/signal-cli && \
    chmod -R g+rwX /var/lib/signal-cli /opt/signal-cli

WORKDIR /var/lib/signal-cli

# Switch to standard non-root user (UID 1001, GID 0)
USER 1001

EXPOSE 8080

ENTRYPOINT ["signal-cli", "--config", "/var/lib/signal-cli", "daemon", "--http", "0.0.0.0:8080"]
