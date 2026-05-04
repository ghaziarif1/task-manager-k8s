# ============================================================================
# Script: deploy-full-vm.ps1
# Objectif: DÉPLOIEMENT COMPLET - Docker Compose + Kubernetes sur VMs
# ============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKER1_IP = "192.168.1.19"
$WORKER1_USER = "k8suser"
$WORKER2_IP = "192.168.1.20"
$WORKER2_USER = "k8suser"

$WORKERS = @(
    @{IP = $WORKER1_IP; User = $WORKER1_USER},
    @{IP = $WORKER2_IP; User = $WORKER2_USER}
)

function Test-DockerDaemon {
    & docker info >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERREUR] Docker daemon non accessible." -ForegroundColor Red
        Write-Host "  Assurez-vous que Docker Desktop est demarre et que le moteur Docker est disponible." -ForegroundColor Yellow
        Write-Host "  Si vous utilisez Docker Desktop, activez Linux containers." -ForegroundColor Yellow
        exit 1
    }
}

function Invoke-RemoteSSH {
    param(
        [string]$User,
        [string]$IP,
        [string]$Command
    )

    $output = & ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$User@$IP" $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SSH error to $IP : $output"
    }
    return $output
}

function Invoke-RemoteSCP {
    param(
        [string]$LocalPath,
        [string]$User,
        [string]$IP,
        [string]$RemotePath
    )

    $remoteTarget = "$User@$IP:$RemotePath"
    $output = & scp -o BatchMode=yes -o StrictHostKeyChecking=no -r $LocalPath $remoteTarget 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SCP error to $IP : $output"
    }
    return $output
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DÉPLOIEMENT COMPLET - PHASE 1 & PHASE 2" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# PHASE 1: DOCKER COMPOSE (LOCAL)
# ============================================================================
Write-Host "`n[PHASE 1] Docker Compose - Déploiement local..." -ForegroundColor Yellow

try {
    docker compose -f docker-compose.yml down -v 2>$null
    Write-Host "  -> Nettoyage precedent..." -ForegroundColor Cyan
} catch {}

# Verifier si le port est libre
$port_check = netstat -ano 2>$null | Select-String ":5432"
if ($port_check) {
    Write-Host "  [!] Port 5432 deja utilise, liberation en cours..." -ForegroundColor Yellow
    $process_id = $port_check -split '\s+' | Select-Object -Last 1
    Stop-Process -Id $process_id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

Write-Host "  -> Build et demarrage..." -ForegroundColor Cyan
Test-DockerDaemon

docker compose -f docker-compose.yml up --build -d

Write-Host "  -> Verification des services..." -ForegroundColor Cyan
$health_check = docker compose -f docker-compose.yml ps | Select-String "healthy|running"
if ($health_check) {
    Write-Host "[OK] Phase 1 - Docker Compose active" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Phase 1 - Services en cours de demarrage..." -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2: KUBERNETES - CONSTRUCTION DES IMAGES
# ============================================================================
Write-Host "`n[PHASE 2] Kubernetes - Construction des images Docker..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker build -t task-manager-k8s-backend:latest -f backend/Dockerfile ./backend

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker build -t task-manager-k8s-frontend:v5 -f frontend/Dockerfile ./frontend

Write-Host "[OK] Images construites" -ForegroundColor Green

# ============================================================================
# PHASE 2: KUBERNETES - SAUVEGARDE DES IMAGES
# ============================================================================
Write-Host "`n[PHASE 2] Kubernetes - Sauvegarde des images en TAR..." -ForegroundColor Yellow

Write-Host "  -> Backend TAR..." -ForegroundColor Cyan
docker save -o backend.tar task-manager-k8s-backend:latest

Write-Host "  -> Frontend TAR..." -ForegroundColor Cyan
docker save -o frontend.tar task-manager-k8s-frontend:v5

Write-Host "[OK] Images sauvegardées" -ForegroundColor Green

# ============================================================================
# PHASE 2: KUBERNETES - TRANSFER IMAGES AUX VMS
# ============================================================================
Write-Host "`n[PHASE 2] Kubernetes - Transfer des images aux workers..." -ForegroundColor Yellow

foreach ($worker in $WORKERS) {
    Write-Host "  -> Worker ($($worker.IP))..." -ForegroundColor Cyan
    
    try {
        # Creer dossier distant
        Invoke-RemoteSSH -User $worker.User -IP $worker.IP -Command "mkdir -p /tmp/k8s-images"
        
        # Transferer les images TAR
        Invoke-RemoteSCP -LocalPath backend.tar -User $worker.User -IP $worker.IP -RemotePath "/tmp/k8s-images/"
        Invoke-RemoteSCP -LocalPath frontend.tar -User $worker.User -IP $worker.IP -RemotePath "/tmp/k8s-images/"
        
        # Charger les images dans Docker du worker
        Invoke-RemoteSSH -User $worker.User -IP $worker.IP -Command "docker load -i /tmp/k8s-images/backend.tar"
        Invoke-RemoteSSH -User $worker.User -IP $worker.IP -Command "docker load -i /tmp/k8s-images/frontend.tar"
        
        Write-Host "     [OK]" -ForegroundColor Green
    } catch {
        Write-Host "     [ERROR] $_" -ForegroundColor Red
        Write-Host "     Continuant malgre l'erreur..." -ForegroundColor Yellow
    }
}

# ============================================================================
# PHASE 2: KUBERNETES - TRANSFÉRER MANIFESTS
# ============================================================================
Write-Host "`n[PHASE 2] Kubernetes - Transfer des manifests..." -ForegroundColor Yellow

$TEMP_MANIFEST = "/tmp/manifests"
Invoke-RemoteSSH -User $MASTER_USER -IP $MASTER_IP -Command "mkdir -p $TEMP_MANIFEST && rm -rf $TEMP_MANIFEST/*"

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
        Invoke-RemoteSCP -LocalPath $manifest -User $MASTER_USER -IP $MASTER_IP -RemotePath "$TEMP_MANIFEST/"
    } else {
        Write-Host "  [!] $(Split-Path $manifest -Leaf) - NON TROUVE" -ForegroundColor Yellow
    }
}

