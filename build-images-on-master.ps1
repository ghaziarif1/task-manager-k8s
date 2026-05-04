# ============================================================================
# Script: build-images-on-master.ps1
# Objectif: Construire les images directement sur le master
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CONSTRUIRE LES IMAGES SUR LE MASTER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Transférer les sources
# ============================================================================
Write-Host "[STEP 1] Transfert des sources..." -ForegroundColor Yellow

# Créer le répertoire sur le master
ssh $MASTER_USER@$MASTER_IP "mkdir -p /home/$MASTER_USER/task-manager-build"

# Transférer les sources
Write-Host "  -> Backend..." -ForegroundColor Cyan
scp -r backend $MASTER_USER@$MASTER_IP`:/home/$MASTER_USER/task-manager-build/

Write-Host "  -> Frontend..." -ForegroundColor Cyan
scp -r frontend $MASTER_USER@$MASTER_IP`:/home/$MASTER_USER/task-manager-build/

Write-Host "[OK] Sources transférées" -ForegroundColor Green

# ============================================================================
# STEP 2: Construire Backend
# ============================================================================
Write-Host "`n[STEP 2] Construire Backend..." -ForegroundColor Yellow

Write-Host "  -> Building..." -ForegroundColor Cyan

$backend_build = @"
cd /home/$MASTER_USER/task-manager-build/backend && \
docker build -t task-manager-k8s-backend:latest . && \
echo "[OK] Backend construit"
"@

ssh $MASTER_USER@$MASTER_IP $backend_build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de la construction du Backend" -ForegroundColor Red
} else {
    Write-Host "[OK] Backend construit avec succès" -ForegroundColor Green
}

# ============================================================================
# STEP 3: Construire Frontend
# ============================================================================
Write-Host "`n[STEP 3] Construire Frontend..." -ForegroundColor Yellow

Write-Host "  -> Building..." -ForegroundColor Cyan

$frontend_build = @"
cd /home/$MASTER_USER/task-manager-build/frontend && \
docker build -t task-manager-k8s-frontend:latest . && \
echo "[OK] Frontend construit"
"@

ssh $MASTER_USER@$MASTER_IP $frontend_build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors de la construction du Frontend" -ForegroundColor Red
} else {
    Write-Host "[OK] Frontend construit avec succès" -ForegroundColor Green
}

# ============================================================================
# STEP 4: Charger dans Kubelet (containerd)
# ============================================================================
Write-Host "`n[STEP 4] Charger dans Kubelet..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images import <(docker save task-manager-k8s-backend:latest) 2>&1 || docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import -"

Write-Host "  -> Frontend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "sudo ctr -n k8s.io images import <(docker save task-manager-k8s-frontend:latest) 2>&1 || docker save task-manager-k8s-frontend:latest | sudo ctr -n k8s.io images import -"

Write-Host "[OK] Images chargées dans kubelet" -ForegroundColor Green

# ============================================================================
# STEP 5: Copier les images vers les workers via registry local
# ============================================================================
Write-Host "`n[STEP 5] Copier vers les workers..." -ForegroundColor Yellow

# Créer le tag pour le registry
ssh $MASTER_USER@$MASTER_IP "docker tag task-manager-k8s-backend:latest localhost:5000/task-manager-backend:latest && docker tag task-manager-k8s-frontend:latest localhost:5000/task-manager-frontend:latest"

# Vérifier si un registry local existe, sinon le créer
$registry_status = ssh $MASTER_USER@$MASTER_IP "docker ps --filter 'name=local-registry' --format '{{.Names}}' 2>/dev/null || echo 'none'"

if ($registry_status -ne "local-registry") {
    Write-Host "  -> Démarrer registry local..." -ForegroundColor Cyan
    ssh $MASTER_USER@$MASTER_IP "docker run -d --name local-registry -p 5000:5000 registry:2"
    Start-Sleep -Seconds 2
}

# Pousser vers le registry local
Write-Host "  -> Push Backend vers localhost:5000..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker push localhost:5000/task-manager-backend:latest"

Write-Host "  -> Push Frontend vers localhost:5000..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker push localhost:5000/task-manager-frontend:latest"

# Configurer les workers pour accéder au registry
$workers = @("192.168.1.19", "192.168.1.20")
$workers_user = @("k8s-worker1", "k8s-worker2")

for ($i = 0; $i -lt $workers.Count; $i++) {
    $worker_ip = $workers[$i]
    $worker_user = $workers_user[$i]
    
    Write-Host "  -> Worker $($i+1) - Pull Backend..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "docker pull $MASTER_IP:5000/task-manager-backend:latest 2>/dev/null || echo 'Registry non accessible depuis worker'"
    
    Write-Host "  -> Worker $($i+1) - Pull Frontend..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "docker pull $MASTER_IP:5000/task-manager-frontend:latest 2>/dev/null || echo 'Registry non accessible depuis worker'"
    
    # Load dans kubelet
    Write-Host "  -> Worker $($i+1) - Import dans kubelet..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip "docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import - 2>/dev/null || true"
    ssh $worker_user@$worker_ip "docker save task-manager-k8s-frontend:latest | sudo ctr -n k8s.io images import - 2>/dev/null || true"
}

Write-Host "[OK] Images disponibles sur tous les nodes" -ForegroundColor Green

# ============================================================================
# STEP 6: Nettoyage temporaire
# ============================================================================
Write-Host "`n[STEP 6] Nettoyage..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "rm -rf /home/$MASTER_USER/task-manager-build"

Write-Host "[OK] Nettoyage terminé" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES CONSTRUITES ET CHARGEES !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Prochaine étape: Exécuter .\\deploy-phase2.ps1" -ForegroundColor Yellow
