# ============================================================================
# Script: deploy-kubernetes.ps1
# Objectif: Déployer l'application complète sur Kubernetes
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$K8S_MANIFEST_DIR = ".\k8s"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEPLOIEMENT KUBERNETES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# STEP 1: Vérifier la connectivité au cluster
# ============================================================================
Write-Host "`n[STEP 1] Verification du cluster..." -ForegroundColor Yellow

$kubectl_check = ssh $MASTER_USER@$MASTER_IP "kubectl cluster-info" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Cluster non accessible" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Cluster accessible" -ForegroundColor Green

# ============================================================================
# STEP 2: Appliquer les manifests
# ============================================================================
Write-Host "`n[STEP 2] Application des manifests..." -ForegroundColor Yellow

$manifests = @(
    "namespace.yaml",
    "configmap.yaml",
    "secret.yaml",
    "db-statefulset.yaml",
    "backend-deployment.yaml",
    "frontend-deployment.yaml",
    "networkpolicy.yaml"
)

foreach ($manifest in $manifests) {
    $manifest_path = Join-Path $K8S_MANIFEST_DIR $manifest
    
    if (-not (Test-Path $manifest_path)) {
        Write-Host "  [!] $manifest - NON TROUVE" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "  -> Applying $manifest..." -ForegroundColor Cyan
    
    # Lire le contenu du manifest
    $content = Get-Content $manifest_path -Raw
    
    # L'appliquer via kubectl
    $content | ssh $MASTER_USER@$MASTER_IP "kubectl apply -f -"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "     [OK]" -ForegroundColor Green
    } else {
        Write-Host "     [ERROR]" -ForegroundColor Red
    }
}

# ============================================================================
# STEP 3: Attendre que les pods soient running
# ============================================================================
Write-Host "`n[STEP 3] Attente des pods..." -ForegroundColor Yellow

$wait_seconds = 60
for ($i = 0; $i -lt $wait_seconds; $i += 5) {
    $pods = ssh $MASTER_USER@$MASTER_IP "kubectl get pods -n app-dev -o jsonpath='{.items[*].status.phase}' 2>/dev/null"
    
    if ($pods -match "Running" -and -not ($pods -match "Pending")) {
        Write-Host "[OK] Tous les pods sont en Running" -ForegroundColor Green
        break
    }
    
    Write-Host "  Attente: ${i}s / ${wait_seconds}s..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
}

# ============================================================================
# STEP 4: Afficher le statut
# ============================================================================
Write-Host "`n[STEP 4] Statut des deployments..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "kubectl get deployments -n app-dev"
ssh $MASTER_USER@$MASTER_IP "kubectl get statefulsets -n app-dev"
ssh $MASTER_USER@$MASTER_IP "kubectl get pods -n app-dev"
ssh $MASTER_USER@$MASTER_IP "kubectl get services -n app-dev"

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "DEPLOIEMENT TERMINE !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Pour consulter les logs:" -ForegroundColor Cyan
Write-Host "  kubectl logs -n app-dev <pod-name>" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Pour acceder au frontend:" -ForegroundColor Cyan
Write-Host "  kubectl port-forward -n app-dev svc/frontend 3000:80" -ForegroundColor White
