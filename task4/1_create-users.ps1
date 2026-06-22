# create-users.ps1
# Создание пользователей Kubernetes с сертификатами (Windows)

$ErrorActionPreference = "Stop"

# Пути к CA сертификатам Minikube (по умолчанию)
$CA_CRT = "$env:USERPROFILE\.minikube\ca.crt"
$CA_KEY = "$env:USERPROFILE\.minikube\ca.key"

# Список пользователей
$USERS = @("devops-user", "security-user", "dev-user", "viewer-user")

# Создаём папку для сертификатов
New-Item -ItemType Directory -Force -Path ".\certs" | Out-Null

foreach ($USER in $USERS) {
    Write-Host "=== Creating user: $USER ===" -ForegroundColor Green

    # Генерация приватного ключа
    openssl genrsa -out ".\certs\$USER.key" 2048

    # Создание CSR (Certificate Signing Request)
    openssl req -new -key ".\certs\$USER.key" -out ".\certs\$USER.csr" -subj "/CN=$USER/O=group-$USER"

    # Подписываем сертификат с помощью CA кластера
    openssl x509 -req -in ".\certs\$USER.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial -out ".\certs\$USER.crt" -days 365

    # Создаём kubeconfig для пользователя
    kubectl config set-credentials $USER --client-certificate=".\certs\$USER.crt" --client-key=".\certs\$USER.key" --embed-certs=true

    # Создаём контекст
    kubectl config set-context "${USER}-context" --cluster=minikube --user=$USER
}

Write-Host "=== Users created successfully ===" -ForegroundColor Green