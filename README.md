# SpinKube — empirical tests & vertical demo

Reproducible benchmarks for the project activity on **SpinKube** (Serverless
WebAssembly on Kubernetes). The goal is **didactic**: measure, with data, the
properties claimed for the platform (fast cold start, small footprint, high
density, scale-to-zero) by comparing the *same* HTTP API implemented twice:

| Variant | Packaging | Runs as |
|---|---|---|
| `apps/spin-hello` | Spin app compiled to **Wasm** (OCI artifact) | `SpinApp` → `containerd-shim-spin` + wasmtime |
| `apps/container-hello` | **Container** image (distroless) | standard `Deployment` (and optionally Knative) |

Both have identical logic and identical CPU/memory limits, so the only variable
is the execution model.

## Repository layout

```
apps/
  spin-hello/        # Spin (Go/TinyGo) Wasm app: GET / and GET /count (KV)
  container-hello/   # equivalent Go HTTP server + Dockerfile (baseline)
k8s/
  spinapp.yaml                 # Wasm workload (Spin Operator)
  container-deployment.yaml    # container baseline (Deployment + Service)
  keda-scaledobject-cpu.yaml   # CPU elasticity (min 1) for the load test
  keda-http-scaledobject.yaml  # true scale-to-zero (KEDA HTTP add-on)
  knative-service.yaml         # optional Knative baseline for scale-to-zero
bench/
  cold_start.sh      # Test 1
  size_density.sh    # Test 2
  load_test.js       # Test 3 (k6)
  run_all.sh         # build + push + deploy + run everything
results/             # CSV/JSON/txt output (added after running)
```

## Prerequisites

- A SpinKube dev cluster (kind with the Spin shim pre-installed), the **Spin
  Operator**, CRDs and the `spin` runtime class — see the
  [SpinKube quickstart](https://www.spinkube.dev/docs/install/quickstart/).
- [`spin`](https://developer.fermyon.com/spin/v2/install) CLI + the
  [`spin kube`](https://www.spinkube.dev/docs/install/spin-kube-plugin/) plugin, and TinyGo.
- `kubectl`, `helm`, Docker.
- `metrics-server` (RAM readings), [KEDA](https://keda.sh) (+ the HTTP add-on for
  scale-to-zero), an Ingress controller (e.g. ingress-nginx).
- Tooling: [`k6`](https://k6.io), [`crane`](https://github.com/google/go-containerregistry), `jq`.

## Quick start

```bash
# 1. build, push, deploy both workloads and run all three tests
cd bench
REG=ttl.sh URL=http://hello.spinkube.local ./run_all.sh
```

Or run each step manually (see below).

## The tests

### Test 1 — Cold start latency (`cold_start.sh`)
**What it shows:** a Wasm module starts in milliseconds, while a container Pod
needs seconds (image pull, runtime init). **Method:** scale the workload to zero,
then time the first HTTP 200; repeat N times and report p50/p95. Run it for both
`hello-spin` and `hello-container` (and, optionally, the Knative service).

### Test 2 — Artifact size & node density (`size_density.sh`)
**What it shows:** the Wasm OCI artifact is KB–MB vs tens–hundreds of MB for a
container image, so pulls are faster and far more instances fit on a node.
**Method:** read the compressed artifact size from the registry, then ramp the
replica count and read steady-state RAM per pod (pods/node).

### Test 3 — Throughput & tail latency (`load_test.js`, k6)
**What it shows:** at the same replicas and limits, the lightweight runtime
sustains comparable or better throughput and tail latency for a stateless HTTP
workload. **Method:** fixed load, record RPS and p50/p95/p99 + error rate for
both variants.

### Vertical demo — from code to autoscaled Wasm service
End-to-end flow that shows the platform working live:

```bash
cd apps/spin-hello
spin registry push --build ttl.sh/hello-spin:24h     # build + publish (OCI)
spin kube deploy   --from  ttl.sh/hello-spin:24h     # deploy via the operator
kubectl apply -f ../../k8s/keda-http-scaledobject.yaml  # scale-to-zero on HTTP
# idle -> 0 replicas; the first request wakes it in milliseconds
curl http://hello.spinkube.local/count                  # stateful endpoint (KV)
```

## A note on KEDA & scale-to-zero

KEDA's **CPU/memory** scalers cannot scale to zero (they keep `minReplicaCount ≥ 1`),
so they are used here only for elasticity under load (`keda-scaledobject-cpu.yaml`).
For genuine **scale-to-zero** on HTTP traffic we use the **KEDA HTTP Add-on**
(`keda-http-scaledobject.yaml`): its interceptor buffers the first request while
the Deployment scales 0→1, which is also a clean way to measure end-to-end cold
start. Knative (`knative-service.yaml`) is included as an alternative
container-based scale-to-zero baseline.

## Results

`results/` is intentionally empty: run the scripts on your cluster and commit the
CSV/JSON/txt files, then summarise them in the presentation (slides 22–25).
