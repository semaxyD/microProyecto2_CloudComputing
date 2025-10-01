#!/bin/bash
set -euo pipefail

echo "🧹 Limpiando recursos de MicroStore en Kubernetes..."

# Verificar que kubectl está configurado
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl no está configurado o no puede conectar al cluster"
    exit 1
fi

# Función para eliminar recursos con timeout
cleanup_resources() {
    local resource_path=$1
    local resource_name=$2
    
    if [[ -d "$resource_path" ]]; then
        echo "🗑️ Eliminando $resource_name..."
        kubectl delete -f "$resource_path" --ignore-not-found --timeout=60s || {
            echo "⚠️ Warning: Timeout eliminando $resource_name, forzando eliminación..."
            kubectl delete -f "$resource_path" --ignore-not-found --force --grace-period=0 || true
        }
    else
        echo "⚠️ Warning: No se encuentra el directorio $resource_path"
    fi
}

# Verificar que estamos en el directorio correcto
if [[ ! -d "k8s" ]]; then
    echo "❌ Error: No se encuentra el directorio k8s. Ejecuta desde la raíz del proyecto."
    exit 1
fi

echo "📋 Estado actual del namespace microstore:"
kubectl get all -n microstore 2>/dev/null || echo "Namespace microstore no encontrado o vacío"

# Eliminar en orden inverso al despliegue
cleanup_resources "k8s/frontend" "Frontend"
cleanup_resources "k8s/orders" "Orders Service"
cleanup_resources "k8s/products" "Products Service"
cleanup_resources "k8s/users" "Users Service"
cleanup_resources "k8s/mysql" "MySQL Database"
cleanup_resources "k8s/common" "Common Resources (Secrets & ConfigMaps)"

# Esperar a que se eliminen los PVCs
echo "⏳ Esperando eliminación de volúmenes persistentes..."
kubectl delete pvc --all -n microstore --timeout=60s || {
    echo "⚠️ Warning: Timeout eliminando PVCs, continuando..."
}

# Eliminar el namespace si existe
echo "🗑️ Eliminando namespace microstore..."
kubectl delete namespace microstore --ignore-not-found --timeout=60s || {
    echo "⚠️ Warning: Timeout eliminando namespace, forzando eliminación..."
    kubectl delete namespace microstore --ignore-not-found --force --grace-period=0 || true
}

echo ""
echo "🔍 Verificando limpieza..."
echo "========================"

# Verificar que no queden recursos
REMAINING_PODS=$(kubectl get pods -n microstore --no-headers 2>/dev/null | wc -l || echo "0")
REMAINING_PVC=$(kubectl get pvc -n microstore --no-headers 2>/dev/null | wc -l || echo "0")

if [[ "$REMAINING_PODS" -eq 0 && "$REMAINING_PVC" -eq 0 ]]; then
    echo "✅ Limpieza completada exitosamente"
    echo "🎯 Todos los recursos de MicroStore han sido eliminados"
else
    echo "⚠️ Warning: Algunos recursos pueden estar pendientes de eliminación:"
    kubectl get all,pvc -n microstore 2>/dev/null || echo "Namespace no accesible"
fi

echo ""
echo "💡 Para destruir completamente la infraestructura de Azure:"
echo "=========================================================="
echo "cd infra/terraform"
echo "terraform destroy"
echo ""
echo "🔄 Para recrear el despliegue:"
echo "==============================="
echo "./scripts/deploy.sh"

echo ""
echo "✅ Proceso de limpieza completado"
