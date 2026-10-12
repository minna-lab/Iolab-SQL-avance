
-- ============================================
-- IOLAB - VALIDATION FINALE
-- Responsable : Cheffe de projet
-- ============================================

-- 1. Vérifier la base de données
SELECT current_database(), current_user;

-- 2. Vérifier les quatre tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 3. Vérifier le nombre de lignes
SELECT 'appareils' AS table_nom, COUNT(*) AS total
FROM appareils
UNION ALL
SELECT 'techniciens', COUNT(*) FROM techniciens
UNION ALL
SELECT 'interventions', COUNT(*) FROM interventions
UNION ALL
SELECT 'historique', COUNT(*) FROM historique;

-- 4. Répartition des interventions
SELECT statut, COUNT(*) AS total
FROM interventions
GROUP BY statut
ORDER BY statut;

-- 5. Interventions terminées sans compte rendu
SELECT COUNT(*) AS interventions_incorrectes
FROM interventions
WHERE statut = 'terminée'
AND (
    compte_rendu IS NULL
    OR TRIM(compte_rendu) = ''
);

-- 6. Vérifier les relations entre les tables
SELECT
    i.id_intervention,
    a.nom AS appareil,
    t.nom AS technicien,
    i.statut
FROM interventions i
JOIN appareils a
    ON i.id_appareil = a.id_appareil
JOIN techniciens t
    ON i.id_technicien = t.id_technicien
ORDER BY i.id_intervention
LIMIT 10;

-- 7. Vérifier les clés étrangères
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS table_referencee
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.constraint_schema = kcu.constraint_schema
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
    AND tc.constraint_schema = ccu.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- 8. Vérifier la fonction métier
-- À exécuter après l'intégration du membre 2.
-- SELECT nombre_interventions_appareil(1);

-- 9. Vérifier les vues
-- À exécuter après l'intégration du membre 3.
-- SELECT * FROM vue_technicien LIMIT 5;
-- SELECT * FROM vue_superviseur LIMIT 5;
