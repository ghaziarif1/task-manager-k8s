# ============================================================================
# Script: cleanup-disk-space.ps1
# Objectif: Nettoyer l'espace disque sur la VM Master
# ============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CLEANUP ESPACE DISQUE - MASTER VM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[*] Verifier l'espace disque avant..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "df -h | grep -E '^/|^Filesystem'"

Write-Host "`n[*] Nettoyer les images Docker non utilisees..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "docker image prune -af"

Write-Host "`n[*] Nettoyer les volumes Docker orphelins..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "docker volume prune -f"

Write-Host "`n[*] Nettoyer les containers arretes..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "docker container prune -f"

Write-Host "`n[*] Supprimer le cache npm..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "rm -rf ~/.npm"

Write-Host "`n[*] Supprimer les caches d'apt..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "sudo apt-get clean"
ssh $MASTER_USER@$MASTER_IP "sudo apt-get autoclean"

Write-Host "`n[*] Verifier l'espace disque apres..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "df -h | grep -E '^/|^Filesystem'"

Write-Host "`n[OK] Nettoyage termine !" -ForegroundColor Green
