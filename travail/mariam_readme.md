## Partie Mariam : sécurité, vues et performances

### Vues `vue_technicien` et `vue_superviseur`

- **Ce qu'elles font :** `vue_technicien` présente les interventions non terminées (appareil, description de la panne, technicien, date, statut). `vue_superviseur` présente un bilan par appareil (nombre total d'interventions et nombre d'interventions terminées).
- **Pourquoi :** limiter les données visibles selon le métier.
- **Preuve :**

```sql
SELECT * FROM vue_technicien LIMIT 5;
SELECT * FROM vue_superviseur LIMIT 5;
```

Résultat observé : `vue_technicien` ne contient aucune intervention `terminee`. `vue_superviseur` affiche 500 interventions par appareil et 166 ou 167 terminées.

### Rôles et privilèges

- **Ce qu'ils font :** `role_technicien` peut lire uniquement `vue_technicien`. `role_superviseur` peut lire uniquement `vue_superviseur`. `user_technicien` et `user_superviseur` appartiennent chacun à leur rôle. Aucun droit de lecture n'est donné sur les tables métier.
- **Pourquoi :** appliquer le principe du moindre privilège.
- **Preuve :**

```sql
SET ROLE role_technicien;
SELECT * FROM vue_technicien LIMIT 3;
SELECT * FROM interventions LIMIT 3;
SELECT * FROM vue_superviseur LIMIT 3;
RESET ROLE;

SET ROLE role_superviseur;
SELECT * FROM vue_superviseur LIMIT 3;
SELECT * FROM interventions LIMIT 3;
RESET ROLE;
```

Résultat observé : le `SELECT` sur la vue attribuée au rôle réussit. Le `SELECT` sur la table `interventions` et sur la vue de l'autre rôle donne `permission denied`.

### Index et mesures de performance

- **Ce qu'ils font :** `idx_interventions_appareil` accélère la recherche par appareil. `idx_interventions_date` accélère la recherche par période.
- **Pourquoi :** travailler efficacement sur 10 000 interventions.
- **Preuve :** requêtes mesurées avec `EXPLAIN (ANALYZE, BUFFERS)`, avant puis après création de chaque index.

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM interventions WHERE id_appareil = 5;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM interventions WHERE date_intervention BETWEEN '2025-03-01' AND '2025-03-07';
```

| Index | Requête testée | Avant (ms) | Après (ms) | Plan avant / après |
|---|---|---:|---:|---|
| `idx_interventions_appareil` | `WHERE id_appareil = 5` | 2.222 | 0.422 | Seq Scan / Bitmap Heap Scan (Bitmap Index Scan) |
| `idx_interventions_date` | `WHERE date_intervention BETWEEN '2025-03-01' AND '2025-03-07'` | 1.096 | 0.097 | Seq Scan / Bitmap Heap Scan (Bitmap Index Scan) |
