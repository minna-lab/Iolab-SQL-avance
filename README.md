# IoTLab – Gestion des interventions de maintenance

Projet PostgreSQL de groupe (3 membres) : suivre les appareils électroniques, les techniciens, les interventions et leurs changements de statut.

> **État : scripts assemblés mais non testés ensemble.** Les preuves ci-dessous doivent être complétées à partir de pgAdmin avant le rendu.

## Répartition

- **Membre 1 – cheffe de projet** : tables, données, intégration, vérification sur base vide, README.
- **Membre 2** : fonction `nombre_interventions_appareil`, fonction-trigger de clôture, trigger et tests.
- **Membre 3** : deux vues, deux rôles avec un utilisateur chacun, droits, deux index et mesures de performances.

## Base et données

Quatre tables liées : `appareils`, `techniciens`, `interventions`, `historique`. Les scripts prévoient 20 appareils, 10 techniciens, 10 000 interventions et 2 000 lignes d'historique initial.

Preuve à exécuter : `tests/tests_validation_finale.sql`. Reporter ici les nombres réellement observés après exécution sur une base vide.

## Fonction

**Ce qu'elle fait :** `nombre_interventions_appareil(id)` compte les interventions d'un appareil.

**Pourquoi :** identifier les appareils les plus souvent concernés.

**Preuve :** comparer le résultat avec `SELECT COUNT(*) FROM interventions WHERE id_appareil=1;` (résultat : **à renseigner**).

## Trigger

**Ce qu'il fait :** interdit de créer ou clôturer une intervention `terminée` lorsque son `compte_rendu` est vide.

**Pourquoi dans la base :** la règle est appliquée quelle que soit l'application cliente.

**Preuve :** tester une insertion sans compte rendu (refus attendu), puis avec compte rendu (succès attendu), à partir du fichier `tests/tests_fonction_trigger.sql`. Résultat observé : **à renseigner**.

## Vues

**Ce qu'elles font :** `vue_technicien` présente les interventions non terminées ; `vue_superviseur` présente les statistiques par appareil.

**Pourquoi :** abstraire les tables et limiter les données visibles par métier.

**Preuve :** `SELECT * FROM vue_technicien LIMIT 5;` et `SELECT * FROM vue_superviseur LIMIT 5;` (résultats : **à renseigner**).

## Rôles et droits

**Ce qu'ils font :** `role_technicien` ne lit que `vue_technicien`, `role_superviseur` ne lit que `vue_superviseur`. Chacun a son utilisateur `LOGIN` associé. Les mots de passe ne sont pas stockés dans GitHub.

**Pourquoi :** appliquer le principe du moindre privilège.

**Preuve :** `tests/tests_roles_vues.sql` : accès autorisé à la vue attribuée, accès refusé à `interventions` et à la vue de l'autre rôle. Messages observés : **à renseigner**.

## Index et performances

**Ce qu'ils font :** accélérer certaines recherches par appareil et période (`idx_interventions_appareil`, `idx_interventions_date`).

**Pourquoi :** évaluer les index avec au moins 10 000 lignes. Un index n'accélère pas nécessairement toute requête.

**Preuve :** exécuter `tests/tests_index.sql` **avant** puis **après** `sql/07_index.sql`, conserver temps et plans d'exécution réels :

| Index | Temps avant (ms) | Temps après (ms) | Plan avant / après |
|---|---:|---:|---|
| `idx_interventions_appareil` | À mesurer | À mesurer | À renseigner |
| `idx_interventions_date` | À mesurer | À mesurer | À renseigner |

## Reproduction

Dans pgAdmin connecté à **une base vide**, lancer `projet.sql` en entier. Ne pas exécuter de test de refus volontaire dans le script final. Les rôles existent au niveau du serveur : leur création est conditionnelle. Les utilisateurs sont sans mot de passe par défaut ; en définir localement si une connexion directe est nécessaire.

**Attention :** le seul fichier SQL exigé pour le rendu est `projet.sql`, accompagné de ce README. Les dossiers `sql/` et `tests/` sont des aides au développement.

## Présentation

8 minutes en direct, sans diaporama : rôle (autorisé/refusé), vue, index (avant/après), trigger (refus). Les trois membres doivent comprendre les quatre démonstrations.
