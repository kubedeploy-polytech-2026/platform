# Политики

Argo CD устанавливает Gatekeeper 3.23.1 и каталог `policies` из `main`.
В `kubedeploy-demo` запрещены privileged-контейнеры, `latest`, образы без тега
или digest и отсутствие requests/limits для CPU и памяти. Шаблоны workload
проверяются через ExpansionTemplate. Системные namespace не входят в область правил.
Webhook видит requests, подставленные Kubernetes из limits. Gator проверяет
исходный объект без этих подстановок.

`make policies-check` запускает Gator без кластера; та же проверка выполняется в CI.
`make policies-smoke` проверяет настоящий webhook через серверный dry-run,
не создавая тестовые workload. Ожидаемый отказ должен содержать имя политики.
