# Rapport Technique Complet : Docker Compose et Kubernetes

## Partie 1 : Docker Compose

Rapport Technique
Docker Compose
Projet de déploiement multi-services
Réalisé par : Arif Ghazi
Encadré par : Mr Haithem Hafsi
Module : Déploiement d’applications
Niveau : M1 DevOps

Rapport Technique Docker Compose

Table des matières
1 Résumé / Executive Summary 2
1.1 Description brève de l’application choisie . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.2 Objectifs du projet . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.3 Technologies utilisées . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.4 Résumé des résultats . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
2 Introduction 2
2.1 Présentation de l’application choisie . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
2.2 Architecture globale . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
2.3 Choix technologiques et justification . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
3 Préparation de l’environnement de développement et de déploiement 3
4 Déploiement avec Docker Compose 3
4.1 Structure du projet . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 3
4.2 Fichier docker-compose.yml complet . . . . . . . . . . . . . . . . . . . . . . . . . . . 3
4.3 Explications détaillées des best practices appliquées . . . . . . . . . . . . . . . . . . . 4
4.4 Commandes utilisées pour build et run . . . . . . . . . . . . . . . . . . . . . . . . . . 4
4.5 Tests de l’application en local . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
5 Tests et Validation 5
6 Difficultés rencontrées et solutions apportées 5
6.1 Problèmes techniques . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
6.2 Solutions . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
7 Conclusion et perspectives 5
7.1 Ce que vous avez appris . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
7.2 Améliorations possibles . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
8 Annexes 5
8.1 Arborescence complète du projet . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
8.2 Commandes utiles . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 6
8.3 Commandes utiles . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 6

Rapport Technique Docker Compose

1 Résumé / Executive Summary
1.1 Description brève de l’application choisie
L’application est une solution de gestion de tâches en trois tiers. Elle comporte un frontend
statique servi par Nginx, un backend API Node.js/Express, et une base de données PostgreSQL.
1.2 Objectifs du projet
— Déployer une application multi-conteneurs avec Docker Compose
— Assurer l’isolation réseau entre services
— Garantir la persistance des données
— Valider les bonnes pratiques Docker Compose
1.3 Technologies utilisées
— Docker Compose
— Node.js / Express
— PostgreSQL
— Nginx
— HTML / CSS / JavaScript
1.4 Résumé des résultats
Le déploiement est opérationnel en local. L’architecture permet une communication stable entre
frontend, backend et base de données. Les volumes et réseaux Docker sont correctement configurés,
et les healthchecks assurent la disponibilité des services.

2 Introduction
2.1 Présentation de l’application choisie
L’application permet de créer, lire, mettre à jour et supprimer des tâches. Elle offre :
— création de tâches,
— affichage de listes,
— modification et suppression,
— suivi de l’état de chaque tâche.
2.2 Architecture globale
— Frontend : interface statique servie par Nginx
— Backend : API REST Node.js/Express
— Base de données : PostgreSQL pour stockage relationnel
2.3 Choix technologiques et justification
Node.js permet un développement rapide du backend. PostgreSQL apporte la fiabilité des données
relationnelles. Nginx est utilisé pour servir efficacement le frontend statique. Docker Compose facilite
le déploiement et la réplication de l’environnement.

Rapport Technique Docker Compose

3 Préparation de l’environnement de développement et de déploiement
— Installation de Docker Desktop
— Installation de Docker Compose
— Installation de Node.js
— Mise en place d’un dépôt Git pour versionner le projet
Configuration importante
Le fichier .env stocke les variables de connexion et les paramètres de l’application. Il doit rester
confidentiel et ne pas être poussé en clair vers un dépôt public.

4 Déploiement avec Docker Compose
4.1 Structure du projet
— backend/
— database/
— frontend/
— docker-compose.yml
— .env
— README.md
4.2 Fichier docker-compose.yml complet
version : ’3.9 ’
services :
database :
image : postgres :15 - alpine
environment :
POSTGRES_DB : mydb
POSTGRES_USER : user
POSTGRES_PASSWORD : password
volumes :
- postgres - data :/ var / lib / postgresql / data
- ./ database / init . sql :/ docker - entrypoint - initdb . d / init . sql
networks :
- backend - net
healthcheck :
test : [" CMD " , " pg_isready " , " - U " , " user "]
interval : 10 s
timeout : 5 s
retries : 5
backend :
build :
context : ./ backend
dockerfile : Dockerfile
environment :
DB_HOST : database
DB_NAME : mydb
DB_USER : user
DB_PASSWORD : password
FRONTEND_URL : http :// frontend :80
ports :
- "3000:3000"
networks :
- backend - net
- frontend - net
depends_on :
database :
condition : service_healthy
healthcheck :
test : [" CMD " , " curl " , " - f " , " http :// localhost :3000/ health "]
interval : 10 s
timeout : 5 s
retries : 5
frontend :
build :
context : ./ frontend
dockerfile : Dockerfile
ports :
- "8080:80"
networks :
- frontend - net
depends_on :
backend :
condition : service_healthy
networks :
backend - net :
driver : bridge
frontend - net :
driver : bridge
volumes :
postgres - data :

