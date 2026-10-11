#!/usr/bin/env bash
set -Eeuo pipefail

context=k3d-kubedeploy
namespace=kubedeploy-backend
local_port=18080
log_file="${TMPDIR:-/tmp}/kubedeploy-backend-port-forward.log"

kubectl --context "$context" --namespace "$namespace" \
  port-forward service/backend "$local_port:8080" >"$log_file" 2>&1 &
port_forward_pid=$!
trap 'kill "$port_forward_pid" 2>/dev/null || true' EXIT

for attempt in {1..20}; do
  if response="$(curl --fail --silent --show-error \
    "http://127.0.0.1:$local_port/health" 2>/dev/null)"; then
    if [[ "$response" != '{"status":"ok"}' ]]; then
      printf 'Unexpected health response: %s\n' "$response" >&2
      exit 1
    fi
    printf 'Backend health check passed: %s\n' "$response"
    exit 0
  fi
  sleep 1
done

printf 'Backend health check failed; port-forward output:\n' >&2
cat "$log_file" >&2
exit 1
