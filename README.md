# jupyter-template

A ready-to-run **JupyterLab + Apache Spark** image, plus a Helm chart that
deploys it to Kubernetes.

| | |
| --- | --- |
| Base image | [`quay.io/jupyter/all-spark-notebook`](https://quay.io/repository/jupyter/all-spark-notebook) |
| Base tag | `2026-09-29` |
| Included | JupyterLab 4.6, Notebook 7.6, Jupyter Server 2.21, Python 3.13, R 4.5, Spark 4.2, Java 21 |
| Architectures | `linux/amd64`, `linux/arm64` |
| Chart | `helm/jupyter-template`, `apiVersion: v2`, Helm 3.22+ and 4.x |
| Chart schema | `values.schema.json` (validated on install, upgrade and template) |
| Tests | 148 unit tests across 11 `helm-unittest` suites |

---

## Contents

- [Why this image](#why-this-image)
- [Quick start with Docker](#quick-start-with-docker)
- [Using Spark](#using-spark)
- [Deploying with Helm](#deploying-with-helm)
  - [Getting the token](#getting-the-token)
  - [Persisting notebooks](#persisting-notebooks)
  - [Exposing over Ingress](#exposing-over-ingress)
  - [Exposing over Gateway API](#exposing-over-gateway-api)
  - [Running as root / enabling sudo](#running-as-root--enabling-sudo)
- [Configuration reference](#configuration-reference)
- [Command-line arguments to Jupyter](#command-line-arguments-to-jupyter)
- [Development](#development)
- [Migrating from the previous version](#migrating-from-the-previous-version)
- [Licence](#licence)

---

## Why this image

The upstream Jupyter images are large and change layout between releases. This
repository exists to pin one known-good combination and add only what a
deployment actually needs:

- **Pinned upstream release.** The base image is pinned to a dated tag rather
  than `latest`, so a rebuild is reproducible. Override with
  `--build-arg BASE_TAG=...`.
- **Registry moved to Quay.io.** The Jupyter project stopped pushing to Docker
  Hub in October 2023; the Docker Hub copies are frozen and no longer receive
  security fixes. This image builds from `quay.io`.
- **Multi-arch.** The upstream date tag is a multi-platform OCI index, so this
  image builds for both amd64 and arm64 without architecture-prefixed tags.
- **HTTPS on by default.** `GEN_CERT=yes` makes the server generate a
  self-signed certificate, so the endpoint is not served over plain HTTP.
- **Nothing else added.** The previous revision ran `apt-get update && apt-get
  clean`, which installed nothing while the comment claimed it installed system
  updates. That layer is gone; see [Development](#development).

## Quick start with Docker

```bash
docker pull ghcr.io/23skdu/jupyter-template:latest

docker run --rm -p 8888:8888 \
  -e JUPYTER_TOKEN=change-me \
  ghcr.io/23skdu/jupyter-template:latest
```

Jupyter serves **HTTPS** on `https://localhost:8888/lab` (self-signed, so your
browser will warn). Log in with the token you passed in.

### `--user root`, and when it matters

The base image already sets `USER 1000`, so the container starts unprivileged.
The upstream `start.sh` entrypoint only applies `NB_UID`, `NB_GID`, `CHOWN_HOME`
and `GRANT_SUDO` when it is given `--user root`, in which case it re-executes
itself as `jovyan` via `sudo` afterwards.

| Option | Works without `--user root`? |
| --- | --- |
| `GEN_CERT` | **Yes** — read straight from the environment by `jupyter_server_config.py` |
| `JUPYTER_TOKEN`, `DOCKER_STACKS_JUPYTER_CMD`, `NOTEBOOK_ARGS`, `NB_USER` | **Yes** — plain environment variables |
| `GRANT_SUDO`, `NB_UID`, `NB_GID`, `CHOWN_HOME`, `CHOWN_EXTRA` | **No** — need `--user root` |

To enable passwordless `sudo` (for `apt install`) and uid/gid remapping:

```bash
docker run --rm --user root -p 8888:8888 \
  -e JUPYTER_TOKEN=change-me \
  -e GRANT_SUDO=yes \
  ghcr.io/23skdu/jupyter-template:latest
```

Only enable `GRANT_SUDO` for users you trust: it hands the notebook user
unrestricted root inside the container.

### Other useful environment variables

| Variable | Effect |
| --- | --- |
| `DOCKER_STACKS_JUPYTER_CMD` | Run something other than `jupyter lab`, e.g. `notebook`, `nbclassic`, `server` |
| `JUPYTER_PORT` | Listen on a port other than 8888 |
| `NOTEBOOK_ARGS` | Extra flags for the `jupyter` subcommand, e.g. `--log-level=DEBUG` |
| `NB_USER`, `NB_UID`, `NB_GID` | Rename / re-map the notebook user (**requires `--user root`**) |
| `CHOWN_HOME`, `CHOWN_HOME_OPTS` | `chown` the home directory at startup (**requires `--user root`**) |
| `RESTARTABLE` | Restart Jupyter instead of exiting when it quits |
| `JUPYTER_ENV_VARS_TO_UNSET` | Comma-separated variables to drop before starting Jupyter |

Startup hooks: drop shell scripts into `/usr/local/bin/start-notebook.d/` (before
the standard options are applied) or `/usr/local/bin/before-notebook.d/` (after,
just before Jupyter starts).

## Using Spark

The image ships Spark as a **distribution** under `/usr/local/spark`, with
PySpark packaged as `pyspark.zip` rather than installed into the Python
environment. So `import pyspark` does not work out of the box in a notebook.

Two supported ways to get a Spark session:

**1. `spark-submit` — works with no configuration**

```bash
spark-submit my_job.py
```

**2. Add `/usr/local/spark/python` to `PYTHONPATH` — needed for notebooks**

```bash
docker run --rm -p 8888:8888 \
  -e JUPYTER_TOKEN=change-me \
  -e PYTHONPATH=/usr/local/spark/python:/usr/local/spark/python/lib/py4j-0.10.9.9-src.zip \
  ghcr.io/23skdu/jupyter-template:latest
```

The exact `py4j` filename tracks the Spark release; find it with:

```bash
ls /usr/local/spark/python/lib
```

Then in a notebook:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.master("local[*]").getOrCreate()
df = spark.read.csv("s3://my-bucket/events/")
```

### Spark UI

The Spark UI listens on port 4040, and each additional Spark context gets the
next free port (4040, 4041, …). Expose them when you need to inspect jobs:

```bash
docker run --rm -p 8888:8888 -p 4040:4040 \
  -e JUPYTER_TOKEN=change-me \
  ghcr.io/23skdu/jupyter-template:latest
```

In Kubernetes, set `spark.ui.enabled=true`, which adds a `spark-ui` container
port and a matching Service port.

> **Note:** the `pyspark` launcher script is broken in the current upstream
> release (`Running python applications through 'pyspark' is not supported`).
> Use `spark-submit`, as above.

## Deploying with Helm

```bash
helm upgrade --install jupyter ./helm/jupyter-template \
  --namespace jupyter --create-namespace \
  --set persistence.enabled=true
```

`helm template` works the same way for a dry run:

```bash
helm template jupyter ./helm/jupyter-template --namespace jupyter
```

### Getting the token

By default the chart generates a random 48-character token, stores it in a
Secret, and injects it as `JUPYTER_TOKEN`. On first install Helm generates it;
subsequent upgrades keep the existing value, so the URL stays stable.

```bash
kubectl get secret jupyter-jupyter-template \
  -o jsonpath='{.data.token}' | base64 -d; echo
```

Set a token you already know with `--set token.value=...`, or reference your own
Secret:

```bash
--set token.create=false --set token.existingSecret=my-jupyter-secret
```

To use a password instead of a token, turn the env var off and pass a hash:

```bash
--set token.injectEnv=false \
--set 'extraArgs[0]=--PasswordIdentityProvider.hashed_password=argon2:$argon2id$v=19$m=10240,t=10,p=8$...'
```

### Persisting notebooks

**Without this, every rescheduled pod loses its notebooks** — the chart
deploys a `Deployment`, whose filesystem is ephemeral.

```yaml
persistence:
  enabled: true
  size: 20Gi
  # storageClass: nfs-client
  # accessModes: [ReadWriteMany]
  mountPath: /home/jovyan/work
```

The claim is mounted at `mountPath` so the container (uid 1000) can write
without changing ownership of the rest of `$HOME`. To hold the entire home
directory — needed for `ReadWriteMany` volumes that must carry Jupyter's
runtime files — set `persistence.homeVolume: true`, which mounts at
`/home/jovyan`.

Use an existing claim with `persistence.existingClaim`.

The chart also sets `podSecurityContext.fsGroup: 100`, the gid that owns
`/home/jovyan` and `/opt/conda` in the image, so volumes are writable even when
a cluster (OpenShift, ACK, EKS Pod Identity) reassigns the uid.

### Exposing over Ingress

Jupyter holds long-lived **websockets** open for terminals and kernels, so the
proxy in front of it needs a generous idle timeout. With nginx-ingress:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  hosts:
    - host: jupyter.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: jupyter-tls
      hosts:
        - jupyter.example.com
```

If your server runs under a sub-path, tell Jupyter about it as well, otherwise
assets 404:

```yaml
extraArgs:
  - --ServerApp.base_url=/jupyter/
ingress:
  hosts:
    - host: example.com
      paths:
        - path: /jupyter
          pathType: Prefix
```

### Exposing over Gateway API

```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: gateway
      sectionName: http
  hostnames:
    - jupyter.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
  timeouts:
    request: 24h
```

Requires the Gateway API v1 CRDs and a controller that supports them.

### Running as root / enabling sudo

`NB_UID`, `NB_GID`, `CHOWN_HOME` and `GRANT_SUDO` only take effect when the
entrypoint starts as root. To use them, opt out of the non-root defaults:

```yaml
securityContext:
  runAsNonRoot: false
  runAsUser: 0
jupyterEnv:
  - name: GRANT_SUDO
    value: "yes"
  - name: CHOWN_HOME
    value: "yes"
  - name: CHOWN_HOME_OPTS
    value: -R
```

## Configuration reference

All values are validated against `values.schema.json`, so a typo fails at
`helm template` time rather than producing a broken manifest.

### Top level

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Number of replicas. **Keep at 1** — see note below. |
| `image.repository` | `ghcr.io/23skdu/jupyter-template` | Image repository. |
| `image.pullPolicy` | `IfNotPresent` | `Always`, `IfNotPresent` or `Never`. |
| `image.tag` | `""` | Image tag. Empty falls back to `.Chart.appVersion`. |
| `imagePullSecrets` | `[]` | Secrets for pulling from a private registry. |
| `nameOverride` | `""` | Overrides the chart name in labels. |
| `fullnameOverride` | `""` | Overrides the generated resource name. |
| `serviceAccount.create` | `true` | Create a ServiceAccount. |
| `serviceAccount.automount` | `false` | Mount the API token into the pod. |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations. |
| `serviceAccount.name` | `""` | Use a fixed ServiceAccount name. |
| `podAnnotations` / `podLabels` | `{}` | Extra pod metadata. |
| `podSecurityContext` | `fsGroup: 100`, `fsGroupChangePolicy: OnRootMismatch` | Pod-level security context. |
| `securityContext` | drop `ALL`, no privilege escalation, non-root | Container security context. |
| `extraArgs` | `[]` | Arguments appended to `start-notebook.py`. |
| `jupyterEnv` | `[]` | Env vars consumed by the upstream entrypoint. |
| `extraEnv` | `[]` | Free-form env vars. |
| `envFrom` | `[]` | `configMapRef` / `secretRef` sources. |
| `terminationGracePeriodSeconds` | `30` | Drain time for kernels and terminals. |
| `resources` | `250m`/1Gi requests, 4Gi memory limit | Resource requests and limits. |
| `startupProbe` | 30 × 10s | Tolerates slow Spark startup. |
| `livenessProbe` / `readinessProbe` | 30s / 10s periods | `GET /` on the `http` port. |
| `volumes` / `volumeMounts` | `[]` | Extra volumes and mounts. |
| `nodeSelector` / `tolerations` / `affinity` / `topologySpreadConstraints` | `{}` / `[]` | Scheduling. |

### Authentication — `token`

| Key | Default | Description |
| --- | --- | --- |
| `token.create` | `true` | Create the token Secret. |
| `token.value` | `""` | Literal token. Empty generates one on first install and reuses it. |
| `token.existingSecret` | `""` | Reference an existing Secret instead. |
| `token.existingSecretKey` | `token` | Key inside that Secret. |
| `token.injectEnv` | `true` | Inject `JUPYTER_TOKEN` into the container. |
| `token.annotations` | `{}` | Secret annotations. |

### Networking — `service`, `ingress`, `httpRoute`, `spark`

| Key | Default | Description |
| --- | --- | --- |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `8888` | Service and container port. |
| `service.annotations` / `service.labels` | `{}` | Extra Service metadata. |
| `ingress.enabled` | `false` | Create an Ingress. |
| `ingress.className` | `""` | Ingress class. |
| `ingress.annotations` | `{}` | e.g. proxy timeouts. |
| `ingress.hosts` | `jupyter.local` at `/` (Prefix) | Host and paths. |
| `ingress.tls` | `[]` | TLS secrets and their hosts. |
| `httpRoute.enabled` | `false` | Create a Gateway API `HTTPRoute`. |
| `httpRoute.parentRefs` | `gateway`/`http` | Gateways to attach to. |
| `httpRoute.hostnames` | `[jupyter.local]` | Matching hostnames. |
| `httpRoute.rules` | PathPrefix `/` | Matches and filters. `backendRefs` is generated. |
| `httpRoute.timeouts` | `{}` | e.g. `request: 24h`. |
| `spark.ui.enabled` | `false` | Expose the Spark UI on 4040. |
| `spark.ui.port` | `4040` | Spark UI port. |

### Storage — `persistence`

| Key | Default | Description |
| --- | --- | --- |
| `persistence.enabled` | `false` | Mount a claim for the working directory. |
| `persistence.existingClaim` | `""` | Use an existing PVC. |
| `persistence.storageClass` | cluster default | StorageClass name, or `-` for none. |
| `persistence.accessModes` | `[ReadWriteOnce]` | Access modes. |
| `persistence.size` | `10Gi` | Requested size. |
| `persistence.mountPath` | `/home/jovyan/work` | Mount point. |
| `persistence.homeVolume` | `false` | Mount at `/home/jovyan` instead. |
| `persistence.annotations` / `labels` | `{}` | Extra PVC metadata. |

### Autoscaling — `autoscaling`

| Key | Default | Description |
| --- | --- | --- |
| `autoscaling.enabled` | `false` | Create an HPA (and drop `spec.replicas`). |
| `autoscaling.minReplicas` / `maxReplicas` | `1` / `5` | Bounds. |
| `autoscaling.targetCPUUtilizationPercentage` | `80` | CPU target. |
| `autoscaling.targetMemoryUtilizationPercentage` | unset | Memory target. |

> **A note on replicas.** Jupyter Server is stateful: it owns open terminals,
> running kernels and a single token. Scaling past one replica does **not** load
> balance — it gives each user a different, isolated server with a different
> token and filesystem, chosen at random by the Service. `helm install` prints a
> warning when `replicaCount > 1`. If you need many independent users, use
> [JupyterHub](https://jupyterhub.readthedocs.io/) or
> [Zero to JupyterHub](https://zero-to-jupyterhub.readthedocs.io/) instead.

## Command-line arguments to Jupyter

`extraArgs` values are appended to `start-notebook.py` and forwarded verbatim to
Jupyter Server. Useful options:

| Argument | Purpose |
| --- | --- |
| `--ServerApp.base_url=/jupyter/` | Serve under a sub-path. |
| `--ServerApp.root_dir=/home/jovyan/work` | Where the file browser starts. |
| `--ServerApp.default_url=/lab` | Landing page. |
| `--ServerApp.token=""` `--ServerApp.password=""` | Disable token/password (**do not expose publicly**). |
| `--PasswordIdentityProvider.hashed_password=...` | Password auth. |
| `--IdentityProvider.token=...` | Use a fixed token. |
| `--ServerApp.allow_origin=...` | CORS, for split frontend/backend. |
| `--ServerApp.log_level=DEBUG` | Verbose logging. |

See the [Jupyter Server documentation](https://jupyter-server.readthedocs.io/en/latest/operators/public-server.html).

## Development

### Building

```bash
docker build -t jupyter-template:dev .
docker build -t jupyter-template:dev --build-arg BASE_TAG=spark-4.2.0 .
```

The build context is limited to the `Dockerfile` by `.dockerignore`, so CI and
local builds do not upload the chart, workflows or docs.

Run it:

```bash
docker run --rm -p 8888:8888 -e JUPYTER_TOKEN=change-me jupyter-template:dev
```

### Chart tests

```bash
# Helm 3
helm plugin install https://github.com/helm-unittest/helm-unittest.git

# Helm 4 (signature verification is not supported for git-installed plugins)
helm plugin install https://github.com/helm-unittest/helm-unittest.git --verify=false

helm lint helm/jupyter-template --strict
helm unittest helm/jupyter-template --strict
```

`tests/` holds 148 assertions across 11 suites:

| Suite | Covers |
| --- | --- |
| `deployment` (42) | Image resolution, env, probes, security context, resources, scheduling, metadata |
| `helpers` (12) | Name/fullname derivation, 63-char DNS truncation, chart and app-version labels |
| `persistence` (15) | PVC creation and pod wiring for both mount modes |
| `token-secret` (8) | Token generation, quoting, and `create`/`existingSecret` |
| `service` (7) | Types, ports, Spark UI, selectors |
| `serviceaccount` (8) | Creation, automount, naming |
| `ingress` (9) | Hosts, paths, TLS, class, annotations |
| `httproute` (12) | Parent refs, rules, filters, generated `backendRefs`, timeouts |
| `hpa` (6) | Metrics and replica bounds |
| `test-connection` (9) | The `helm test` probe pod |
| `schema` (20) | Rejection cases for invalid values |

The suites are excluded from the packaged chart via `.helmignore`; run them from
a checkout.

### Linting

`lint.yml` runs on every push and pull request:

- **hadolint** on the Dockerfile.
- **helm lint --strict**, `helm template` (default and all-features values), and
  `helm unittest --strict` against **both Helm 3.22 and Helm 4.3**.
- **yamllint** over the repo's static YAML.
- **actionlint** over the workflows.

## Migrating from the previous version

Changes since chart `0.1.0`, and what to do about them:

| Change | Action |
| --- | --- |
| Base image moved from Docker Hub to `quay.io` (Hub is frozen at 2023-10-20) | Rebuild and republish. |
| Base image moved from `x86_64-python-3.11` to `2026-09-29` (Python 3.13, Spark 4.2, R 4.5) | Rebuild; kernels and packages may need reinstalling. |
| The image no longer declares `USER ${NB_UID}` | Nothing: the base image already sets `USER 1000`. |
| `image.tag` now defaults to `""` and falls back to `appVersion` | If you pinned `latest`, `helm upgrade` will switch you to `2026-09-29`. Set `image.tag` explicitly to stay on `latest`. |
| A `JUPYTER_TOKEN` Secret is now created by default | Log in with the token instead of trusting an unauthenticated server. |
| `serviceAccount.automount` now defaults to `false` | Set it to `true` if you exec into the pod via the API. |
| `resources` now defaults to real requests and a memory limit | Change the numbers if your cluster needs different values. |
| `pathType` defaults to `Prefix` instead of `ImplementationSpecific` | Verify your Ingress still routes as intended. |
| `topologySpreadConstraints` added | Nothing; empty by default. |
| `values.schema.json` added | Unknown keys are now rejected. Remove any stray key from your values files. |
| Chart `appVersion` is now the image tag | If you overrode `image.tag`, nothing changes. |

## Licence

[BSD 3-Clause](LICENSE), matching the upstream Jupyter Docker Stacks.
