# ============================================================================
# Script: load-images-direct-k8s.ps1
# Objectif: Charger les images directement dans Kubernetes
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$IMAGE_BACKEND = "task-manager-backend:v1.0"
$IMAGE_FRONTEND = "task-manager-frontend:v1.0"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CHARGER LES IMAGES DANS K8S" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Sauvegarder les images
# ============================================================================
Write-Host "`n[STEP 1] Sauvegarde des images Docker..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker save $IMAGE_BACKEND -o backend.tar
Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker save $IMAGE_FRONTEND -o frontend.tar
Write-Host "[OK] Images sauvegardees" -ForegroundColor Green

# ============================================================================
# STEP 2: Transférer vers Master
# ============================================================================
Write-Host "`n[STEP 2] Transfert vers Master..." -ForegroundColor Yellow

Write-Host "  -> Créer le répertoire..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "mkdir -p /tmp/k8s-images"

Write-Host "  -> Backend..." -ForegroundColor Cyan
scp backend.tar $MASTER_USER@$MASTER_IP`:/tmp/k8s-images/

Write-Host "  -> Frontend..." -ForegroundColor Cyan
scp frontend.tar $MASTER_USER@$MASTER_IP`:/tmp/k8s-images/

Write-Host "[OK] Images transférees" -ForegroundColor Green

# ============================================================================
# STEP 3: Charger dans Docker sur Master
# ============================================================================
Write-Host "`n[STEP 3] Chargement dans Docker (Master)..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker load -i /tmp/k8s-images/backend.tar"

Write-Host "  -> Frontend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker load -i /tmp/k8s-images/frontend.tar"

Write-Host "[OK] Images chargees sur Master" -ForegroundColor Green

# ============================================================================
# STEP 4: Charger dans Kubelet sur tous les nodes
# ============================================================================
Write-Host "`n[STEP 4] Chargement dans Kubelet (tous les nodes)..." -ForegroundColor Yellow

# Masters
Write-Host "  -> Backend (Master)..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images import /tmp/k8s-images/backend.tar"

Write-Host "  -> Frontend (Master)..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images import /tmp/k8s-images/frontend.tar"

# Workers
foreach ($i in 0..1) {
    $worker_ip = @("192.168.1.19", "192.168.1.20")[$i]
    $worker_user = @("k8s-worker1", "k8s-worker2")[$i]
    
    Write-Host "  -> Transfert Worker $($i+1)..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "mkdir -p /tmp/k8s-images"
    scp backend.tar $worker_user@$worker_ip`:/tmp/k8s-images/
    scp frontend.tar $worker_user@$worker_ip`:/tmp/k8s-images/
    
    Write-Host "  -> Backend (Worker $($i+1))..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "sudo ctr -n k8s.io images import /tmp/k8s-images/backend.tar"
    
    Write-Host "  -> Frontend (Worker $($i+1))..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "sudo ctr -n k8s.io images import /tmp/k8s-images/frontend.tar"
}

Write-Host "[OK] Images chargees sur tous les nodes" -ForegroundColor Green

# ============================================================================
# STEP 5: Nettoyage
# ============================================================================
Write-Host "`n[STEP 5] Nettoyage..." -ForegroundColor Yellow
Remove-Item -Path "backend.tar" -Force
Remove-Item -Path "frontend.tar" -Force
ssh $MASTER_USER@$MASTER_IP "rm -rf /tmp/k8s-images"
Write-Host "[OK] Nettoyage termine" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES CHARGEES DANS K8S !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Images disponibles:" -ForegroundColor Cyan
Write-Host "  - $IMAGE_BACKEND" -ForegroundColor White
Write-Host "  - $IMAGE_FRONTEND" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Prochaine etape: Deployer sur Kubernetes" -ForegroundColor Green
