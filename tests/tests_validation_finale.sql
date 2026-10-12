-- Exécuter seulement après l'installation complète.
SELECT current_database(), current_user;
SELECT 'appareils' AS table_nom, COUNT(*) AS total FROM appareils
UNION ALL SELECT 'techniciens', COUNT(*) FROM techniciens
UNION ALL SELECT 'interventions', COUNT(*) FROM interventions
UNION ALL SELECT 'historique', COUNT(*) FROM historique;
SELECT statut, COUNT(*) FROM interventions GROUP BY statut ORDER BY statut;
SELECT COUNT(*) AS clotures_sans_compte_rendu FROM interventions
WHERE statut='terminée' AND NULLIF(BTRIM(compte_rendu),'') IS NULL;
SELECT nombre_interventions_appareil(1) AS via_fonction,
       (SELECT COUNT(*) FROM interventions WHERE id_appareil=1) AS via_count;
SELECT COUNT(*) AS interventions_non_terminees FROM vue_technicien;
SELECT * FROM vue_superviseur ORDER BY id_appareil LIMIT 20;
SELECT indexname FROM pg_indexes WHERE schemaname='public'
AND indexname IN ('idx_interventions_appareil','idx_interventions_date');
