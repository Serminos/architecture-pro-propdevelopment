#!/bin/bash
set -e

echo "=== Проверка Gatekeeper Constraints ==="
kubectl get constraints

echo "=== Попытка создания пода с нарушением через Gatekeeper ==="
kubectl run test-privileged --image=nginx --privileged -n audit-zone --dry-run=client -o yaml | kubectl apply -f - && echo "ОШИБКА: Gatekeeper должен был запретить" || echo "✅ Запрещено Gatekeeper"

echo "=== Создание безопасного пода ==="
kubectl run test-secure --image=nginx -n audit-zone --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod test-secure -n audit-zone || true

echo "Проверка завершена."