Write-Host "[OK] Manifests transférés" -ForegroundColor Green

# ============================================================================
# PHASE 2: KUBERNETES - APPLIQUER MANIFESTS
# ============================================================================
Write-Host "`n[PHASE 2] Kubernetes - Application des manifests..." -ForegroundColor Yellow

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
    
    Invoke-RemoteSSH -User $MASTER_USER -IP $MASTER_IP -Command "kubectl apply -f $remote_file" | Out-Null
    
    Write-Host "     [OK]" -ForegroundColor Green
}

# ============================================================================
# PHASE 2: KUBERNETES - ATTENDRE LES PODS
# ============================================================================
Write-Host "`n[PHASE 2] Kubernetes - Attente des pods (max 120 secondes)..." -ForegroundColor Yellow

$timeout = 120
$interval = 5
$elapsed = 0

while ($elapsed -lt $timeout) {
    try {
        $pods_status = Invoke-RemoteSSH -User $MASTER_USER -IP $MASTER_IP -Command "kubectl get pods -n app-dev -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{"\n"}{end}'"
    } catch {
        Write-Host "  [ERROR] Impossible de recuperer le status des pods: $_" -ForegroundColor Red
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($pods_status)) {
        Write-Host "  [ERROR] Aucun status de pods recu depuis le master K8s" -ForegroundColor Red
        exit 1
    }

    $all_ready = $true
    foreach ($line in $pods_status.Split("`n")) {
        if ($line -and -not $line.Contains("Running") -and -not $line.Contains("Succeeded")) {
            $all_ready = $false
            break
        }
    }
    
    if ($all_ready) {
        Write-Host "  [OK] Tous les pods sont prêts!" -ForegroundColor Green
        break
    }
    
    Write-Host "  Status à ${elapsed}s..." -ForegroundColor Gray
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

# ============================================================================
# RESUME FINAL
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RESUME - DEPLOIEMENT COMPLET" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[PHASE 1] Docker Compose (LOCAL):" -ForegroundColor Yellow
Write-Host "  Frontend: http://localhost:8080" -ForegroundColor Green
Write-Host "  Backend: http://localhost:4000/api/tasks" -ForegroundColor Green

Write-Host "`n[PHASE 2] Kubernetes (VMs):" -ForegroundColor Yellow
Write-Host "  Master: $MASTER_IP" -ForegroundColor Green
Write-Host "  Workers: $WORKER1_IP, $WORKER2_IP" -ForegroundColor Green

try {
    Invoke-RemoteSSH -User $MASTER_USER -IP $MASTER_IP -Command "kubectl get nodes; echo ''; kubectl get pods -n app-dev" | Out-Null
} catch {
    Write-Host "  [!] Impossible de verifier le cluster K8s" -ForegroundColor Yellow
}

Write-Host "`n[OK] Deploiement complet termine!" -ForegroundColor Green
Write-Host "" -ForegroundColor White

# ============================================================================
# NETTOYAGE
# ============================================================================
Write-Host "`nNettoyage des fichiers temporaires..." -ForegroundColor Yellow
Remove-Item -Path backend.tar, frontend.tar -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Fait" -ForegroundColor Green
