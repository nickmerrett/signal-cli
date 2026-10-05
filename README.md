# Signal CLI on OpenShift / Kubernetes

A lightweight, OpenShift-compliant container deployment wrapping official upstream [`AsamK/signal-cli`](https://github.com/AsamK/signal-cli) in native HTTP daemon mode (`--http`).

## Features

- **Native Single-Process**: Direct Java HTTP daemon without multi-process supervisors (`s6-overlay`), Go wrappers, or D-Bus daemon requirements.
- **OpenShift Security Ready**: Built on Red Hat UBI 9 (`openjdk-21-runtime`) with group `0` write permissions. Complies with `restricted` / `restricted-v2` SecurityContextConstraints (no `anyuid` or root needed).
- **Persistent Data**: Stores keys, accounts, and session data on a standard `PersistentVolumeClaim`.

---

## File Structure

- [`Dockerfile`](Dockerfile:1) — Builds the OpenShift-ready image based on Red Hat UBI 9 OpenJDK 21.
- [`deployment.yaml`](deployment.yaml:1) — Kubernetes/OpenShift manifests for PVC, Deployment, and Service.
- [`tekton-pipelinerun.yaml`](tekton-pipelinerun.yaml:1) — Tekton pipeline definition for building with Buildah.

---

## Building the Image

### Option A: Local Build (Podman / Docker)

```bash
# Build the image locally
podman build -t signal-cli:latest .

# Tag and push to your target registry
podman tag signal-cli:latest <your-registry>/<your-namespace>/signal-cli:latest
podman push <your-registry>/<your-namespace>/signal-cli:latest
```

### Option B: OpenShift Pipelines (Tekton)

Using the OpenShift `buildah` cluster task:

```bash
tkn task start buildah \
  --param IMAGE="<your-registry>/<your-namespace>/signal-cli:latest" \
  --param DOCKERFILE="Dockerfile" \
  --param TLSVERIFY="false" \
  --workspace name=source,claimName=shared-workspace-pvc \
  --showlog
```

Or trigger using [`tekton-pipelinerun.yaml`](tekton-pipelinerun.yaml:1):

```bash
oc create -f tekton-pipelinerun.yaml
tkn pipelinerun logs -f -L
```

---

## Deploying to OpenShift

1. Update the image reference in [`deployment.yaml`](deployment.yaml:31) to point to your pushed image.

2. Apply the manifest:
   ```bash
   oc apply -f deployment.yaml
   ```

3. Verify the deployment:
   ```bash
   oc get pods -l app=signal-cli
   oc logs -l app=signal-cli -f
   ```

---

## Registering / Linking an Account

Once the pod is running, you can link an existing Signal account or register a new number using the HTTP REST endpoints.

### 1. Linking an Existing Account (QR Code)

Get a linking URI / QR code:

```bash
# Inside the cluster or via port-forward:
oc port-forward svc/signal-cli 8080:8080

# Request linking device URI
curl -s http://localhost:8080/v1/qrcodelink?device_name=openshift-bot | jq
```

Scan the returned URI with your Signal mobile app under **Settings > Linked Devices**.

### 2. Registering a New Phone Number

```bash
# Request SMS verification code
curl -X POST http://localhost:8080/v1/register/<PHONE_NUMBER>

# Submit verification code
curl -X POST http://localhost:8080/v1/register/<PHONE_NUMBER>/verify/<CODE>
```

---

## REST API Reference

The container exposes upstream `signal-cli` HTTP REST endpoints on port `8080`:

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/v1/qrcodelink` | Generate QR code URI to link a secondary device |
| `GET` | `/v1/accounts` | List configured Signal accounts |
| `POST` | `/v1/send` | Send a message or attachment |
| `POST` | `/v1/register/<number>` | Initiate registration for a phone number |
| `POST` | `/v1/register/<number>/verify/<code>` | Verify registration with SMS/voice code |
