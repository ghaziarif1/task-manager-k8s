# ============================================================================
# Script: deploy-phase2.ps1
# Objectif: PHASE 2 - Déployer sur Kubernetes sans passer par les images TAR
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$TEMP_MANIFEST = "/tmp/manifests"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PHASE 2: DEPLOIEMENT KUBERNETES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Vérifier la connectivité
# ============================================================================
Write-Host "[STEP 1] Vérification de la connectivité..." -ForegroundColor Yellow

try {
    $result = ssh $MASTER_USER@$MASTER_IP "kubectl version --short" -ErrorAction Stop
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Connexion au cluster établie" -ForegroundColor Green
        Write-Host "     $result" -ForegroundColor Gray
    }
} catch {
    Write-Host "[ERROR] Impossible de se connecter au cluster" -ForegroundColor Red
    exit 1
}

# ============================================================================
# STEP 2: Transférer les manifests
# ============================================================================
Write-Host "`n[STEP 2] Transfert des manifests..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "mkdir -p $TEMP_MANIFEST" -ErrorAction Stop

$manifests = @(
    "k8s/namespace.yaml",
    "k8s/configmap.yaml", 
    "k8s/secret.yaml",
    "k8s/db-statefulset.yaml",
    "k8s/backend-deployment.yaml",
    "k8s/frontend-deployment.yaml",
    "k8s/networkpolicy.yaml"
)

foreach ($manifest in $manifests) {
    if (Test-Path $manifest) {
        Write-Host "  -> $(Split-Path $manifest -Leaf)..." -ForegroundColor Cyan
        scp $manifest $MASTER_USER@$MASTER_IP`:$TEMP_MANIFEST/ -ErrorAction Stop
    } else {
        Write-Host "  [!] $(Split-Path $manifest -Leaf) - NON TROUVE" -ForegroundColor Yellow
    }
}

Write-Host "[OK] Manifests transférés" -ForegroundColor Green

# ============================================================================
# STEP 3: Appliquer les manifests
# ============================================================================
Write-Host "`n[STEP 3] Application des manifests..." -ForegroundColor Yellow

$apply_order = @(
    "namespace.yaml",
    "configmap.yaml",
    "secret.yaml",
    "db-statefulset.yaml",
    "backend-deployment.yaml",
    "frontend-deployment.yaml",
    "networkpolicy.yaml"
)

foreach ($file in $apply_order) {
    $remote_file = "$TEMP_MANIFEST/$file"
    
    Write-Host "  -> Applying $file..." -ForegroundColor Cyan
    
    $result = ssh $MASTER_USER@$MASTER_IP "kubectl apply -f $remote_file" -ErrorAction Stop
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "     [OK]" -ForegroundColor Green
    } else {
        Write-Host "     [ERROR] $result" -ForegroundColor Red
    }
}

# ============================================================================
# STEP 4: Attendre les pods
# ============================================================================
Write-Host "`n[STEP 4] Attente des pods (max 120 secondes)..." -ForegroundColor Yellow

$timeout = 120
$interval = 5
$elapsed = 0

while ($elapsed -lt $timeout) {
    Write-Host "  Status à ${elapsed}s..." -ForegroundColor Gray
    
    $pods_status = ssh $MASTER_USER@$MASTER_IP "kubectl get pods -n app-dev -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{\"\\n\"}{end}' 2>/dev/null"
    
    # Vérifier si tous les pods sont Running
    if ($pods_status) {
        $all_running = $true
        foreach ($line in $pods_status.Split("`n")) {
            if ($line -and -not $line.Contains("Running")) {
                $all_running = $false
                break
            }
        }
        
        if ($all_running) {
            Write-Host "[OK] Tous les pods sont en Running!" -ForegroundColor Green
            break
        }
    }
    
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

# ============================================================================
# STEP 5: Afficher le statut final
# ============================================================================
Write-Host "`n[STEP 5] Statut final..." -ForegroundColor Yellow
Write-Host "" -ForegroundColor White

Write-Host "Deployments:" -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "kubectl get deployments -n app-dev" -ErrorAction Stop

Write-Host "`nStatefulSets:" -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "kubectl get statefulsets -n app-dev" -ErrorAction Stop

Write-Host "`nPods:" -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "kubectl get pods -n app-dev" -ErrorAction Stop

Write-Host "`nServices:" -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "kubectl get services -n app-dev" -ErrorAction Stop

# ============================================================================
# STEP 6: Nettoyer
# ============================================================================
Write-Host "`n[STEP 6] Nettoyage..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "rm -rf $TEMP_MANIFEST" -ErrorAction Stop
Write-Host "[OK] Nettoyage terminé" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "PHASE 2 COMPLETEE !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Prochaine étape: Phase 3 - Tests et Validation" -ForegroundColor Yellow
