# 🚀 MicroStore - Infraestructura y Despliegue

Esta guía te llevará paso a paso desde la creación de la infraestructura en Azure hasta el despliegue completo de la aplicación MicroStore en Kubernetes.

## 📋 Prerrequisitos

- **Azure CLI** instalado y configurado (`az login`)
- **Terraform** >= 1.2
- **Docker** para construir las imágenes
- **kubectl** para gestionar Kubernetes
- Suscripción de Azure activa

## � GUÍA PASO A PASO CON AZURE CLI (COMANDOS ESPECÍFICOS)

### 🔐 PASO 1: Configuración Inicial de Azure CLI

```bash
# 1.1 Verificar que Azure CLI está instalado
az --version
# Deberías ver la versión de Azure CLI

# 1.2 Hacer login en Azure (abrirá el navegador)
az login
# Selecciona tu cuenta y autoriza

# 1.3 Listar todas tus suscripciones
az account list --output table
# Verás algo como:
# Name                     CloudName    SubscriptionId                        State    IsDefault
# ----------------------   -----------  ------------------------------------  -------  -----------
# Azure for Students       AzureCloud   12345678-1234-1234-1234-123456789012  Enabled  True

# 1.4 Seleccionar la suscripción correcta (si tienes varias)
az account set --subscription "12345678-1234-1234-1234-123456789012"
# Reemplaza con tu Subscription ID

# 1.5 Verificar suscripción activa
az account show --query "name" --output tsv
# Debe mostrar el nombre de tu suscripción

# 1.6 Verificar tenant actual
az account show --query tenantId -o tsv
# Debe de mostrar el Id del tenant

# 1.7 Verificar que puedes crear recursos (verificar permisos)
az group list --output table
# Si ves una lista (aunque esté vacía), tienes permisos

# 1.8 Exportamos los ID's para que terraform sepa donde operar
export ARM_SUBSCRIPTION_ID="1234abcd-...."   # tu subscription ID real
export ARM_TENANT_ID="abcd5678-...."         # tu tenant ID real
#Podemos comprobar con:
echo $ARM_SUBSCRIPTION_ID
echo $ARM_TENANT_ID


```

### 🌍 PASO 1.5: Planificación de Región y Recursos (NUEVO)

```bash
# 1.7 Listar TODAS las regiones disponibles en Azure
az account list-locations -o table
# Verás todas las regiones: eastus, westus2, westeurope, etc.

# 1.8 Ver regiones donde YA tienes recursos (si tienes algunos)
az resource list --query "[].location" -o tsv | sort -u
# Muestra solo regiones donde ya tienes algo desplegado

# 1.9 Verificar tamaños de VM disponibles en tu región preferida
REGION="East US"  # Cambiar por tu región preferida
az vm list-skus --location "$REGION" -o table
# Verás todos los tamaños disponibles: Standard_B2s, Standard_D2s_v3, etc.

# 1.10 Verificar específicamente que Standard_B2s está disponible
az vm list-skus --location "$REGION" --query "[?name=='Standard_B2s']" -o table
# Debe mostrar Standard_B2s como disponible

# 1.11 Si Standard_B2s no está disponible, buscar alternativas similares
az vm list-skus --location "$REGION" --query "[?contains(name, 'B2')]" -o table
# Muestra todas las opciones B2: Standard_B2s, Standard_B2ms, etc.

# 1.12 Verificar quotas actuales en la región
az vm list-usage --location "$REGION" -o table
# Muestra limits y uso actual de vCPUs, etc.

# 1.13 Si hay problemas de quota, listar regiones con Standard_B2s disponible
az vm list-skus --all --query "[?name=='Standard_B2s' && locations!=null].locations[]" -o tsv | sort -u
# Te dice en qué regiones puedes usar Standard_B2s
```

**💡 Casos de uso para estos comandos:**

🔍 **Antes de Terraform**: Verificar que tu región elegida soporta Standard_B2s  
🔍 **Si Terraform falla**: Cambiar región en `variables.tf`  
🔍 **Optimización**: Elegir región más cercana a tus usuarios  
🔍 **Troubleshooting**: Verificar quotas si hay errores de límites  

### 🏢 PASO 2: Crear Resource Group Manualmente (Opcional)

