#!/usr/bin/env bash
set -Eeuo pipefail

context=k3d-kubedeploy
namespace=argocd
local_port=18081

if ! kubectl --context "$context" --namespace "$namespace" \
  get service argocd-server >/dev/null 2>&1; then
  printf 'Argo CD is not installed; run make argocd-up first\n' >&2
  exit 1
fi

if ! password="$(kubectl --context "$context" --namespace "$namespace" \
  get secret argocd-initial-admin-secret \
  -o go-template='{{.data.password | base64decode}}')"; then
  printf 'Initial admin password is unavailable\n' >&2
  exit 1
fi

printf 'Argo CD UI: https://127.0.0.1:%d\n' "$local_port"
printf 'Username: admin\n'
printf 'Password: %s\n' "$password"
printf 'Keep this command running while the UI is open.\n'

exec kubectl --context "$context" --namespace "$namespace" \
  port-forward service/argocd-server "$local_port:443"
