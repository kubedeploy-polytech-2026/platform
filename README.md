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

## Удаление кластера

```bash
make cluster-down
```
