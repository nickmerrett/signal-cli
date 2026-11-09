# Wolfi base (Chainguard's undistro), from ubi9-minimal. Two stages, so nothing
# needed to *fetch* the binary can end up in the image that runs.
#
# Why Docker Hub: Chainguard's own registry (cgr.dev) returns 401 even for a manifest
# pull of wolfi-base, but the same image is published publicly as
# docker.io/chainguard/wolfi-base. No credentials needed.
#
# Why this works at all: ldd against the 0.14.10 Linux-native tarball shows the binary
# links exactly two shared libraries - libc.so.6 (the base's glibc) and libz.so.1. No
# libstdc++, no OpenSSL, because the TLS stack lives inside the GraalVM native image.
# ca-certificates is still required at runtime: signal-cli reads the system trust store
# to talk TLS to Signal's servers.

# ---------------------------------------------------------------------------
# Stage 1: fetch. This stage carries curl, gzip and gnutar, and is discarded
# whole - so none of them, nor the OpenSSL/Kerberos/LDAP stack curl pulls in,
# can reach the runtime image. That is the point of splitting the stages rather
# than installing and then `apk del`-ing, which leaves the files in an earlier
# layer where they still ship and still show up in a scanner.
#
# Note: in Wolfi the tar command comes from a package named 'gnutar', not 'tar'.
# The index declares it as "p:cmd:tar", so `apk add tar` fails with "no such
# package" while curl, gzip and zlib all resolve normally.
# ---------------------------------------------------------------------------
FROM docker.io/chainguard/wolfi-base:latest AS fetch

ARG SIGNAL_CLI_VERSION=0.14.10

RUN apk add --no-cache curl gzip gnutar && \
    mkdir -p /out && \
    curl -fsSL "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    | tar -xz -C /out && \
    chmod 0755 /out/signal-cli

# ---------------------------------------------------------------------------
# Stage 2: runtime. Needs zlib and ca-certificates and nothing else.
#
# /usr/bin, not /usr/local/bin: Wolfi does not create /usr/local/bin, so the ubi9
# form fails with "ln: /usr/local/bin/signal-cli: No such file or directory".
# /usr/bin exists and is on PATH, so the Deployment's `command: [signal-cli, ...]`
# resolves with no PATH changes anywhere.
# ---------------------------------------------------------------------------
FROM docker.io/chainguard/wolfi-base:latest

USER 0

ENV SIGNAL_CLI_CONFIG_DIR=/var/lib/signal-cli \
    HOME=/var/lib/signal-cli

RUN apk add --no-cache zlib ca-certificates && \
    mkdir -p /opt/signal-cli/bin /var/lib/signal-cli && \
    chgrp -R 0 /var/lib/signal-cli /opt/signal-cli && \
    chmod -R g+rwX /var/lib/signal-cli /opt/signal-cli

COPY --from=fetch /out/signal-cli /opt/signal-cli/bin/signal-cli

# GID 0 ownership on the copied binary too, for OpenShift arbitrary UID.
RUN ln -s /opt/signal-cli/bin/signal-cli /usr/bin/signal-cli && \
    chgrp 0 /opt/signal-cli/bin/signal-cli && \
    chmod 0755 /opt/signal-cli/bin/signal-cli

WORKDIR /var/lib/signal-cli

# Switch to standard non-root user (UID 1001, GID 0)
USER 1001

EXPOSE 8080

ENTRYPOINT ["signal-cli", "--config", "/var/lib/signal-cli", "daemon", "--http", "0.0.0.0:8080"]
