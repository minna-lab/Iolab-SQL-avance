-- IoTLab · Tests · validation finale
-- À lancer après l'installation complète de projet.sql.
-- Lecture seule : rien n'est modifié.


-- 1. Où suis-je ?
SELECT current_database(), current_user;


-- 2. Les effectifs de chaque table
--    Vérification : 100, 10, 10000 et 2857 sur le jeu de données initial.
SELECT 'appareils' AS table_nom, count(*) AS total FROM appareils
UNION ALL SELECT 'techniciens',   count(*) FROM techniciens
UNION ALL SELECT 'interventions', count(*) FROM interventions
UNION ALL SELECT 'historique',    count(*) FROM historique;


-- 3. La répartition par statut
--    Vérification : en attente 4285 · en cours 2858 · terminée 2857.
SELECT statut, count(*) AS total
FROM interventions
GROUP BY statut
ORDER BY statut;


-- 4. Aucune intervention terminée sans compte rendu
--    Vérification : 0.
SELECT count(*) AS clotures_sans_compte_rendu
FROM interventions
WHERE statut = 'terminée'
  AND (compte_rendu IS NULL OR btrim(compte_rendu) = '');


-- 5. Pas d'orphelins : chaque historique pointe vers une intervention existante
--    Vérification : 0.
SELECT count(*) AS historique_orphelin
FROM historique h
LEFT JOIN interventions i ON i.id_intervention = h.id_intervention
WHERE i.id_intervention IS NULL;


-- 6. La fonction donne le même résultat qu'un count direct
--    Vérification : deux valeurs identiques.
SELECT nombre_interventions_appareil(1) AS par_la_fonction,
       (SELECT count(*) FROM interventions WHERE id_appareil = 1) AS count_direct;


-- 7. La vue technicien correspond aux interventions non terminées
--    Vérification : deux valeurs identiques.
SELECT (SELECT count(*) FROM vue_technicien) AS par_la_vue,
       (SELECT count(*) FROM interventions WHERE statut <> 'terminée') AS par_la_table;


-- 8. La vue superviseur : une ligne par appareil
--    Vérification : cinq lignes, avec 100 interventions au total par appareil.
SELECT * FROM vue_superviseur ORDER BY id_appareil LIMIT 5;


-- 9. Les objets attendus existent
--    Vérification : 1 trigger, 4 rôles, 2 index.
SELECT (SELECT count(*) FROM pg_trigger WHERE tgname = 'trg_verifier_cloture') AS triggers,
       (SELECT count(*) FROM pg_roles
        WHERE rolname IN ('role_technicien', 'role_superviseur',
                          'user_technicien', 'user_superviseur'))             AS roles,
       (SELECT count(*) FROM pg_indexes
        WHERE indexname IN ('idx_interventions_appareil',
                            'idx_interventions_date'))                        AS index;
