# ============================================================================
# Script: retag-and-load-images.ps1
# Objectif: Retaguer les images et les charger sur tous les nodes
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKERS_IPS = @("192.168.1.19", "192.168.1.20")
$WORKERS_USERS = @("k8s-worker1", "k8s-worker2")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RETAGUER ET CHARGER LES IMAGES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Retaguer les images localement
# ============================================================================
Write-Host "[STEP 1] Retaguer les images..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker tag task-manager-backend:v1.0 task-manager-k8s-backend:latest
if ($LASTEXITCODE -eq 0) { Write-Host "     [OK]" -ForegroundColor Green }

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker tag task-manager-frontend:v1.0 task-manager-k8s-frontend:latest
if ($LASTEXITCODE -eq 0) { Write-Host "     [OK]" -ForegroundColor Green }

# ============================================================================
# STEP 2: Verifier les images
# ============================================================================
Write-Host "`n[STEP 2] Verification des images..." -ForegroundColor Yellow

docker images | grep "task-manager-k8s"

# ============================================================================
# STEP 3: Charger via registry local sur Master
# ============================================================================
Write-Host "`n[STEP 3] Charger via registry local (Master)..." -ForegroundColor Yellow

# Le registry local 192.168.1.12:5000 devrait déjà être running sur le master

Write-Host "  -> Tag pour registry (Backend)..." -ForegroundColor Cyan
docker tag task-manager-k8s-backend:latest 192.168.1.12:5000/task-manager-backend:latest

Write-Host "  -> Tag pour registry (Frontend)..." -ForegroundColor Cyan
docker tag task-manager-k8s-frontend:latest 192.168.1.12:5000/task-manager-frontend:latest

Write-Host "  -> Push Backend vers registry..." -ForegroundColor Cyan
docker push 192.168.1.12:5000/task-manager-backend:latest 2>&1 | Select-String -Pattern "^(digest:|pushed|error)" | Out-Host

Write-Host "  -> Push Frontend vers registry..." -ForegroundColor Cyan
docker push 192.168.1.12:5000/task-manager-frontend:latest 2>&1 | Select-String -Pattern "^(digest:|pushed|error)" | Out-Host

Write-Host "[OK] Images dans registry" -ForegroundColor Green

# ============================================================================
# STEP 4: Charger sur tous les nodes via registry
# ============================================================================
Write-Host "`n[STEP 4] Charger sur tous les nodes..." -ForegroundColor Yellow

# Master
Write-Host "  -> Master (Backend)..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images pull 192.168.1.12:5000/task-manager-backend:latest"
Write-Host "  -> Master (Frontend)..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images pull 192.168.1.12:5000/task-manager-frontend:latest"

# Workers
for ($i = 0; $i -lt $WORKERS_IPS.Count; $i++) {
    $worker_ip = $WORKERS_IPS[$i]
    $worker_user = $WORKERS_USERS[$i]
    
    Write-Host "  -> Worker $($i+1) (Backend)..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "sudo ctr -n k8s.io images pull 192.168.1.12:5000/task-manager-backend:latest"
    
    Write-Host "  -> Worker $($i+1) (Frontend)..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "sudo ctr -n k8s.io images pull 192.168.1.12:5000/task-manager-frontend:latest"
}

Write-Host "[OK] Images chargees sur tous les nodes" -ForegroundColor Green

# ============================================================================
# STEP 5: Verifier sur Master
# ============================================================================
Write-Host "`n[STEP 5] Verification sur Master..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images ls" | grep "task-manager"

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES CHARGEES ET PRET A DEPLOYER !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Les images suivantes sont maintenant disponibles:" -ForegroundColor Cyan
Write-Host "  - task-manager-k8s-backend:latest" -ForegroundColor White
Write-Host "  - task-manager-k8s-frontend:latest" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Vous pouvez maintenant executer: .\\deploy-phase2.ps1" -ForegroundColor Green
