# 🚀 MicroStore - Despliegue en Azure Kubernetes Service (AKS)

**Proyecto 2 - Cloud Computing**  
*Implementación de arquitectura de microservicios en Azure Kubernetes Service usando Terraform*

## 📋 Descripción del Proyecto

Este proyecto implementa una **arquitectura de microservicios completa** desplegada en **Azure Kubernetes Service (AKS)** utilizando **Terraform** para la infraestructura como código. La aplicación MicroStore incluye gestión de usuarios, productos y órdenes con un frontend web moderno.

### 🎯 Objetivos del Proyecto
- ✅ **Cluster AKS**: Implementación de cluster Kubernetes en Azure con al menos 2 nodos
- ✅ **Aplicación de Interés**: Despliegue de aplicación MicroStore en AKS  
- ✅ **Supervisión**: Uso de servicios de monitoreo de Azure (Container Insights)
- ✅ **Terraform + AKS**: Automatización completa con Infrastructure as Code

## 🏗️ Arquitectura del Sistema

### Microservicios Implementados
- **👥 microUsers** (Puerto 5002): Gestión de usuarios y autenticación
- **📦 microProducts** (Puerto 5003): Catálogo y gestión de productos  
- **📋 microOrders** (Puerto 5004): Procesamiento de órdenes de compra
- **🌐 frontend** (Puerto 5001): Interfaz web administrativa moderna
- **🗄️ MySQL 8.0**: Base de datos persistente con StatefulSet

### Infraestructura Azure
- **☸️ AKS Cluster**: 2 nodos Standard_B2s con auto-scaling (1-5 nodos)
- **📦 Azure Container Registry (ACR)**: Registro privado de imágenes Docker
- **📊 Log Analytics Workspace**: Monitoreo y observabilidad  
- **🚪 NGINX Ingress Controller**: Balanceador de carga y routing
- **💾 Azure Disk**: Almacenamiento persistente para MySQL

```
🌐 Internet
    ↓
🚪 NGINX Ingress Controller (IP pública)
    ↓  
☸️  AKS Cluster (2-5 nodos)
    ├── 🌐 Frontend (Flask) → 5001
    ├── 👥 Users Service → 5002  
    ├── 📦 Products Service → 5003
    ├── 📋 Orders Service → 5004
    └── 🗄️ MySQL StatefulSet → 3306
        └── 💾 Azure Disk (5GB PVC)
```

## 📋 Requisitos Previos