```bash
# 2.1 Elegir una región y nombre para tu Resource Group
RESOURCE_GROUP="rg-microstore-dev"
LOCATION="East US"

# 2.2 Crear el Resource Group
az group create \
  --name $RESOURCE_GROUP \
  --location "$LOCATION" \
  --tags Environment=dev Project=MicroStore

# 2.3 Verificar que se creó correctamente
az group show --name $RESOURCE_GROUP --output table
# Deberías ver tu Resource Group listado

# NOTA: Este paso es opcional porque Terraform también puede crear el RG
```

### �🏗️ PASO 3: Infraestructura con Terraform (DETALLADO)

```bash
# 3.1 Ir al directorio de Terraform
cd infra/terraform

# 3.2 Verificar que los archivos están ahí
ls -la
# Deberías ver: main.tf, variables.tf, outputs.tf

# 3.3 Inicializar Terraform (descargar providers)
terraform init
# Verás:
# * Downloading plugin for provider "azurerm"...
# * Downloading plugin for provider "random"...
# Terraform has been successfully initialized!

# 3.4 Validar la configuración de Terraform
terraform validate
# Si todo está bien: "Success! The configuration is valid."

# 3.5 Ver qué recursos se van a crear (DRY RUN)
terraform plan
# Verás una lista detallada de recursos que se crearán:
# + azurerm_resource_group.rg
# + azurerm_container_registry.acr
# + azurerm_kubernetes_cluster.aks
# + azurerm_log_analytics_workspace.law
# + etc.

# 3.6 Aplicar la infraestructura (CREAR TODO)
terraform apply
# Te preguntará: "Do you want to perform these actions?" 
# Escribe: yes

# ESTO TOMA 10-15 MINUTOS - Va a crear:
# ✅ Resource Group
# ✅ Azure Container Registry (ACR)
# ✅ Log Analytics Workspace  
# ✅ AKS Cluster con 2 nodos
# ✅ Permisos entre AKS y ACR
# ✅ NGINX Ingress Controller

# 3.7 Verificar que todo se creó correctamente
terraform output
# Verás todos los outputs como:
# acr_login_server = "microstoreacr1234.azurecr.io"
# aks_cluster_name = "aks-microstore-cluster"
# resource_group_name = "rg-microstore-dev"
```

### ⚙️ PASO 4: Configurar kubectl para AKS

```bash
# 4.1 Volver a la raíz del proyecto
cd ../..

# 4.2 Ejecutar el script de configuración
chmod +x scripts/setup-k8s.sh
./scripts/setup-k8s.sh

# El script hace internamente:
# - Obtiene credenciales: az aks get-credentials --resource-group X --name Y
# - Configura kubectl automáticamente
# - Verifica conectividad al cluster

# 4.3 Verificación manual (opcional)
kubectl cluster-info
# Deberías ver:
# Kubernetes control plane is running at https://aks-microstore-xxxxx.hcp.eastus.azmk8s.io:443

kubectl get nodes
# Deberías ver 2 nodos:
# NAME                       STATUS   ROLES   AGE   VERSION
# aks-agentpool-xxxxx-vmss000000   Ready    agent   5m    v1.28.3
# aks-agentpool-xxxxx-vmss000001   Ready    agent   5m    v1.28.3
```

```bash
# Ir al directorio de Terraform
cd infra/terraform

# Inicializar Terraform
terraform init

# Revisar el plan de ejecución
terraform plan

# Aplicar la infraestructura
terraform apply
```

**Recursos que se crearán:**
- 🏢 Resource Group
- ⚙️ AKS Cluster (2 nodos Standard_B2s)
- 📦 Azure Container Registry (ACR)
- 📊 Log Analytics Workspace
- 🚪 NGINX Ingress Controller

### 🐳 PASO 5: Construir y Subir Imágenes Docker (DETALLADO)

