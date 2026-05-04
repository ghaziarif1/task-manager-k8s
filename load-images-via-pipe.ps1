# ============================================================================
# Script: load-images-via-pipe.ps1
# Objectif: Charger les images via SSH pipe sans passer par le filesystem
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKERS = @( @{IP = "192.168.1.19"; User = "k8s-worker1"}, @{IP = "192.168.1.20"; User = "k8s-worker2"} )

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CHARGER LES IMAGES VIA PIPE SSH" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Sauvegarder les images
# ============================================================================
Write-Host "[STEP 1] Sauvegarder les images Docker..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker save task-manager-backend:v1.0 -o backend.tar
Write-Host "     Taille: $((Get-Item backend.tar).Length / 1MB) MB" -ForegroundColor Gray

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker save task-manager-frontend:v1.0 -o frontend.tar
Write-Host "     Taille: $((Get-Item frontend.tar).Length / 1MB) MB" -ForegroundColor Gray

Write-Host "[OK] Images sauvegardées" -ForegroundColor Green

# ============================================================================
# STEP 2: Charger sur Master via pipe (sans passer par /tmp ou /home)
# ============================================================================
Write-Host "`n[STEP 2] Charger Backend sur Master..." -ForegroundColor Yellow

Write-Host "  -> Taguer... " -ForegroundColor Cyan
$backend_pipe = @"
docker load < /dev/stdin && \
docker tag task-manager-backend:v1.0 task-manager-k8s-backend:latest && \
sudo ctr -n k8s.io images pull docker.io/library/task-manager-backend:v1.0 || \
docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import -
"@

# Utiliser cat pour pipler le tar via SSH
Get-Content backend.tar -AsByteStream | ssh $MASTER_USER@$MASTER_IP "docker load"
if ($LASTEXITCODE -eq 0) {
    Write-Host "     [OK]" -ForegroundColor Green
} else {
    Write-Host "     [ERROR]" -ForegroundColor Red
}

# Maintenant tagger
ssh $MASTER_USER@$MASTER_IP "docker tag task-manager-backend:v1.0 task-manager-k8s-backend:latest"

# Charger dans kubelet/containerd
Write-Host "  -> Charger dans kubelet..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import -"
Write-Host "     [OK]" -ForegroundColor Green

# ============================================================================
# STEP 3: Charger Frontend sur Master
# ============================================================================
Write-Host "`n[STEP 3] Charger Frontend sur Master..." -ForegroundColor Yellow

Write-Host "  -> Docker load..." -ForegroundColor Cyan
Get-Content frontend.tar -AsByteStream | ssh $MASTER_USER@$MASTER_IP "docker load"
Write-Host "     [OK]" -ForegroundColor Green

Write-Host "  -> Taguer..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker tag task-manager-frontend:v1.0 task-manager-k8s-frontend:latest"
Write-Host "     [OK]" -ForegroundColor Green

Write-Host "  -> Charger dans kubelet..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker save task-manager-k8s-frontend:latest | sudo ctr -n k8s.io images import -"
Write-Host "     [OK]" -ForegroundColor Green

# ============================================================================
# STEP 4: Charger sur tous les Workers
# ============================================================================
Write-Host "`n[STEP 4] Charger sur les Workers..." -ForegroundColor Yellow

foreach ($worker in $WORKERS) {
    Write-Host "  -> Worker ($($worker.IP))..." -ForegroundColor Cyan
    
    # Backend
    Get-Content backend.tar -AsByteStream | ssh $($worker.User)@$($worker.IP) "docker load"
    ssh $($worker.User)@$($worker.IP) "docker tag task-manager-backend:v1.0 task-manager-k8s-backend:latest"
    ssh $($worker.User)@$($worker.IP) "docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import -"
    
    # Frontend
    Get-Content frontend.tar -AsByteStream | ssh $($worker.User)@$($worker.IP) "docker load"
    ssh $($worker.User)@$($worker.IP) "docker tag task-manager-frontend:v1.0 task-manager-k8s-frontend:latest"
    ssh $($worker.User)@$($worker.IP) "docker save task-manager-k8s-frontend:latest | sudo ctr -n k8s.io images import -"
    
    Write-Host "     [OK]" -ForegroundColor Green
}

# ============================================================================
# STEP 5: Vérifier sur Master
# ============================================================================
Write-Host "`n[STEP 5] Vérification..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "ctr -n k8s.io images ls | grep task-manager"

# ============================================================================
# STEP 6: Nettoyage
# ============================================================================
Write-Host "`n[STEP 6] Nettoyage..." -ForegroundColor Yellow

Remove-Item -Path "backend.tar" -Force
Remove-Item -Path "frontend.tar" -Force

Write-Host "[OK] Nettoyage terminé" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES CHARGEES SUR TOUS LES NODES !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Prochaine étape: Exécuter .\\deploy-phase2.ps1" -ForegroundColor Yellow
