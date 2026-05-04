# ============================================================================
# Script: setup-registry-v3.ps1
# Objectif: Mettre en place un Registre Docker Local
# Version: Utilise des commandes SSH simples sans redirection complexe
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
Write-Host "SETUP REGISTRE DOCKER LOCAL - V3" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Déployer le Registry Docker sur le Master
# ============================================================================
Write-Host "`n[STEP 1] Lancement du Registry Docker sur le Master..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP @"
docker ps -a --format '{{.Names}}' | grep -q 'docker-registry' && docker rm -f docker-registry || true
docker run -d --name docker-registry --restart always -p $REGISTRY_PORT`:5000 registry:2
sleep 3
curl -s http://localhost:$REGISTRY_PORT/v2/ > /dev/null && echo '[OK] Registry accessible' || echo '[ERROR] Registry non accessible'
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de déployer le registre" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Registry Docker déployé" -ForegroundColor Green

# ============================================================================
# STEP 2: Configurer la confiance du Registre sur tous les nodes
# ============================================================================
Write-Host "`n[STEP 2] Configuration du Registre (insecure) sur tous les nodes..." -ForegroundColor Yellow

# Script de configuration Docker
$config_cmd = @"
sudo mkdir -p /etc/docker
echo '{
  "insecure-registries": ["$REGISTRY_URL"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}' | sudo tee /etc/docker/daemon.json > /dev/null
sudo systemctl daemon-reload
sudo systemctl restart docker
sleep 3
docker --version
echo '[OK] Docker configuré'
"@

# Appliquer sur le Master
Write-Host "  → Configuration du Master..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP $config_cmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de configurer le Master" -ForegroundColor Red
    exit 1
}

# Appliquer sur les Workers
foreach ($i in 0..1) {
    $worker_ip = $WORKERS[$i]
    $worker_user = $WORKER_USERS[$i]
    Write-Host "  → Configuration du Worker $($i+1) ($worker_ip)..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip $config_cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Impossible de configurer le Worker $($i+1)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[OK] Tous les nodes configurés" -ForegroundColor Green

# ============================================================================
# STEP 3: Construire les images Docker localement
# ============================================================================
Write-Host "`n[STEP 3] Construction des images Docker (Windows local)..." -ForegroundColor Yellow

if (-not (Test-Path ".\backend\Dockerfile")) {
    Write-Host "[ERROR] Dockerfile backend non trouvé" -ForegroundColor Red
    exit 1
}

Write-Host "  → Build Backend..." -ForegroundColor Cyan
docker build -t $IMAGE_BACKEND .\backend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors du build Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend construit" -ForegroundColor Green

Write-Host "  → Build Frontend..." -ForegroundColor Cyan
docker build -t $IMAGE_FRONTEND .\frontend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors du build Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend construit" -ForegroundColor Green

# ============================================================================
# STEP 4: Taguer les images pour le Registre Local
# ============================================================================
Write-Host "`n[STEP 4] Taggage des images pour le Registre Local..." -ForegroundColor Yellow

$tag_backend = "$REGISTRY_URL/task-manager-backend:v1.0"
$tag_frontend = "$REGISTRY_URL/task-manager-frontend:v1.0"

docker tag $IMAGE_BACKEND $tag_backend
docker tag $IMAGE_FRONTEND $tag_frontend

Write-Host "[OK] Images taggées" -ForegroundColor Green
Write-Host "    Backend: $tag_backend" -ForegroundColor Cyan
Write-Host "    Frontend: $tag_frontend" -ForegroundColor Cyan

# ============================================================================
# STEP 5: Pousser les images vers le Registre Local
# ============================================================================
Write-Host "`n[STEP 5] Push des images vers le Registre Local..." -ForegroundColor Yellow

Write-Host "  → Push Backend..." -ForegroundColor Cyan
docker push $tag_backend
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend pushé" -ForegroundColor Green

Write-Host "  → Push Frontend..." -ForegroundColor Cyan
docker push $tag_frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Frontend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frontend pushé" -ForegroundColor Green

# ============================================================================
# STEP 6: Vérifier le contenu du Registre
# ============================================================================
Write-Host "`n[STEP 6] Vérification du Registre..." -ForegroundColor Yellow

$verify_output = ssh $MASTER_USER@$MASTER_IP "curl -s http://localhost:$REGISTRY_PORT/v2/_catalog"
Write-Host "  Contenu du Registre:" -ForegroundColor Cyan
Write-Host $verify_output

# ============================================================================
# STEP 7: Résumé final
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SETUP TERMINÉ AVEC SUCCÈS ✅" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nInformations pour Kubernetes :" -ForegroundColor Cyan
Write-Host "  Registry URL: $REGISTRY_URL" -ForegroundColor White
Write-Host "  Backend Image: $tag_backend" -ForegroundColor White
Write-Host "  Frontend Image: $tag_frontend" -ForegroundColor White

Write-Host "`nProchaines étapes :" -ForegroundColor Cyan
Write-Host "  1. Mettre à jour les manifests K8s avec les URLs du registre" -ForegroundColor White
Write-Host "  2. Appliquer les manifests au cluster" -ForegroundColor White
Write-Host "  3. Vérifier les Pods" -ForegroundColor White

Write-Host "`nCommandes utiles :" -ForegroundColor Cyan
Write-Host "  # Lister les images du registre" -ForegroundColor White
Write-Host "  curl -s http://$REGISTRY_URL/v2/_catalog" -ForegroundColor White
Write-Host "  # Vérifier les Pods" -ForegroundColor White
Write-Host "  kubectl get pods -n app-dev" -ForegroundColor White
Write-Host "  # Voir les logs d'un Pod" -ForegroundColor White
Write-Host "  kubectl logs -n app-dev <pod-name>" -ForegroundColor White
Write-Host "`n"
