# 🪟 GUÍA ESPECÍFICA PARA WINDOWS POWERSHELL

## 🎯 Comandos adaptados para PowerShell en Windows

### 📋 1. Verificación inicial en PowerShell
```powershell
# Verificar Azure CLI
az --version

# Verificar Terraform
terraform --version

# Verificar Docker
docker --version

# Verificar kubectl
kubectl version --client
```

### 🔐 2. Login y configuración de Azure
```powershell
# Login (abrirá navegador)
az login

# Listar suscripciones
az account list --output table

# Seleccionar suscripción (reemplaza con tu ID)
az account set --subscription "12345678-1234-1234-1234-123456789012"

# Verificar suscripción activa
az account show --query "name" --output tsv
```

### 🌍 2.5. Validación de región y recursos (PowerShell)
```powershell
# Ver todas las regiones disponibles
az account list-locations --output table

# Definir región preferida
$region = "East US"

# Verificar que Standard_B2s está disponible en tu región
az vm list-skus --location $region --query "[?name=='Standard_B2s']" --output table

# Verificar quotas de vCPU en la región
az vm list-usage --location $region --query "[?name.value=='Total Regional vCPUs']" --output table

# Si Standard_B2s no está disponible, buscar alternativas
az vm list-skus --location $region --query "[?contains(name, 'B2') || contains(name, 'D2')]" --output table

# Buscar regiones donde Standard_B2s SÍ está disponible
az vm list-skus --all --query "[?name=='Standard_B2s' && locations!=null].locations[]" --output tsv | Sort-Object -Unique

# Ver regiones donde ya tienes recursos (si aplica)
az resource list --query "[].location" --output tsv | Sort-Object -Unique
```

### 🏗️ 3. Crear infraestructura
```powershell
# Ir al directorio de Terraform
Set-Location infra\terraform

# Inicializar Terraform
terraform init

# Ver plan de ejecución
terraform plan

# Aplicar infraestructura (CONFIRMAR CON 'yes')
terraform apply

# Ver outputs cuando termine
terraform output
```

### ⚙️ 4. Configurar kubectl (PowerShell específico)
```powershell
# Volver a la raíz del proyecto
Set-Location ..\..

# Si los scripts .sh no funcionan en Windows, comandos manuales:
$resourceGroup = terraform -chdir=infra/terraform output -raw resource_group_name
$clusterName = terraform -chdir=infra/terraform output -raw aks_cluster_name

# Configurar kubectl
az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing

# Verificar conexión
kubectl cluster-info
kubectl get nodes
```

### 🐳 5. Build de imágenes (PowerShell)
```powershell
# Obtener info del ACR
$acrName = terraform -chdir=infra/terraform output -raw acr_name
$acrLoginServer = terraform -chdir=infra/terraform output -raw acr_login_server

# Login al ACR
az acr login --name $acrName

# Build de las 4 imágenes
docker build -t "${acrLoginServer}/microstore-users:latest" microUsers/
docker build -t "${acrLoginServer}/microstore-products:latest" microProducts/
docker build -t "${acrLoginServer}/microstore-orders:latest" microOrders/
docker build -t "${acrLoginServer}/microstore-frontend:latest" frontend/

# Push al ACR
docker push "${acrLoginServer}/microstore-users:latest"
docker push "${acrLoginServer}/microstore-products:latest"
docker push "${acrLoginServer}/microstore-orders:latest"
docker push "${acrLoginServer}/microstore-frontend:latest"

# Verificar que se subieron
az acr repository list --name $acrName --output table
```

### 📝 6. Actualizar manifiestos (PowerShell)
```powershell
# Obtener URL del ACR
$acrLoginServer = terraform -chdir=infra/terraform output -raw acr_login_server
Write-Host "ACR Login Server: $acrLoginServer"

# Reemplazar <TU_REGISTRY> en todos los manifiestos
Get-ChildItem -Recurse k8s -Filter "*.yaml" | ForEach-Object { 
    (Get-Content $_.FullName) -replace '<TU_REGISTRY>', $acrLoginServer | Set-Content $_.FullName 
}

# Verificar que se reemplazaron
Select-String -Path "k8s\*\*.yaml" -Pattern "azurecr.io"
```

### 🚀 7. Desplegar aplicación (PowerShell manual)
```powershell
# Crear namespace
kubectl create namespace microstore

# Aplicar recursos comunes
kubectl apply -f k8s\common\

# Aplicar MySQL
kubectl apply -f k8s\mysql\

# Esperar que MySQL esté listo (máximo 5 minutos)
kubectl wait --for=condition=ready pod -l app=mysql -n microstore --timeout=300s

# Si MySQL no está listo, ver logs:
# kubectl logs -l app=mysql -n microstore --tail=50

# Aplicar microservicios
kubectl apply -f k8s\users\
kubectl apply -f k8s\products\
kubectl apply -f k8s\orders\

# Aplicar frontend
kubectl apply -f k8s\frontend\

# Verificar estado
kubectl get all -n microstore
```

