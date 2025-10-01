#!/bin/bash
set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐳 Script de Build Híbrido para MicroStore${NC}"
echo -e "${BLUE}� Auto-detecta: ACR Tasks → Docker Local (fallback)${NC}"
echo "================================================================"

# Verificar que estamos en el directorio correcto
if [[ ! -d "microUsers" || ! -d "microProducts" || ! -d "microOrders" || ! -d "frontend" ]]; then
    echo -e "${RED}❌ Error: Debe ejecutar desde la raíz del proyecto${NC}"
    exit 1
fi

# Verificar que estamos logueados en Azure
if ! az account show &>/dev/null; then
    echo -e "${RED}❌ Error: No estás autenticado en Azure${NC}"
    echo "   Ejecuta: az login"
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

# Verificar que el ACR existe y tenemos acceso
echo "� Verificando acceso al Azure Container Registry..."
if ! az acr show --name "$ACR_NAME" --output none 2>/dev/null; then
    echo -e "${RED}❌ Error: No se puede acceder al ACR '$ACR_NAME'${NC}"
    echo "   Verifica que el nombre sea correcto y que tengas permisos."
    exit 1
fi

# Detectar método de build disponible
USE_DOCKER_LOCAL=false

echo ""
echo -e "${BLUE}🔍 Detectando método de build disponible...${NC}"

# Test si ACR Tasks funciona
echo "🧪 Probando ACR Tasks..."
if az acr build --registry "$ACR_NAME" --image test:latest --file microUsers/Dockerfile microUsers/ &>/dev/null; then
    echo -e "${GREEN}✅ ACR Tasks funciona - usando ACR Tasks${NC}"
    USE_DOCKER_LOCAL=false
else
    echo -e "${YELLOW}⚠️ ACR Tasks no disponible - probando Docker local...${NC}"
    if command -v docker &>/dev/null && docker ps &>/dev/null; then
        echo -e "${GREEN}✅ Docker local funciona - usando Docker + ACR Login${NC}"
        USE_DOCKER_LOCAL=true
        # Login al ACR para push
        if ! az acr login --name "$ACR_NAME"; then
            echo -e "${RED}❌ Error: No se pudo hacer login al ACR${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Error: Ni ACR Tasks ni Docker local están disponibles${NC}"
        exit 1
    fi
fi

# Definir los servicios y sus directorios
declare -A SERVICES=(
    ["microstore-users"]="microUsers"
    ["microstore-products"]="microProducts"
    ["microstore-orders"]="microOrders"
    ["microstore-frontend"]="frontend"
)

# Función para build con ACR Tasks
build_with_acr_task() {
    local service_name=$1
    local directory=$2
    local image_name="${service_name}:latest"
    
    echo ""
    echo -e "${YELLOW}☁️ Building $service_name con ACR Task...${NC}"
    echo -e "${BLUE}   Directorio: $directory${NC}"
    echo -e "${BLUE}   Imagen: $ACR_LOGIN_SERVER/$image_name${NC}"
    
    # Verificar que existe el Dockerfile
    if [[ ! -f "$directory/Dockerfile" ]]; then
        echo -e "${RED}❌ Error: No se encontró Dockerfile en $directory${NC}"
        return 1
    fi
    
    # Usar ACR Task para build y push en un solo comando
    if ! az acr build \
        --registry "$ACR_NAME" \
        --image "$image_name" \
        --file "$directory/Dockerfile" \
        "$directory"; then
        echo -e "${RED}❌ Error building $service_name con ACR Task${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ $service_name construido y subido exitosamente${NC}"
}

# Función para build con Docker local
build_with_docker_local() {
    local service_name=$1
    local directory=$2
    local image_name="${ACR_LOGIN_SERVER}/${service_name}:latest"
    
    echo ""
    echo -e "${YELLOW}🐳 Building $service_name con Docker local...${NC}"
    echo -e "${BLUE}   Directorio: $directory${NC}"
    echo -e "${BLUE}   Imagen: $image_name${NC}"
    
    # Verificar que existe el Dockerfile
    if [[ ! -f "$directory/Dockerfile" ]]; then
        echo -e "${RED}❌ Error: No se encontró Dockerfile en $directory${NC}"
        return 1
    fi
    
    # Build local
    if ! docker build -t "$image_name" "$directory"; then
        echo -e "${RED}❌ Error building $service_name con Docker${NC}"
        return 1
    fi
    
    # Push al ACR
    if ! docker push "$image_name"; then
        echo -e "${RED}❌ Error pushing $service_name al ACR${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ $service_name construido y subido exitosamente${NC}"
}

# Build de todas las imágenes
FAILED_SERVICES=()

echo ""
if [[ "$USE_DOCKER_LOCAL" == "true" ]]; then
    echo -e "${BLUE}� Iniciando build con Docker local + ACR push...${NC}"
else
    echo -e "${BLUE}☁️ Iniciando build con ACR Tasks...${NC}"
fi
echo "   (Esto puede tomar varios minutos por servicio)"

for service in "${!SERVICES[@]}"; do
    directory=${SERVICES[$service]}
    
    if [[ "$USE_DOCKER_LOCAL" == "true" ]]; then
        if ! build_with_docker_local "$service" "$directory"; then
            FAILED_SERVICES+=("$service")
        fi
    else
        if ! build_with_acr_task "$service" "$directory"; then
            FAILED_SERVICES+=("$service")
        fi
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
    echo -e "${YELLOW}🔍 Verificando imágenes en ACR...${NC}"
    az acr repository list --name "$ACR_NAME" --output table
    
    echo ""
    echo -e "${GREEN}🚀 Siguiente paso: Actualizar manifiestos de Kubernetes${NC}"
    echo "   Reemplaza <TU_REGISTRY> en los archivos YAML con: $ACR_LOGIN_SERVER"
    echo ""
    echo "   Comando sugerido (Cloud Shell - bash):"
    echo "   find k8s -name '*.yaml' -exec sed -i 's|<TU_REGISTRY>|$ACR_LOGIN_SERVER|g' {} +"
    
else
    echo -e "${RED}❌ Falló el build de los siguientes servicios:${NC}"
    for service in "${FAILED_SERVICES[@]}"; do
        echo "  • $service"
    done
    echo ""
    echo -e "${YELLOW}💡 Consejos para troubleshooting:${NC}"
    echo "   1. Verifica los Dockerfiles en cada directorio"
    echo "   2. Revisa los logs de ACR Task en Azure Portal"
    echo "   3. Asegúrate de tener permisos en el ACR"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Proceso completado exitosamente${NC}"
if [[ "$USE_DOCKER_LOCAL" == "true" ]]; then
    echo -e "${BLUE}ℹ️ Usado: Docker local + ACR push${NC}"
else
    echo -e "${BLUE}ℹ️ Usado: ACR Tasks (build remoto)${NC}"
fi