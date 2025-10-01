# PowerShell Script para Build de Imágenes Docker + ACR Push
# Para Windows con Docker Desktop + Azure CLI

param(
    [switch]$Help
)

if ($Help) {
    Write-Host "🐳 Build Script para MicroStore - PowerShell Edition" -ForegroundColor Green
    Write-Host "Usage: .\scripts\build-images.ps1" -ForegroundColor Cyan
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - Docker Desktop running" -ForegroundColor White
    Write-Host "  - Azure CLI logged in" -ForegroundColor White
    Write-Host "  - Terraform state available" -ForegroundColor White
    exit 0
}

Write-Host "🐳 Script de Build para MicroStore - PowerShell Edition" -ForegroundColor Green
Write-Host "🚀 Usando Docker Local + Azure Container Registry" -ForegroundColor Blue
Write-Host "================================================================" -ForegroundColor Gray

# Verificar que estamos en el directorio correcto
$requiredDirs = @("microUsers", "microProducts", "microOrders", "frontend")
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        Write-Host "❌ Error: Debe ejecutar desde la raíz del proyecto" -ForegroundColor Red
        Write-Host "   Directorios requeridos: $($requiredDirs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

# Verificar que Docker está ejecutándose
Write-Host "🔍 Verificando Docker Desktop..." -ForegroundColor Cyan
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker disponible: $dockerVersion" -ForegroundColor Green
    
    $dockerPs = docker ps 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Docker no está ejecutándose" -ForegroundColor Red
        Write-Host "   Inicia Docker Desktop y prueba: docker ps" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Docker daemon ejecutándose correctamente" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Docker no está instalado o no está en PATH" -ForegroundColor Red
    Write-Host "   Instala Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Verificar que Azure CLI está logueado
Write-Host "🔍 Verificando Azure CLI..." -ForegroundColor Cyan
try {
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: No estás autenticado en Azure" -ForegroundColor Red
        Write-Host "   Ejecuta: az login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Azure CLI autenticado: $($azAccount.user.name)" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Azure CLI no está instalado o no funciona" -ForegroundColor Red
    exit 1
}

# Leer información del ACR desde Terraform outputs
Write-Host "📋 Obteniendo información del ACR desde Terraform..." -ForegroundColor Cyan

$acrName = ""
$acrLoginServer = ""

if (Test-Path "infra\terraform\terraform.tfstate") {
    try {
        Push-Location "infra\terraform"
        $acrName = terraform output -raw acr_name 2>$null
        $acrLoginServer = terraform output -raw acr_login_server 2>$null
        Pop-Location
        
        if ($acrName -and $acrLoginServer) {
            Write-Host "✅ ACR obtenido desde Terraform" -ForegroundColor Green
        } else {
            throw "Outputs vacíos"
        }
    } catch {
        Write-Host "⚠️ No se pudo leer desde Terraform outputs" -ForegroundColor Yellow
    }
}

if (-not $acrName) {
    Write-Host "⚠️ No se encontró terraform.tfstate o outputs vacíos" -ForegroundColor Yellow
    $acrName = Read-Host "Ingresa el nombre del ACR (ej: microstoreacr123abc)"
    $acrLoginServer = "$acrName.azurecr.io"
}

if (-not $acrName) {
    Write-Host "❌ Error: No se pudo obtener el nombre del ACR" -ForegroundColor Red
    exit 1
}

Write-Host "🎯 ACR destino: $acrLoginServer" -ForegroundColor Green

# Verificar acceso al ACR
Write-Host "🔍 Verificando acceso al Azure Container Registry..." -ForegroundColor Cyan
try {
    $acrInfo = az acr show --name $acrName 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "ACR no accesible"
    }
    Write-Host "✅ ACR accesible: $($acrInfo.name) ($($acrInfo.sku.name))" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: No se puede acceder al ACR '$acrName'" -ForegroundColor Red
    Write-Host "   Verifica que el nombre sea correcto y que tengas permisos." -ForegroundColor Yellow
    exit 1
}

# Login al ACR
Write-Host "🔐 Haciendo login al Azure Container Registry..." -ForegroundColor Cyan
try {
    az acr login --name $acrName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Login falló"
    }
    Write-Host "✅ Login al ACR exitoso" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: No se pudo hacer login al ACR" -ForegroundColor Red
    exit 1
}

