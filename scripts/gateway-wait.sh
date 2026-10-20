#!/usr/bin/env bash
set -Eeuo pipefail

context=k3d-kubedeploy
kubectl --context "$context" wait --for=condition=Accepted \
  gatewayclass/kubedeploy-envoy --timeout=180s
kubectl --context "$context" --namespace kubedeploy-gateway wait \
  --for=condition=Accepted gateway/kubedeploy --timeout=180s
kubectl --context "$context" --namespace kubedeploy-gateway wait \
  --for=condition=Programmed gateway/kubedeploy --timeout=180s
selector='gateway.envoyproxy.io/owning-gateway-namespace=kubedeploy-gateway,gateway.envoyproxy.io/owning-gateway-name=kubedeploy'
deployment="$(kubectl --context "$context" --namespace envoy-gateway-system \
  get deployments --selector "$selector" -o name)"
if [[ -z "$deployment" || "$deployment" == *$'\n'* ]]; then
  echo 'Expected exactly one Envoy deployment for Gateway kubedeploy' >&2
  exit 1
fi
kubectl --context "$context" --namespace envoy-gateway-system \
  rollout status "$deployment" --timeout=180s
