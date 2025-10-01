#!/bin/bash
set -euo pipefail

echo "⚙️ Configurando acceso a AKS y preparando entorno..."

# Verificar si Terraform fue ejecutado
if [[ ! -f "infra/terraform/terraform.tfstate" ]]; then
    echo "❌ Error: No se encontró terraform.tfstate"
    echo "💡 Primero ejecuta: cd infra/terraform && terraform apply"
    exit 1
fi

# Obtener información del cluster desde Terraform
echo "📋 Obteniendo información del cluster AKS..."
RESOURCE_GROUP=$(terraform -chdir=infra/terraform output -raw resource_group_name)
CLUSTER_NAME=$(terraform -chdir=infra/terraform output -raw aks_cluster_name)
ACR_NAME=$(terraform -chdir=infra/terraform output -raw acr_name)

echo "🎯 Configuración detectada:"
echo "  • Resource Group: $RESOURCE_GROUP"
echo "  • Cluster AKS: $CLUSTER_NAME"
echo "  • ACR: $ACR_NAME"

# Configurar kubectl
echo "🔧 Configurando kubectl..."
if ! az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing; then
    echo "❌ Error configurando kubectl. Verifica que estés autenticado en Azure."
    exit 1
fi

# Verificar conectividad
echo "🔍 Verificando conectividad al cluster..."
if ! kubectl cluster-info; then
    echo "❌ Error: No se puede conectar al cluster AKS"
    exit 1
fi

# Mostrar información del cluster
echo ""
echo "📊 Información del cluster:"
echo "=========================="
kubectl get nodes
echo ""
kubectl get namespaces

# Verificar que NGINX Ingress Controller esté instalado
echo ""
echo "🚪 Verificando Ingress Controller..."
if kubectl get namespace ingress-nginx &>/dev/null; then
    echo "✅ NGINX Ingress Controller ya está instalado"
    kubectl get pods -n ingress-nginx
else
    echo "⚠️ NGINX Ingress Controller no detectado"
    echo "💡 Se instalará automáticamente durante el despliegue"
fi

# Crear namespace para la aplicación si no existe
echo ""
echo "📁 Preparando namespace microstore..."
kubectl create namespace microstore --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Configuración completada"
echo "🚀 Siguiente paso: ./scripts/build-images.sh (si no has subido las imágenes)"
echo "🚀 O directamente: ./scripts/deploy.sh"