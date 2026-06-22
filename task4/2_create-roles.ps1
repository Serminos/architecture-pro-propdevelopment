# create-roles.ps1
# Создание ролей RBAC (Windows)

function Apply-Manifest {
    param([string]$Manifest)
    $tempFile = [System.IO.Path]::GetTempFileName()
    $Manifest | Out-File -FilePath $tempFile -Encoding utf8
    kubectl apply -f $tempFile
    Remove-Item $tempFile
}

# Создаём namespace development, если его нет
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -

# 1. Кластерная роль для просмотра секретов
$manifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-viewer
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
"@
Apply-Manifest $manifest

# 2. Роль для разработчиков в namespace "development"
$manifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: namespace-editor
rules:
- apiGroups: ["", "apps", "batch", "extensions"]
  resources: ["pods", "deployments", "services", "configmaps", "secrets", "jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
"@
Apply-Manifest $manifest

Write-Host "=== Roles created successfully ===" -ForegroundColor Green