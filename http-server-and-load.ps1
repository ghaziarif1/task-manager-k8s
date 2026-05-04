# ============================================================================
# Script: http-server-and-load.ps1
# Objectif: Démarrer un serveur HTTP et charger les images via curl
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"
$WORKERS = @( @{IP = "192.168.1.19"; User = "k8s-worker1"}, @{IP = "192.168.1.20"; User = "k8s-worker2"} )
$WINDOWS_IP = "192.168.1.x"  # À déterminer automatiquement
$HTTP_PORT = $null  # À déterminer automatiquement

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CHARGER VIA HTTP SERVER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

# ============================================================================
# STEP 1: Déterminer l'IP du Windows client
# ============================================================================
Write-Host "[STEP 1] Déterminer l'IP Windows..." -ForegroundColor Yellow

$local_ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -or $_.PrefixOrigin -eq "Manual" } | Select-Object -ExpandProperty IPAddress

$windows_ip = $local_ips | Where-Object { $_ -like "192.168.1.*" } | Select-Object -First 1

if (-not $windows_ip) {
    Write-Host "[ERROR] Impossible de déterminer l'IP Windows" -ForegroundColor Red
    exit 1
}

Write-Host "  IP Windows: $windows_ip" -ForegroundColor Cyan
Write-Host "[OK] IP détectée" -ForegroundColor Green

# ============================================================================
# STEP 2: Sauvegarder les images
# ============================================================================
Write-Host "`n[STEP 2] Sauvegarder les images..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
docker save task-manager-backend:v1.0 -o backend.tar
Write-Host "     OK" -ForegroundColor Green

Write-Host "  -> Frontend..." -ForegroundColor Cyan
docker save task-manager-frontend:v1.0 -o frontend.tar
Write-Host "     OK" -ForegroundColor Green

# ============================================================================
# STEP 3: Démarrer le serveur HTTP
# ============================================================================
Write-Host "`n[STEP 3] Démarrer le serveur HTTP..." -ForegroundColor Yellow

# Trouver un port libre
$listener = $null
$port_found = $false

for ($port = 50000; $port -lt 50100; $port++) {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$port/")
    
    try {
        $listener.Start()
        $HTTP_PORT = $port
        $port_found = $true
        Write-Host "  -> Serveur démarré sur port $HTTP_PORT" -ForegroundColor Cyan
        break
    } catch {
        $listener.Close()
    }
}

if (-not $port_found) {
    Write-Host "  [ERROR] Impossible de trouver un port libre" -ForegroundColor Red
    exit 1
}

# Fonction pour servir les fichiers
function Serve-HttpRequests {
    param([System.Net.HttpListener]$listener)
    
    try {
        while ($true) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            $requested_file = $request.Url.LocalPath.TrimStart('/')
            $file_path = Join-Path $pwd $requested_file
            
            if (Test-Path $file_path) {
                Write-Host "    [HTTP] Serving: $requested_file" -ForegroundColor Gray
                $file_bytes = [System.IO.File]::ReadAllBytes($file_path)
                $response.ContentLength64 = $file_bytes.Length
                $response.OutputStream.Write($file_bytes, 0, $file_bytes.Length)
            } else {
                Write-Host "    [HTTP] Not found: $requested_file" -ForegroundColor Gray
                $response.StatusCode = 404
            }
            
            $response.Close()
        }
    } finally {
        $listener.Close()
    }
}

# Démarrer le serveur en background
$server_job = Start-Job -ScriptBlock $function:Serve-HttpRequests -ArgumentList $listener

Write-Host "[OK] Serveur HTTP en cours d'exécution" -ForegroundColor Green

# ============================================================================
# STEP 4: Charger sur Master
# ============================================================================
Write-Host "`n[STEP 4] Charger sur Master..." -ForegroundColor Yellow

Write-Host "  -> Backend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "curl -s http://${windows_ip}:${HTTP_PORT}/backend.tar | docker load && docker tag task-manager-backend:v1.0 task-manager-k8s-backend:latest && docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import -"
Write-Host "     [OK]" -ForegroundColor Green

Write-Host "  -> Frontend..." -ForegroundColor Cyan
ssh $MASTER_USER@$MASTER_IP "curl -s http://${windows_ip}:${HTTP_PORT}/frontend.tar | docker load && docker tag task-manager-frontend:v1.0 task-manager-k8s-frontend:latest && docker save task-manager-k8s-frontend:latest | sudo ctr -n k8s.io images import -"
Write-Host "     [OK]" -ForegroundColor Green

# ============================================================================
# STEP 5: Charger sur tous les Workers
# ============================================================================
Write-Host "`n[STEP 5] Charger sur les Workers..." -ForegroundColor Yellow

foreach ($worker in $WORKERS) {
    Write-Host "  -> Worker ($($worker.IP))..." -ForegroundColor Cyan
    
    # Backend
    ssh $worker.User@$worker.IP "curl -s http://${windows_ip}:${HTTP_PORT}/backend.tar | docker load && docker tag task-manager-backend:v1.0 task-manager-k8s-backend:latest && docker save task-manager-k8s-backend:latest | sudo ctr -n k8s.io images import -"
    
    # Frontend
    ssh $worker.User@$worker.IP "curl -s http://${windows_ip}:${HTTP_PORT}/frontend.tar | docker load && docker tag task-manager-frontend:v1.0 task-manager-k8s-frontend:latest && docker save task-manager-k8s-frontend:latest | sudo ctr -n k8s.io images import -"
    
    Write-Host "     [OK]" -ForegroundColor Green
}

# ============================================================================
# STEP 6: Arrêter le serveur HTTP
# ============================================================================
Write-Host "`n[STEP 6] Arrêter le serveur..." -ForegroundColor Yellow

$listener.Close()
Stop-Job -Job $server_job -Force
Write-Host "[OK] Serveur arrêté" -ForegroundColor Green

# ============================================================================
# STEP 7: Vérifier
# ============================================================================
Write-Host "`n[STEP 7] Vérification..." -ForegroundColor Yellow

ssh $MASTER_USER@$MASTER_IP "ctr -n k8s.io images ls | grep task-manager"

# ============================================================================
# STEP 8: Nettoyage
# ============================================================================
Write-Host "`n[STEP 8] Nettoyage..." -ForegroundColor Yellow

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
