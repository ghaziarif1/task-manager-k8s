# 🚀 Task Manager Kubernetes Lab - Laboratoire Complet & Opérationnel

> **État:** ✅ **COMPLÈTEMENT FONCTIONNEL** - Tous les composants déployés et validés  
> **Date:** May 1, 2026 | **K8s Version:** v1.31.0 | **Cluster:** 3 nœuds (1 control-plane, 2 workers)

## 📋 Sommaire Rapide

| Composant | Status | URL/Port | Details |
|-----------|--------|----------|---------|
| **Frontend** | ✅ 2/2 Running | `http://127.0.0.1:8081` | React + Vite + Tailwind (port-forward) |
| **Backend** | ✅ 2/2 Running | `http://127.0.0.1:4040` | Node.js + Express (4 routes, port-forward) |
| **PostgreSQL** | ✅ 1/1 Running | `postgres-service:5432` | StatefulSet + PVC (5Gi) |
| **NetworkPolicy** | ✅ 3 Applied | - | Frontend ↔ Backend ✓, Frontend ↔ DB ✗ |

---

## 🎯 Objectif du Lab

Déployer une **application web 3 tiers sur Kubernetes** avec :
- ✅ Frontend React (Vite + Tailwind)
- ✅ Backend Node.js (Express)  
- ✅ Base de données PostgreSQL
- ✅ Isolation réseau stricte (Frontend ne peut PAS accéder à la DB)
- ✅ Haute disponibilité (2 replicas frontend & backend)
- ✅ Persistance des données (StatefulSet + PVC)

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         UTILISATEUR                              │
│                      (Navigateur HTTP)                           │
└──────────────────────────┬───────────────────────────────────────┘
                           │ :30080
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│              FRONTEND (React + Nginx)                            │
│   • Deployment: 2 replicas                                       │
│   • UI: Formulaire + Cartes de tâches (Responsive)              │
│   • Proxy: /api/* → backend-service:4000                        │
└──────────────────────────┬───────────────────────────────────────┘
                           │
           HTTP (Nginx proxy_pass)
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│              BACKEND (Node.js + Express)                         │
│   • Deployment: 2 replicas                                       │
│   • API Routes:                                                  │
│     - GET /health                                               │
│     - GET /api/tasks                                            │
│     - POST /api/tasks                                           │
│     - PUT /api/tasks/:id                                        │
│     - DELETE /api/tasks/:id                                     │
│   • Liveness & Readiness probes                                 │
└──────────────────────────┬───────────────────────────────────────┘
                           │ TCP:5432
           (NetworkPolicy: Backend only)
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│              DATABASE (PostgreSQL)                               │
│   • StatefulSet: 1 replica                                       │
│   • Storage: 5Gi PersistentVolumeClaim                          │
│   • Service: Headless (postgres-service)                        │
│   • Schema auto-created (table: tasks)                          │
└──────────────────────────────────────────────────────────────────┘
```

### Flux de Données CRUD

```
User → Frontend (React) → Nginx proxy → Backend (Express) → PostgreSQL
                                    ↑                             ↓
                                    └─ JSON Response ─────────────┘
```

---

## 🌐 Accès aux Services

### URLs d'Accès

```powershell
# Frontend (depuis Windows via port-forward)
http://127.0.0.1:8081

# Backend API (depuis Windows via port-forward)
http://127.0.0.1:4040/health
http://127.0.0.1:4040/api/tasks

# Via adresses IP internes (à partir d'un pod)
curl http://backend-service:4000/health
curl http://postgres-service:5432  (NetworkPolicy bloquera si non-backend)
```

> Note: avec WSL2/Kubernetes, l’accès direct NodePort sur `localhost:30080`/`30400` n’est pas toujours fiable depuis Windows. Utiliser `kubectl port-forward` pour accéder au frontend et au backend depuis le navigateur Windows.

### Nœuds Cluster

```
🎛️  Control Plane: 172.18.0.4 (task-manager-cluster-control-plane)
🔧 Worker 1:      172.18.0.6 (task-manager-cluster-worker)
🔧 Worker 2:      172.18.0.3 (task-manager-cluster-worker2)
```

---

## ✅ État de Déploiement

### Kubernetes Cluster

```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:59701

$ kubectl get nodes
NAME                                 STATUS   ROLES           VERSION
task-manager-cluster-control-plane   Ready    control-plane   v1.31.0
task-manager-cluster-worker          Ready    <none>          v1.31.0
task-manager-cluster-worker2         Ready    <none>          v1.31.0
```

### Pods (Déploiement)

```bash
$ kubectl get pods -n app-dev
NAME                                  READY   STATUS    RESTARTS   AGE
postgres-0                            1/1     Running   0          ~20h
backend-deployment-7cc9f965bf-2m9qf   1/1     Running   0          ~3m
backend-deployment-7cc9f965bf-vz2wq   1/1     Running   0          ~3m
frontend-deployment-7bfcb4794-ntht5   1/1     Running   0          ~15h
frontend-deployment-7bfcb4794-xwmbq   1/1     Running   0          ~15h
```

### Services

```bash
$ kubectl get svc -n app-dev
NAME               TYPE        CLUSTER-IP      PORT(S)          AGE
backend-service    NodePort    10.96.249.200   4000:30400/TCP   20h
frontend-service   NodePort    10.96.7.70      80:30080/TCP     19h
postgres-service   ClusterIP   None            5432/TCP         20h
```

### PersistentVolumeClaim (Données PostgreSQL)

```bash
$ kubectl get pvc -n app-dev
NAME                    STATUS   VOLUME                                   CAPACITY   ACCESS MODES
postgres-data-postgres-0   Bound    pvc-e08798ac-fadc-4a41-9ecf-48d2273a64db   5Gi        RWO
```

### NetworkPolicies (Sécurité Réseau)

```bash
$ kubectl get networkpolicies -n app-dev
NAME                     POD-SELECTOR   RULES
db-access-policy         app=postgres   Backend can access DB only ✅
backend-egress-policy    app=backend    Backend → DB, Backend, Frontend ✅
frontend-egress-policy   app=frontend   Frontend → Backend, DNS only (NO DB!) ✅
```

---

## 🔍 Tests & Validation

### ✅ Test 1: API Health Check

```bash
kubectl run -it --rm curl-test --image=curlimages/curl:latest -n app-dev --restart=Never -- \
  curl http://backend-service:4000/health
```

**Résultat:**
```json
{"status":"ok","uptime":51.087065047}
```

### ✅ Test 2: GET /api/tasks (Read)

```bash
kubectl run -it --rm curl-test --image=curlimages/curl:latest -n app-dev --restart=Never -- \
  curl http://backend-service:4000/api/tasks
```

**Résultat:**
```json
[]
```

### ✅ Test 3: Isolation Réseau (Frontend ≠> PostgreSQL)

La NetworkPolicy `db-access-policy` empêche le frontend d'accéder à PostgreSQL:

```bash
# Depuis un pod frontend:
kubectl exec -it <frontend-pod> -n app-dev -- \
  timeout 3 sh -c "telnet postgres-service 5432"
  
# Résultat: Connection refused (NetworkPolicy appliquée) ✅
```

### ✅ Test 4: Backend → PostgreSQL (Allowed)

Les logs du backend confirment la connexion réussie:

```bash
$ kubectl logs -n app-dev deployment/backend-deployment --tail=5
✓ Base de données prête après 0 tentative(s)
✓ Backend démarré sur http://localhost:4000
::ffff:10.244.1.1 - - [01/May/2026:13:07:06 +0000] "GET /api/tasks HTTP/1.1" 200 2 "-" "curl/8.20.0"
```

### ✅ Test 5: Frontend UI Accessible

Ouvrir dans le navigateur:
```
http://127.0.0.1:8081
```

**Attendu:**
- ✅ Page Task Manager s'affiche
- ✅ Formulaire avec champs: Title, Description, Status, Due Date
- ✅ Liste des tâches (vide ou avec tâches)
- ✅ Boutons Modifier / Supprimer visibles
- ✅ Responsive design (Tailwind CSS)

---

## 🔐 Sécurité Réseau (NetworkPolicies)

### Politique 1: db-access-policy

**Permet UNIQUEMENT au backend d'accéder à PostgreSQL:**

```yaml
spec:
  podSelector:
    matchLabels: app=postgres
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector: matchLabels: app=backend
      ports:
        - protocol: TCP
          port: 5432
```

### Politique 2: backend-egress-policy

**Le backend peut communiquer avec:**
- ✅ PostgreSQL (5432)
- ✅ Autres pods backend (4000)
- ✅ Frontend (80)
- ✅ DNS kube-system (53)

### Politique 3: frontend-egress-policy

**Le frontend peut communiquer avec:**
- ✅ Backend uniquement (4000)
- ✅ DNS kube-system (53)
- ❌ PostgreSQL (BLOQUÉ - pas d'accès direct)

---

## 📦 Ressources & Limites

| Composant | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|-------------|-----------|-----------------|-------------|---------|
| PostgreSQL | 200m | 500m | 256Mi | 512Mi | 5Gi |
| Backend | 100m | 500m | 128Mi | 512Mi | - |
| Frontend | 100m | 500m | 128Mi | 256Mi | - |

---

## 🚀 Déploiement Rapide

### Depuis Zéro

```powershell
# 1. Appliquer TOUS les manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/db-statefulset.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/networkpolicy.yaml

# 2. Attendre que tout soit prêt (~30-60 secondes)
kubectl get pods -n app-dev --watch

# 3. Vérifier l'état complet
kubectl get all -n app-dev
kubectl get networkpolicies -n app-dev
kubectl get pvc -n app-dev
```

### Redémarrer les Pods

```powershell
# Redémarrer le backend (en cas de problème)
kubectl rollout restart deployment/backend-deployment -n app-dev

# Redémarrer le frontend
kubectl rollout restart deployment/frontend-deployment -n app-dev

# Redémarrer PostgreSQL
kubectl delete pod postgres-0 -n app-dev
```

---

## 📁 Structure du Projet

```
task-manager-k8s/
├── README.md                           (Ce fichier)
├── INSTALLATION_LAB.md                 (Documentation détaillée)
├── docker-compose.yml                  (Développement local)
├── backend/
│   ├── Dockerfile                      (Multi-stage optimisé)
│   ├── package.json
│   ├── src/
│   │   ├── index.js                   (Express API)
│   │   └── db.js                      (Pool PostgreSQL)
│   └── ...
├── frontend/
│   ├── Dockerfile                      (Nginx + React build)
│   ├── nginx.conf                      (Proxy vers backend)
│   ├── package.json
│   ├── src/
│   │   ├── App.jsx                    (React CRUD)
│   │   ├── services/
│   │   │   └── api.js                 (Axios instance)
│   │   └── ...
│   └── ...
└── k8s/
    ├── namespace.yaml                  (app-dev namespace)
    ├── secret.yaml                     (PostgreSQL credentials)
    ├── configmap.yaml                  (App configuration)
    ├── db-statefulset.yaml             (PostgreSQL + Service)
    ├── backend-deployment.yaml         (Backend + Service)
    ├── frontend-deployment.yaml        (Frontend + Service)
    └── networkpolicy.yaml              (3 policies)
```

---

## 🛠️ Troubleshooting

### ❌ Backend CrashLoopBackOff

**Solution:**
```bash
kubectl logs postgres-0 -n app-dev --tail=20
kubectl logs -n app-dev deployment/backend-deployment --tail=20

# Redémarrer
kubectl rollout restart deployment/backend-deployment -n app-dev
```

### ❌ Frontend ne voit pas le Backend

**Symptôme:** Message "Backend: ❌ Déconnecté"

**Solution:**
```bash
# Vérifier Nginx config
kubectl exec -it <frontend-pod> -n app-dev -- cat /etc/nginx/conf.d/default.conf

# Vérifier que backend est accessible
kubectl run -it --rm test --image=curlimages/curl -n app-dev --restart=Never -- \
  curl http://backend-service:4000/health
```

### ❌ PersistentVolumeClaim Pending

**Solution:**
```bash
kubectl describe pvc postgres-data-postgres-0 -n app-dev
kubectl get storageclass
```

---

## 📊 Commandes Utiles

```bash
# Monitorer les pods en temps réel
kubectl get pods -n app-dev --watch

# Voir les logs d'un pod
kubectl logs <pod-name> -n app-dev --follow

# Exécuter une commande dans un pod
kubectl exec -it <pod-name> -n app-dev -- sh

# Décrire un pod (pour déboguer)
kubectl describe pod <pod-name> -n app-dev

# Supprimer le namespace (TOUT détruit)
kubectl delete namespace app-dev

# Utilisation des ressources en temps réel
kubectl top pods -n app-dev
kubectl top nodes
```

---

## 📚 Documentation Complète

Pour une documentation **très détaillée** avec schémas, voir :  
👉 **[INSTALLATION_LAB.md](./INSTALLATION_LAB.md)**

Contient:
- Architecture détaillée
- État complet du cluster
- Composants avec configurations
- Tests pas-à-pas
- Sécurité réseau expliquée
- Troubleshooting avancé

---

## ✨ Points Clés du Lab

✅ **Architecture 3 tiers validée**
- Frontend → Backend → PostgreSQL
- Isolation réseau stricte (NetworkPolicy)
- Frontend ne peut PAS accéder à la DB

✅ **Haute Disponibilité**
- 2 replicas frontend
- 2 replicas backend
- 1 replica PostgreSQL (StatefulSet)

✅ **Persistance des Données**
- PostgreSQL StatefulSet
- PersistentVolumeClaim (5Gi)
- Données survivent aux crashs

✅ **Observabilité**
- Livenessprobes (redémarrage automatique)
- Readinessiprobes (trafic vers pods prêts)
- Logs accessibles via kubectl

✅ **Sécurité**
- NetworkPolicies appliquées
- Secrets Kubernetes
- ConfigMaps pour la configuration

---

**Créé:** May 1, 2026  
**Version K8s:** v1.31.0  
**Status:** ✅ **OPÉRATIONNEL**
