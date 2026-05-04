# Task Manager Kubernetes Lab

## État du cluster Kubernetes
- Cluster kubeadm avec 3 nœuds réels dans VMware Workstation
- Master: `k8suser-virtual-machine`
- Workers: `k8sworker1-virtual-machine`, `k8sworker2-virtual-machine`
- Vérifié: `kubectl get nodes` et `kubectl get pods -n kube-system`
- Test réseau ok depuis un Pod: `kubectl exec test-pod -- ping 8.8.8.8`

## Architecture du laboratoire
- Frontend: React + Vite + Tailwind CSS
- Backend: Node.js + Express
- Base de données: PostgreSQL
- Namespace Kubernetes: `app-dev`

## Prochaine étape
Développement du frontend React + Tailwind CSS et déploiement Kubernetes.

## État actuel
- Cluster Kubernetes kubeadm validé avec 3 nœuds.
- Backend Node.js + Express testé via Docker Compose.
- Frontend React + Vite + Tailwind créé et compilé avec succès.
- Manifests Kubernetes créés pour : namespace, Secret, ConfigMap, PostgreSQL StatefulSet, Backend Deployment, Frontend Deployment, NetworkPolicy.

## Déploiement Kubernetes
1. Construire les images Docker localement :
   ```powershell
   docker build -t task-manager-k8s-backend:latest .\backend
   docker build -t task-manager-k8s-frontend:latest .\frontend
   ```
2. Si votre cluster Kubernetes est sur des VMs distinctes, chargez ou poussez les images vers chaque nœud :
   - Construire l'image sur chaque nœud, ou
   - Pousser vers un registre privé accessible par le cluster.

3. Appliquer les manifests :
   ```powershell
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/secret.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/db-statefulset.yaml
   kubectl apply -f k8s/backend-deployment.yaml
   kubectl apply -f k8s/frontend-deployment.yaml
   kubectl apply -f k8s/networkpolicy.yaml
   ```
4. Vérifier :
   ```powershell
   kubectl get all -n app-dev
   kubectl get pvc -n app-dev
   kubectl get networkpolicies -n app-dev
   ```

## Notes
- Le frontend est construit pour contacter `http://backend-service:4000` en cluster Kubernetes.
- La `NetworkPolicy` empêche les pods non-backend d’accéder directement à PostgreSQL.

## Test local backend
1. Lancer Docker Desktop / démarrer le daemon Docker.
2. Depuis la racine du projet :
   ```powershell
   docker compose up --build -d
   ```
3. Vérifier l’API :
   ```powershell
   curl http://localhost:4000/health
   ```
4. Arrêter le test local :
   ```powershell
   docker compose down
   ```