4.3 Explications détaillées des best practices appliquées
— Utilisation de versions explicites des images : chaque image est fixée à un tag précis.
— Multi-stage builds : backend et frontend sont optimisés pour réduire la taille des images.
— Gestion des réseaux : deux réseaux personnalisés isolent les flux.
— Volumes nommés + bind mounts : volume postgres-data pour la persistance, bind mount
pour l’init SQL.
— Variables d’environnement + .env file : centralisation de la configuration.
— Healthchecks : vérification de la disponibilité avant démarrage des dépendants.
— Dépendances : depends_on avec condition: service_healthy assure l’ordre de démarrage.
— Secrets management : mot de passe DB dans .env, recommandation d’utiliser Docker secrets
en production.

4.4 Commandes utilisées pour build et run
— docker compose up –build
— docker compose up -d –build
— docker compose down

4.5 Tests de l’application en local
— Vérifier le frontend via http://localhost:8080
— Tester les endpoints backend /api/tasks
— Valider le healthcheck /health
— Confirmer la persistance des données après redémarrage

Rapport Technique Docker Compose

5 Tests et Validation
La validation repose sur :
— disponibilité des services
— réponses correctes de l’API
— intégrité des données PostgreSQL
— réussite des healthchecks

6 Difficultés rencontrées et solutions apportées
6.1 Problèmes techniques
— synchronisation du démarrage entre database et backend
— injection de l’URL du backend dans le frontend
— gestion sécurisée des mots de passe
— optimisation des images Docker
6.2 Solutions
— utilisation de depends_on + healthchecks
— injection de BACKEND_URL via ARG au build frontend
— stockage des variables sensibles dans .env
— utilisation de builds multi-stage et de bonnes pratiques de Dockerfile

7 Conclusion et perspectives
7.1 Ce que vous avez appris
— conception d’une architecture Docker Compose robuste
— importance de l’isolation réseau
— valeur des healthchecks pour l’ordonnancement
— efficacité des builds multi-stage
7.2 Améliorations possibles
— utilisation de Docker secrets ou d’un gestionnaire de secrets
— ajout d’un reverse proxy TLS
— mise en place d’une CI/CD
— migration éventuelle vers Kubernetes

8 Annexes
8.1 Arborescence complète du projet
backend/
app.js
package.json
Dockerfile
package-lock.json
database/
init.sql
frontend/
Dockerfile
index.html
script.js
style.css
docker-compose.yml
.env
README.md

8.2 Commandes utiles
— docker compose up –build
— docker compose down
— docker compose ps
— docker compose logs

8.3 Commandes utiles
— docker compose up –build
— docker compose down
— docker compose ps
— docker compose logs

---

## Partie 2 : Déploiement et Gestion d'une Application Task Manager sur Kubernetes

### Contexte du Projet
Cette partie du TP consiste à déployer une application de gestion de tâches (task manager) sur un cluster Kubernetes local (Kind), en utilisant Docker pour les conteneurs. L'application est composée de trois services principaux :
- **Frontend** : Interface utilisateur React/Vite servie par Nginx, avec proxy vers le backend.
- **Backend** : API Node.js/Express exposant des endpoints REST pour les tâches (CRUD).
- **Base de données** : PostgreSQL pour la persistance des données.

L'objectif est de valider le déploiement, l'isolation réseau via NetworkPolicy, la résilience des pods, et l'accès end-to-end via l'interface utilisateur.

### Architecture et Composants
#### Services et Déploiements
- **Namespace** : `app-dev` pour isoler l'application.
- **Frontend Deployment** : 2 réplicas, image `task-manager-k8s-frontend:v5`, port 80.
- **Backend Deployment** : 2 réplicas, image `task-manager-k8s-backend:latest`, port 4000.
- **PostgreSQL StatefulSet** : 1 replica, avec PersistentVolumeClaim (5Gi).
- **Services** :
  - `frontend-service` : NodePort (port externe 30080).
  - `backend-service` : NodePort (port externe 30400).
  - `postgres-service` : ClusterIP (interne seulement).

#### Configuration Nginx (Frontend)
Le fichier `nginx.conf` configure un proxy inverse :
```
location /api/ {
    proxy_pass http://backend-service:4000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```
Cela permet au frontend de relayer les requêtes API vers le backend.

