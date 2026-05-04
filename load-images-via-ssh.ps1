# ============================================================================
# Script: load-images-via-ssh.ps1
# Objectif: Charger les images via SSH et cat (compatible PS 5.1)
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKERS = @( @{IP = "192.168.1.19"; User = "k8s-worker1"}, @{IP = "192.168.1.20"; User = "k8s-worker2"} )

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CHARGER LES IMAGES VIA SSH" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Sauvegarder les images
# ============================================================================
Write-Host "[STEP 1] Sauvegarder les images Docker..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker save task-manager-backend:v1.0 -o backend.tar
$backend_size = [math]::Round((Get-Item backend.tar).Length / 1MB, 2)
Write-Host "     Taille: $backend_size MB" -ForegroundColor Gray

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker save task-manager-frontend:v1.0 -o frontend.tar
$frontend_size = [math]::Round((Get-Item frontend.tar).Length / 1MB, 2)
Write-Host "     Taille: $frontend_size MB" -ForegroundColor Gray

Write-Host "[OK] Images sauvegardées" -ForegroundColor Green

# ============================================================================
# STEP 2: Fonction pour charger sur un node
# ============================================================================
function Load-ImageOnNode {
    param(
        [string]$NodeUser,
        [string]$NodeIP,
        [string]$ImageTarPath,
        [string]$ImageName,
        [string]$NodeName
    )
    
    Write-Host "  -> $NodeName - Load $ImageName..." -ForegroundColor Cyan
    
    # Créer une commande pour charger l'image via stdin
    $cmd = @"
cat > /tmp/image.tar && docker load -i /tmp/image.tar && docker tag $ImageName task-manager-k8s-${ImageName}:latest && docker save task-manager-k8s-${ImageName}:latest | sudo ctr -n k8s.io images import - && rm /tmp/image.tar
"@
    
    # Transférer via SSH
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.FileName = "ssh"
    $proc.StartInfo.Arguments = "$NodeUser@$NodeIP `"$cmd`""
    $proc.StartInfo.RedirectStandardInput = $true
    $proc.Start()
    
    # Ouvrir le fichier et le streamer
    $file = [System.IO.File]::OpenRead($ImageTarPath)
    $file.CopyTo($proc.StandardInput.BaseStream)
    $proc.StandardInput.Close()
    $proc.WaitForExit()
    $file.Close()
    
    if ($proc.ExitCode -eq 0) {
        Write-Host "     [OK]" -ForegroundColor Green
        return $true
    } else {
        Write-Host "     [ERROR] Exit code: $($proc.ExitCode)" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# STEP 3: Charger sur Master
# ============================================================================
Write-Host "`n[STEP 3] Charger sur Master..." -ForegroundColor Yellow

Load-ImageOnNode -NodeUser $MASTER_USER -NodeIP $MASTER_IP -ImageTarPath "backend.tar" -ImageName "task-manager-backend:v1.0" -NodeName "Master"
Load-ImageOnNode -NodeUser $MASTER_USER -NodeIP $MASTER_IP -ImageTarPath "frontend.tar" -ImageName "task-manager-frontend:v1.0" -NodeName "Master"

# ============================================================================
# STEP 4: Charger sur tous les Workers
# ============================================================================
Write-Host "`n[STEP 4] Charger sur les Workers..." -ForegroundColor Yellow

foreach ($worker in $WORKERS) {
    Load-ImageOnNode -NodeUser $worker.User -NodeIP $worker.IP -ImageTarPath "backend.tar" -ImageName "task-manager-backend:v1.0" -NodeName "Worker ($($worker.IP))"
    Load-ImageOnNode -NodeUser $worker.User -NodeIP $worker.IP -ImageTarPath "frontend.tar" -ImageName "task-manager-frontend:v1.0" -NodeName "Worker ($($worker.IP))"
}

# ============================================================================
# STEP 5: Vérifier sur Master
# ============================================================================
Write-Host "`n[STEP 5] Vérification..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "ctr -n k8s.io images ls | grep task-manager"

# ============================================================================
# STEP 6: Nettoyage
# ============================================================================
Write-Host "`n[STEP 6] Nettoyage..." -ForegroundColor Yellow

Remove-Item -Path "backend.tar" -Force
Remove-Item -Path "frontend.tar" -Force

Write-Host "[OK] Nettoyage terminé" -ForegroundColor Green

# ============================================================================
# FIN
# ============================================================================
Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "IMAGES CHARGEES SUR TOUS LES NODES !" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Prochaine étape: Exécuter .\\deploy-phase2.ps1" -ForegroundColor Yellow
