## Инструкция по настройке аудита, симуляции инцидентов и анализу логов

### Окружение
- **ОС:** Ubuntu 26.04 (виртуальная машина)
- **ПО:** Docker, Minikube v1.38.1, kubectl, jq
- **Кластер:** Minikube с драйвером Docker, CNI Calico
- **Политика аудита:** `audit-policy.yaml` (включена в apiserver через `--extra-config`)
- **Вывод аудита:** `stdout` контейнера kube-apiserver (`--audit-log-path=-`)

---

### 1. Создание политики аудита

```bash
mkdir -p ~/.minikube/files/etc/ssl/certs
cat > ~/.minikube/files/etc/ssl/certs/audit-policy.yaml << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    verbs: ["create", "delete", "update", "patch", "get", "list"]
    resources:
      - group: ""
        resources: ["pods", "secrets", "configmaps", "serviceaccounts", "roles", "rolebindings"]
  - level: Metadata
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["pods", "secrets", "configmaps", "serviceaccounts", "namespaces"]
EOF
```

### 2. Запуск Minikube с аудитом

```bash
minikube start \
  --network-plugin=cni --cni=calico \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml \
  --extra-config=apiserver.audit-log-path=-
```

**Результат:** кластер запущен, аудит включён, события пишутся в stdout apiserver.

### 3. Симуляция подозрительных действий

```bash
./simulate-incident.sh
```

**Результат:** созданы namespace `secure-ops`, сервисный аккаунт `monitoring`, под `attacker-pod`, выполнен неудачный доступ к секретам от имени `monitoring`, создан привилегированный под `privileged-pod`, попытка `exec` в CoreDNS (ошибка `cat` в Alpine), попытка удаления `audit-policy.yaml` с локального пути (несуществующий файл), создан RoleBinding `escalate-binding` с правами `cluster-admin`.

### 4. Извлечение аудит-лога

```bash
# Получить ID контейнера apiserver
CONTAINER_ID=$(minikube ssh "docker ps --filter name=k8s_kube-apiserver -q")
# Сохранить все логи контейнера
minikube ssh "docker logs $CONTAINER_ID 2>&1" > full_apiserver.log
# Отфильтровать только аудит-события (по наличию "apiVersion":"audit.k8s.io/v1")
grep '"apiVersion":"audit.k8s.io/v1"' full_apiserver.log > audit.log
```

**Результат:** файл `audit.log` содержит JSON-строки реальных аудит-событий.

### 5. Фильтрация подозрительных событий

Используется скрипт `filter-audit.sh`, который отбирает события по следующим критериям:
- Чтение секретов (`verb: get`, `resource: secrets`),
- Создание привилегированных подов (`privileged: true`),
- Выполнение команд в подах (`subresource: exec`),
- Создание RoleBinding с ролью `cluster-admin`,
- Удаление политик аудита (`verb: delete`, ресурс `policies.audit.k8s.io` или URI содержит `audit-policy`).

```bash
chmod +x filter-audit.sh
./filter-audit.sh audit.log audit-extract.json
```

**Результат:** в `audit-extract.json` записано **5 подозрительных событий**:
1. Чтение секрета `bootstrap-token-0ajev6` в `kube-system` пользователем `kubernetes-admin`.
2. Создание привилегированного пода `privileged-pod` (первое событие) пользователем `minikube-user`.
3. Создание ещё одного привилегированного пода `privileged-pod` (повторное) тем же пользователем.
4. Системное событие создания пода `calico-node` (привилегированный init-контейнер) - можно отнести к легитимной активности, но скрипт его извлёк, так как формально там `privileged: true`.
5. Создание пода `kube-proxy` (также привилегированный контейнер) - аналогично.

*Примечание:* События `exec` и удаления политики не были записаны из-за ограничений политики аудита (не отслеживаются подресурсы и API-группа `audit.k8s.io`). RoleBinding `escalate-binding` не попал в лог, так как политика аудита на момент выполнения не включала `rbac.authorization.k8s.io` в правило уровня `RequestResponse` с нужными глаголами.

### 6. Отчёт `analysis.md`

На основе `audit-extract.json` сформирован отчёт, описывающий каждое подозрительное событие, его инициатора и возможные последствия.