### Herramientas Necesarias
- **Azure CLI** >= 2.0 - [Instalación](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **Terraform** >= 1.2 - [Instalación](https://www.terraform.io/downloads.html)
- **Docker** - Para construir imágenes localmente
- **kubectl** - Cliente Kubernetes (se instala con Azure CLI)
- **Cuenta Azure** - Suscripción activa (Azure for Students recomendada)

### Verificación de Prerrequisitos
```bash
# Verificar instalaciones
az --version
terraform --version  
docker --version
kubectl version --client

# Login en Azure
az login
```

## 🚀 Guía de Despliegue Completa

### 🔐 1. Configuración Inicial de Azure

```bash
# 1. Login en Azure (abre navegador)
az login

# 2. Listar y seleccionar suscripción
az account list --output table
az account set --subscription "TU-SUBSCRIPTION-ID"

# 3. Validar región y recursos disponibles
REGION="East US"  # Cambiar por tu región preferida
az vm list-skus --location "$REGION" --query "[?name=='Standard_B2s']" -o table
az vm list-usage --location "$REGION" --query "[?name.value=='Total Regional vCPUs']" -o table
```

### 🏗️ 2. Crear Infraestructura con Terraform

```bash
# 1. Ir al directorio de Terraform
cd infra/terraform

# 2. Inicializar Terraform (descargar providers)
terraform init

# 3. Revisar plan de ejecución
terraform plan

# 4. Crear infraestructura (10-15 minutos)
terraform apply
# Escribir: yes

# 5. Verificar outputs
terraform output
```

**Recursos creados:**
- 🏢 Resource Group: `rg-microstore-dev`
- ☸️ AKS Cluster: `aks-microstore-cluster`  
- 📦 Azure Container Registry: `microstoreacr[random]`
- 📊 Log Analytics Workspace para monitoreo
- 🔐 Role assignments automáticos entre AKS y ACR

### ⚙️ 3. Configurar Acceso a Kubernetes

```bash
# 1. Volver a la raíz del proyecto
cd ../..

# 2. Configurar kubectl automáticamente
./scripts/setup-k8s.sh

# 3. Verificar conexión
kubectl cluster-info
kubectl get nodes
```

### 🐳 4. Construir y Subir Imágenes Docker

```bash
# 1. Ejecutar script de build automático
./scripts/build-images.sh

# El script realiza:
# - Login automático al ACR
# - Build de 4 imágenes Docker
# - Push al Azure Container Registry
# - Verificación de imágenes subidas

# 2. Verificar imágenes en ACR
ACR_NAME=$(terraform -chdir=infra/terraform output -raw acr_name)
az acr repository list --name $ACR_NAME --output table
```

### 📝 5. Actualizar Manifiestos de Kubernetes

```bash
# 1. Obtener URL del ACR
ACR_LOGIN_SERVER=$(terraform -chdir=infra/terraform output -raw acr_login_server)

# 2. Reemplazar placeholders en manifiestos
find k8s -name '*.yaml' -exec sed -i "s|<TU_REGISTRY>|$ACR_LOGIN_SERVER|g" {} +

# 3. Verificar cambios
grep -r "azurecr.io" k8s/
```

### 🚀 6. Desplegar Aplicación

```bash
# 1. Ejecutar despliegue completo
./scripts/deploy.sh

# El script despliega en orden:
# 1. Namespace microstore
# 2. Secrets y ConfigMaps  
# 3. MySQL StatefulSet
# 4. Microservicios (users, products, orders)
# 5. Frontend web
# 6. Verificaciones automáticas

# 2. Verificar estado del despliegue
kubectl get all -n microstore
```

### 🌐 7. Acceder a la Aplicación

```bash
# 1. Obtener IP externa del Ingress (puede tardar 2-5 minutos)
kubectl get svc ingress-nginx-controller -n ingress-nginx

# 2. Cuando aparezca EXTERNAL-IP, acceder a:
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "🌐 Frontend: http://$INGRESS_IP/"
echo "👥 Users API: http://$INGRESS_IP/api/users/"  
echo "📦 Products API: http://$INGRESS_IP/api/products/"
echo "📋 Orders API: http://$INGRESS_IP/api/orders/"
```

## 📊 Supervisión y Monitoreo

### Container Insights en Azure Portal
1. 🌐 Acceder a [Azure Portal](https://portal.azure.com)
2. 🔍 Buscar Resource Group: `rg-microstore-dev`
3. ☸️ Seleccionar cluster AKS: `aks-microstore-cluster`
4. 📊 Click en **"Insights"** en el menú izquierdo
5. 📈 Visualizar métricas en tiempo real:
   - CPU y memoria de nodos
   - Estado de pods y contenedores
   - Logs centralizados
   - Alertas y notificaciones

### Monitoreo desde CLI
```bash
# Ver métricas de recursos
kubectl top nodes
kubectl top pods -n microstore

# Logs en tiempo real
kubectl logs -f deployment/frontend -n microstore
kubectl logs -f deployment/users -n microstore

# Eventos del cluster
kubectl get events -n microstore --sort-by='.lastTimestamp'

# Estado detallado de pods
kubectl describe pod <pod-name> -n microstore
```

## 🧪 Pruebas de Funcionamiento

### Verificación de APIs
```bash
# Variables
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Probar frontend
curl -I http://$INGRESS_IP/

# Probar APIs de microservicios
curl http://$INGRESS_IP/api/users/users | jq .
curl http://$INGRESS_IP/api/products/products | jq .  
curl http://$INGRESS_IP/api/orders/orders | jq .
```

### Pruebas de Resiliencia
```bash
# Simular falla de un microservicio
kubectl scale deployment users --replicas=0 -n microstore

# Verificar en frontend (debe mostrar error)
curl http://$INGRESS_IP/api/users/users

# Restaurar servicio
kubectl scale deployment users --replicas=2 -n microstore

# Verificar recuperación automática
kubectl get pods -n microstore --watch
```

## 📁 Estructura del Proyecto

```
📁 microProyecto2_CloudComputing/
├── 🐳 frontend/                    # Aplicación web Flask con UI moderna
│   ├── web/templates/             # Plantillas HTML con Bootstrap
│   ├── web/static/                # CSS, JS, assets
│   ├── Dockerfile                 # Imagen Docker del frontend
│   └── requirements.txt           # Dependencias Python
├── 🔧 microUsers/                 # Microservicio de usuarios
│   ├── users/controllers/         # Lógica de negocio  
│   ├── users/models/              # Modelos de datos
│   └── Dockerfile                 # Imagen Docker
├── 📦 microProducts/              # Microservicio de productos
│   ├── products/controllers/      # API REST de productos
│   ├── products/models/           # Esquemas de BD
│   └── Dockerfile
├── 📋 microOrders/                # Microservicio de órdenes
│   ├── orders/controllers/        # Procesamiento de órdenes
│   ├── orders/models/             # Modelos de órdenes
│   └── Dockerfile  
├── ☸️ k8s/                        # Manifiestos Kubernetes
│   ├── common/                    # Secrets y ConfigMaps
│   ├── mysql/                     # Base de datos MySQL
│   ├── users/                     # Deployment, Service, Ingress
│   ├── products/                  # Manifiestos de productos
│   ├── orders/                    # Manifiestos de órdenes
│   └── frontend/                  # Manifiestos de frontend
├── 🏗️ infra/terraform/            # Infrastructure as Code
│   ├── main.tf                    # Recursos principales de Azure
│   ├── variables.tf               # Variables configurables
│   └── outputs.tf                 # Outputs del despliegue
├── 📜 scripts/                    # Scripts de automatización
│   ├── setup-k8s.sh              # Configurar kubectl
│   ├── build-images.sh           # Build y push de imágenes
│   ├── deploy.sh                  # Despliegue completo
│   ├── cleanup.sh                 # Limpieza de recursos
│   └── validate-local.sh         # Validación previa
├── 📖 INFRASTRUCTURE.md           # Guía detallada de despliegue
├── 🪟 WINDOWS-GUIDE.md            # Guía específica para Windows
├── init.sql                       # Script de inicialización de BD
└── README.md                      # Este archivo
```

## 🛠️ Comandos Útiles

### Gestión del Cluster
```bash
# Ver estado general
kubectl get all -n microstore

# Escalar servicios
kubectl scale deployment users --replicas=3 -n microstore

# Auto-scaling
kubectl autoscale deployment users --cpu-percent=50 --min=1 --max=10 -n microstore

# Port forwarding para desarrollo
kubectl port-forward svc/frontend-service -n microstore 5001:5001
```

### Debugging y Logs
```bash
# Logs de un servicio específico
kubectl logs -l app=users -n microstore --tail=50

# Acceder a un pod
kubectl exec -it deployment/users -n microstore -- /bin/bash

# Verificar configuración
kubectl describe deployment users -n microstore
kubectl get configmap -n microstore -o yaml
```

### Gestión de Imágenes
```bash
# Listar imágenes en ACR
az acr repository list --name $(terraform -chdir=infra/terraform output -raw acr_name)

# Ver tags de una imagen
az acr repository show-tags --name $ACR_NAME --repository microstore-users

# Limpiar imágenes antiguas
az acr repository delete --name $ACR_NAME --repository microstore-users --tag latest
```

## 🧹 Limpieza de Recursos

### ⚠️ IMPORTANTE: Gestión de Costos
Los recursos de AKS consumen créditos de Azure. **Se recomienda destruir el cluster** después de las pruebas y recrearlo antes de la sustentación.

### Limpiar Solo la Aplicación
```bash
# Mantener infraestructura, eliminar aplicación
./scripts/cleanup.sh

# Verificar limpieza
kubectl get all -n microstore
```

### Destruir Toda la Infraestructura
```bash
# ⚠️ CUIDADO: Esto elimina TODO
cd infra/terraform
terraform destroy
# Escribir: yes

# Verificar en Azure Portal que todo se eliminó
az group list --query "[?name=='rg-microstore-dev']" --output table
```

### Recrear Antes de Sustentación
```bash
# Ejecutar toda la secuencia nuevamente
az login
cd infra/terraform && terraform apply
cd ../.. && ./scripts/setup-k8s.sh
./scripts/build-images.sh
# Actualizar manifiestos y desplegar...
```

## 📈 Características Técnicas Implementadas

### ✅ Kubernetes en Azure
- **AKS Cluster** con 2 nodos mínimo, auto-scaling hasta 5
- **Node Pools** configurados con Standard_B2s
- **RBAC** habilitado para seguridad
- **Container Insights** para monitoreo nativo

### ✅ Aplicación de Microservicios
- **4 microservicios** independientes en Flask
- **MySQL 8.0** con persistencia en Azure Disk
- **NGINX Ingress** para balanceamiento de carga
- **Secrets y ConfigMaps** para configuración

### ✅ Infrastructure as Code
- **Terraform** para toda la infraestructura
- **Azure Container Registry** integrado
- **Role Assignments** automáticos
- **Log Analytics** pre-configurado

### ✅ DevOps y Automatización
- **Scripts bash** para automatización completa
- **Docker multi-stage builds** optimizados
- **Health checks** y **readiness probes**
- **Validación previa** con `validate-local.sh`

## 🎯 Demostración de Objetivos

### 1. ✅ Cluster AKS Implementado
- **Verificación Portal**: Azure Portal → AKS → Insights
- **Verificación CLI**: `kubectl get nodes` y `az aks show`
- **Dos nodos mínimo**: Configurado en `variables.tf`

### 2. ✅ Aplicación Desplegada  
- **Frontend accesible**: `http://[INGRESS-IP]/`
- **APIs funcionales**: Endpoints `/api/users/`, `/api/products/`, `/api/orders/`
- **Base de datos persistente**: MySQL con datos de prueba

### 3. ✅ Supervisión Activa
- **Container Insights**: Métricas en tiempo real en Azure Portal
- **Logs centralizados**: `kubectl logs` y Azure Monitor
- **Alertas configurables**: Disponibles en Azure Portal

### 4. ✅ Terraform + AKS (Opcional)
- **Infrastructure as Code**: Todo en `infra/terraform/`
- **Despliegue reproducible**: `terraform apply`
- **Gestión de estado**: terraform.tfstate

## 🔗 Enlaces de Referencia

- 📖 [Guía oficial AKS](https://learn.microsoft.com/es-es/azure/aks/learn/quick-kubernetes-deploy-portal)
- 🏗️ [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- ☸️ [Kubernetes Documentation](https://kubernetes.io/docs/)
- 📊 [Azure Monitor for Containers](https://docs.microsoft.com/azure/azure-monitor/containers/)

---

**🎓 Proyecto desarrollado para Cloud Computing - Implementación completa de microservicios en Azure Kubernetes Service**


