# KubeDeploy Platform

Локальная платформа для деплоя

## Требования

- Docker;
- k3d;
- kubectl;
- make.

## Создание кластера

```bash
make cluster-up
```

Команда создаёт кластер `kubedeploy`, ожидает готовности узлов и выводит их
состояние.

## Проверка

```bash
make cluster-status
```

Ожидаемый результат: один control-plane и один worker в состоянии `Ready`.

## Минимальный запуск

Сначала соберите образ в соседнем репозитории:

```bash
cd ../backend
make test
make image
```

Затем импортируйте образ в k3d и разверните backend:

```bash
cd ../platform
make backend-deploy
make backend-status
make backend-smoke
```

## Argo CD

Платформа использует Argo CD `v3.5.5`. Для локальной среды устанавливается
non-HA вариант, закреплённый по release commit.

```bash
make argocd-up
make argocd-status
```

Чтобы открыть UI:

```bash
make argocd-ui
```

Команда выведет одноразовый пароль администратора и запустит port-forward на
`https://127.0.0.1:18081`. Пока port-forward работает, используйте имя
пользователя `admin`.

На этом этапе Argo CD только установлен. Application и управление системными
компонентами через GitOps будут добавлены отдельной веткой.

## Удаление кластера

```bash
make cluster-down
```