### 🔍 8. Verificación y acceso (PowerShell)
```powershell
# Ver todos los pods
kubectl get pods -n microstore -o wide

# Obtener IP del Ingress Controller (puede tardar unos minutos)
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Obtener IP cuando esté disponible
$ingressIP = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
Write-Host "Frontend URL: http://$ingressIP/"
Write-Host "Users API: http://$ingressIP/api/users/"
Write-Host "Products API: http://$ingressIP/api/products/"
Write-Host "Orders API: http://$ingressIP/api/orders/"

# Probar conectividad
Invoke-WebRequest -Uri "http://$ingressIP/" -Method Head
```

### 🧪 9. Testing y debugging (PowerShell)
```powershell
# Ver logs de un servicio específico
kubectl logs -l app=frontend -n microstore --tail=20

# Ver eventos del namespace
kubectl get events -n microstore --sort-by='.lastTimestamp'

# Ejecutar comandos dentro de un pod
kubectl exec -it deployment/users -n microstore -- /bin/sh

# Port forwarding para testing local
kubectl port-forward svc/frontend-service -n microstore 5001:5001
# Luego abrir: http://localhost:5001
```

### 🧹 10. Limpieza (PowerShell)
```powershell
# Opción 1: Limpiar solo la aplicación
kubectl delete namespace microstore

# Opción 2: Destruir toda la infraestructura
Set-Location infra\terraform
terraform destroy
# Escribir: yes
```

## 🚨 Troubleshooting específico para Windows

### Error: "az command not found"
```powershell
# Instalar Azure CLI desde:
# https://aka.ms/installazurecliwindows
# O usar winget:
winget install Microsoft.AzureCLI
```

### Error: "terraform command not found"
```powershell
# Instalar Terraform desde:
# https://www.terraform.io/downloads.html
# O usar chocolatey:
choco install terraform
```

### Error: "kubectl command not found"
```powershell
# Instalar kubectl:
az aks install-cli
# O descargar desde: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

### Error: Scripts .sh no funcionan en Windows
```powershell
# Opción 1: Usar Git Bash
# Opción 2: Usar WSL (Windows Subsystem for Linux)
# Opción 3: Usar los comandos PowerShell de esta guía

# Para habilitar WSL:
wsl --install
```

### Error: Docker no está disponible
```powershell
# Instalar Docker Desktop desde:
# https://www.docker.com/products/docker-desktop
# Asegúrate de que esté ejecutándose antes de build
```

## 🎯 Comando único para Windows (todo en uno)

```powershell
# Ejecutar todo de una vez (después de az login)
$subscription = "TU-SUBSCRIPTION-ID"
az account set --subscription $subscription
Set-Location infra\terraform
terraform init
terraform apply -auto-approve
Set-Location ..\..
$rg = terraform -chdir=infra/terraform output -raw resource_group_name
$cluster = terraform -chdir=infra/terraform output -raw aks_cluster_name
$acr = terraform -chdir=infra/terraform output -raw acr_login_server
az aks get-credentials --resource-group $rg --name $cluster --overwrite-existing
az acr login --name (terraform -chdir=infra/terraform output -raw acr_name)
docker build -t "$acr/microstore-users:latest" microUsers/
docker build -t "$acr/microstore-products:latest" microProducts/
docker build -t "$acr/microstore-orders:latest" microOrders/
docker build -t "$acr/microstore-frontend:latest" frontend/
docker push "$acr/microstore-users:latest"
docker push "$acr/microstore-products:latest"
docker push "$acr/microstore-orders:latest"
docker push "$acr/microstore-frontend:latest"
Get-ChildItem -Recurse k8s -Filter "*.yaml" | ForEach-Object { (Get-Content $_.FullName) -replace '<TU_REGISTRY>', $acr | Set-Content $_.FullName }
kubectl create namespace microstore
kubectl apply -f k8s\common\
kubectl apply -f k8s\mysql\
kubectl wait --for=condition=ready pod -l app=mysql -n microstore --timeout=300s
kubectl apply -f k8s\users\
kubectl apply -f k8s\products\
kubectl apply -f k8s\orders\
kubectl apply -f k8s\frontend\
kubectl get all -n microstore
$ip = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
Write-Host "¡Listo! Accede a: http://$ip/"
```

**⚠️ IMPORTANTE**: Reemplaza `TU-SUBSCRIPTION-ID` con tu ID real de suscripción antes de ejecutar.