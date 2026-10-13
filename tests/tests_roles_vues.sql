-- IoTLab · TESTS · rôles et vues


-- A. Technicien : actions AUTORISÉES
SET ROLE user_technicien;

SELECT * FROM vue_technicien LIMIT 3;

SELECT nombre_interventions_appareil(1);

BEGIN;
CALL cloturer_intervention(3, 'Capteur remplace, essais valides');
ROLLBACK;

RESET ROLE;


-- B. Technicien : actions REFUSÉES (une seule à la fois)
--    Attendu : « permission denied »

-- SET ROLE user_technicien;
-- SELECT * FROM interventions LIMIT 3;              -- table interdite
-- RESET ROLE;

-- SET ROLE user_technicien;
-- SELECT * FROM vue_superviseur LIMIT 3;            -- vue de l'autre rôle
-- RESET ROLE;

-- SET ROLE user_technicien;
-- UPDATE interventions SET statut = 'terminée';     -- modification directe
-- RESET ROLE;


-- C. Superviseur : actions AUTORISÉES
SET ROLE user_superviseur;

SELECT * FROM vue_superviseur ORDER BY id_appareil LIMIT 3;

RESET ROLE;


-- D. Superviseur : actions REFUSÉES (une seule à la fois)
--    Attendu : « permission denied »

-- SET ROLE user_superviseur;
-- SELECT * FROM interventions LIMIT 3;              -- table interdite
-- RESET ROLE;

-- SET ROLE user_superviseur;
-- SELECT * FROM vue_technicien LIMIT 3;             -- vue de l'autre rôle
-- RESET ROLE;

-- SET ROLE user_superviseur;
-- CALL cloturer_intervention(3, 'Test');            -- il contrôle, il ne modifie pas
-- RESET ROLE;
