# ============================================================================
# Script: configure-docker-registry.ps1
# Objectif: Configurer Docker Desktop pour accepter le registry insécurisé
# ============================================================================

$ErrorActionPreference = "Stop"

$DOCKER_CONFIG = "$env:USERPROFILE\.docker"
$DAEMON_JSON = "$DOCKER_CONFIG\daemon.json"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CONFIGURE DOCKER REGISTRY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[*] Création du répertoire Docker..." -ForegroundColor Yellow
if (-not (Test-Path $DOCKER_CONFIG)) {
    New-Item -ItemType Directory -Path $DOCKER_CONFIG -Force | Out-Null
    Write-Host "[OK] Répertoire créé" -ForegroundColor Green
} else {
    Write-Host "[OK] Répertoire existe" -ForegroundColor Green
}

Write-Host "`n[*] Configuration du daemon.json..." -ForegroundColor Yellow
$config = @{
    "insecure-registries" = @("192.168.1.12:5000")
}

$config | ConvertTo-Json | Out-File -FilePath $DAEMON_JSON -Encoding UTF8

Write-Host "[OK] Configuration écrite" -ForegroundColor Green
Write-Host "Fichier: $DAEMON_JSON" -ForegroundColor Cyan

Write-Host "`n[*] Redémarrage de Docker Desktop..." -ForegroundColor Yellow
Write-Host "    (Si Docker Desktop ne redémarre pas automatiquement):" -ForegroundColor Yellow
Write-Host "    1. Ouvrez Docker Desktop Settings" -ForegroundColor White
Write-Host "    2. Allez dans Resources > Docker Engine" -ForegroundColor White
Write-Host "    3. Vérifiez la configuration" -ForegroundColor White
Write-Host "    4. Cliquez sur 'Apply & Restart'" -ForegroundColor White

Write-Host "`n[OK] Configuration terminée !" -ForegroundColor Green
