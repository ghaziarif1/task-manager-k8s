# ============================================================================
# Script: test-vm-readiness.ps1
# Objectif: Verifier les prerequis sur les VMs avant le deploiement
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKER1_IP = "192.168.1.19"
$WORKER1_USER = "k8suser"
$WORKER2_IP = "192.168.1.20"
$WORKER2_USER = "k8suser"

$WORKERS = @(
    @{IP = $WORKER1_IP; User = $WORKER1_USER; Name = "Worker 1"},
    @{IP = $WORKER2_IP; User = $WORKER2_USER; Name = "Worker 2"}
)

function Invoke-SSHCheck {
    param(
        [string]$User,
        [string]$IP,
        [string]$Command
    )

    try {
        $output = & ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$User@$IP" $Command 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $output = $_.Exception.Message
        $exitCode = 1
    }

    return @{ExitCode = $exitCode; Output = $output}
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION DE LA PREPARATION DES VMs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# TEST 1: CONNECTIVITE SSH
# ============================================================================
Write-Host "[TEST 1] Connectivite SSH..." -ForegroundColor Yellow

$ssh_ok = $true

# Master
$result = Invoke-SSHCheck -User $MASTER_USER -IP $MASTER_IP -Command "echo OK"
if ($result.ExitCode -eq 0) {
    Write-Host "  OK Master ($MASTER_IP)" -ForegroundColor Green
} else {
    Write-Host "  ERREUR Master ($MASTER_IP)" -ForegroundColor Red
    Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
    $ssh_ok = $false
}

# Workers
foreach ($worker in $WORKERS) {
    $result = Invoke-SSHCheck -User $worker.User -IP $worker.IP -Command "echo OK"
    if ($result.ExitCode -eq 0) {
        Write-Host "  OK $($worker.Name) ($($worker.IP))" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR $($worker.Name) ($($worker.IP))" -ForegroundColor Red
        Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
        $ssh_ok = $false
    }
}

if (-not $ssh_ok) {
    Write-Host "`n[ERREUR] Impossible de se connecter a une ou plusieurs VMs" -ForegroundColor Red
    Write-Host "  Verifiez :" -ForegroundColor Yellow
    Write-Host "    1. Les VMs sont allumees" -ForegroundColor Gray
    Write-Host "    2. Les IPs sont correctes" -ForegroundColor Gray
    Write-Host "    3. SSH est configure (cles SSH ou mot de passe)" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Toutes les VMs sont accessibles en SSH" -ForegroundColor Green

# ============================================================================
# TEST 2: DOCKER SUR MASTER ET WORKERS
# ============================================================================
Write-Host "`n[TEST 2] Docker..." -ForegroundColor Yellow

$docker_ok = $true

# Master
$result = Invoke-SSHCheck -User $MASTER_USER -IP $MASTER_IP -Command "docker --version"
if ($result.ExitCode -eq 0) {
    Write-Host "  OK Master: $($result.Output.Trim())" -ForegroundColor Green
} else {
    Write-Host "  ERREUR Master - Docker non accessible" -ForegroundColor Red
    Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
    $docker_ok = $false
}

# Workers
foreach ($worker in $WORKERS) {
    $result = Invoke-SSHCheck -User $worker.User -IP $worker.IP -Command "docker --version"
    if ($result.ExitCode -eq 0) {
        Write-Host "  OK $($worker.Name): $($result.Output.Trim())" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR $($worker.Name) - Docker non accessible" -ForegroundColor Red
        Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
        $docker_ok = $false
    }
}

if (-not $docker_ok) {
    Write-Host "`n[ERREUR] Docker n'est pas accessible" -ForegroundColor Red
    exit 1
}

# ============================================================================
# TEST 3: KUBERNETES SUR MASTER
# ============================================================================
Write-Host "`n[TEST 3] Kubernetes (Master)..." -ForegroundColor Yellow

$result = Invoke-SSHCheck -User $MASTER_USER -IP $MASTER_IP -Command "kubectl version --short"
if ($result.ExitCode -eq 0) {
    Write-Host "  OK Kubernetes disponible:" -ForegroundColor Green
    Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
} else {
    Write-Host "  ERREUR Kubernetes non accessible" -ForegroundColor Red
    Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
    exit 1
}

# ============================================================================
# TEST 4: ETAT DU CLUSTER
# ============================================================================
Write-Host "`n[TEST 4] Etat du cluster..." -ForegroundColor Yellow

$result = Invoke-SSHCheck -User $MASTER_USER -IP $MASTER_IP -Command "kubectl get nodes"
if ($result.ExitCode -eq 0) {
    Write-Host "  Nodes:" -ForegroundColor Cyan
    $result.Output | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "  ERREUR Impossible de recuperer les nodes" -ForegroundColor Red
    Write-Host "    $($result.Output.Trim())" -ForegroundColor Gray
    exit 1
}

# ============================================================================
# RESUME FINAL
# ============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RESUME - PREPARATION DES VMs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[OK] Les VMs sont PRETS pour le deploiement!" -ForegroundColor Green

Write-Host "`nProchaines etapes :" -ForegroundColor Yellow
Write-Host "  1. Executer: .\deploy-full-vm.ps1" -ForegroundColor Gray
Write-Host "  2. Attendre la fin du deploiement (5-10 minutes)" -ForegroundColor Gray
Write-Host "  3. Verifier avec: kubectl get pods -n app-dev" -ForegroundColor Gray
Write-Host "  4. Acceder aux services (voir DEPLOYMENT-GUIDE-VM.md)" -ForegroundColor Gray

Write-Host "" -ForegroundColor White
