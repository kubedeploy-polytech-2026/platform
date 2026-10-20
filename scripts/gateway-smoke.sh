#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
context=k3d-kubedeploy
bash "$project_root/scripts/gateway-wait.sh"
selector='gateway.envoyproxy.io/owning-gateway-namespace=kubedeploy-gateway,gateway.envoyproxy.io/owning-gateway-name=kubedeploy'
service="$(kubectl --context "$context" --namespace envoy-gateway-system \
  get services --selector "$selector" -o name)"
if [[ -z "$service" || "$service" == *$'\n'* ]]; then
  echo 'Expected exactly one Envoy Service for Gateway kubedeploy' >&2
  exit 1
fi

work_dir="$(mktemp -d)"
port_forward_pid=''
# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
  result=$?
  if (( result != 0 )); then
    cat "$work_dir/port-forward.log" >&2 || true
  fi
  if [[ -n "$port_forward_pid" ]]; then
    kill "$port_forward_pid" 2>/dev/null || true
    wait "$port_forward_pid" 2>/dev/null || true
  fi
  rm -rf "$work_dir"
}
trap 'cleanup' EXIT
kubectl --context "$context" --namespace envoy-gateway-system \
  port-forward "$service" :80 --address=127.0.0.1 >"$work_dir/port-forward.log" 2>&1 &
port_forward_pid=$!

for ((attempt=0; attempt<30; attempt++)); do
  if ! kill -0 "$port_forward_pid" 2>/dev/null; then
    echo 'Envoy port-forward exited before readiness' >&2
    exit 1
  fi
  local_port="$(awk '/^Forwarding from 127.0.0.1:/ {split($3, address, ":"); print address[2]; exit}' "$work_dir/port-forward.log")"
  if [[ -n "$local_port" ]]; then
    # This hostname intentionally cannot match the Gateway listener.
    status="$(curl --silent --show-error --max-time 5 --output /dev/null \
      --write-out '%{http_code}' --header 'Host: gateway-smoke.invalid' \
      "http://127.0.0.1:$local_port/" || true)"
    if [[ "$status" == 404 ]]; then
      echo 'Gateway smoke passed: Accepted, Programmed, Envoy ready, unmatched host returns HTTP 404'
      exit 0
    fi
  fi
  sleep 1
done
echo 'Gateway smoke failed: expected HTTP 404 from Envoy for unmatched hostname' >&2
exit 1