```bash
# 5.1 Verificar que Docker está ejecutándose
docker --version
docker ps
# Si no funciona, inicia Docker Desktop

# 5.2 Ejecutar el script de build automático
chmod +x scripts/build-images.sh
./scripts/build-images.sh

# El script hace internamente:
# - Obtiene el ACR name desde Terraform: terraform output -raw acr_name
# - Hace login: az acr login --name <acr-name>
# - Build de 4 imágenes:
#   * docker build -t <acr>.azurecr.io/microstore-users:latest microUsers/
#   * docker build -t <acr>.azurecr.io/microstore-products:latest microProducts/
#   * docker build -t <acr>.azurecr.io/microstore-orders:latest microOrders/
#   * docker build -t <acr>.azurecr.io/microstore-frontend:latest frontend/
# - Push al ACR: docker push <imagen>

# 5.3 Verificar que las imágenes se subieron
ACR_NAME=$(terraform -chdir=infra/terraform output -raw acr_name)
az acr repository list --name $ACR_NAME --output table
# Deberías ver:
# Result
# ----------------
# microstore-users
# microstore-products  
# microstore-orders
# microstore-frontend

# 5.4 Ver detalles de una imagen específica
az acr repository show-tags --name $ACR_NAME --repository microstore-users --output table
# Deberías ver el tag "latest"
```

### 📝 PASO 6: Actualizar Manifiestos con ACR Real

```bash
# 6.1 Obtener la URL completa del ACR
ACR_LOGIN_SERVER=$(terraform -chdir=infra/terraform output -raw acr_login_server)
echo "Tu ACR es: $ACR_LOGIN_SERVER"
# Ejemplo: microstoreacr1234abcd.azurecr.io

# 6.2 Verificar que los manifiestos tienen placeholders
grep -r "<TU_REGISTRY>" k8s/
# Deberías ver líneas como:
# k8s/users/deployment.yaml:        image: <TU_REGISTRY>/microstore-users:latest

# 6.3 Reemplazar placeholders con tu ACR real
find k8s -name '*.yaml' -exec sed -i "s|<TU_REGISTRY>|$ACR_LOGIN_SERVER|g" {} +

# Para Windows PowerShell (si el comando anterior no funciona):
# Get-ChildItem -Recurse k8s -Filter "*.yaml" | ForEach-Object { (Get-Content $_.FullName) -replace '<TU_REGISTRY>', $ACR_LOGIN_SERVER | Set-Content $_.FullName }

# 6.4 Verificar que se reemplazaron correctamente
grep -r "azurecr.io" k8s/
# Ahora deberías ver líneas como:
# k8s/users/deployment.yaml:        image: microstoreacr1234abcd.azurecr.io/microstore-users:latest
```

### 🚀 PASO 7: Desplegar la Aplicación (DETALLADO)

```bash
# 7.1 Ejecutar validación local (recomendado)
chmod +x scripts/validate-local.sh
./scripts/validate-local.sh
# Verifica sintaxis YAML, namespaces, estructura

# 7.2 Desplegar la aplicación completa
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# El script hace internamente paso a paso:
# 1. Crear namespace: kubectl create namespace microstore
# 2. Aplicar secrets/configmaps: kubectl apply -f k8s/common/
# 3. Desplegar MySQL: kubectl apply -f k8s/mysql/
# 4. Esperar MySQL: kubectl wait --for=condition=ready pod -l app=mysql -n microstore --timeout=300s
# 5. Desplegar microservicios: kubectl apply -f k8s/{users,products,orders}/
# 6. Desplegar frontend: kubectl apply -f k8s/frontend/
# 7. Verificar todos los servicios

# 7.3 Si algo falla, el script muestra automáticamente:
# - Estado de pods
# - Logs recientes
# - Eventos del cluster
# - Sugerencias de solución
```

### 🔍 PASO 8: Verificar el Despliegue (COMANDOS ESPECÍFICOS)

```bash
# 8.1 Ver estado general
kubectl get all -n microstore
# Verás todos los recursos: pods, services, deployments, etc.

# 8.2 Verificar que todos los pods están Running
kubectl get pods -n microstore -o wide
# Estado esperado: STATUS = Running para todos

# 8.3 Ver logs de MySQL (si hay problemas)
kubectl logs -l app=mysql -n microstore --tail=20

# 8.4 Ver logs de un microservicio específico
kubectl logs -l app=users -n microstore --tail=20

# 8.5 Ver eventos del namespace (para debugging)
kubectl get events -n microstore --sort-by='.lastTimestamp'

# 8.6 Verificar servicios y sus IPs internas
kubectl get svc -n microstore
# Verás las ClusterIP de cada servicio

# 8.7 Verificar el Ingress
kubectl get ingress -n microstore
# Verás las rutas configuradas

# 8.8 Obtener IP externa del Ingress Controller
kubectl get svc ingress-nginx-controller -n ingress-nginx
# Busca la EXTERNAL-IP (puede tardar unos minutos en asignarse)
```

