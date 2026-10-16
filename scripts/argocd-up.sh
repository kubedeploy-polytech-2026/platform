#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
context=k3d-kubedeploy
namespace=argocd

if ! kubectl --context "$context" get --raw=/readyz >/dev/null 2>&1; then
  printf 'Kubernetes context %s is unavailable; run make cluster-up first\n' "$context" >&2
  exit 1
fi

kubectl --context "$context" create namespace "$namespace" \
  --dry-run=client -o yaml | kubectl --context "$context" apply -f -

for attempt in 1 2 3; do
  if kubectl --context "$context" apply -k "$project_root/argocd" \
    --server-side --force-conflicts --field-manager=kubedeploy-bootstrap; then
    break
  fi
  if ((attempt == 3)); then
    printf 'Argo CD installation failed after %d attempts\n' "$attempt" >&2
    exit 1
  fi
  printf 'Argo CD installation attempt %d failed; retrying\n' "$attempt" >&2
  sleep 3
done

deployments=(
  argocd-applicationset-controller
  argocd-dex-server
  argocd-notifications-controller
  argocd-redis
  argocd-repo-server
  argocd-server
)

for deployment in "${deployments[@]}"; do
  kubectl --context "$context" --namespace "$namespace" \
    rollout status "deployment/$deployment" --timeout=300s
done

kubectl --context "$context" --namespace "$namespace" \
  rollout status statefulset/argocd-application-controller --timeout=300s

kubectl --context "$context" --namespace "$namespace" get pods
