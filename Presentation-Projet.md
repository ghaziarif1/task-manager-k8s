# Présentation : Déploiement d'une Application Full-Stack (Docker Compose et Kubernetes)

## Slide 1 : Titre
- **Titre** : Déploiement d'une Application Full-Stack
- **Sous-titre** : Docker Compose et Kubernetes
- **Auteur** : Arif Ghazi
- **Institution** : ISET Tozeur - M1 DevOps
- **Date** : 2026
- **Visuels** : Logo ISET (si disponible), icônes Docker et Kubernetes.

## Slide 2 : Agenda
- **Titre** : Agenda
- **Contenu** :
  - Application, Architecture et Technologies
  - Environnement de travail
  - Phase 1 : Docker Compose
  - Phase 2 : Kubernetes
  - Tests et validation
  - Difficultés et solutions
  - Conclusion
- **Visuels** : Liste numérotée avec icônes pour chaque section.

## Slide 3 : Application, Architecture et Technologies
- **Titre** : Application et Architecture
- **Contenu** :
  - Application de gestion de tâches CRUD (créer, lire, mettre à jour, supprimer).
  - Frontend : React/Vite servi par Nginx.
  - Backend : API REST Node.js/Express (/api/tasks).
  - Base de données : PostgreSQL.
  - Flux : Frontend → Backend → PostgreSQL.
  - Technologies : Docker, Docker Compose, Kubernetes (kubeadm), Node.js, Express, React, Vite, Nginx, PostgreSQL.
- **Visuels** : Schéma simple (boîtes connectées par flèches) montrant les 3 tiers + icônes tech.

## Slide 4 : Environnement de travail
- **Titre** : Environnement de travail
- **Contenu** :
  - Machine : Windows (client) + 3 VMs Linux (cluster).
  - Cluster Kubernetes réel (kubeadm) : 1 master + 2 workers.
  - Master : 192.168.1.12 (control-plane).
  - Workers : 192.168.1.19 et 192.168.1.20.
  - Namespace : app-dev pour isolation.
  - Outils : kubectl, SSH, VS Code, Git.
- **Visuels** : Schéma du cluster K8s (3 VMs : 1 master bleu, 2 workers verts + réseau 192.168.1.0/24).

## Slide 5 : Phase 1 – Docker Compose
- **Titre** : Phase 1 : Docker Compose
- **Contenu** :
  - Architecture : Services (frontend, backend, database), réseaux (frontend-net, backend-net), volume persistant.
  - Best practices : Versions fixes, builds multi-stage, healthchecks, isolation réseau.
  - Démo : Commande `docker compose up --build`, test via http://localhost:8080, persistance des données.
- **Visuels** : Schéma d'architecture Docker (boîtes pour services, lignes pour réseaux), capture d'écran de `docker compose ps`.

## Slide 6 : Phase 2 – Kubernetes (Cluster + Objets)
- **Titre** : Phase 2 : Kubernetes (cluster réel)
- **Contenu** :
  - Cluster kubeadm : 1 master + 2 workers, namespace app-dev.
  - Objets : Deployment (frontend/backend), Service (NodePort), StatefulSet (PostgreSQL), PVC, ConfigMap/Secret.
  - Déploiement : build images → transfert SSH → `kubectl apply -f k8s/`.
  - Services exposés sur ports NodePort (30080 frontend, 30400 backend).
- **Visuels** : Diagramme des objets K8s (flèches : Deployment → Service → PVC), schéma du cluster VMs.

## Slide 7 : Configuration et Déploiements K8s
- **Titre** : Configuration et Déploiements K8s
- **Contenu** :
  - ConfigMap : Stockage de config (ex. BACKEND_URL).
  - Secret : Mots de passe encodés (ex. POSTGRES_PASSWORD).
  - PVC : Volume persistant pour PostgreSQL (5Gi).
  - Deployments : Réplicas (2 pour frontend/backend), labels.
  - Services : NodePort (ports 30080/30400).
  - Best practices : Probes (readiness/liveness), NetworkPolicy, StatefulSet pour DB.
- **Visuels** : Exemples de YAML (code snippets), icône de clé pour Secret, disque pour PVC, flowchart du déploiement.

## Slide 8 : Tests et validation
- **Titre** : Tests et Validation
- **Contenu** :
  - Vérifications : `kubectl get pods/services`, port-forward.
  - Tests réseau : NetworkPolicy (frontend bloqué vers postgres).
  - Résilience : Suppression pod → recréation en 30s.
  - End-to-end : CRUD via UI, proxy Nginx validé.
- **Visuels** : Captures avant/après (pods Running), commande `kubectl run` pour test réseau.

## Slide 9 : Difficultés et Solutions + Conclusion
- **Titre** : Difficultés, Solutions et Conclusion
- **Contenu** :
  - Difficultés : Synchronisation DB, chargement images, NetworkPolicy, port-forward occupé.
  - Solutions : Healthchecks, `kind load`, policies ingress/egress, arrêt processus.
  - Conclusion : Projet fonctionnel (95%), isolation et résilience validées.
  - Améliorations : CI/CD, monitoring, GitOps, production K8s.
- **Visuels** : Liste problèmes/solutions, icônes de succès pour conclusion.

## Slide 10 : Questions / Merci
- **Titre** : Merci
- **Contenu** : Questions ?
- **Visuels** : Texte centré, fond coloré, contact si souhaité.

**Conseils généraux pour PPTX** :
- Utilise des couleurs cohérentes (bleu primaire #006699).ubernetes réel (nœuds VM
- Ajoute des diagrammes/infographies : Schéma Docker (services en boîtes), cluster K3s (nœuds), objets K8s (flèches).
- Durée : 10-15 min + 3-5 min questions.
- Si tu veux exporter en PDF depuis LaTeX, compile avec `pdflatex Presentation-Projet.tex`. Si besoin d'ajustements, dis-le !