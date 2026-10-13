# IoTLab — application web de démonstration

Cette application est un **complément** : elle permet de parcourir la base PostgreSQL du projet (appareils, techniciens, interventions, historique), de créer et clôturer des interventions, et de consulter les vues, le diagnostic SQL et les plans d'exécution.
Les preuves du projet (rôles, vues, trigger, index) sont dans le [`README.md`](../README.md) et se montrent dans pgAdmin ou psql.

## Architecture

```text
React (Vite)  http://127.0.0.1:5173
      │  HTTP / JSON
FastAPI       http://127.0.0.1:8000
      │  SQLAlchemy + psycopg
PostgreSQL    tables, vues, fonction, procédure, trigger, rôles, index
```

L'interface ne se connecte jamais directement à PostgreSQL : tout passe par FastAPI.

## Installation

**Prérequis :** PostgreSQL, Python 3, Node.js, et une base créée avec `projet.sql` (voir le README principal).

**1. Backend** (premier terminal, depuis la racine du dépôt) :

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env      # puis renseigner son propre mot de passe PostgreSQL
python -m uvicorn main:app --reload
```

Vérifications : <http://127.0.0.1:8000/docs> (Swagger) et <http://127.0.0.1:8000/api/db-test> (nom de la base utilisée).

**2. Frontend** (deuxième terminal) :

```powershell
cd frontend
npm install
npm run dev
```

L'application s'ouvre sur <http://127.0.0.1:5173>. Après toute modification d'un fichier `.env`, redémarrer le serveur concerné.

## Utilisation

| Page | Ce qu'on y fait |
|---|---|
| Tableau de bord | chiffres clés lus dans PostgreSQL |
| Appareils | recherche, filtre par état, bouton **Compter** (appelle `nombre_interventions_appareil`) |
| Techniciens | liste et recherche |
| Interventions | filtre, pagination, création, passage à « en cours », clôture avec compte rendu |
| Historique | changements de statut, enregistrés dans la même transaction que la modification |
| Administration | diagnostic (rôles, vues, index, trigger, fonctions), consultation des vues, plans `EXPLAIN` |

Le statut suit toujours `en attente → en cours → terminée`. Pour montrer le refus du trigger : passer une intervention « en cours », puis envoyer `{"statut": "terminée", "compte_rendu": null}` depuis Swagger (`PATCH /api/interventions/{id}/statut`). La réponse est une erreur 400 et l'intervention reste « en cours ».

## Routes de l'API

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/health`, `/api/db-test` | santé de l'API, base réellement utilisée |
| GET | `/api/statistiques` | totaux du tableau de bord |
| GET | `/api/appareils`, `/api/techniciens` | listes avec recherche (et filtre d'état pour les appareils) |
| GET | `/api/interventions`, `/api/interventions/{id}` | liste paginée, détail |
| POST | `/api/interventions` | création (statut « en attente ») |
| PATCH | `/api/interventions/{id}/statut` | démarrage ou clôture |
| GET | `/api/historique`, `/api/historique/{id}` | historique global, historique d'une intervention |
| GET | `/api/fonction/{id_appareil}` | appelle `nombre_interventions_appareil` |
| GET | `/api/vues/technicien`, `/api/vues/superviseur` | contenu des deux vues |
| GET | `/api/sql/diagnostic` | objets SQL présents (3 fonctions/procédures, 1 trigger, 2 vues, 2 index, 4 rôles) |
| GET | `/api/sql/index-performance` | plans `EXPLAIN (ANALYZE, BUFFERS)` pour un appareil et une période |

## Problèmes fréquents

| Message ou symptôme | Cause probable | Solution |
|---|---|---|
| `Could not import module "main"` | uvicorn lancé hors de `backend/` | `cd backend` avant la commande |
| `password authentication failed` | mauvais identifiants dans `backend/.env` | comparer avec la connexion pgAdmin |
| `database "iolab" does not exist` | nom de base différent (`Iolab` ≠ `iolab`) | corriger `DB_NAME` dans `backend/.env` |
| Erreur CORS dans le navigateur | origine React non autorisée | vérifier `CORS_ORIGINS`, redémarrer FastAPI |
| `Failed to resolve import "lucide-react"` | dépendances non installées | `npm install` dans `frontend/` |
| pgAdmin affiche `25P02` | transaction précédente en erreur | exécuter `ROLLBACK;` |

## Sécurité et limites

- Application **locale** de démonstration : pas d'authentification, ne pas l'exposer sur Internet.
- Le compte `postgres` est très privilégié ; une vraie mise en production demanderait un compte applicatif restreint.
- `backend/.env` contient des identifiants : ne jamais le commiter (il est dans `.gitignore`). Les variables `VITE_...` sont visibles dans le navigateur : n'y mettre aucun secret.
- Les rôles SQL (`user_technicien`, `user_superviseur`) ne correspondent pas à des connexions dans l'interface : leurs droits se démontrent dans pgAdmin avec `SET ROLE`.
