# IoTLab — suivi des pannes et des interventions d'un laboratoire

Base PostgreSQL qui suit les appareils électroniques d'un laboratoire (ESP32, Arduino, Raspberry Pi…), les techniciens qui les réparent, les interventions et l'historique de leurs changements de statut.
Projet de groupe de SQL avancé (Bachelor 2, Ycode A2627_4728).

| Membre | Contribution principale |
|---|---|
| Minna | tables, données, assemblage de `projet.sql`, README |
| Raïssa | fonction, trigger, procédure et leurs tests |
| Mariam | vues, rôles, droits, index et mesures |

## La base

Quatre tables reliées : `appareils` ← `interventions` → `techniciens`, et `historique` → `interventions`.

| Table | Lignes |
|---|---:|
| `appareils` | 100 |
| `techniciens` | 10 |
| `interventions` (la plus grosse) | 10 000 |
| `historique` | 2 857 |

Les données sont générées avec `generate_series`, de façon reproductible (pas de `random()`).

## Fonction et procédure

**Ce qu'elles font :** `nombre_interventions_appareil(id)` compte les interventions d'un appareil. `cloturer_intervention(id, compte_rendu)` passe une intervention « en cours » à « terminée » et écrit la ligne d'historique.

**Pourquoi elles sont là :** la clôture est une opération en plusieurs étapes (contrôler le statut, modifier, tracer). En une procédure, elle réussit en entier ou échoue en entier. Elle s'exécute avec les droits de son propriétaire : c'est ce qui permet au technicien de clôturer sans accès direct aux tables.

**La preuve :**
- `SELECT nombre_interventions_appareil(1);` renvoie 100, comme `SELECT COUNT(*) FROM interventions WHERE id_appareil = 1;`.
- `CALL cloturer_intervention(3, 'Capteur remplacé');` passe l'intervention 3 à « terminée » et ajoute une ligne `en cours → terminée` dans `historique`.
- `CALL cloturer_intervention(4, 'Test');` (intervention « en attente ») est refusé : « Seule une intervention en cours peut être clôturée ».

## Trigger

**Ce qu'il fait :** `trg_verifier_cloture` refuse qu'une intervention passe à « terminée » sans compte rendu (vide ou fait uniquement d'espaces), à l'insertion comme à la modification.

**Pourquoi dans la base plutôt que dans l'application :** la règle vaut pour tout le monde : l'interface web, pgAdmin, la procédure, un script. Une règle codée seulement dans l'application se contourne avec une simple requête SQL.

**La preuve :** `CALL cloturer_intervention(3, NULL);` échoue avec « Impossible de terminer une intervention sans compte rendu. », l'intervention reste « en cours » et aucune ligne d'historique n'est écrite. Avec un compte rendu, la même commande réussit.

## Vues

**Ce qu'elles font :**

| Vue | Montre | Cache |
|---|---|---|
| `vue_technicien` | les interventions non terminées (appareil, panne, technicien, date, statut) | les interventions terminées, les comptes rendus |
| `vue_superviseur` | par appareil : total et nombre d'interventions terminées | tout le détail (pannes, techniciens, dates) |

**Pourquoi elles sont là :** chaque métier voit ce dont il a besoin, et les rôles n'ont aucun droit sur les tables : la vue est leur seule porte d'entrée.

**La preuve :** `SELECT COUNT(*) FROM vue_technicien;` renvoie 7 143, comme `SELECT COUNT(*) FROM interventions WHERE statut <> 'terminée';`. `SELECT * FROM vue_superviseur;` renvoie 100 lignes (une par appareil).

## Rôles et droits

**Ce qu'ils font :**

| Rôle-métier | Utilisateur | Peut | Ne peut pas |
|---|---|---|---|
| `role_technicien` | `user_technicien` | lire `vue_technicien`, appeler `cloturer_intervention` et `nombre_interventions_appareil` | lire une table ou l'autre vue, modifier directement |
| `role_superviseur` | `user_superviseur` | lire `vue_superviseur`, appeler `nombre_interventions_appareil` | lire une table ou l'autre vue, modifier quoi que ce soit |

**Pourquoi :** moindre privilège. Les droits sont donnés aux rôles-métiers, jamais aux personnes. Les utilisateurs sont créés sans mot de passe, car le dépôt est public : l'administrateur en définit un en local.

**La preuve :** après `SET ROLE user_technicien;`
- `SELECT * FROM vue_technicien LIMIT 3;` : autorisé.
- `SELECT * FROM interventions LIMIT 1;` : `permission denied for table interventions`.
- `SELECT * FROM vue_superviseur;` : `permission denied for view vue_superviseur`.

Après `SET ROLE user_superviseur;`, `SELECT * FROM vue_superviseur;` est autorisé et `CALL cloturer_intervention(3, 'x');` est refusé (`permission denied for procedure cloturer_intervention`). `RESET ROLE;` revient à l'administrateur.

## Index

**Ce qu'ils font :** `idx_interventions_appareil` accélère la recherche des interventions d'un appareil (et la fonction de comptage). `idx_interventions_date` accélère la recherche par période.

**Pourquoi :** sans index, PostgreSQL lit les 10 000 lignes à chaque recherche. Avec 100 appareils, un appareil ne représente que 1 % des lignes : l'index est sélectif et sert vraiment.

**La preuve :** `EXPLAIN (ANALYZE, BUFFERS)` sur les mêmes requêtes, avant puis après `sql/07_index.sql` (médiane de 9 exécutions, PostgreSQL 16) :

| Requête | Avant | Après | Plan avant → après |
|---|---:|---:|---|
| `WHERE id_appareil = 5` | 0,613 ms | 0,174 ms | Seq Scan → Bitmap Index Scan |
| une semaine de `date_intervention` | 0,671 ms | 0,168 ms | Seq Scan → Bitmap Index Scan |

Les temps varient selon la machine : les relancer avec `tests/tests_index.sql`. La lecture passe de 130 pages à 102 (appareil) et 46 (période).

## Reproduire

`projet.sql` s'exécute en une fois sur une base vide, sans erreur (testé aussi au second passage : les rôles existent déjà, ce qui ne génère que des messages `NOTICE`).

```bash
psql -U postgres -c "CREATE DATABASE projet"
psql -U postgres -d projet -f projet.sql
```

Dans pgAdmin : créer une base vide, ouvrir le Query Tool, charger `projet.sql` et exécuter avec F5.

Les scripts de vérification sont dans `tests/`. Les fichiers `sql/` sont les morceaux de `projet.sql`, dans l'ordre : tables, données, fonctions, trigger, vues, rôles, index.

## Application web (en complément)

Une interface React + FastAPI permet de parcourir la base. Elle n'est pas nécessaire au projet : voir [`docs/APPLICATION.md`](docs/APPLICATION.md).
