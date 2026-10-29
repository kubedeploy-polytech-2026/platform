#!/usr/bin/env bash
set -euo pipefail
: "${GITHUB_APP_PRIVATE_KEY_FILE:?Set GITHUB_APP_PRIVATE_KEY_FILE}"
[[ -r "$GITHUB_APP_PRIVATE_KEY_FILE" ]] || { echo 'App private key is not readable' >&2; exit 1; }
context=k3d-kubedeploy
kubectl --context "$context" apply --server-side --field-manager=kubedeploy-local-secrets -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: kubedeploy-system
YAML
kubectl --context "$context" --namespace kubedeploy-system create secret generic deploy-controller-github-app \
  --from-file="private-key.pem=$GITHUB_APP_PRIVATE_KEY_FILE" --dry-run=client -o yaml |
  kubectl --context "$context" --namespace kubedeploy-system apply --server-side \
    --field-manager=kubedeploy-local-secrets -f -
