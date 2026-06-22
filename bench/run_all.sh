#!/usr/bin/env bash
# Convenience wrapper: build + push both apps, deploy them, then run the 3 tests.
# Assumes a working SpinKube cluster (see ../README.md) and that you are in bench/.
set -euo pipefail

REG="${REG:-ttl.sh}"
URL="${URL:-http://hello.spinkube.local}"

echo ">> build & push Spin (Wasm) app"
( cd ../apps/spin-hello && spin registry push --build "$REG/hello-spin:24h" )

echo ">> build & push container baseline"
( cd ../apps/container-hello \
  && docker build -t "$REG/hello-container:24h" . \
  && docker push "$REG/hello-container:24h" )

echo ">> deploy both workloads"
kubectl apply -f ../k8s/spinapp.yaml
kubectl apply -f ../k8s/container-deployment.yaml
kubectl rollout status deploy/hello-spin      --timeout=180s
kubectl rollout status deploy/hello-container --timeout=180s

echo ">> Test 1 - cold start"
./cold_start.sh hello-spin      "$URL" 20 | tee ../results/coldstart_spin.csv
./cold_start.sh hello-container "$URL" 20 | tee ../results/coldstart_container.csv

echo ">> Test 2 - size & density"
./size_density.sh "$REG/hello-spin:24h"      hello-spin      20 | tee ../results/size_density_spin.txt
./size_density.sh "$REG/hello-container:24h" hello-container 20 | tee ../results/size_density_container.txt

echo ">> Test 3 - throughput & latency (k6)"
URL="$URL" k6 run --summary-export ../results/load_spin.json load_test.js

echo ">> done. Results in ../results/"
