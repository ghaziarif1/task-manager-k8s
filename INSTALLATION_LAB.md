# 🚀 Kubernetes Task Manager - Laboratoire Complet

## 📋 Table des matières
1. [Architecture](#architecture)
2. [État du Cluster](#état-du-cluster)
3. [Composants Déployés](#composants-déployés)
4. [Accès aux Services](#accès-aux-services)
5. [Tests et Validation](#tests-et-validation)
6. [Sécurité Réseau](#sécurité-réseau)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture

### Vue d'ensemble 3 tiers

```
┌─────────────────────────────────────────────────────────────────┐
│                    UTILISATEUR (Navigateur)                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    HTTP:3000 / NodePort:30080
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│         FRONTEND (React + Vite + Tailwind CSS)                  │
│  - Déploiement: 2 replicas                                      │
│  - Service: NodePort sur port 30080                             │
│  - Proxy Nginx: /api/* → backend-service:4000                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
              Proxy Nginx vers backend-service:4000
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│         BACKEND (Node.js + Express)                             │
│  - Déploiement: 2 replicas                                      │
│  - Service: ClusterIP sur port 4000                             │
│  - API REST: /health, /api/tasks (CRUD complet)                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
             Connexion TCP: postgres-service:5432
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│         DATABASE (PostgreSQL)                                   │
│  - StatefulSet: 1 replica avec PVC                              │
│  - Service: Headless (ClusterIP: None)                          │
│  - Storage: 5Gi PersistentVolumeClaim                           │
│  - Port: 5432 (accessible uniquement par backend)               │
└─────────────────────────────────────────────────────────────────┘
```

### Flux de données

1. **Utilisateur accède au frontend** → `http://worker-ip:30080` ou `http://127.0.0.1:8081` via port-forward
2. **Frontend fait une requête API** → `/api/tasks` (via proxy Nginx vers `backend-service:4000`)
3. **Backend traite la requête** → Query PostgreSQL
4. **PostgreSQL retourne les données** → Backend envoie JSON au Frontend
5. **Frontend affiche les tâches** → Interface React responsive

### Contrainte d'isolation réseau ✅

- ✅ Frontend **NE PEUT PAS** accéder directement à PostgreSQL
- ✅ Seul le backend peut accéder à PostgreSQL
- ✅ Enforced par NetworkPolicies Kubernetes

---

## 📊 État du Cluster

### Cluster Information
```bash
Kubernetes Control Plane: https://127.0.0.1:59701
Version: v1.31.0
Network Plugin: kindnet (CNI)
```

### Nœuds Kubernetes (3 total)
```
NAME                                 STATUS   ROLES           AGE    VERSION
task-manager-cluster-control-plane   Ready    control-plane   2d1h   v1.31.0
task-manager-cluster-worker          Ready    <none>          2d1h   v1.31.0
task-manager-cluster-worker2         Ready    <none>          2d1h   v1.31.0
```

### Namespace
- **app-dev** : Namespace dédié pour toute l'application

---

## 🔧 Composants Déployés

### 1️⃣ PostgreSQL (StatefulSet)

| Propriété | Valeur |
|-----------|--------|
| **Image** | `postgres:15-alpine` |
| **Replicas** | 1 |
| **Service** | postgres-service (Headless) |
| **Port** | 5432 |
| **Storage** | 5Gi PVC (data-postgres-0) |
| **Probes** | Readiness + Liveness |
| **Ressources** | 200m CPU / 256Mi RAM (req), 500m / 512Mi (limits) |

**État actuel:**
```
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   1/1     Running   2          ~20h
```

**Variables d'environnement:**
```
POSTGRES_USER: postgres (base64 encoded)
POSTGRES_PASSWORD: supersecret123 (base64 encoded)
POSTGRES_DB: tasksby (base64 encoded)
```

### 2️⃣ Backend (Deployment + Service)

| Propriété | Valeur |
|-----------|--------|
| **Image** | `task-manager-k8s-backend:latest` |
| **Replicas** | 2 |
| **Service** | backend-service (ClusterIP) |
| **Port Interne** | 4000 |
| **Port NodePort** | 30400 |
| **Probes** | GET /health (5s initial, 10s period) |
| **Ressources** | 100m CPU / 128Mi RAM (req), 500m / 512Mi (limits) |

**État actuel:**
```
NAME                                READY   STATUS    RESTARTS   AGE
backend-deployment-7cc9f965bf-2m9qf   1/1     Running   0          ~3m
backend-deployment-7cc9f965bf-vz2wq   1/1     Running   0          ~3m
```

**Routes API:**
- `GET /health` → Status du backend
- `GET /api/tasks` → Récupérer toutes les tâches
- `POST /api/tasks` → Créer une tâche
- `PUT /api/tasks/:id` → Modifier une tâche
- `DELETE /api/tasks/:id` → Supprimer une tâche

### 3️⃣ Frontend (Deployment + Service)

| Propriété | Valeur |
|-----------|--------|
| **Image** | `task-manager-k8s-frontend:latest` |
| **Replicas** | 2 |
| **Service** | frontend-service (NodePort) |
| **Port** | 80 (Nginx) |
| **NodePort** | 30080 |
| **Ressources** | 100m CPU / 128Mi RAM (req), 500m / 256Mi (limits) |

**État actuel:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
frontend-deployment-7bfcb4794-ntht5   1/1     Running   0          ~15h
frontend-deployment-7bfcb4794-xwmbq   1/1     Running   0          ~15h
```

### 4️⃣ ConfigMap & Secrets

**ConfigMap (task-manager-config):**
```yaml
BACKEND_API_URL: http://192.168.1.101:30400
BACKEND_INTERNAL_URL: http://backend-service:4000
```

**Secret (task-manager-secrets):**
```yaml
POSTGRES_USER: postgres
POSTGRES_PASSWORD: supersecret123
POSTGRES_DB: tasksby
```

---

## 🌐 Accès aux Services

### URL d'accès

| Service | Type | URL Accès | Internal |
|---------|------|-----------|----------|
| **Frontend** | NodePort:30080 | `http://127.0.0.1:8081` (port-forward) / `http://172.18.0.6:30080` | N/A |
| **Backend** | NodePort:30400 | `http://127.0.0.1:4040` (port-forward) / `http://172.18.0.6:30400` | `backend-service:4000` |
| **PostgreSQL** | ClusterIP (Headless) | N/A | `postgres-service:5432` |

### Adresses IP des nœuds

```
task-manager-cluster-control-plane: 172.18.0.4
task-manager-cluster-worker:        172.18.0.6
task-manager-cluster-worker2:       172.18.0.3
```

### Accès via localhost (depuis Windows avec port-forward)

```powershell
# Frontend
http://127.0.0.1:8081

# Backend
http://127.0.0.1:4040
```

> Si `localhost:30080`/`localhost:30400` ne répond pas depuis Windows, utilisez `kubectl port-forward`.

---

## ✅ Tests et Validation

### Test 1: Vérifier l'état des pods

```bash
kubectl get pods -n app-dev
```

**Résultat attendu:**
- ✅ postgres-0 → 1/1 Running
- ✅ backend-deployment-* → 2/2 Running
- ✅ frontend-deployment-* → 2/2 Running

### Test 2: Vérifier l'état des services

```bash
kubectl get svc -n app-dev
```

**Résultat attendu:**
```
NAME               TYPE        CLUSTER-IP      PORT(S)          AGE
backend-service    NodePort    10.96.249.200   4000:30400/TCP   20h
frontend-service   NodePort    10.96.7.70      80:30080/TCP     19h
postgres-service   ClusterIP   None            5432/TCP         20h
```

### Test 3: Vérifier les PersistentVolumeClaims

```bash
kubectl get pvc -n app-dev
```

**Résultat attendu:**
```
NAME                    STATUS   VOLUME   CAPACITY   ACCESS MODES
postgres-data-postgres-0   Bound    pvc-...   5Gi        RWO
```

### Test 4: Vérifier les NetworkPolicies

```bash
kubectl get networkpolicies -n app-dev
```

**Résultat attendu:**
```
NAME                     POD-SELECTOR
backend-egress-policy    app=backend
db-access-policy         app=postgres
frontend-egress-policy   app=frontend
```

### Test 5: Vérifier la connectivité du Backend à PostgreSQL

```bash
kubectl logs -n app-dev deployment/backend-deployment --tail=5
```

**Résultat attendu:**
```
✓ Base de données prête après 0 tentative(s)
✓ Backend démarré sur http://localhost:4000
```

### Test 6: Tester l'API GET /health

```bash
kubectl run -it --rm curl-test --image=curlimages/curl:latest -n app-dev --restart=Never -- \
  curl http://backend-service:4000/health
```

**Résultat attendu:**
```json
{"status":"ok","uptime":51.087065047}
```

### Test 7: Tester l'API GET /api/tasks

```bash
kubectl run -it --rm curl-test --image=curlimages/curl:latest -n app-dev --restart=Never -- \
  curl http://backend-service:4000/api/tasks
```

**Résultat attendu:**
```json
[]
```

### Test 8: Accéder au Frontend

Ouvrir le navigateur et accéder à:
```
http://127.0.0.1:8081
```

ou, si vous pouvez atteindre le NodePort du worker :

```
http://172.18.0.6:30080
```

(Si besoin, utilisez le port-forward : `kubectl port-forward -n app-dev svc/frontend-service 8081:80`)

**Résultat attendu:**
- ✅ Page d'accueil Task Manager s'affiche
- ✅ Liste des tâches vide (ou avec tâches existantes)

---

## 🔒 Sécurité Réseau

### NetworkPolicies Déployées

#### 1️⃣ db-access-policy
**Permet UNIQUEMENT au backend d'accéder à PostgreSQL:**
```yaml
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 5432
```

#### 2️⃣ backend-egress-policy
**Le backend peut faire des requêtes sortantes vers:**
- ✅ PostgreSQL (5432)
- ✅ Autres pods backend (4000)
- ✅ Frontend (80)
- ✅ DNS kube-system (53)

#### 3️⃣ frontend-egress-policy
**Le frontend peut faire des requêtes sortantes vers:**
- ✅ Backend (4000)
- ✅ DNS kube-system (53)
- ❌ PostgreSQL (BLOQUÉ - pas d'accès direct)

### Isolation Réseau Validée ✅

La NetworkPolicy empêche le frontend d'accéder directement à PostgreSQL:
```bash
# Ce test échouerait (timeoutwait):
kubectl exec -it frontend-pod -n app-dev -- \
  timeout 3 bash -c "cat < /dev/null > /dev/tcp/postgres-service/5432"

# Résultat: Connection refused (NetworkPolicy appliquée)
```

---

## 🐛 Troubleshooting

### Problème: Backend ne se connecte pas à PostgreSQL

**Symptômes:**
```
CrashLoopBackOff
❌ Erreur d'initialisation du backend: Base de données non accessible
```

**Solutions:**

1. **Vérifier l'état de PostgreSQL:**
   ```bash
   kubectl logs postgres-0 -n app-dev --tail=20
   ```

2. **Vérifier les variables d'environnement du backend:**
   ```bash
   kubectl exec -it backend-pod -n app-dev -- env | grep POSTGRES
   ```

3. **Vérifier la connectivité réseau:**
   ```bash
   kubectl exec -it backend-pod -n app-dev -- \
     nc -zv postgres-service 5432
   ```

4. **Redémarrer le backend:**
   ```bash
   kubectl rollout restart deployment/backend-deployment -n app-dev
   ```

### Problème: Frontend n'accède pas au backend

**Symptômes:**
- Message "Backend: ❌ Déconnecté" dans l'UI
- Erreurs de CORS dans la console

**Solutions:**

1. **Vérifier que le backend est accessible:**
   ```bash
   curl http://backend-service:4000/health
   ```

2. **Vérifier les logs du backend CORS:**
   ```bash
   kubectl logs -n app-dev deployment/backend-deployment | grep CORS
   ```

3. **Vérifier la configuration Nginx du frontend:**
   ```bash
   kubectl exec -it frontend-pod -n app-dev -- cat /etc/nginx/conf.d/default.conf
   ```

### Problème: PersistentVolumeClaim reste Pending

**Symptômes:**
```
postgres-data-postgres-0   Pending
```

**Solutions:**

1. **Vérifier les StorageClasses disponibles:**
   ```bash
   kubectl get storageclass
   ```

2. **Vérifier les événements du PVC:**
   ```bash
   kubectl describe pvc postgres-data-postgres-0 -n app-dev
   ```

3. **Vérifier l'espace disque disponible:**
   ```bash
   kubectl get pv
   ```

---

## 📊 Ressources et Performance

### Resource Requests & Limits

| Composant | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|-----------------|--------------|
| PostgreSQL | 200m | 500m | 256Mi | 512Mi |
| Backend | 100m | 500m | 128Mi | 512Mi |
| Frontend | 100m | 500m | 128Mi | 256Mi |

### Vérifier l'utilisation réelle

```bash
kubectl top pods -n app-dev
kubectl top nodes
```

---

## 🚀 Déploiement Initial

### Commandes pour déployer depuis zéro

```bash
# 1. Créer le namespace
kubectl apply -f k8s/namespace.yaml

# 2. Créer les secrets et configmaps
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/configmap.yaml

# 3. Déployer PostgreSQL
kubectl apply -f k8s/db-statefulset.yaml
kubectl wait --for=condition=Ready pod -l app=postgres -n app-dev --timeout=300s

# 4. Déployer le backend
kubectl apply -f k8s/backend-deployment.yaml
kubectl wait --for=condition=Ready pod -l app=backend -n app-dev --timeout=300s

# 5. Déployer le frontend
kubectl apply -f k8s/frontend-deployment.yaml
kubectl wait --for=condition=Ready pod -l app=frontend -n app-dev --timeout=300s

# 6. Appliquer les NetworkPolicies
kubectl apply -f k8s/networkpolicy.yaml

# 7. Vérifier que tout est opérationnel
kubectl get all -n app-dev
kubectl get networkpolicies -n app-dev
```

### Vérifier que tout est prêt

```bash
kubectl get pods -n app-dev
# Attendre que tous les pods soient 1/1 Running
```

---

## 📝 Notes Importantes

1. **Les images Docker doivent être présentes** sur les nœuds ou dans un registre accessible
2. **Les secrets** sont en base64 (pas vraiment sécurisé pour la prod)
3. **Les NetworkPolicies** nécessitent un CNI compatible (kindnet, Calico, Flannel)
4. **Les PersistentVolumes** dépendent du StorageClass disponible (kind utilise local-path)
5. **Les livenessProbes** et **readinessProbes** assurent la stabilité et la résilience

---

## 📚 Fichiers Manifests

Tous les fichiers de configuration Kubernetes sont dans le dossier `k8s/`:

- `namespace.yaml` - Création du namespace app-dev
- `secret.yaml` - Secrets PostgreSQL pour le backend
- `configmap.yaml` - Configuration de l'application
- `db-statefulset.yaml` - StatefulSet PostgreSQL + Service headless
- `backend-deployment.yaml` - Deployment backend + Service ClusterIP → NodePort
- `frontend-deployment.yaml` - Deployment frontend + Service NodePort
- `networkpolicy.yaml` - 3 NetworkPolicies pour l'isolation réseau

---

**Lab créé le:** May 1, 2026  
**Version Kubernetes:** v1.31.0  
**État du lab:** ✅ OPÉRATIONNEL ET VALIDÉ
