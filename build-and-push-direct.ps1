# ============================================================================
# Script: build-and-push-direct.ps1
# Objectif: Construire les images localement et les pousser vers le registry
# ============================================================================

$ErrorActionPreference = "Stop"

$REGISTRY_URL = "192.168.1.12:5000"
$IMAGE_BACKEND = "task-manager-backend:v1.0"
$IMAGE_FRONTEND = "task-manager-frontend:v1.0"
$TAG_BACKEND = "$REGISTRY_URL/task-manager-backend:v1.0"
$TAG_FRONTEND = "$REGISTRY_URL/task-manager-frontend:v1.0"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "BUILD & PUSH DIRECTEMENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Construire Backend
# ============================================================================
Write-Host "`n[STEP 1] Build Backend..." -ForegroundColor Yellow
docker build -t $IMAGE_BACKEND .\backend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur build Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend construit" -ForegroundColor Green

# ============================================================================
# STEP 2: Construire Frontend
# ============================================================================
Write-Host "`n[STEP 2] Build Frontend..." -ForegroundColor Yellow
docker build -t $IMAGE_FRONTEND .\frontend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur build Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend construit" -ForegroundColor Green

# ============================================================================
# STEP 3: Tagger les images
# ============================================================================
Write-Host "`n[STEP 3] Taggage des images..." -ForegroundColor Yellow
docker tag $IMAGE_BACKEND $TAG_BACKEND
docker tag $IMAGE_FRONTEND $TAG_FRONTEND
Write-Host "[OK] Images taggees" -ForegroundColor Green
Write-Host "    Backend: $TAG_BACKEND" -ForegroundColor Cyan
Write-Host "    Frontend: $TAG_FRONTEND" -ForegroundColor Cyan

# ============================================================================
# STEP 4: Push Backend
# ============================================================================
Write-Host "`n[STEP 4] Push Backend..." -ForegroundColor Yellow
docker push $TAG_BACKEND
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur push Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend pousse" -ForegroundColor Green

# ============================================================================
# STEP 5: Push Frontend
# ============================================================================
Write-Host "`n[STEP 5] Push Frontend..." -ForegroundColor Yellow
docker push $TAG_FRONTEND
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur push Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend pousse" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "BUILD & PUSH REUSSI !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Images disponibles dans le registry:" -ForegroundColor Cyan
Write-Host "  - $TAG_BACKEND" -ForegroundColor White
Write-Host "  - $TAG_FRONTEND" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Prochaine etape: Deployer sur Kubernetes" -ForegroundColor Green
