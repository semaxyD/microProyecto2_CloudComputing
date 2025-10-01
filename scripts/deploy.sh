#!/bin/bash
set -euo pipefail

echo "🚀 Desplegando aplicación MicroStore en AKS..."

# Verificar que kubectl está configurado
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl no está configurado o no puede conectar al cluster"
    echo "💡 Ejecuta: az aks get-credentials --resource-group <rg-name> --name <cluster-name>"
    exit 1
fi

# Verificar que estamos en el directorio correcto
if [[ ! -d "k8s" ]]; then
    echo "❌ Error: No se encuentra el directorio k8s. Ejecuta desde la raíz del proyecto."
    exit 1
fi

echo "📋 Información del cluster:"
kubectl cluster-info

# Función para mostrar logs en caso de error
show_debug_info() {
    local service=$1
    echo ""
    echo "🔍 Información de debug para $service:"
    echo "================================="
    echo "📊 Estado de pods:"
    kubectl get pods -l app=$service -n microstore -o wide || true
    echo ""
    echo "📋 Descripción del pod:"
    kubectl describe pods -l app=$service -n microstore | tail -20 || true
    echo ""
    echo "📋 Logs recientes:"
    kubectl logs -l app=$service -n microstore --tail=30 || true
    echo ""
    echo "📋 Eventos del namespace:"
    kubectl get events -n microstore --sort-by='.lastTimestamp' | tail -10 || true
}

# 1. Crear namespace si no existe
echo "🔧 Configurando namespace microstore..."
kubectl create namespace microstore --dry-run=client -o yaml | kubectl apply -f -

# 2. Aplicar recursos comunes (secrets y configmaps)
echo "🔑 Aplicando recursos comunes..."
if ! kubectl apply -f k8s/common/; then
    echo "❌ Error aplicando recursos comunes"
    kubectl get events -n microstore --sort-by='.lastTimestamp' | tail -10
    exit 1
fi

# 3. Desplegar MySQL
echo "🗄️ Desplegando MySQL..."
if ! kubectl apply -f k8s/mysql/; then
    echo "❌ Error aplicando manifiestos de MySQL"
    kubectl get events -n microstore --sort-by='.lastTimestamp' | tail -10
    exit 1
fi

echo "⏳ Esperando que MySQL esté listo (máximo 5 minutos)..."
if ! kubectl wait --for=condition=ready pod -l app=mysql -n microstore --timeout=300s; then
    echo "❌ Error: MySQL no está listo después de 5 minutos"
    show_debug_info "mysql"
    echo ""
    echo "💡 Posibles soluciones:"
    echo "   • Verificar recursos del cluster: kubectl top nodes"
    echo "   • Revisar volúmenes persistentes: kubectl get pvc -n microstore"
    echo "   • Verificar secrets: kubectl get secrets -n microstore"
    exit 1
fi

echo "✅ MySQL está listo!"

# 4. Desplegar microservicios
echo "🔧 Desplegando microservicios..."
if ! kubectl apply -f k8s/users/; then
    echo "❌ Error aplicando manifiestos de users"
    show_debug_info "users"
    exit 1
fi

if ! kubectl apply -f k8s/products/; then
    echo "❌ Error aplicando manifiestos de products"
    show_debug_info "products"
    exit 1
fi

if ! kubectl apply -f k8s/orders/; then
    echo "❌ Error aplicando manifiestos de orders"
    show_debug_info "orders"
    exit 1
fi

# 5. Desplegar frontend
echo "🌐 Desplegando frontend..."
if ! kubectl apply -f k8s/frontend/; then
    echo "❌ Error aplicando manifiestos de frontend"
    show_debug_info "frontend"
    exit 1
fi

# 6. Esperar a que todos los pods estén listos
echo "⏳ Esperando que todos los servicios estén listos..."

services=("users" "products" "orders" "frontend")
failed_services=()

for service in "${services[@]}"; do
    echo "  • Esperando $service..."
    if ! kubectl wait --for=condition=ready pod -l app=$service -n microstore --timeout=180s; then
        echo "⚠️ Warning: $service no está listo después de 3 minutos"
        failed_services+=("$service")
        show_debug_info "$service"
    else
        echo "  ✅ $service está listo"
    fi
done

# Mostrar advertencias si algún servicio falló
if [[ ${#failed_services[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️ Los siguientes servicios no están completamente listos:"
    for service in "${failed_services[@]}"; do
        echo "   • $service"
    done
    echo ""
    echo "💡 El despliegue puede continuar, pero verifica estos servicios manualmente."
fi

# 7. Verificar el estado del despliegue
echo ""
echo "📊 Estado del despliegue:"
echo "========================"

echo "🟢 Pods:"
kubectl get pods -n microstore -o wide

echo ""
echo "🔗 Servicios:"
kubectl get svc -n microstore

echo ""
echo "🌐 Ingress:"
kubectl get ingress -n microstore

# 8. Obtener información de acceso
echo ""
echo "🎯 Información de acceso:"
echo "========================"

# Obtener IP del LoadBalancer si existe
FRONTEND_IP=$(kubectl get svc frontend-service -n microstore -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ -n "$FRONTEND_IP" ]]; then
    echo "🌐 Frontend disponible en: http://$FRONTEND_IP:5001"
else
    echo "🌐 Frontend: Esperando asignación de IP externa..."
    echo "   Puedes usar port-forward: kubectl port-forward svc/frontend-service -n microstore 5001:5001"
fi

# Verificar Ingress Controller
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ -n "$INGRESS_IP" ]]; then
    echo "🚪 Ingress Controller IP: $INGRESS_IP"
    echo "   Puedes acceder via:"
    echo "   - Frontend: http://$INGRESS_IP/"
    echo "   - Users API: http://$INGRESS_IP/api/users/"
    echo "   - Products API: http://$INGRESS_IP/api/products/"
    echo "   - Orders API: http://$INGRESS_IP/api/orders/"
else
    echo "🚪 Ingress Controller: Esperando asignación de IP..."
fi

echo ""
echo "🔍 Comandos útiles:"
echo "==================="
echo "• Ver logs: kubectl logs -f deployment/<service-name> -n microstore"
echo "• Escalar: kubectl scale deployment <service-name> --replicas=3 -n microstore"
echo "• Port-forward: kubectl port-forward svc/<service-name> <local-port>:<service-port> -n microstore"
echo "• Describir pod: kubectl describe pod <pod-name> -n microstore"

echo ""
echo "✅ ¡Despliegue completado exitosamente!"
echo "🎉 MicroStore está ejecutándose en Kubernetes"
