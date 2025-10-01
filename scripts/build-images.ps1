param([switch]$Help)

if ($Help) {
    Write-Host "build-images.ps1 - Script para construir imagenes Docker y subirlas a ACR" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USO:" -ForegroundColor Yellow
    Write-Host "  .\build-images.ps1          # Ejecutar el build completo"
    Write-Host "  .\build-images.ps1 -Help    # Mostrar esta ayuda"
    Write-Host ""
    Write-Host "PREREQUISITOS:" -ForegroundColor Yellow
    Write-Host "  - Docker Desktop ejecutandose"
    Write-Host "  - Azure CLI configurado (az login)"
    Write-Host "  - ACR creado (manualmente o via Terraform)"
    exit 0
}

# Verificar directorios requeridos
$requiredDirs = @("microUsers", "microProducts", "microOrders", "frontend")
Write-Host "Verificando estructura del proyecto..." -ForegroundColor Cyan

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        Write-Host "ERROR: Directorio '$dir' no encontrado" -ForegroundColor Red
        Write-Host "   Ejecuta este script desde la raiz del proyecto" -ForegroundColor Yellow
        exit 1
    }
}

# Verificar Docker Desktop
Write-Host "Verificando Docker Desktop..." -ForegroundColor Cyan
try {
    docker version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker no disponible"
    }
    Write-Host "OK: Docker Desktop funcionando" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker Desktop no esta ejecutandose" -ForegroundColor Red
    Write-Host "   Inicia Docker Desktop y espera a que este listo" -ForegroundColor Yellow
    exit 1
}

# Verificar Azure CLI
Write-Host "Verificando Azure CLI..." -ForegroundColor Cyan
try {
    az account show | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "No hay sesion Azure"
    }
    Write-Host "OK: Azure CLI configurado" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No hay sesion activa en Azure CLI" -ForegroundColor Red
    Write-Host "   Ejecuta: az login" -ForegroundColor Yellow
    exit 1
}

# Obtener informacion del ACR
Write-Host "Obteniendo informacion del ACR..." -ForegroundColor Cyan
$acrName = ""
$acrLoginServer = ""

if (Test-Path "infra\terraform\terraform.tfstate") {
    try {
        Push-Location "infra\terraform"
        $acrName = terraform output -raw acr_name 2>$null
        $acrLoginServer = terraform output -raw acr_login_server 2>$null
        Pop-Location
        
        if ($acrName -and $acrLoginServer) {
            Write-Host "OK: ACR obtenido desde Terraform" -ForegroundColor Green
        } else {
            throw "Outputs vacios"
        }
    } catch {
        Write-Host "AVISO: No se pudo leer desde Terraform outputs" -ForegroundColor Yellow
    }
}

if (-not $acrName) {
    Write-Host "AVISO: No se encontro terraform.tfstate o outputs vacios" -ForegroundColor Yellow
    $acrName = Read-Host "Ingresa el nombre del ACR (ej: microstoreacr123abc)"
    $acrLoginServer = "$acrName.azurecr.io"
}

if (-not $acrName) {
    Write-Host "ERROR: No se pudo obtener el nombre del ACR" -ForegroundColor Red
    exit 1
}

Write-Host "ACR destino: $acrLoginServer" -ForegroundColor Green

# Verificar acceso al ACR
Write-Host "Verificando acceso al Azure Container Registry..." -ForegroundColor Cyan
try {
    $acrInfo = az acr show --name $acrName 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "ACR no accesible"
    }
    Write-Host "OK: ACR accesible: $($acrInfo.name) ($($acrInfo.sku.name))" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se puede acceder al ACR '$acrName'" -ForegroundColor Red
    Write-Host "   Verifica que el nombre sea correcto y que tengas permisos." -ForegroundColor Yellow
    exit 1
}

# Login al ACR
Write-Host "Haciendo login al Azure Container Registry..." -ForegroundColor Cyan
try {
    az acr login --name $acrName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Login fallo"
    }
    Write-Host "OK: Login al ACR exitoso" -ForegroundColor Green
} catch {
    Write-Host "ERROR: No se pudo hacer login al ACR" -ForegroundColor Red
    exit 1
}

# Definir servicios y directorios
$services = @{
    "microstore-users" = "microUsers"
    "microstore-products" = "microProducts" 
    "microstore-orders" = "microOrders"
    "microstore-frontend" = "frontend"
}

# Funcion para build y push
function Build-And-Push {
    param(
        [string]$ServiceName,
        [string]$Directory
    )
    
    $imageName = "$acrLoginServer/${ServiceName}:latest"
    
    Write-Host ""
    Write-Host "Building $ServiceName..." -ForegroundColor Yellow
    Write-Host "   Directorio: $Directory" -ForegroundColor Blue
    Write-Host "   Imagen: $imageName" -ForegroundColor Blue
    
    # Verificar Dockerfile
    $dockerfilePath = Join-Path $Directory "Dockerfile"
    if (-not (Test-Path $dockerfilePath)) {
        Write-Host "ERROR: No se encontro Dockerfile en $Directory" -ForegroundColor Red
        return $false
    }
    
    # Build
    Write-Host "Ejecutando docker build..." -ForegroundColor Cyan
    try {
        docker build -t $imageName $Directory
        if ($LASTEXITCODE -ne 0) {
            throw "Build fallo"
        }
    } catch {
        Write-Host "ERROR building $ServiceName" -ForegroundColor Red
        return $false
    }
    
    # Push
    Write-Host "Ejecutando docker push..." -ForegroundColor Cyan
    try {
        docker push $imageName
        if ($LASTEXITCODE -ne 0) {
            throw "Push fallo"
        }
    } catch {
        Write-Host "ERROR pushing $ServiceName" -ForegroundColor Red
        return $false
    }
    
    Write-Host "OK: $ServiceName completado exitosamente" -ForegroundColor Green
    return $true
}

# Build todas las imagenes
Write-Host ""
Write-Host "Iniciando build de imagenes con Docker local..." -ForegroundColor Blue
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
Write-Host "Resumen del Build:" -ForegroundColor Cyan
Write-Host "===================="

if ($failedServices.Count -eq 0) {
    Write-Host "OK: Todas las imagenes se construyeron y subieron exitosamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "Imagenes disponibles en ACR:" -ForegroundColor Cyan
    foreach ($service in $services.Keys) {
        Write-Host "  - $acrLoginServer/${service}:latest" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Verificando imagenes en ACR..." -ForegroundColor Cyan
    try {
        az acr repository list --name $acrName --output table
    } catch {
        Write-Host "AVISO: No se pudo listar repositorios (pero el push fue exitoso)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Siguiente paso: Actualizar manifiestos de Kubernetes" -ForegroundColor Green
    Write-Host "   Reemplaza placeholders en los archivos YAML con: $acrLoginServer" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Comando sugerido (PowerShell):" -ForegroundColor Cyan
    Write-Host "   Ver documentacion para reemplazar placeholders con $acrLoginServer" -ForegroundColor White
    
} else {
    Write-Host "ERROR: Fallo el build de los siguientes servicios:" -ForegroundColor Red
    foreach ($service in $failedServices) {
        Write-Host "  - $service" -ForegroundColor Red
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
Write-Host "OK: Proceso completado exitosamente" -ForegroundColor Green
Write-Host "INFO: Usado Docker Desktop + ACR push" -ForegroundColor Blue