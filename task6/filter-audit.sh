#!/bin/bash
# filter-audit.sh – извлекает подозрительные события из audit.log

AUDIT_LOG="${1:-audit.log}"
OUTPUT="${2:-audit-extract.json}"

if [ ! -f "$AUDIT_LOG" ]; then
    echo "Файл $AUDIT_LOG не найден"
    exit 1
fi

echo "Анализируем $AUDIT_LOG..."

# 1. Доступ к секретам (попытки чтения секретов, особенно в kube-system)
SECRETS=$(jq -s '[.[] | select(.objectRef.resource == "secrets" and .verb == "get")]' "$AUDIT_LOG")

# 2. Создание привилегированных подов (containers с securityContext.privileged == true)
PRIVILEGED=$(jq -s '[.[] | select(.objectRef.resource == "pods" and .verb == "create" and (.requestObject.spec.containers[]?.securityContext.privileged == true))]' "$AUDIT_LOG")

# 3. Использование kubectl exec (подресурс exec)
EXEC=$(jq -s '[.[] | select(.objectRef.subresource == "exec")]' "$AUDIT_LOG")

# 4. Создание RoleBinding с roleRef.name == "cluster-admin"
RB=$(jq -s '[.[] | select(.objectRef.resource == "rolebindings" and .verb == "create" and (.requestObject.roleRef.name == "cluster-admin"))]' "$AUDIT_LOG")

# 5. Попытка удаления audit-policy (ресурс policies.audit.k8s.io или в URI audit-policy)
AUDIT_DEL=$(jq -s '[.[] | select(.verb == "delete" and (.objectRef.apiGroup == "audit.k8s.io" or (.requestURI | test("audit-policy"))))]' "$AUDIT_LOG")

# Объединяем все события, убираем возможные дубликаты по auditID
jq -s 'add | unique_by(.auditID)' \
  <(echo "$SECRETS") \
  <(echo "$PRIVILEGED") \
  <(echo "$EXEC") \
  <(echo "$RB") \
  <(echo "$AUDIT_DEL") > "$OUTPUT"

COUNT=$(jq '. | length' "$OUTPUT")
echo "Извлечено $COUNT подозрительных событий в $OUTPUT"