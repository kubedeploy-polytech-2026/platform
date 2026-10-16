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

## Системный слой

Root Application читает конфигурацию из этого репозитория и создаёт первый
управляемый системный компонент - Envoy Gateway `v1.9.2`.

```bash
make bootstrap
make platform-status
```

Для root Application и Envoy Gateway включены автоматическая синхронизация и
prune, но отключён self-heal. Ручное изменение ресурса останется в кластере, а
Argo CD покажет drift.

На этом этапе Envoy Gateway установлен как controller. GatewayClass, Gateway и
маршрут к backend будут добавлены отдельным изменением.

## Удаление кластера

```bash
make cluster-down
```
