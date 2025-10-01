#!/bin/bash
set -euo pipefail

echo "🧪 Script de Validación Local para MicroStore"
echo "============================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️ $message${NC}" ;;
    esac
}

# Verificar prerrequisitos
echo "🔍 Verificando prerrequisitos..."

# Verificar herramientas necesarias
check_tool() {
    local tool=$1
    if command -v "$tool" &> /dev/null; then
        print_status "SUCCESS" "$tool está instalado"
        return 0
    else
        print_status "ERROR" "$tool no está instalado"
        return 1
    fi
}

TOOLS_OK=true
check_tool "kubectl" || TOOLS_OK=false
check_tool "docker" || TOOLS_OK=false

if [[ "$TOOLS_OK" = false ]]; then
    print_status "ERROR" "Faltan herramientas necesarias"
    exit 1
fi

# Verificar estructura del proyecto
echo ""
echo "📁 Verificando estructura del proyecto..."

check_directory() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        print_status "SUCCESS" "Directorio $dir existe"
        return 0
    else
        print_status "ERROR" "Directorio $dir no encontrado"
        return 1
    fi
}

STRUCTURE_OK=true
check_directory "k8s" || STRUCTURE_OK=false
check_directory "k8s/common" || STRUCTURE_OK=false
check_directory "k8s/mysql" || STRUCTURE_OK=false
check_directory "k8s/users" || STRUCTURE_OK=false
check_directory "k8s/products" || STRUCTURE_OK=false
check_directory "k8s/orders" || STRUCTURE_OK=false
check_directory "k8s/frontend" || STRUCTURE_OK=false

if [[ "$STRUCTURE_OK" = false ]]; then
    print_status "ERROR" "Estructura de proyecto incompleta"
    exit 1
fi

# Verificar Dockerfiles
echo ""
echo "🐳 Verificando Dockerfiles..."

check_dockerfile() {
    local service=$1
    local path=$2
    if [[ -f "$path/Dockerfile" ]]; then
        print_status "SUCCESS" "Dockerfile para $service existe"
        return 0
    else
        print_status "ERROR" "Dockerfile para $service no encontrado en $path"
        return 1
    fi
}

DOCKERFILES_OK=true
check_dockerfile "users" "microUsers" || DOCKERFILES_OK=false
check_dockerfile "products" "microProducts" || DOCKERFILES_OK=false
check_dockerfile "orders" "microOrders" || DOCKERFILES_OK=false
check_dockerfile "frontend" "frontend" || DOCKERFILES_OK=false

if [[ "$DOCKERFILES_OK" = false ]]; then
    print_status "WARNING" "Algunos Dockerfiles faltan, pero continuaremos..."
fi

# Validar sintaxis YAML
echo ""
echo "📝 Validando sintaxis de manifiestos YAML..."

