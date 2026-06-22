#!/bin/bash
set -e

NAMESPACE="audit-zone"

echo "=== Проверка PodSecurity Admission ==="
echo "1. Попытка создать привилегированный под (должна быть ошибка):"
kubectl apply -f insecure-manifests/01-privileged-pod.yaml && echo "ОШИБКА: под должен быть отклонён" || echo "✅ Отклонён (ожидаемо)"

echo "2. Попытка создать под с hostPath (должна быть ошибка):"
kubectl apply -f insecure-manifests/02-hostpath-pod.yaml && echo "ОШИБКА: под должен быть отклонён" || echo "✅ Отклонён (ожидаемо)"

echo "3. Попытка создать под от root (должна быть ошибка):"
kubectl apply -f insecure-manifests/03-root-user-pod.yaml && echo "ОШИБКА: под должен быть отклонён" || echo "✅ Отклонён (ожидаемо)"

echo "=== Проверка безопасных манифестов (должны создаться) ==="
kubectl apply -f secure-manifests/01-secure.yaml
kubectl apply -f secure-manifests/02-secure.yaml
kubectl apply -f secure-manifests/03-secure.yaml

echo "Проверка созданных подов в namespace $NAMESPACE:"
kubectl get pods -n $NAMESPACE

echo "=== Очистка ==="
kubectl delete -f secure-manifests/01-secure.yaml || true
kubectl delete -f secure-manifests/02-secure.yaml || true
kubectl delete -f secure-manifests/03-secure.yaml || true