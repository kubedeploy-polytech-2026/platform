# Контроллер в кластере

Перед синхронизацией создайте Secret из локального ключа App:

```bash
GITHUB_APP_PRIVATE_KEY_FILE="$HOME/.config/kubedeploy/app.pem" bash scripts/controller-secret.sh
```

Application `deploy-controller` читает `controller` из `main`. Образ закреплён
по digest релиза; пакет GHCR должен быть Public. Контроллер использует отдельный
ServiceAccount, запускается без root с read-only файловой системой.
Ключ не хранится в Git. Состояние находится на PVC, обновление заменяет один Pod.
PVC сохраняется при удалении Application и prune.

```bash
kubectl --context k3d-kubedeploy -n kubedeploy-system rollout status deployment/deploy-controller
kubectl --context k3d-kubedeploy -n kubedeploy-system logs deployment/deploy-controller --tail=20
```

Запрос создаётся workflow `Request deployment` репозитория `environment`.
