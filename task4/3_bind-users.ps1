# bind-users.ps1
# Привязка пользователей к ролям (Windows)

function Apply-Manifest {
    param([string]$Manifest)
    $tempFile = [System.IO.Path]::GetTempFileName()
    $Manifest | Out-File -FilePath $tempFile -Encoding utf8
    kubectl apply -f $tempFile
    Remove-Item $tempFile
}

# 1. DevOps → cluster-admin
$manifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devops-admin-binding
subjects:
- kind: User
  name: devops-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
"@
Apply-Manifest $manifest

# 2. Security → secret-viewer
$manifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-secret-binding
subjects:
- kind: User
  name: security-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-viewer
  apiGroup: rbac.authorization.k8s.io
"@
Apply-Manifest $manifest

# 3. Developer → namespace-editor в namespace development
$manifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-editor-binding
  namespace: development
subjects:
- kind: User
  name: dev-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-editor
  apiGroup: rbac.authorization.k8s.io
"@
Apply-Manifest $manifest

# 4. Viewer → view
$manifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer-binding
subjects:
- kind: User
  name: viewer-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
"@
Apply-Manifest $manifest

Write-Host "=== Bindings created successfully ===" -ForegroundColor Green