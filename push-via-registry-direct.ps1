# ============================================================================
# Script: push-via-registry-direct.ps1
# Objectif: Utiliser le registry 192.168.1.12:5000 directement
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$REGISTRY = "192.168.1.12:5000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "POUSSER LES IMAGES VIA LE REGISTRY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Vérifier le registry
# ============================================================================
Write-Host "[STEP 1] Vérifier le registry..." -ForegroundColor Yellow

$registry_check = ssh $MASTER_USER@$MASTER_IP "docker ps --filter 'name=registry' --format '{{.Names}}'"

if ($registry_check -like "*registry*") {
    Write-Host "  [OK] Registry est en cours d'exécution" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Registry n'est pas en cours d'exécution" -ForegroundColor Red
    Write-Host "  -> Démarrage du registry..." -ForegroundColor Cyan
    ssh $MASTER_USER@$MASTER_IP "docker run -d --name registry -p 5000:5000 registry:2"
    Start-Sleep -Seconds 2
}

# ============================================================================
# STEP 2: Taguer les images pour le registry
# ============================================================================
Write-Host "`n[STEP 2] Taguer les images..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker tag task-manager-backend:v1.0 $REGISTRY/task-manager-backend:v1.0
docker tag $REGISTRY/task-manager-backend:v1.0 $REGISTRY/task-manager-backend:latest
Write-Host "     [OK]" -ForegroundColor Green

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker tag task-manager-frontend:v1.0 $REGISTRY/task-manager-frontend:v1.0
docker tag $REGISTRY/task-manager-frontend:v1.0 $REGISTRY/task-manager-frontend:latest
Write-Host "     [OK]" -ForegroundColor Green

# ============================================================================
# STEP 3: Pousser vers le registry
# ============================================================================
Write-Host "`n[STEP 3] Pousser les images..." -ForegroundColor Yellow

Write-Host "  -> Backend v1.0..." -ForegroundColor Cyan
docker push $REGISTRY/task-manager-backend:v1.0 2>&1 | Select-String "digest:|error" | Out-Host

Write-Host "  -> Backend latest..." -ForegroundColor Cyan
docker push $REGISTRY/task-manager-backend:latest 2>&1 | Select-String "digest:|error" | Out-Host

Write-Host "  -> Frontend v1.0..." -ForegroundColor Cyan
docker push $REGISTRY/task-manager-frontend:v1.0 2>&1 | Select-String "digest:|error" | Out-Host

Write-Host "  -> Frontend latest..." -ForegroundColor Cyan
docker push $REGISTRY/task-manager-frontend:latest 2>&1 | Select-String "digest:|error" | Out-Host

Write-Host "[OK] Images poussées vers le registry" -ForegroundColor Green

# ============================================================================
# STEP 4: Vérifier sur le registry
# ============================================================================
Write-Host "`n[STEP 4] Vérifier le registry..." -ForegroundColor Yellow

Write-Host "  -> Catalogues:" -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "curl -s http://localhost:5000/v2/_catalog | jq '.repositories[]' 2>/dev/null || curl -s http://localhost:5000/v2/_catalog"

# ============================================================================
# STEP 5: Modifier les manifests pour utiliser le registry
# ============================================================================
Write-Host "`n[STEP 5] Modifier les manifests..." -ForegroundColor Yellow

# Remplacer les noms d'images dans les manifests
$backend_yaml = Get-Content "k8s/backend-deployment.yaml" -Raw
$backend_yaml = $backend_yaml -replace "image: task-manager-k8s-backend:latest", "image: $REGISTRY/task-manager-backend:latest"
$backend_yaml = $backend_yaml -replace "imagePullPolicy: IfNotPresent", "imagePullPolicy: Always"
Set-Content "k8s/backend-deployment.yaml" $backend_yaml

$frontend_yaml = Get-Content "k8s/frontend-deployment.yaml" -Raw
$frontend_yaml = $frontend_yaml -replace "image: task-manager-k8s-frontend:latest", "image: $REGISTRY/task-manager-frontend:latest"
$frontend_yaml = $frontend_yaml -replace "imagePullPolicy: IfNotPresent", "imagePullPolicy: Always"
Set-Content "k8s/frontend-deployment.yaml" $frontend_yaml

Write-Host "[OK] Manifests modifiés" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES DANS LE REGISTRY !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Registry: http://$REGISTRY" -ForegroundColor Cyan
Write-Host "  - $REGISTRY/task-manager-backend:latest" -ForegroundColor White
Write-Host "  - $REGISTRY/task-manager-frontend:latest" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Prochaine étape: Exécuter .\\deploy-phase2.ps1" -ForegroundColor Yellow
