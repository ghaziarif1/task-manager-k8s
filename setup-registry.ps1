# ============================================================================
# Script: setup-registry.ps1
# Objectif: Mettre en place un Registre Docker Local et configurer le cluster
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
Write-Host "SETUP REGISTRE DOCKER LOCAL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Déployer le Registry Docker sur le Master
# ============================================================================
Write-Host "`n[STEP 1] Déploiement du Registry Docker sur le Master ($MASTER_IP)..." -ForegroundColor Yellow

$registry_cmd = @"
# Vérifier si le registre existe déjà
if ! docker ps -a --format '{{.Names}}' | grep -q 'docker-registry'; then
    echo '[INFO] Lancement du Registry Docker...'
    docker run -d `
      --name docker-registry `
      --restart always `
      -p $REGISTRY_PORT`:5000 `
      registry:2
    sleep 3
    echo '[OK] Registry Docker démarré'
else
    echo '[INFO] Registry Docker déjà en cours d''exécution'
    docker start docker-registry 2>/dev/null || true
fi

# Vérifier la santé du registry
curl -s http://localhost:$REGISTRY_PORT/v2/ > /dev/null && echo '[OK] Registry accessible' || echo '[ERROR] Registry non accessible'
"@

ssh $MASTER_USER@$MASTER_IP $registry_cmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de déployer le registre sur le Master" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Registry Docker déployé" -ForegroundColor Green

# ============================================================================
# STEP 2: Configurer la confiance du Registre sur tous les nodes
# ============================================================================
Write-Host "`n[STEP 2] Configuration de la confiance du Registre (insecure registry)..." -ForegroundColor Yellow

$configure_registry = @"
# Créer le dossier de configuration Docker s'il n'existe pas
mkdir -p /etc/docker

# Créer/Mettre à jour daemon.json
cat > /etc/docker/daemon.json <<EOF
{
  "insecure-registries": ["$REGISTRY_URL"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Redémarrer le daemon Docker
systemctl restart docker
sleep 2

# Vérifier que Docker a redémarré correctement
docker --version
echo '[OK] Configuration appliquée et Docker redémarré'
"@

# Appliquer sur le Master
Write-Host "  → Configuration du Master..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP $configure_registry
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Impossible de configurer le Master" -ForegroundColor Red
    exit 1
}

# Appliquer sur les Workers
foreach ($i in 0..1) {
    $worker_ip = $WORKERS[$i]
    $worker_user = $WORKER_USERS[$i]
    Write-Host "  → Configuration du Worker $($i+1) ($worker_ip)..." -ForegroundColor Cyan
    ssh $worker_user@$worker_ip $configure_registry
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Impossible de configurer le Worker $($i+1)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[OK] Tous les nodes configurés" -ForegroundColor Green

# ============================================================================
# STEP 3: Construire les images Docker
# ============================================================================
Write-Host "`n[STEP 3] Construction des images Docker..." -ForegroundColor Yellow

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path ".\backend\Dockerfile")) {
    Write-Host "[ERROR] Dockerfile backend non trouvé. Vérifiez le répertoire courant." -ForegroundColor Red
    exit 1
}

Write-Host "  → Build Backend..." -ForegroundColor Cyan
docker build -t $IMAGE_BACKEND .\backend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors du build du Backend" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Backend construit" -ForegroundColor Green

Write-Host "  → Build Frontend..." -ForegroundColor Cyan
docker build -t $IMAGE_FRONTEND .\frontend\
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Erreur lors du build du Frontend" -ForegroundColor Red
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

# ============================================================================
# STEP 5: Pousser les images vers le Registre
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
# STEP 6: Vérification
# ============================================================================
Write-Host "`n[STEP 6] Vérification du Registre..." -ForegroundColor Yellow

$verify_cmd = @"
# Lister les images du registre
curl -s http://localhost:$REGISTRY_PORT/v2/_catalog | python3 -m json.tool 2>/dev/null || curl -s http://localhost:$REGISTRY_PORT/v2/_catalog
"@

Write-Host "  → Contenu du Registre Docker :" -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP $verify_cmd

# ============================================================================
# STEP 7: Afficher les informations finales
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
Write-Host "  3. Vérifier que les Pods démarre et télécharges les images" -ForegroundColor White

Write-Host "`nCommandes utiles :" -ForegroundColor Cyan
Write-Host "  # Vérifier les images du registre" -ForegroundColor White
Write-Host "  curl -s http://$REGISTRY_URL/v2/_catalog | ConvertFrom-Json" -ForegroundColor White
Write-Host "`n"
