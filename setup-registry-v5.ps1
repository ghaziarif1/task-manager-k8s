# ============================================================================
# Script: setup-registry-v5.ps1
# Objectif: Mettre en place un Registre Docker Local
# Version: Avec instructions manuelles pour les droits sudo
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
Write-Host "SETUP REGISTRE DOCKER LOCAL - V5" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n⚠️  IMPORTANT: Vous devez avoir les droits sudo sur les VMs" -ForegroundColor Yellow
Write-Host "Si vous n'avez pas sudo, exécutez ces commandes sur CHAQUE VM:" -ForegroundColor Yellow
Write-Host "  sudo usermod -aG docker `$USER" -ForegroundColor White
Write-Host "  sudo systemctl restart docker" -ForegroundColor White
Write-Host "  newgrp docker" -ForegroundColor White
Write-Host "`nAppuyez sur Entrée quand c'est fait..." -ForegroundColor Yellow
Read-Host

# ============================================================================
# STEP 1: Vérifier les droits Docker sur les VMs
# ============================================================================
Write-Host "`n[STEP 1] Vérification des droits Docker..." -ForegroundColor Yellow

Write-Host "  → Test Master..." -ForegroundColor Cyan
$docker_test = ssh $MASTER_USER@$MASTER_IP "docker --version"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker non accessible sur Master. Vérifiez les droits utilisateur." -ForegroundColor Red
    Write-Host "Solution: sudo usermod -aG docker $MASTER_USER && sudo systemctl restart docker" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Docker accessible sur Master" -ForegroundColor Green

foreach ($i in 0..1) {
    $worker_ip = $WORKERS[$i]
    $worker_user = $WORKER_USERS[$i]
    Write-Host "  → Test Worker $($i+1) ($worker_ip)..." -ForegroundColor Cyan
    $docker_test = ssh $worker_user@$worker_ip "docker --version"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker non accessible sur Worker $($i+1). Vérifiez les droits utilisateur." -ForegroundColor Red
        Write-Host "Solution: sudo usermod -aG docker $worker_user && sudo systemctl restart docker" -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "[OK] Docker accessible sur tous les nodes" -ForegroundColor Green

# ============================================================================
# STEP 2: Déployer le Registry Docker sur le Master
# ============================================================================
Write-Host "`n[STEP 2] Déploiement du Registry Docker sur le Master..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "docker ps -a --format '{{.Names}}' | grep -q 'docker-registry' && docker rm -f docker-registry || true"
ssh $MASTER_USER@$MASTER_IP "docker run -d --name docker-registry --restart always -p $REGISTRY_PORT`:5000 registry:2"
Start-Sleep -Seconds 3

# Vérifier que le registry fonctionne
$registry_check = ssh $MASTER_USER@$MASTER_IP "curl -s http://localhost:$REGISTRY_PORT/v2/ > /dev/null && echo 'OK' || echo 'ERROR'"
if ($registry_check -notlike "*OK*") {
    Write-Host "[ERROR] Registry non accessible sur le Master" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Registry Docker déployé et accessible" -ForegroundColor Green

# ============================================================================
# STEP 3: Configuration manuelle du Registre (insecure)
# ============================================================================
Write-Host "`n[STEP 3] Configuration MANUELLE requise sur chaque node..." -ForegroundColor Yellow

$config_commands = @"
# Exécutez ces commandes sur CHAQUE VM (Master + Workers):
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
"@

Write-Host "📋 COMMANDES À EXÉCUTER MANUELLEMENT SUR CHAQUE VM:" -ForegroundColor Cyan
Write-Host $config_commands -ForegroundColor White

Write-Host "`nSur Master ($MASTER_IP):" -ForegroundColor Yellow
Write-Host "  ssh $MASTER_USER@$MASTER_IP" -ForegroundColor White
Write-Host "  [collez les commandes ci-dessus]" -ForegroundColor White

Write-Host "`nSur Worker 1 ($($WORKERS[0])):" -ForegroundColor Yellow
Write-Host "  ssh $($WORKER_USERS[0])@$($WORKERS[0])" -ForegroundColor White
Write-Host "  [collez les commandes ci-dessus]" -ForegroundColor White

Write-Host "`nSur Worker 2 ($($WORKERS[1])):" -ForegroundColor Yellow
Write-Host "  ssh $($WORKER_USERS[1])@$($WORKERS[1])" -ForegroundColor White
Write-Host "  [collez les commandes ci-dessus]" -ForegroundColor White

Write-Host "`n✅ Quand c'est fait sur TOUS les nodes, appuyez sur Entrée pour continuer..." -ForegroundColor Green
Read-Host

# ============================================================================
# STEP 4: Construire les images Docker localement
# ============================================================================
Write-Host "`n[STEP 4] Construction des images Docker (Windows local)..." -ForegroundColor Yellow

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
# STEP 5: Taguer les images pour le Registre Local
# ============================================================================
Write-Host "`n[STEP 5] Taggage des images pour le Registre Local..." -ForegroundColor Yellow

$tag_backend = "$REGISTRY_URL/task-manager-backend:v1.0"
$tag_frontend = "$REGISTRY_URL/task-manager-frontend:v1.0"

docker tag $IMAGE_BACKEND $tag_backend
docker tag $IMAGE_FRONTEND $tag_frontend

Write-Host "[OK] Images taggées" -ForegroundColor Green
Write-Host "    Backend: $tag_backend" -ForegroundColor Cyan
Write-Host "    Frontend: $tag_frontend" -ForegroundColor Cyan

# ============================================================================
# STEP 6: Pousser les images vers le Registre Local
# ============================================================================
Write-Host "`n[STEP 6] Push des images vers le Registre Local..." -ForegroundColor Yellow

Write-Host "  → Push Backend..." -ForegroundColor Cyan
docker push $tag_backend
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Backend" -ForegroundColor Red
    Write-Host "Vérifiez que le registry est accessible: curl -s http://$REGISTRY_URL/v2/" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Backend pushé" -ForegroundColor Green

Write-Host "  → Push Frontend..." -ForegroundColor Cyan
docker push $tag_frontend
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de pousser le Frontend" -ForegroundColor Red
    Write-Host "Vérifiez que le registry est accessible: curl -s http://$REGISTRY_URL/v2/" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Frontend pushé" -ForegroundColor Green

# ============================================================================
# STEP 7: Vérifier le contenu du Registre
# ============================================================================
Write-Host "`n[STEP 7] Vérification du Registre..." -ForegroundColor Yellow

$verify_output = ssh $MASTER_USER@$MASTER_IP "curl -s http://localhost:$REGISTRY_PORT/v2/_catalog"
Write-Host "  Contenu du Registre:" -ForegroundColor Cyan
Write-Host $verify_output

# ============================================================================
# STEP 8: Résumé final
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
