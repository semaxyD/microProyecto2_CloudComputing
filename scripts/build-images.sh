#!/bin/bash
set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐳 Script de Build y Push de Imágenes Docker para MicroStore${NC}"
echo "================================================================"

# Verificar que estamos en el directorio correcto
if [[ ! -d "microUsers" || ! -d "microProducts" || ! -d "microOrders" || ! -d "frontend" ]]; then
    echo -e "${RED}❌ Error: Debe ejecutar desde la raíz del proyecto${NC}"
    exit 1
fi

# Leer información del ACR desde Terraform outputs (si existe)
if [[ -f "infra/terraform/terraform.tfstate" ]]; then
    echo "📋 Obteniendo información del ACR desde Terraform..."
    ACR_NAME=$(terraform -chdir=infra/terraform output -raw acr_name 2>/dev/null || echo "")
    ACR_LOGIN_SERVER=$(terraform -chdir=infra/terraform output -raw acr_login_server 2>/dev/null || echo "")
else
    echo -e "${YELLOW}⚠️ No se encontró terraform.tfstate. Debes proporcionar manualmente el ACR.${NC}"
    read -p "Nombre del ACR (ej: microstoreacr123abc): " ACR_NAME
    ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
fi

if [[ -z "$ACR_NAME" ]]; then
    echo -e "${RED}❌ Error: No se pudo obtener el nombre del ACR${NC}"
    exit 1
fi

echo -e "${GREEN}🎯 ACR destino: $ACR_LOGIN_SERVER${NC}"

# Login al ACR
echo "🔐 Haciendo login al Azure Container Registry..."
if ! az acr login --name "$ACR_NAME"; then
    echo -e "${RED}❌ Error: No se pudo hacer login al ACR. Verifica que estés autenticado en Azure.${NC}"
    exit 1
fi

# Definir los servicios y sus directorios
declare -A SERVICES=(
    ["microstore-users"]="microUsers"
    ["microstore-products"]="microProducts"
    ["microstore-orders"]="microOrders"
    ["microstore-frontend"]="frontend"
)

# Función para build y push de una imagen
build_and_push() {
    local service_name=$1
    local directory=$2
    local image_name="${ACR_LOGIN_SERVER}/${service_name}:latest"
    
    echo ""
    echo -e "${YELLOW}🔨 Building $service_name...${NC}"
    
    if ! docker build -t "$image_name" "$directory"; then
        echo -e "${RED}❌ Error building $service_name${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📤 Pushing $service_name to ACR...${NC}"
    
    if ! docker push "$image_name"; then
        echo -e "${RED}❌ Error pushing $service_name${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ $service_name pushed successfully${NC}"
}

# Build y push de todas las imágenes
FAILED_SERVICES=()

for service in "${!SERVICES[@]}"; do
    directory=${SERVICES[$service]}
    
    if [[ -f "$directory/Dockerfile" ]]; then
        if ! build_and_push "$service" "$directory"; then
            FAILED_SERVICES+=("$service")
        fi
    else
        echo -e "${RED}❌ Error: No se encontró Dockerfile en $directory${NC}"
        FAILED_SERVICES+=("$service")
    fi
done

echo ""
echo "📊 Resumen del Build:"
echo "===================="

if [[ ${#FAILED_SERVICES[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ Todas las imágenes se construyeron y subieron exitosamente${NC}"
    echo ""
    echo "🎯 Imágenes disponibles en ACR:"
    for service in "${!SERVICES[@]}"; do
        echo "  • ${ACR_LOGIN_SERVER}/${service}:latest"
    done
    
    echo ""
    echo -e "${GREEN}🚀 Siguiente paso: Actualizar manifiestos de Kubernetes${NC}"
    echo "   Reemplaza <TU_REGISTRY> en los archivos YAML con: $ACR_LOGIN_SERVER"
    echo ""
    echo "   Comando sugerido:"
    echo "   find k8s -name '*.yaml' -exec sed -i 's|<TU_REGISTRY>|$ACR_LOGIN_SERVER|g' {} +"
    
else
    echo -e "${RED}❌ Falló el build/push de los siguientes servicios:${NC}"
    for service in "${FAILED_SERVICES[@]}"; do
        echo "  • $service"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Proceso completado exitosamente${NC}"