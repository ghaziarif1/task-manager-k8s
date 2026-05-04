# Guide de Déploiement - Architecture VMs

## Vue d'ensemble

Ce projet démontre le déploiement d'une application full-stack en **deux phases** :

- **Phase 1** : Docker Compose (développement local)
- **Phase 2** : Kubernetes classique (cluster réel sur 3 VMs)

## Prérequis

### Client (Windows)
- PowerShell 5.1+
- Docker Desktop (pour Phase 1)
- SSH client
- kubectl (configuré pour les VMs)

### VMs Linux
- **Master** (192.168.1.12) : Kubernetes control-plane
- **Worker 1** (192.168.1.19) : Kubernetes worker
- **Worker 2** (192.168.1.20) : Kubernetes worker
- Docker installé sur chaque VM
- Kubernetes (kubeadm) configuré

### Identifiants SSH
- Master : `k8suser@192.168.1.12`
- Worker 1 : `k8s-worker1@192.168.1.19`
- Worker 2 : `k8s-worker2@192.168.1.20`

## Architecture

```
Windows (Client)
    ├── Phase 1: Docker Compose (localhost:8080)
    │   ├── Frontend (Nginx/React)
    │   ├── Backend (Node.js/Express)
    │   └── Database (PostgreSQL)
    │
    └── Phase 2: Kubernetes (VMs)
        ├── Master (192.168.1.12)
        │   └── control-plane
        ├── Worker 1 (192.168.1.19)
        │   ├── frontend pod
        │   └── backend pod
        └── Worker 2 (192.168.1.20)
            ├── frontend pod
            ├── backend pod
            └── postgres pod
```

## Déploiement

### Option 1 : Déploiement Complet (Phase 1 + Phase 2)

```powershell
.\deploy-full-vm.ps1
```

Ce script :
1. Lance Docker Compose localement
2. Construit les images Docker (backend, frontend)
3. Sauvegarde les images en TAR
4. Transfère les images aux workers
5. Charge les images dans Docker des workers
6. Transfère les manifests K8s au master
7. Applique les manifests avec kubectl
8. Attend que les pods soient Running

**Durée estimée** : 5-10 minutes

### Option 2 : Docker Compose Seul

```powershell
docker compose -f docker-compose.yml up --build
```

Accès : `http://localhost:8080`

### Option 3 : Kubernetes Seul

```powershell
# 1. Construire les images
docker build -t task-manager-k8s-backend:latest -f backend/Dockerfile ./backend
docker build -t task-manager-k8s-frontend:v5 -f frontend/Dockerfile ./frontend

# 2. Exporter en TAR
docker save -o backend.tar task-manager-k8s-backend:latest
docker save -o frontend.tar task-manager-k8s-frontend:v5

# 3. Transférer et charger sur workers
scp backend.tar k8s-worker1@192.168.1.19:/tmp/
scp backend.tar k8s-worker2@192.168.1.20:/tmp/
ssh k8s-worker1@192.168.1.19 "docker load -i /tmp/backend.tar"
ssh k8s-worker2@192.168.1.20 "docker load -i /tmp/backend.tar"
# (répéter pour frontend)

# 4. Transférer les manifests
scp k8s/*.yaml k8suser@192.168.1.12:/tmp/manifests/

# 5. Appliquer les manifests
ssh k8suser@192.168.1.12 "kubectl apply -f /tmp/manifests/"
```

## Vérification

### Phase 1 (Docker Compose)

```powershell
docker compose -f docker-compose.yml ps
docker compose -f docker-compose.yml logs backend
```

### Phase 2 (Kubernetes)

```powershell
# Depuis le master
ssh k8suser@192.168.1.12 "kubectl get pods -n app-dev"
ssh k8suser@192.168.1.12 "kubectl get svc -n app-dev"
ssh k8suser@192.168.1.12 "kubectl get nodes"
```

## Accès aux services

### Phase 1 (Local)
- Frontend : `http://localhost:8080`
- Backend API : `http://localhost:4000/api/tasks`
- PostgreSQL : `localhost:5432`

### Phase 2 (Kubernetes - VMs)
- Frontend (NodePort) : `http://192.168.1.19:30080` ou `http://192.168.1.20:30080`
- Backend (NodePort) : `http://192.168.1.19:30400/api/tasks`
- PostgreSQL (ClusterIP) : interne au cluster

## Configuration Kubernetes

### Namespace
```
app-dev
```

### Deployments
- **frontend-deployment** : 2 replicas
- **backend-deployment** : 2 replicas

### StatefulSet
- **postgres** : 1 replica (persistant)

### Services
- **frontend-service** : NodePort 30080
- **backend-service** : ClusterIP (interne)
- **postgres-service** : ClusterIP (interne)

### Persistance
- **PVC** : 5Gi pour PostgreSQL

### Secrets
```
task-manager-secrets:
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: supersecret123
  POSTGRES_DB: tasksby
```

## Tests

### Test de connectivité (depuis master)

```bash
# Frontend accessible
kubectl port-forward -n app-dev svc/frontend-service 8081:80
# Accès : http://localhost:8081

# Backend accessible
kubectl run test-backend --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s http://backend-service:4000/api/tasks -n app-dev

# NetworkPolicy testée
kubectl run test-policy --rm -it --restart=Never --image=curlimages/curl -n app-dev -- \
  curl -s --connect-timeout 2 http://postgres-service:5432
# Doit échouer (accès bloqué)
```

## Dépannage

### Les images ne se chargent pas sur les workers

```bash
# Vérifier que Docker est accessible sur le worker
ssh k8s-worker1@192.168.1.19 "docker images"

# Recharger manuellement
docker save task-manager-k8s-backend:latest | ssh k8s-worker1@192.168.1.19 "docker load"
```

### Les pods restent en Pending

```bash
# Vérifier les descriptions
ssh k8suser@192.168.1.12 "kubectl describe pod <pod-name> -n app-dev"

# Vérifier les ressources disponibles
ssh k8suser@192.168.1.12 "kubectl top nodes"
ssh k8suser@192.168.1.12 "kubectl top pods -n app-dev"
```

### La base de données ne s'initialise pas

```bash
# Vérifier les logs PostgreSQL
ssh k8suser@192.168.1.12 "kubectl logs postgres-0 -n app-dev"

# Vérifier les secrets
ssh k8suser@192.168.1.12 "kubectl get secrets -n app-dev"
```

## Nettoyage

### Supprimer le déploiement Kubernetes

```bash
ssh k8suser@192.168.1.12 "kubectl delete namespace app-dev"
```

### Arrêter Docker Compose

```powershell
docker compose -f docker-compose.yml down -v
```

## Ressources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/reference/)
- [kubeadm Setup Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)

---

**Auteur** : Arif Ghazi  
**Institution** : ISET Tozeur - M1 DevOps  
**Date** : 2026
