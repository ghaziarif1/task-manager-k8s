# ============================================================================
# Script: push-images-via-daemon.ps1
# Objectif: Charger les images directement dans Kubernetes via le daemon  
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKERS = @("192.168.1.19", "192.168.1.20")
$WORKER_USERS = @("k8s-worker1", "k8s-worker2")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PUSH IMAGES VIA DAEMON" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Tag des images pour le repository local
# ============================================================================
Write-Host "`n[STEP 1] Tag des images..." -ForegroundColor Yellow

docker tag task-manager-backend:v1.0 localhost:5000/task-manager-backend:v1.0
docker tag task-manager-frontend:v1.0 localhost:5000/task-manager-frontend:v1.0

Write-Host "[OK] Images taggees" -ForegroundColor Green

# ============================================================================
# STEP 2: Push vers un registry local temporaire
# ============================================================================
Write-Host "`n[STEP 2] Configuration du registry local temporaire..." -ForegroundColor Yellow

# Lancer un registry local sur port 5001
$registry_check = docker ps --filter "name=local-registry" --format "{{.Names}}" 2>$null
if ($registry_check -ne "local-registry") {
    Write-Host "  -> Demarrage du registry..." -ForegroundColor Cyan
    docker run -d --name local-registry -p 5001:5000 registry:2 | Out-Null
    Start-Sleep -Seconds 2
}

Write-Host "[OK] Registry local en cours d'execution" -ForegroundColor Green

# ============================================================================
# STEP 3: Modifier le daemon pour accepter localhost:5001
# ============================================================================
Write-Host "`n[STEP 3] Configuration du daemon.json..." -ForegroundColor Yellow

$DOCKER_CONFIG = "$env:USERPROFILE\.docker"
$DAEMON_JSON = "$DOCKER_CONFIG\daemon.json"

$config = @{
    "insecure-registries" = @("192.168.1.12:5000", "localhost:5001")
}

$config | ConvertTo-Json | Out-File -FilePath $DAEMON_JSON -Encoding UTF8

Write-Host "[OK] daemon.json configure" -ForegroundColor Green

# ============================================================================
# STEP 4: Push vers localhost:5001 (qui est accessible en local)
# ============================================================================
Write-Host "`n[STEP 4] Push local..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker push localhost:5001/task-manager-backend:v1.0

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker push localhost:5001/task-manager-frontend:v1.0

Write-Host "[OK] Images disponibles localement" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES CHARGEES !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Registry local: http://localhost:5001" -ForegroundColor Cyan
Write-Host "  - localhost:5001/task-manager-backend:v1.0" -ForegroundColor White
Write-Host "  - localhost:5001/task-manager-frontend:v1.0" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Utilisez imagePullPolicy: Never dans les manifests!" -ForegroundColor Yellow
