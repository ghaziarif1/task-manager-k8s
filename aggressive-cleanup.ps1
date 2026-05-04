# ============================================================================
# Script: aggressive-cleanup.ps1
# Objectif: Nettoyer agressivement l'espace disque sur la VM Master
# ============================================================================

$ErrorActionPreference = "Stop"

$MASTER_IP = "192.168.1.12"
$MASTER_USER = "k8suser"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AGGRESSIVE CLEANUP - MASTER VM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[*] Espace AVANT:" -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "df -h / | tail -1"

Write-Host "`n[*] Demonter les ISO..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "sudo umount /media/k8suser/Ubuntu* 2>/dev/null || true"
ssh $MASTER_USER@$MASTER_IP "sudo umount /media/k8suser/CDROM 2>/dev/null || true"

Write-Host "`n[*] Supprimer les fichiers de log volumineux..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "sudo find /var/log -name '*.gz' -delete"
ssh $MASTER_USER@$MASTER_IP "sudo truncate -s 0 /var/log/*.log 2>/dev/null || true"

Write-Host "`n[*] Vider le cache journal..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "sudo journalctl --vacuum=100M"

Write-Host "`n[*] Supprimer le cache apt..." -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "sudo apt-get clean -y"
ssh $MASTER_USER@$MASTER_IP "sudo apt-get autoclean -y"
ssh $MASTER_USER@$MASTER_IP "sudo apt-get autoremove -y"

Write-Host "`n[*] Espace APRES:" -ForegroundColor Yellow
ssh $MASTER_USER@$MASTER_IP "df -h / | tail -1"

Write-Host "`n[OK] Nettoyage agressif termine !" -ForegroundColor Green
