#!/usr/bin/env bash
# Test 1 - Cold start latency.
# Measures the time from "scale 0 -> 1" to the first successful HTTP 200,
# i.e. the time the platform needs to bring a workload up from zero.
#
# Usage:
#   ./cold_start.sh <deployment> <url> [iterations]
# Example (expose the app via Ingress first, so <url> stays stable at 0 pods):
#   ./cold_start.sh hello-spin      http://hello.spinkube.local 20
#   ./cold_start.sh hello-container http://hello.spinkube.local 20
set -euo pipefail

DEPLOY="${1:-hello-spin}"
URL="${2:-http://hello.spinkube.local}"
N="${3:-20}"

echo "deployment,iteration,cold_start_ms"
for i in $(seq 1 "$N"); do
  kubectl scale "deploy/$DEPLOY" --replicas=0 >/dev/null
  kubectl wait --for=delete pod -l "app=$DEPLOY" --timeout=60s >/dev/null 2>&1 || true

  kubectl scale "deploy/$DEPLOY" --replicas=1 >/dev/null
  t0=$(date +%s%3N)
  until curl -sf "$URL/" >/dev/null 2>&1; do :; done
  t1=$(date +%s%3N)

  echo "$DEPLOY,$i,$((t1 - t0))"
done
