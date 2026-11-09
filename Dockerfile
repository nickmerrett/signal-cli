# Wolfi base (Chainguard's undistro). Swapped in from ubi9-minimal purely as an
# experiment - see the PR. Nothing else about how this image is built changes.
#
# Why this base is reachable without any credentials: Chainguard's own registry
# (cgr.dev) returns 401 even for a manifest pull of wolfi-base, but the same image is
# published publicly on Docker Hub as chainguard/wolfi-base.
FROM docker.io/chainguard/wolfi-base:latest

USER 0

ARG SIGNAL_CLI_VERSION=0.14.10
ENV SIGNAL_CLI_CONFIG_DIR=/var/lib/signal-cli \
    HOME=/var/lib/signal-cli

# 1. Install what is needed to download and extract the native binary, plus the
#    runtime libraries the binary actually links against.
#    Verified with ldd against the 0.14.10 Linux-native tarball: it needs exactly
#    libc.so.6 (from the base's glibc) and libz.so.1. Nothing else - no libstdc++,
#    no OpenSSL, because the TLS stack is inside the GraalVM native image.
#    ca-certificates must REMAIN installed: signal-cli talks TLS to Signal's servers
#    and reads the system trust store.
#    NOTE: in Wolfi the tar command comes from a package named 'gnutar', not 'tar'.
#    The index lists it as "p:cmd:tar=1.35-r11", so `apk add tar` fails with
#    "no such package" while curl, gzip, zlib and ca-certificates all resolve.
# 2. Download and extract AsamK/signal-cli Linux-native package (archive contains just
#    the single binary 'signal-cli').
# 3. Drop curl/gzip/gnutar again - they are build-time only, so the final image
#    carries no download or archive tooling. zlib and ca-certificates stay, being
#    genuine runtime dependencies of the binary.
#    NOTE: link into /usr/bin, not /usr/local/bin. Wolfi has no /usr/local/bin, so the
#    ubi9 form fails with "No such file or directory" - ln cannot create a link inside
#    a directory that does not exist. /usr/bin exists and is on PATH, so the live
#    Deployment's `command: [signal-cli, ...]` resolves with no PATH changes.
# 4. Configure GID 0 permissions for OpenShift arbitrary UID compatibility.
RUN apk add --no-cache zlib ca-certificates curl gzip gnutar && \
    mkdir -p /opt/signal-cli/bin /var/lib/signal-cli && \
    curl -fsSL "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    | tar -xz -C /opt/signal-cli/bin && \
    ln -s /opt/signal-cli/bin/signal-cli /usr/bin/signal-cli && \
    apk del curl gzip gnutar && \
    chgrp -R 0 /var/lib/signal-cli /opt/signal-cli && \
    chmod -R g+rwX /var/lib/signal-cli /opt/signal-cli

WORKDIR /var/lib/signal-cli

# Switch to standard non-root user (UID 1001, GID 0)
USER 1001

EXPOSE 8080

ENTRYPOINT ["signal-cli", "--config", "/var/lib/signal-cli", "daemon", "--http", "0.0.0.0:8080"]
