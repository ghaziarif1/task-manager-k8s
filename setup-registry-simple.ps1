# ============================================================================
# Script: setup-registry-simple.ps1
# Objectif: Mettre en place un Registre Docker Local - Version Simplifiée
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
Write-Host "SETUP REGISTRE DOCKER LOCAL - SIMPLE" -ForegroundColor Cyan
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

Write-Host "Executez ces commandes sur CHAQUE VM:" -ForegroundColor Cyan
Write-Host "sudo mkdir -p /etc/docker" -ForegroundColor White
Write-Host "sudo tee /etc/docker/daemon.json > /dev/null <<EOF" -ForegroundColor White
Write-Host "{" -ForegroundColor White
Write-Host "  `"insecure-registries`": [`"$REGISTRY_URL`"]," -ForegroundColor White
Write-Host "  `"log-driver`": `"json-file`"," -ForegroundColor White
Write-Host "  `"log-opts`": {" -ForegroundColor White
Write-Host "    `"max-size`": `"10m`"," -ForegroundColor White
Write-Host "    `"max-file`": `"3`" -ForegroundColor White
Write-Host "  }" -ForegroundColor White
Write-Host "}" -ForegroundColor White
Write-Host "EOF" -ForegroundColor White
Write-Host "sudo systemctl daemon-reload" -ForegroundColor White
Write-Host "sudo systemctl restart docker" -ForegroundColor White

Write-Host "`nAppuyez sur Entree quand c'est fait..." -ForegroundColor Green
Read-Host

# ============================================================================
# STEP 4: Construire les images
# ============================================================================
Write-Host "`n[STEP 4] Construction des images..." -ForegroundColor Yellow

Write-Host "  -> Build Backend..." -ForegroundColor Cyan
docker build -t $IMAGE_BACKEND .\backend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur build Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend construit" -ForegroundColor Green

Write-Host "  -> Build Frontend..." -ForegroundColor Cyan
docker build -t $IMAGE_FRONTEND .\frontend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur build Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend construit" -ForegroundColor Green

# ============================================================================
# STEP 5: Tagger les images
# ============================================================================
Write-Host "`n[STEP 5] Taggage des images..." -ForegroundColor Yellow

$tag_backend = "$REGISTRY_URL/task-manager-backend:v1.0"
$tag_frontend = "$REGISTRY_URL/task-manager-frontend:v1.0"

docker tag $IMAGE_BACKEND $tag_backend
docker tag $IMAGE_FRONTEND $tag_frontend

Write-Host "[OK] Images taggees" -ForegroundColor Green
Write-Host "    Backend: $tag_backend" -ForegroundColor Cyan
Write-Host "    Frontend: $tag_frontend" -ForegroundColor Cyan

# ============================================================================
# STEP 6: Pousser les images
# ============================================================================
Write-Host "`n[STEP 6] Push des images..." -ForegroundColor Yellow

Write-Host "  -> Push Backend..." -ForegroundColor Cyan
docker push $tag_backend
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend pousse" -ForegroundColor Green

Write-Host "  -> Push Frontend..." -ForegroundColor Cyan
docker push $tag_frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend pousse" -ForegroundColor Green

# ============================================================================
# STEP 7: Verification
# ============================================================================
Write-Host "`n[STEP 7] Verification du Registre..." -ForegroundColor Yellow

$verify_output = ssh $MASTER_USER@$MASTER_IP "curl -s http://localhost:$REGISTRY_PORT/v2/_catalog"
Write-Host "  Contenu du Registre:" -ForegroundColor Cyan
Write-Host $verify_output

# ============================================================================
# STEP 8: Resume final
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETUP TERMINE AVEC SUCCES ✅" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nInformations pour Kubernetes:" -ForegroundColor Cyan
Write-Host "  Registry URL: $REGISTRY_URL" -ForegroundColor White
Write-Host "  Backend Image: $tag_backend" -ForegroundColor White
Write-Host "  Frontend Image: $tag_frontend" -ForegroundColor White

Write-Host "`nProchaines etapes:" -ForegroundColor Cyan
Write-Host "  1. Mettre a jour les manifests K8s" -ForegroundColor White
Write-Host "  2. Appliquer les manifests" -ForegroundColor White
Write-Host "  3. Verifier les Pods" -ForegroundColor White