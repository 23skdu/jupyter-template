# Tests

Test tooling for this repository. Everything here mirrors the CI jobs so you can
run the same checks locally without waiting for a push.

> **Two directories called `tests`.** This one holds test *tooling* (the Makefile
> you are reading, the values fixture). The chart's unit test suites live in
> `helm/jupyter-template/tests/*_test.yaml` and are the subject of these tools.

## Quick start

```bash
make -C tests          # everything: linters, helm lint, template, unit tests
make -C tests help     # list every target
```

`check` runs:

| Step | Target | Equivalent CI job |
| --- | --- | --- |
| hadolint on `Dockerfile` | `lint-docker` | `lint-docker` |
| yamllint with `.yamllint` | `lint-yaml` | `lint-yaml` |
| actionlint on `.github/workflows` | `lint-workflows` | `lint-yaml` |
| `helm lint --strict` | `chart-lint` | `lint-helm` (Helm 3.22 and 4.3) |
| `helm template` with default values | `render` | `lint-helm` |
| `helm template` with every feature on | `render-all` | `lint-helm` |
| 148 `helm unittest` assertions | `unit` | `lint-helm` |

## Prerequisites

`make doctor` prints the binary each target will use and flags anything missing:

```
$ make -C tests doctor
helm (3.x)   bin/helm-v3.22.0                      v3.22.0+g144ca65
helm (4.x)   bin/helm-v4.3.0                      v4.3.0+gbec5b06
hadolint     bin/hadolint                         Haskell Dockerfile Linter 2.14.0
yamllint     bin/yamllint/bin/yamllint            yamllint 1.38.0
actionlint   bin/actionlint                       1.7.12
helm-unittest  installed for bin/helm-v3.22.0
```

To fetch everything pinned, without touching your `PATH`:

```bash
make -C tests tools     # downloads into ./bin (gitignored)
```

That installs Helm 3.22.0 and 4.3.0 side by side — useful because the two
versions live under the same `helm` name and CI tests both. Every target prefers
`./bin` and falls back to whatever is on `PATH`, so `make -C tests check` works
either way.

To uninstall: `make -C tests clean`.

## Targets

### Full runs

| Target | Description |
| --- | --- |
| `check` | Everything, in CI order. Exits non-zero on the first failure. |
| `lint` | All linters, including `helm lint`. |
| `lint-ci` | Only the linters that CI runs outside the Helm matrix. |
| `test` | Alias for `check`. |

### Helm

| Target | Description |
| --- | --- |
| `unit` | `helm unittest --strict` against the default Helm. |
| `chart-lint` | `helm lint --strict`. |
| `render` | `helm template` with default values. |
| `render-all` | `helm template` with every optional feature enabled. |
| `helm3` | `chart-lint` + `render` + `render-all` + `unit` on Helm 3.22.0. |
| `helm4` | The same on Helm 4.3.0. |

`helm3` and `helm4` verify the binary really is the expected version before
running, so a stale `helm` on `PATH` fails loudly instead of silently testing
the wrong version.

### Individual linters

| Target | Description |
| --- | --- |
| `lint-docker` | hadolint on `Dockerfile`. |
| `lint-yaml` | yamllint, using the `.yamllint` config shared with CI. |
| `lint-workflows` | actionlint on `.github/workflows`. |

### Environment

| Target | Description |
| --- | --- |
| `doctor` | Show resolved binaries and versions. |
| `plugin` | Install the `helm-unittest` plugin (idempotent; also runs automatically). |
| `tools` | Download pinned Helm, hadolint, actionlint and a yamllint venv. |
| `clean` | Remove `./bin` and generated JUnit reports. |

## Options

Append any of these to a target.