validate_yaml_files() {
    local dir=$1
    local errors=0
    
    if [[ -d "$dir" ]]; then
        for file in "$dir"/*.yaml; do
            if [[ -f "$file" ]]; then
                if kubectl apply --dry-run=client -f "$file" &>/dev/null; then
                    print_status "SUCCESS" "$(basename "$file") - Sintaxis válida"
                else
                    print_status "ERROR" "$(basename "$file") - Error de sintaxis"
                    kubectl apply --dry-run=client -f "$file" || true
                    ((errors++))
                fi
            fi
        done
    fi
    return $errors
}

YAML_ERRORS=0
echo "  Validando k8s/common/..."
validate_yaml_files "k8s/common" || ((YAML_ERRORS+=$?))

echo "  Validando k8s/mysql/..."
validate_yaml_files "k8s/mysql" || ((YAML_ERRORS+=$?))

echo "  Validando k8s/users/..."
validate_yaml_files "k8s/users" || ((YAML_ERRORS+=$?))

echo "  Validando k8s/products/..."
validate_yaml_files "k8s/products" || ((YAML_ERRORS+=$?))

echo "  Validando k8s/orders/..."
validate_yaml_files "k8s/orders" || ((YAML_ERRORS+=$?))

echo "  Validando k8s/frontend/..."
validate_yaml_files "k8s/frontend" || ((YAML_ERRORS+=$?))

if [[ $YAML_ERRORS -gt 0 ]]; then
    print_status "ERROR" "$YAML_ERRORS archivos YAML tienen errores de sintaxis"
    echo ""
    print_status "INFO" "Corrige los errores de sintaxis antes de desplegar en Azure"
    exit 1
fi

# Verificar que los manifiestos tienen namespace
echo ""
echo "🏷️ Verificando namespaces en manifiestos..."

check_namespace_in_files() {
    local dir=$1
    local missing=0
    
    if [[ -d "$dir" ]]; then
        for file in "$dir"/*.yaml; do
            if [[ -f "$file" ]]; then
                if grep -q "namespace: microstore" "$file"; then
                    print_status "SUCCESS" "$(basename "$file") - Namespace correcto"
                else
                    print_status "WARNING" "$(basename "$file") - Namespace faltante o incorrecto"
                    ((missing++))
                fi
            fi
        done
    fi
    return $missing
}

NAMESPACE_MISSING=0
check_namespace_in_files "k8s/common" || ((NAMESPACE_MISSING+=$?))
check_namespace_in_files "k8s/mysql" || ((NAMESPACE_MISSING+=$?))
check_namespace_in_files "k8s/users" || ((NAMESPACE_MISSING+=$?))
check_namespace_in_files "k8s/products" || ((NAMESPACE_MISSING+=$?))
check_namespace_in_files "k8s/orders" || ((NAMESPACE_MISSING+=$?))
check_namespace_in_files "k8s/frontend" || ((NAMESPACE_MISSING+=$?))

if [[ $NAMESPACE_MISSING -gt 0 ]]; then
    print_status "WARNING" "$NAMESPACE_MISSING manifiestos sin namespace 'microstore'"
    print_status "INFO" "Los recursos se desplegarán en el namespace 'default'"
fi

# Verificar dependencias de imágenes
echo ""
echo "🏷️ Verificando referencias de imágenes..."

check_image_references() {
    local dir=$1
    local placeholder_found=0
    
    if [[ -d "$dir" ]]; then
        for file in "$dir"/*.yaml; do
            if [[ -f "$file" ]] && grep -q "image:" "$file"; then
                if grep -q "<TU_REGISTRY>" "$file"; then
                    print_status "WARNING" "$(basename "$file") - Contiene placeholder <TU_REGISTRY>"
                    ((placeholder_found++))
                else
                    print_status "SUCCESS" "$(basename "$file") - Referencias de imagen OK"
                fi
            fi
        done
    fi
    return $placeholder_found
}

PLACEHOLDER_COUNT=0
check_image_references "k8s/users" || ((PLACEHOLDER_COUNT+=$?))
check_image_references "k8s/products" || ((PLACEHOLDER_COUNT+=$?))
check_image_references "k8s/orders" || ((PLACEHOLDER_COUNT+=$?))
check_image_references "k8s/frontend" || ((PLACEHOLDER_COUNT+=$?))

if [[ $PLACEHOLDER_COUNT -gt 0 ]]; then
    print_status "WARNING" "$PLACEHOLDER_COUNT manifiestos con placeholders de imagen"
    print_status "INFO" "Recuerda reemplazar <TU_REGISTRY> con tu ACR antes del despliegue"
fi

# Verificar scripts
echo ""
echo "📜 Verificando scripts..."

check_script() {
    local script=$1
    if [[ -f "scripts/$script" ]]; then
        if [[ -x "scripts/$script" ]]; then
            print_status "SUCCESS" "$script - Existe y es ejecutable"
        else
            print_status "WARNING" "$script - Existe pero no es ejecutable (chmod +x)"
        fi
    else
        print_status "ERROR" "$script - No encontrado"
        return 1
    fi
}

SCRIPTS_OK=true
check_script "setup-k8s.sh" || SCRIPTS_OK=false
check_script "build-images.sh" || SCRIPTS_OK=false
check_script "deploy.sh" || SCRIPTS_OK=false
check_script "cleanup.sh" || SCRIPTS_OK=false

# Resumen final
echo ""
echo "📊 Resumen de Validación:"
echo "========================"

if [[ "$TOOLS_OK" = true && "$STRUCTURE_OK" = true && $YAML_ERRORS -eq 0 && "$SCRIPTS_OK" = true ]]; then
    print_status "SUCCESS" "Validación completada exitosamente"
    echo ""
    print_status "INFO" "El proyecto está listo para desplegar en Azure"
    echo ""
    echo "🚀 Próximos pasos recomendados:"
    echo "  1. cd infra/terraform && terraform apply"
    echo "  2. ./scripts/setup-k8s.sh"
    echo "  3. ./scripts/build-images.sh"
    echo "  4. Reemplazar <TU_REGISTRY> en manifiestos"
    echo "  5. ./scripts/deploy.sh"
else
    print_status "WARNING" "Validación completada con advertencias"
    echo ""
    if [[ $YAML_ERRORS -gt 0 ]]; then
        print_status "ERROR" "❗ Hay errores críticos de sintaxis YAML que deben corregirse"
        exit 1
    else
        print_status "INFO" "Las advertencias no impiden el despliegue, pero es recomendable resolverlas"
    fi
fi

echo ""
print_status "INFO" "Para probar localmente: usa Minikube, Kind, o Docker Desktop con Kubernetes"