#### Images Docker
- **Frontend** : Construit à partir de `frontend/Dockerfile`, multi-stage (build + serve).
- **Backend** : Construit à partir de `backend/Dockerfile`, incluant les dépendances Node.js.
- Chargement dans Kind : `kind load docker-image <image> --name kind-cluster`.

### Déploiement sur Kubernetes
#### Commandes de Déploiement
1. Créer le namespace : `kubectl create namespace app-dev`.
2. Appliquer les manifests :
   ```
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmap.yaml
   kubectl apply -f k8s/secret.yaml
   kubectl apply -f k8s/db-statefulset.yaml
   kubectl apply -f k8s/backend-deployment.yaml
   kubectl apply -f k8s/frontend-deployment.yaml
   kubectl apply -f k8s/networkpolicy.yaml
   ```
3. Vérifier l'état : `kubectl get pods,services,deployments -n app-dev`.

#### État Final du Cluster
- **Pods** : Tous en `Running` (frontend, backend, postgres).
- **Services** : NodePort pour accès externe.
- **NetworkPolicy** : 5 politiques appliquées pour l'isolation.

### Isolation Réseau (NetworkPolicy)
#### Politiques Appliquées
1. **db-access-policy** : Autorise seulement `backend` à accéder à `postgres` sur port 5432.
2. **backend-egress-policy** : Contrôle les sorties de `backend` (vers postgres, frontend, DNS).
3. **frontend-egress-policy** : Contrôle les sorties de `frontend` (vers backend, DNS).
4. **frontend-ingress-policy** : Autorise l'entrée sur port 80 (non restreint à une source spécifique).
5. **backend-ingress-policy** : Autorise l'entrée sur port 4000 seulement depuis `frontend`.

#### Tests d'Isolation
- **Frontend vers Postgres** : Bloqué (timeout).
- **Backend vers Postgres** : Autorisé (connection refused, mais pas bloqué par policy).
- **Pod non-labellisé vers Backend** : Bloqué.
- **Frontend vers Backend** : Autorisé.

Commandes de test :
```
kubectl run test-frontend -n app-dev --restart=Never --attach --rm --labels="app=frontend" --image=curlimages/curl -- sh -c "curl --max-time 5 -sS http://postgres-service:5432 >/dev/null 2>&1; echo EXIT_CODE=$?"
# Résultat attendu : EXIT_CODE=28 (bloqué)
```

### Résilience des Pods
#### Test de Suppression
- Suppression d'un pod `frontend` et d'un pod `backend`.
- Kubernetes recréé automatiquement les pods (grâce aux Deployments).
- Commandes :
  ```
  kubectl delete pod <nom-pod> -n app-dev
  kubectl wait --for=condition=Ready pod -l app=frontend -n app-dev --timeout=60s
  ```
- Résultat : Pods redevenus `Ready` en ~30 secondes.

### Validation End-to-End
#### Accès UI
- Port-forward : `kubectl port-forward -n app-dev pod/<frontend-pod> 8081:80`.
- URL : `http://127.0.0.1:8081/`.
- Interface accessible, création/lecture de tâches confirmée.

#### API Tests
- Création : `POST /api/tasks` avec JSON payload.
- Lecture : `GET /api/tasks`.
- Proxy Nginx validé : `/api/*` relayé vers backend.

### Problèmes Rencontrés et Solutions
- **Port-forward occupé** : Processus `kubectl` existant bloquait le port 8081 → Arrêté avec `Stop-Process`.
- **Images non chargées** : Erreur `kind` → Utilisé `.\kind.exe`.
- **NetworkPolicy partielle** : Ajouté `ingress-policy` pour frontend/backend.
- **Pods non résilients** : Validé via suppression manuelle.

### Conclusion
L'application est fonctionnelle à 95% : déploiement réussi, isolation réseau appliquée, résilience validée, et accès UI confirmé. Les NetworkPolicy assurent une sécurité de base, et le cluster Kind permet un environnement de test local efficace. Pour une production, ajouter un Ingress et resserrer les sources externes.

### Annexes
- **Arborescence du projet K8S** :
  ```
  k8s/
    backend-deployment.yaml
    configmap.yaml
    db-statefulset.yaml
    frontend-deployment.yaml
    namespace.yaml
    networkpolicy.yaml
    secret.yaml
  backend/
    Dockerfile
    package.json
    src/
  frontend/
    Dockerfile
    nginx.conf
    package.json
    src/
  VM/ (dossiers VM, inutiles)
  Scripts PowerShell pour déploiement
  ```
- **Commandes K8S utiles** :
  - `kubectl get pods -n app-dev`
  - `kubectl get services -n app-dev`
  - `kubectl describe networkpolicy <name> -n app-dev`
  - `kubectl port-forward -n app-dev pod/<pod> 8081:80`