# Definir servicios y directorios
$services = @{
    "microstore-users" = "microUsers"
    "microstore-products" = "microProducts" 
    "microstore-orders" = "microOrders"
    "microstore-frontend" = "frontend"
}

# Función para build y push
function Build-And-Push {
    param(
        [string]$ServiceName,
        [string]$Directory
    )
    
    $imageName = "$acrLoginServer/${ServiceName}:latest"
    
    Write-Host ""
    Write-Host "🔨 Building $ServiceName..." -ForegroundColor Yellow
    Write-Host "   Directorio: $Directory" -ForegroundColor Blue
    Write-Host "   Imagen: $imageName" -ForegroundColor Blue
    
    # Verificar Dockerfile
    $dockerfilePath = Join-Path $Directory "Dockerfile"
    if (-not (Test-Path $dockerfilePath)) {
        Write-Host "❌ Error: No se encontró Dockerfile en $Directory" -ForegroundColor Red
        return $false
    }
    
    # Build
    Write-Host "🏗️ Ejecutando docker build..." -ForegroundColor Cyan
    try {
        docker build -t $imageName $Directory
        if ($LASTEXITCODE -ne 0) {
            throw "Build falló"
        }
    } catch {
        Write-Host "❌ Error building $ServiceName" -ForegroundColor Red
        return $false
    }
    
    # Push
    Write-Host "📤 Ejecutando docker push..." -ForegroundColor Cyan
    try {
        docker push $imageName
        if ($LASTEXITCODE -ne 0) {
            throw "Push falló"
        }
    } catch {
        Write-Host "❌ Error pushing $ServiceName" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ $ServiceName completado exitosamente" -ForegroundColor Green
    return $true
}

# Build todas las imágenes
Write-Host ""
Write-Host "🚀 Iniciando build de imágenes con Docker local..." -ForegroundColor Blue
Write-Host "   (Esto puede tomar varios minutos)" -ForegroundColor Gray

$failedServices = @()
$totalServices = $services.Count
$currentService = 0

foreach ($service in $services.GetEnumerator()) {
    $currentService++
    Write-Host ""
    Write-Host "[$currentService/$totalServices] Procesando: $($service.Key)" -ForegroundColor Magenta
    
    if (-not (Build-And-Push -ServiceName $service.Key -Directory $service.Value)) {
        $failedServices += $service.Key
    }
}

# Resumen
Write-Host ""
Write-Host "📊 Resumen del Build:" -ForegroundColor Cyan
Write-Host "===================="

if ($failedServices.Count -eq 0) {
    Write-Host "✅ Todas las imágenes se construyeron y subieron exitosamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Imágenes disponibles en ACR:" -ForegroundColor Cyan
    foreach ($service in $services.Keys) {
        Write-Host "  • $acrLoginServer/${service}:latest" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🔍 Verificando imágenes en ACR..." -ForegroundColor Cyan
    try {
        az acr repository list --name $acrName --output table
    } catch {
        Write-Host "⚠️ No se pudo listar repositorios (pero el push fue exitoso)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🚀 Siguiente paso: Actualizar manifiestos de Kubernetes" -ForegroundColor Green
    Write-Host "   Reemplaza <TU_REGISTRY> en los archivos YAML con: $acrLoginServer" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Comando sugerido (PowerShell):" -ForegroundColor Cyan
    Write-Host "   (Get-ChildItem k8s -Recurse -Filter '*.yaml').FullName | ForEach-Object { (Get-Content `$_) -replace '<TU_REGISTRY>', '$acrLoginServer' | Set-Content `$_ }" -ForegroundColor White
    
} else {
    Write-Host "❌ Falló el build de los siguientes servicios:" -ForegroundColor Red
    foreach ($service in $failedServices) {
        Write-Host "  • $service" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Consejos para troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verifica que Docker Desktop este ejecutandose" -ForegroundColor White
    Write-Host "   2. Revisa los Dockerfiles en cada directorio" -ForegroundColor White
    Write-Host "   3. Verifica conexion a internet para el push" -ForegroundColor White
    Write-Host "   4. Comprueba permisos en el ACR" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "✅ Proceso completado exitosamente" -ForegroundColor Green
Write-Host "Usado: Docker Desktop + ACR push" -ForegroundColor Blue