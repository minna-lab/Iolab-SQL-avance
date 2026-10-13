-- IoTLab · TESTS · validation finale
-- À exécuter seulement après l'installation complète (projet.sql).
-- Lecture seule : rien n'est modifié.

-- Base et utilisateur courants
SELECT current_database(), current_user;


-- Effectifs de chaque table
SELECT 'appareils' AS table_nom, COUNT(*) AS total FROM appareils
UNION ALL
SELECT 'techniciens',  COUNT(*) FROM techniciens
UNION ALL
SELECT 'interventions', COUNT(*) FROM interventions
UNION ALL
SELECT 'historique',    COUNT(*) FROM historique;


-- Répartition par statut
SELECT statut, COUNT(*) AS total
FROM interventions
GROUP BY statut
ORDER BY statut;


-- Doit retourner 0 : aucune intervention terminée sans compte rendu
SELECT COUNT(*) AS clotures_sans_compte_rendu
FROM interventions
WHERE statut = 'terminée'
  AND NULLIF(BTRIM(compte_rendu), '') IS NULL;


-- Les deux valeurs doivent être identiques
SELECT nombre_interventions_appareil(1) AS via_fonction,
       (SELECT COUNT(*) FROM interventions WHERE id_appareil = 1) AS via_count;


-- Les deux valeurs doivent être identiques
SELECT COUNT(*) AS via_vue FROM vue_technicien;

SELECT COUNT(*) AS via_table
FROM interventions
WHERE statut <> 'terminée';


-- Vue superviseur
SELECT *
FROM vue_superviseur
ORDER BY id_appareil
LIMIT 20;


-- Les deux index doivent apparaître
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('idx_interventions_appareil', 'idx_interventions_date');