```bash
# Ver todos los pods
kubectl get pods -n microstore

# Ver servicios
kubectl get svc -n microstore

# Ver ingress
kubectl get ingress -n microstore

# Logs de un servicio específico
kubectl logs -f deployment/frontend -n microstore
```

### 🌐 PASO 9: Acceder a la Aplicación (OPCIONES DETALLADAS)

#### Opción A: Via Ingress Controller (RECOMENDADO)
```bash
# 9.1 Esperar a que se asigne IP externa (puede tardar 2-5 minutos)
kubectl get svc ingress-nginx-controller -n ingress-nginx --watch
# Espera hasta que aparezca una EXTERNAL-IP (no <pending>)

# 9.2 Obtener la IP del Ingress
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "IP del Ingress: $INGRESS_IP"

# 9.3 Acceder a la aplicación
echo "Frontend: http://$INGRESS_IP/"
echo "Users API: http://$INGRESS_IP/api/users/"
echo "Products API: http://$INGRESS_IP/api/products/"  
echo "Orders API: http://$INGRESS_IP/api/orders/"

# 9.4 Probar en el navegador
# Ve a: http://[IP-DEL-INGRESS]/
```

#### Opción B: LoadBalancer directo en frontend
```bash
# 9.5 Si prefieres acceso directo al frontend
kubectl patch svc frontend-service -n microstore -p '{"spec":{"type":"LoadBalancer"}}'

# 9.6 Obtener IP del frontend
kubectl get svc frontend-service -n microstore --watch
# Espera a que aparezca EXTERNAL-IP

# 9.7 Acceder directamente
FRONTEND_IP=$(kubectl get svc frontend-service -n microstore -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Frontend directo: http://$FRONTEND_IP:5001"
```

#### Opción C: Port Forwarding (para desarrollo/testing)
```bash
# 9.8 Port forward del frontend (en otra terminal)
kubectl port-forward svc/frontend-service -n microstore 5001:5001 &

# 9.9 Acceder localmente
echo "Frontend local: http://localhost:5001"

# 9.10 Para parar el port-forward
# Ctrl+C o: pkill -f "kubectl port-forward"
```

### 🧪 PASO 10: Probar la Aplicación

```bash
# 10.1 Verificar que el frontend carga
curl -I http://$INGRESS_IP/
# Debería devolver: HTTP/1.1 200 OK

# 10.2 Probar la API de usuarios
curl http://$INGRESS_IP/api/users/users
# Debería devolver JSON con lista de usuarios

# 10.3 Probar la API de productos  
curl http://$INGRESS_IP/api/products/products
# Debería devolver JSON con lista de productos

# 10.4 Verificar conectividad a MySQL desde un pod
kubectl exec -it deployment/users -n microstore -- /bin/sh
# Dentro del pod:
# nc -zv mysql-service 3306
# Debería mostrar: mysql-service (10.x.x.x:3306) open
```

## 📊 MONITORIZACIÓN EN AZURE PORTAL