| Option | Example | Description |
| --- | --- | --- |
| `SUITE` | `make -C tests unit SUITE='tests/*ingress*'` | Run a subset of the suites. |
| `JUNIT` | `make -C tests unit JUNIT=report.xml` | Also write a JUnit report (XUnit format by default). |
| `COLOR` | `make -C tests unit COLOR=always` | Force or suppress coloured output (`always`/`never`). |
| `HELM` | `make -C tests chart-lint HELM=/usr/local/bin/helm` | Use a specific Helm binary. |

> `SUITE` is passed to `helm unittest -f`, whose glob is **relative to the
> chart**, not to this directory. Keep the `tests/` prefix — `SUITE=ingress`
> matches nothing.

`SUITE` accepts ordinary globs:

```bash
make -C tests unit SUITE='tests/*ingress*'      # 9 assertions
make -C tests unit SUITE='tests/*schema*'       # 20 assertions
make -C tests unit SUITE='tests/*hpa*' JUNIT=hpa.xml
```

## Suites

`helm/jupyter-template/tests/` holds 148 assertions across 11 suites.

| Suite | Assertions | Covers |
| --- | --- | --- |
| `deployment_test.yaml` | 42 | Image resolution, env, probes, security context, resources, scheduling, metadata |
| `persistence_test.yaml` | 15 | PVC creation and pod wiring for both mount modes |
| `helpers_test.yaml` | 12 | Name/fullname derivation, 63-char DNS truncation, chart and app-version labels |
| `httproute_test.yaml` | 12 | Parent refs, rules, filters, generated `backendRefs`, timeouts |
| `ingress_test.yaml` | 9 | Hosts, paths, TLS, class, annotations |
| `test-connection_test.yaml` | 9 | The `helm test` probe pod |
| `serviceaccount_test.yaml` | 8 | Creation, automount, naming |
| `token-secret_test.yaml` | 8 | Token generation, quoting, and `create`/`existingSecret` |
| `service_test.yaml` | 7 | Types, ports, Spark UI, selectors |
| `hpa_test.yaml` | 6 | Metrics and replica bounds |
| `schema_test.yaml` | 20 | Rejection cases for invalid values |

### Writing a suite

A suite is a YAML file under `helm/jupyter-template/tests/`:

```yaml
suite: <suite name>
templates:
  - service.yaml          # chart-relative; one or more templates to render
release:
  name: rel
  namespace: ns
tests:
  - it: should describe the behaviour
    set:                  # deep-merged over the chart defaults
      spark.ui.enabled: true
    asserts:
      - contains:
          path: spec.ports
          content:
            name: spark-ui
            port: 4040
```

Things worth knowing:

- **`set` deep-merges**, it does not replace. To clear a key, set it to `null`
  (`livenessProbe.httpGet: null`). Writing a whole block and expecting it to
  replace is a common source of confusing failures.
- **`path` is a string**, not a YAML list. Use bracket syntax for keys containing
  dots or slashes: `metadata.labels['app.kubernetes.io/name']`.
- **Target one template at a time** when a suite lists several. `documentIndex`
  is global across every template in the suite, so a Service-only assertion needs
  `template: service.yaml` on the test.
- **`_helpers.tpl` cannot be rendered directly.** Exercise helpers through the
  resource that consumes them — see `helpers_test.yaml`.
- **The chart's `values.schema.json` is enforced automatically**, so any suite
  setting an invalid value will fail. `schema_test.yaml` relies on this and
  asserts `failedTemplate: {}`.

Run one suite while iterating:

```bash
make -C tests unit SUITE='tests/*deployment*'
```

Full assertion reference: <https://github.com/helm-unittest/helm-unittest>

## The all-features values file

`tests/values-all-features.yaml` switches on every optional part of the chart —
Ingress with TLS, HTTPRoute with filters and timeouts, persistence, Spark UI,
autoscaling, extra env, `envFrom`, probes, scheduling constraints and volumes.

`make -C tests render-all` and the CI `helm template (all features enabled)` step
both consume it, so a template branch that only renders under a combination you
forget to set will still be caught.
