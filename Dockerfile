FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:latest

USER 0

ARG SIGNAL_CLI_VERSION=0.14.10
ENV SIGNAL_CLI_CONFIG_DIR=/var/lib/signal-cli \
    HOME=/var/lib/signal-cli

# 1. Install tar and gzip to extract the JVM distribution
# 2. Download the AsamK/signal-cli JVM package - NOT the -Linux-native one. That
#    archive is a GraalVM native image built for x86-64-v3, so it needs avx2/bmi2/fma.
#    The host this runs on is an Intel Atom C3758, which has none of them, so the
#    binary cannot execute there: the image builds and pulls fine and then the
#    container never starts. The JVM build is bytecode and runs on any x86-64.
# 3. Configure GID 0 permissions for OpenShift arbitrary UID compatibility
RUN microdnf install -y tar gzip && \
    microdnf clean all && \
    curl -fsSL "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz" \
    | tar -xz -C /opt && \
    ln -s /opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli /usr/local/bin/signal-cli && \
    mkdir -p /var/lib/signal-cli && \
    chgrp -R 0 /var/lib/signal-cli /opt/signal-cli-${SIGNAL_CLI_VERSION} && \
    chmod -R g+rwX /var/lib/signal-cli /opt/signal-cli-${SIGNAL_CLI_VERSION}

WORKDIR /var/lib/signal-cli

# Standard UBI non-root user (UID 185, GID 0), as in the original build.
USER 185

EXPOSE 8080

ENTRYPOINT ["signal-cli", "--config", "/var/lib/signal-cli", "daemon", "--http", "0.0.0.0:8080"]