### Ver métricas en Azure Portal:
1. 🌐 Ve a [portal.azure.com](https://portal.azure.com)
2. 🔍 Busca tu Resource Group: `rg-microstore-dev`
3. 📊 Click en tu cluster AKS: `aks-microstore-cluster`
4. 📈 En el menú izquierdo → **"Insights"**
5. 🎯 Verás dashboards con:
   - CPU y memoria de nodos
   - Estado de pods
   - Logs en tiempo real
   - Métricas de red

### Comandos CLI para monitorización:
```bash
# Ver uso de recursos de nodos
kubectl top nodes

# Ver uso de recursos de pods
kubectl top pods -n microstore

# Ver logs en tiempo real
kubectl logs -f deployment/frontend -n microstore

# Ver eventos en tiempo real
kubectl get events -n microstore --watch
```

### Container Insights (Azure Portal)
1. Ve a tu cluster AKS en Azure Portal
2. Click en "Insights" en el menú izquierdo
3. Visualiza métricas, logs y performance

### Logs desde CLI
```bash
# Logs de todos los pods
kubectl logs -l app=frontend -n microstore --tail=100

# Logs de MySQL
kubectl logs -l app=mysql -n microstore --tail=50

# Eventos del namespace
kubectl get events -n microstore --sort-by='.lastTimestamp'
```

## 🧹 9. Limpieza

### Limpiar solo la aplicación
```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

### Destruir toda la infraestructura
```bash
cd infra/terraform
terraform destroy
```

## 🛠️ Troubleshooting

### ❌ Problema: Error en Terraform - "VM size not available in region"
```bash
# 1. Verificar tamaños disponibles en tu región actual
REGION=$(terraform -chdir=infra/terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="azurerm_resource_group") | .values.location' 2>/dev/null || echo "East US")
az vm list-skus --location "$REGION" --query "[?name=='Standard_B2s']" -o table

# 2. Si Standard_B2s no está disponible, buscar alternativas
az vm list-skus --location "$REGION" --query "[?contains(name, 'B2') || contains(name, 'D2')]" -o table

# 3. Buscar regiones donde Standard_B2s SÍ está disponible
az vm list-skus --all --query "[?name=='Standard_B2s' && locations!=null].locations[]" -o tsv | sort -u

# 4. Cambiar región en Terraform (editar variables.tf)
# variable "location" { default = "West US 2" }  # Usar región disponible

# 5. Aplicar cambios
terraform plan
terraform apply
```

### ❌ Problema: Error de quota - "Not enough cores available"
```bash
# 1. Verificar uso actual de vCPUs en tu región
REGION="East US"  # Cambiar por tu región
az vm list-usage --location "$REGION" --query "[?name.value=='Total Regional vCPUs']" -o table

# 2. Ver límites de quota actuales
az vm list-usage --location "$REGION" -o table | grep -i cpu

# 3. Si necesitas más quota, solicitar aumento
echo "Solicita aumento de quota en Azure Portal:"
echo "Portal → Subscriptions → Usage + quotas → Compute → Request increase"

# 4. Como alternativa temporal, usar región con más disponibilidad
az vm list-usage --location "West US 2" --query "[?name.value=='Total Regional vCPUs']" -o table
az vm list-usage --location "Central US" --query "[?name.value=='Total Regional vCPUs']" -o table
```

### ❌ Problema: Error de región - "Region not supported for subscription"
```bash
# 1. Verificar regiones habilitadas en tu suscripción
az account list-locations --query "[?metadata.regionType=='Physical']" -o table

# 2. Ver si tienes recursos en otras regiones
az resource list --query "[].location" -o tsv | sort -u

# 3. Verificar tipos de suscripción (algunas tienen limitaciones regionales)
az account show --query "subscriptionPolicies" -o json

# 4. Regiones más comunes para estudiantes/trial:
# East US, West US 2, Central US, West Europe, Southeast Asia
```

### ❌ Problema: Terraform falla al crear AKS - "InsufficientClusterCapacity" 
```bash
# 1. Verificar disponibilidad de nodos en diferentes zonas
az aks get-versions --location "East US" -o table

# 2. Cambiar a un VM size más pequeño temporalmente
# En variables.tf: vm_size = "Standard_B1s"  (en lugar de Standard_B2s)

# 3. Reducir número de nodos iniciales
# En variables.tf: node_count = 1  (en lugar de 2)

# 4. Probar en región diferente con más capacidad
REGIONS=("West US 2" "Central US" "East US 2" "West Europe")
for region in "${REGIONS[@]}"; do
    echo "Checking $region:"
    az vm list-skus --location "$region" --query "[?name=='Standard_B2s']" -o table
done
```

### Problema: Pods en estado Pending
```bash
# Verificar recursos del cluster
kubectl top nodes
kubectl describe pod <pod-name> -n microstore
```

### Problema: MySQL no inicia
```bash
# Ver logs de MySQL
kubectl logs -l app=mysql -n microstore

# Verificar PVC
kubectl get pvc -n microstore
```

### Problema: Error pulling images
```bash
# Verificar que las imágenes están en el ACR
az acr repository list --name <acr-name>

# Verificar permisos AKS-ACR
kubectl describe pod <pod-name> -n microstore
```

### Problema: Servicios no se comunican
```bash
# Verificar DNS interno
kubectl exec -it <pod-name> -n microstore -- nslookup mysql-service

# Verificar variables de entorno
kubectl exec -it <pod-name> -n microstore -- env | grep DB_
```

## 📈 Escalabilidad

```bash
# Escalar un microservicio
kubectl scale deployment users --replicas=3 -n microstore

# Auto-scaling (HPA)
kubectl autoscale deployment users --cpu-percent=50 --min=1 --max=10 -n microstore
```

## 🔐 Seguridad

- ✅ Secrets para credenciales de base de datos
- ✅ RBAC habilitado en AKS
- ✅ Network policies (configurar según necesidades)
- ✅ ACR con autenticación integrada

## 📚 Estructura del Proyecto

```
📁 MicroStore/
├── 🐳 frontend/               # Aplicación web Flask
├── 🔧 microUsers/             # Microservicio de usuarios
├── 📦 microProducts/          # Microservicio de productos
├── 📋 microOrders/            # Microservicio de órdenes
├── ☸️ k8s/                    # Manifiestos Kubernetes
│   ├── common/               # Secrets y ConfigMaps
│   ├── mysql/                # Base de datos MySQL
│   └── {service}/            # Manifiestos por servicio
├── 🏗️ infra/terraform/        # Infraestructura como código
└── 📜 scripts/               # Scripts de automatización
    ├── setup-k8s.sh         # Configurar kubectl
    ├── build-images.sh      # Construir imágenes
    ├── deploy.sh             # Desplegar aplicación
    └── cleanup.sh            # Limpiar recursos
```

## 🎯 Próximos Pasos

1. **CI/CD Pipeline**: Configurar GitHub Actions para despliegue automático
2. **SSL/TLS**: Añadir certificados Let's Encrypt
3. **Backup**: Configurar backup automático de MySQL
4. **Observabilidad**: Integrar Prometheus y Grafana
5. **Security**: Implementar Pod Security Standards

---

## 🚀 RESUMEN EJECUTIVO - ORDEN DE COMANDOS COMPLETO

```bash
# ✅ PASO 1: Configuración inicial de Azure
az login
az account list --output table
az account set --subscription "tu-subscription-id"

# ✅ PASO 1.5: Validación de región y recursos (RECOMENDADO)
REGION="East US"  # Cambiar por tu región preferida
az vm list-skus --location "$REGION" --query "[?name=='Standard_B2s']" -o table
az vm list-usage --location "$REGION" --query "[?name.value=='Total Regional vCPUs']" -o table

# ✅ PASO 2: Validación previa (opcional pero recomendado)
./scripts/validate-local.sh

# ✅ PASO 3: Crear toda la infraestructura de Azure
cd infra/terraform
terraform init
terraform plan
terraform apply  # Escribir: yes (toma 10-15 minutos)

# ✅ PASO 4: Configurar acceso a Kubernetes
cd ../..
./scripts/setup-k8s.sh

# ✅ PASO 5: Construir y subir imágenes Docker
./scripts/build-images.sh

# ✅ PASO 6: Actualizar manifiestos con ACR real
ACR_LOGIN_SERVER=$(terraform -chdir=infra/terraform output -raw acr_login_server)
find k8s -name '*.yaml' -exec sed -i "s|<TU_REGISTRY>|$ACR_LOGIN_SERVER|g" {} +

# ✅ PASO 7: Desplegar toda la aplicación
./scripts/deploy.sh

# ✅ PASO 8: Obtener IP de acceso
kubectl get svc ingress-nginx-controller -n ingress-nginx
# Usar la EXTERNAL-IP para acceder: http://[IP]/

# ✅ PASO 9: Verificar funcionamiento
curl -I http://[IP]/
kubectl get all -n microstore
```

### 🎯 Tiempos esperados:
- **Terraform apply**: 10-15 minutos
- **Build de imágenes**: 5-10 minutos  
- **Despliegue**: 3-5 minutos
- **Asignación de IP externa**: 2-5 minutos

### 🌐 URLs finales:
- **Frontend**: `http://[INGRESS-IP]/`
- **Users API**: `http://[INGRESS-IP]/api/users/`
- **Products API**: `http://[INGRESS-IP]/api/products/`
- **Orders API**: `http://[INGRESS-IP]/api/orders/`

**🎉 ¡Con estos comandos tendrás MicroStore ejecutándose completamente en Azure AKS!**