#!/usr/bin/env bash
# Test 2 - Artifact size & node density.
#   1) compressed artifact size pulled from the registry (crane + jq)
#   2) average steady-state RAM per pod at a given replica count (metrics-server)
#
# Usage:
#   ./size_density.sh <image> <deployment> [replicas]
#   ./size_density.sh ttl.sh/hello-spin:24h      hello-spin      20
#   ./size_density.sh ttl.sh/hello-container:24h hello-container 20
set -euo pipefail

IMG="${1:-ttl.sh/hello-spin:24h}"
DEPLOY="${2:-hello-spin}"
REPLICAS="${3:-20}"

echo "== artifact size: $IMG =="
crane manifest "$IMG" \
  | jq '[.layers[].size] | add' \
  | awk '{printf "  %.2f MB (compressed)\n", $1/1024/1024}'

echo "== RAM per pod ($DEPLOY, avg over $REPLICAS replicas) =="
kubectl scale "deploy/$DEPLOY" --replicas="$REPLICAS" >/dev/null
kubectl rollout status "deploy/$DEPLOY" --timeout=180s >/dev/null
sleep 15  # let usage settle
kubectl top pod -l "app=$DEPLOY" --no-headers \
  | awk '{gsub(/Mi/,"",$3); s+=$3; n++} END{printf "  avg %.1f Mi over %d pods\n", s/n, n}'
