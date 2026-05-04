# ============================================================================
# Script: setup-registry-vm-build.ps1
# Objectif: Mettre en place un Registre Docker Local avec build sur VM
# ============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKERS = @("192.168.1.19", "192.168.1.20")
$WORKER_USERS = @("k8s-worker1", "k8s-worker2")
$REGISTRY_PORT = 5000
$REGISTRY_URL = "$MASTER_IP`:$REGISTRY_PORT"
$IMAGE_BACKEND = "task-manager-backend:v1.0"
$IMAGE_FRONTEND = "task-manager-frontend:v1.0"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SETUP REGISTRE DOCKER LOCAL - BUILD SUR VM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Vérifier les droits Docker
# ============================================================================
Write-Host "`n[STEP 1] Verification des droits Docker..." -ForegroundColor Yellow

Write-Host "  -> Test Master..." -ForegroundColor Cyan
$docker_test = ssh $MASTER_USER@$MASTER_IP "docker --version"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker non accessible sur Master" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Docker accessible sur Master" -ForegroundColor Green

foreach ($i in 0..1) {
    $worker_ip = $WORKERS[$i]
    $worker_user = $WORKER_USERS[$i]
    Write-Host "  -> Test Worker $($i+1) ($worker_ip)..." -ForegroundColor Cyan
    $docker_test = ssh $worker_user@$worker_ip "docker --version"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker non accessible sur Worker $($i+1)" -ForegroundColor Red
        exit 1
    }
}
Write-Host "[OK] Docker accessible sur tous les nodes" -ForegroundColor Green

# ============================================================================
# STEP 2: Déployer le Registry
# ============================================================================
Write-Host "`n[STEP 2] Deploiement du Registry Docker..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "docker ps -a --format '{{.Names}}' | grep -q 'docker-registry' && docker rm -f docker-registry || true"
ssh $MASTER_USER@$MASTER_IP "docker run -d --name docker-registry --restart always -p $REGISTRY_PORT`:5000 registry:2"
Start-Sleep -Seconds 3

$registry_check = ssh $MASTER_USER@$MASTER_IP "curl -s http://localhost:$REGISTRY_PORT/v2/ > /dev/null && echo 'OK' || echo 'ERROR'"
if ($registry_check -notlike "*OK*") {
    Write-Host "[ERROR] Registry non accessible" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Registry deploye et accessible" -ForegroundColor Green

# ============================================================================
# STEP 3: Instructions manuelles
# ============================================================================
Write-Host "`n[STEP 3] Configuration MANUELLE requise..." -ForegroundColor Yellow

$config_text = @"
Executez ces commandes sur CHAQUE VM (Master + Workers):

sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "insecure-registries": ["$REGISTRY_URL"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
sleep 3
docker --version
"@

Write-Host $config_text -ForegroundColor White

Write-Host "`nAppuyez sur Entree quand c'est fait sur TOUTES les VMs..." -ForegroundColor Green
Read-Host

# ============================================================================
# STEP 4: Transférer les sources vers le Master
# ============================================================================
Write-Host "`n[STEP 4] Transfert des sources vers Master..." -ForegroundColor Yellow

Write-Host "  -> Creation repertoire temporaire..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "rm -rf ~/task-manager-build && mkdir -p ~/task-manager-build"

Write-Host "  -> Transfert Backend..." -ForegroundColor Cyan
scp -r .\backend\ $MASTER_USER@$MASTER_IP`:`~/task-manager-build/

Write-Host "  -> Transfert Frontend..." -ForegroundColor Cyan
scp -r .\frontend\ $MASTER_USER@$MASTER_IP`:`~/task-manager-build/

Write-Host "[OK] Sources transferees" -ForegroundColor Green

# ============================================================================
# STEP 5: Construire les images sur le Master
# ============================================================================
Write-Host "`n[STEP 5] Construction des images sur Master..." -ForegroundColor Yellow

Write-Host "  -> Build Backend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "cd ~/task-manager-build/backend && docker build -t $IMAGE_BACKEND ."
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur build Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend construit" -ForegroundColor Green

Write-Host "  -> Build Frontend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "cd ~/task-manager-build/frontend && docker build -t $IMAGE_FRONTEND ."
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur build Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend construit" -ForegroundColor Green

# ============================================================================
# STEP 6: Tagger les images
# ============================================================================
Write-Host "`n[STEP 6] Taggage des images..." -ForegroundColor Yellow

$tag_backend = "$REGISTRY_URL/task-manager-backend:v1.0"
$tag_frontend = "$REGISTRY_URL/task-manager-frontend:v1.0"

ssh $MASTER_USER@$MASTER_IP "docker tag $IMAGE_BACKEND $tag_backend"
ssh $MASTER_USER@$MASTER_IP "docker tag $IMAGE_FRONTEND $tag_frontend"

Write-Host "[OK] Images taggees" -ForegroundColor Green
Write-Host "    Backend: $tag_backend" -ForegroundColor Cyan
Write-Host "    Frontend: $tag_frontend" -ForegroundColor Cyan

# ============================================================================
# STEP 7: Pousser les images
# ============================================================================
Write-Host "`n[STEP 7] Push des images..." -ForegroundColor Yellow

Write-Host "  -> Push Backend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker push $tag_backend"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend pousse" -ForegroundColor Green

Write-Host "  -> Push Frontend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "docker push $tag_frontend"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend pousse" -ForegroundColor Green

# ============================================================================
# STEP 8: Nettoyage
# ============================================================================
Write-Host "`n[STEP 8] Nettoyage..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "rm -rf ~/task-manager-build"
Write-Host "[OK] Nettoyage effectue" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "REGISTRE DOCKER LOCAL OPERATIONNEL !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Images disponibles:" -ForegroundColor Cyan
Write-Host "  - $tag_backend" -ForegroundColor White
Write-Host "  - $tag_frontend" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Vous pouvez maintenant deployer sur Kubernetes !" -ForegroundColor Green
Write-Host "Utilisez les manifests dans le dossier k8s/" -ForegroundColor Cyan