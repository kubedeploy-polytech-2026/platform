#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
context=k3d-kubedeploy
namespace=argocd

if ! kubectl --context "$context" --namespace "$namespace" \
  get deployment argocd-server >/dev/null 2>&1; then
  printf 'Argo CD is not installed; run make argocd-up first\n' >&2
  exit 1
fi

kubectl --context "$context" apply -f "$project_root/argocd/root-application.yaml"

kubectl --context "$context" --namespace "$namespace" wait \
  --for=jsonpath='{.status.sync.status}'=Synced \
  application/kubedeploy-platform --timeout=300s
kubectl --context "$context" --namespace "$namespace" wait \
  --for=create application/envoy-gateway --timeout=120s
kubectl --context "$context" --namespace "$namespace" wait \
  --for=jsonpath='{.status.sync.status}'=Synced \
  application/envoy-gateway --timeout=300s
kubectl --context "$context" --namespace "$namespace" wait \
  --for=jsonpath='{.status.health.status}'=Healthy \
  application/envoy-gateway --timeout=300s

kubectl --context "$context" --namespace envoy-gateway-system \
  rollout status deployment/envoy-gateway --timeout=300s
kubectl --context "$context" --namespace "$namespace" get applications
