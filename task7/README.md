# Задание 7. Аудит и обеспечение соответствия политике безопасности контейнеров

---
## Пошаговая инструкция для проверки
### 1. Создание namespace с PodSecurity
Примените манифест:
```bash
kubectl apply -f 01-create-namespace.yaml
```
Namespace `audit-zone` будет создан с метками, включающими `pod-security.kubernetes.io/enforce=restricted`.

---

### 2. Проверка PodSecurity Admission (без Gatekeeper)

Попытайтесь создать небезопасные поды – они **должны** быть отклонены:

```bash
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
# Ошибка: admission webhook "pod-security..." denied

kubectl apply -f insecure-manifests/02-hostpath-pod.yaml
# Ошибка: hostPath запрещён

kubectl apply -f insecure-manifests/03-root-user-pod.yaml
# Ошибка: runAsUser=0 запрещён
```

Безопасные поды из `secure-manifests/` должны создаваться без ошибок:

```bash
kubectl apply -f secure-manifests/01-secure.yaml
kubectl apply -f secure-manifests/02-secure.yaml
kubectl apply -f secure-manifests/03-secure.yaml

kubectl get pods -n audit-zone
```

После проверки удалите безопасные поды (опционально):

```bash
kubectl delete -f secure-manifests/01-secure.yaml
kubectl delete -f secure-manifests/02-secure.yaml
kubectl delete -f secure-manifests/03-secure.yaml
```

---

### 3. Установка OPA Gatekeeper

Если Gatekeeper ещё не установлен в кластере:

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.13/deploy/gatekeeper.yaml
```

Дождитесь готовности подов:

```bash
kubectl get pods -n gatekeeper-system -w
```

---

### 4. Применение шаблонов и ограничений Gatekeeper

Примените шаблоны ограничений:

```bash
kubectl apply -f gatekeeper/constraint-templates/privileged.yaml
kubectl apply -f gatekeeper/constraint-templates/hostpath.yaml
kubectl apply -f gatekeeper/constraint-templates/runasnonroot.yaml
```

Примените ограничения (действуют только на namespace `audit-zone`):

```bash
kubectl apply -f gatekeeper/constraints/privileged.yaml
kubectl apply -f gatekeeper/constraints/hostpath.yaml
kubectl apply -f gatekeeper/constraints/runasnonroot.yaml
```

Проверьте, что ограничения созданы:

```bash
kubectl get constraints
```

---

### 5. Проверка работы Gatekeeper

Теперь небезопасные поды должны отклоняться **и** PodSecurity, **и** Gatekeeper:

```bash
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
# Ошибка от validation.gatekeeper.sh

kubectl apply -f insecure-manifests/02-hostpath-pod.yaml
# Ошибка от validation.gatekeeper.sh

kubectl apply -f insecure-manifests/03-root-user-pod.yaml
# Ошибка от validation.gatekeeper.sh
```

---

### 6. Автоматическая проверка (скрипты)

В папке `verify/` есть два скрипта:

- `verify-admission.sh` – проверяет PodSecurity (блокировка небезопасных, создание безопасных).
- `validate-security.sh` – проверяет Gatekeeper.

Сделайте их исполняемыми и запустите:

```bash
cd verify
chmod +x *.sh
./verify-admission.sh
./validate-security.sh
```

---

## Ожидаемые результаты

- PodSecurity Admission блокирует все три небезопасных пода.
- Безопасные поды создаются успешно.
- OPA Gatekeeper также блокирует нарушения и обеспечивает дополнительные проверки (запрет `privileged`, `hostPath`, требование `runAsNonRoot`).
- Оба механизма работают совместно, обеспечивая многоуровневую защиту.

---

## Очистка

Если нужно удалить все ресурсы, созданные в рамках задания:

```bash
kubectl delete ns audit-zone
kubectl delete constraints --all
kubectl delete constrainttemplates --all
# Удаление Gatekeeper (если не нужен):
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.13/deploy/gatekeeper.yaml
```