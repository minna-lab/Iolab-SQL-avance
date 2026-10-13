# IoTLab — Gestion des interventions de maintenance

IoTLab est une base PostgreSQL de suivi des appareils électroniques (Arduino, ESP32, Raspberry Pi), des techniciens, des pannes et des interventions. Le projet applique les notions de SQL avancé en Bachelor 2 : fonctions, procédure, trigger, vues, rôles et index.

**Groupe de 3 :** Minna (tables, données, intégration), Raïssa (fonction, procédure, trigger), Mariam (vues, rôles, index).

## 1. Base de données

Les quatre tables sont reliées par clés étrangères : `appareils` ← `interventions` → `techniciens`, et `historique` → `interventions`.

| Table | Données initiales |
|---|---:|
| `appareils` | 100 |
| `techniciens` | 10 |
| `interventions` | 10 000 |
| `historique` | 2 857 |

Les données sont générées avec `generate_series()`. **Preuve :**

```sql
SELECT 'appareils' AS table_nom, COUNT(*) FROM appareils
UNION ALL SELECT 'techniciens', COUNT(*) FROM techniciens
UNION ALL SELECT 'interventions', COUNT(*) FROM interventions
UNION ALL SELECT 'historique', COUNT(*) FROM historique;
```

## 2. Fonction et procédure

**Ce qu'elles font :** `nombre_interventions_appareil(id)` compte les interventions d'un appareil ; `cloturer_intervention(id, compte_rendu)` clôture une intervention en cours et enregistre son historique. **Pourquoi :** centraliser le comptage et réaliser la clôture et sa traçabilité dans une seule opération transactionnelle.

**Preuves :**

```sql
SELECT nombre_interventions_appareil(1);
SELECT COUNT(*) FROM interventions WHERE id_appareil = 1;
-- Les deux résultats sont identiques (100 sur les données initiales).

-- À tester sur une intervention de démonstration au statut 'en cours' :
-- CALL cloturer_intervention(<id>, 'Capteur remplacé et testé');
```

## 3. Trigger

**Ce qu'il fait :** `trg_verifier_cloture` refuse toute intervention `terminée` sans compte rendu non vide. **Pourquoi dans PostgreSQL :** la règle reste obligatoire quel que soit le programme qui modifie la base (application web, pgAdmin ou script).

**Preuve :** sur une intervention de test au statut `en cours`, `CALL cloturer_intervention(<id>, NULL);` est refusé avec le message « Impossible de terminer une intervention sans compte rendu. ». Avec un compte rendu renseigné, la clôture est acceptée.

## 4. Vues

**Ce qu'elles font :** `vue_technicien` présente les interventions non terminées sans compte rendu ; `vue_superviseur` présente le total et le nombre d'interventions terminées par appareil. **Pourquoi :** fournir à chaque métier les informations utiles sans exposer les tables.

**Preuves :**

```sql
SELECT COUNT(*) FROM vue_technicien;
SELECT COUNT(*) FROM interventions WHERE statut <> 'terminée';
-- Résultats identiques : 7 143 sur les données initiales.
SELECT COUNT(*) FROM vue_superviseur;
-- 100 lignes : une par appareil.
```

## 5. Rôles et privilèges

**Ce qu'ils font :** `role_technicien` (utilisateur `user_technicien`) lit sa vue et peut appeler la procédure de clôture ; `role_superviseur` (`user_superviseur`) lit sa vue sans modifier les données. Aucun des deux rôles ne lit directement les tables. **Pourquoi :** appliquer le principe du moindre privilège.

**Preuves** (exécuter séparément dans pgAdmin avec un administrateur ; faire `ROLLBACK;` si une erreur a annulé la transaction) :

```sql
SET ROLE user_technicien;
SELECT * FROM vue_technicien LIMIT 3; -- autorisé
SELECT * FROM interventions LIMIT 1;  -- refusé : permission denied
RESET ROLE;

SET ROLE user_superviseur;
SELECT * FROM vue_superviseur LIMIT 3; -- autorisé
SELECT * FROM vue_technicien LIMIT 1;  -- refusé : permission denied
RESET ROLE;
```

Les utilisateurs de démonstration ne disposent pas de mots de passe dans le script public.

## 6. Index et performances

**Ce qu'ils font :** `idx_interventions_appareil` accélère la recherche par appareil ; `idx_interventions_date` accélère celle par période. **Pourquoi :** optimiser les recherches dans les 10 000 interventions.

**Preuve :** mêmes requêtes avec `EXPLAIN (ANALYZE, BUFFERS)` avant et après les index ; mesures relevées sur PostgreSQL 16 (médiane de 9 exécutions).

| Recherche | Avant index | Après index | Plan |
|---|---:|---:|---|
| `WHERE id_appareil = 5` | 0,613 ms | 0,174 ms | Seq Scan → Bitmap Index Scan |
| Une semaine sur `date_intervention` | 0,671 ms | 0,168 ms | Seq Scan → Bitmap Index Scan |

Ces durées varient selon la machine. Reproduire les requêtes avec `tests/tests_index.sql`, avant et après création des index.

## 7. Exécution et vérification

**`projet.sql`** regroupe dans l'ordre demandé : **tables → données → fonctions/procédure → trigger → vues → rôles → index**. Il est destiné à une **base vide** ; ne pas le rejouer dans la base de travail déjà remplie.

```bash
psql -U postgres -c "CREATE DATABASE iolab_validation"
psql -U postgres -d iolab_validation -f projet.sql
```

Dans pgAdmin, on peut aussi créer une base vide, ouvrir `projet.sql` dans le Query Tool et l'exécuter. Les tests complémentaires sont dans `tests/` et les scripts séparés dans `sql/`.

**Application complémentaire :** une interface React + FastAPI permet de consulter et gérer les interventions ; le livrable évalué reste le script SQL et ses preuves.

**Rendu :** dépôt GitHub public, avec `projet.sql` et `README.md` à la racine. Déposer sur Moodle, avant le **16 octobre 2026 à 23 h 59**, un `.txt` contenant le lien du dépôt et les noms complets des trois membres.
