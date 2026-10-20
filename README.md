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

## Приложения

Score-описание backend, его Service и HTTPRoute находятся в соседнем
репозитории `environment`.

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

Root Application читает `clusters/local` из ветки `main` этого репозитория.
Отдельные Applications управляют Envoy Gateway `v1.9.2` и общим HTTP Gateway.

```bash
make bootstrap
make platform-status
```

Для root Application, Envoy Gateway и Gateway включены автоматическая
синхронизация и prune, но отключён self-heal. Ручное изменение ресурса останется в кластере, а Argo CD покажет drift.

## Общий HTTP Gateway

Application `gateway` читает каталог `gateway` из `main` и создаёт:

- namespace `kubedeploy-gateway`;
- GatewayClass `kubedeploy-envoy` с controller Envoy Gateway;
- EnvoyProxy `local` с Service типа `ClusterIP`;
- Gateway `kubedeploy` с HTTP listener на порту 80 для `kubedeploy.local`.

Локальный доступ идёт через port-forward.

```bash
make gateway-status
make gateway-smoke
```

## Удаление кластера

```bash
make cluster-down
```
