-- IoTLab · Tests · vues, rôles et droits
-- Exécutez un bloc à la fois (sélection, puis F5).
-- SET LOCAL ROLE ne dure que le temps de la transaction : le ROLLBACK
-- nous fait redevenir nous-mêmes, même après une erreur.
-- (Si pgAdmin affiche « transaction is aborted », lancez ROLLBACK; puis le bloc suivant.)


-- 1. Les vues, vues par le propriétaire
--    Vérification : 7143 = 7143 (interventions non terminées) et 100 = 100 (appareils).
SELECT (SELECT count(*) FROM vue_technicien)                       AS vue_technicien,
       (SELECT count(*) FROM interventions WHERE statut <> 'terminée') AS interventions_non_terminees,
       (SELECT count(*) FROM vue_superviseur)                      AS vue_superviseur,
       (SELECT count(*) FROM appareils)                            AS appareils;


-- 2. Technicien : ce qui est AUTORISÉ
--    Vérification : trois lignes, puis 100, puis la clôture passe (puis est annulée).
BEGIN;
SET LOCAL ROLE user_technicien;
SELECT * FROM vue_technicien LIMIT 3;
SELECT nombre_interventions_appareil(1);
CALL cloturer_intervention(3, 'Capteur remplace, essais valides');
ROLLBACK;


-- 3. Technicien : lire une table
--    Vérification : ERROR  permission denied for table interventions
BEGIN;
SET LOCAL ROLE user_technicien;
SELECT * FROM interventions LIMIT 3;
ROLLBACK;


-- 4. Technicien : lire la vue de l'autre rôle
--    Vérification : ERROR  permission denied for view vue_superviseur
BEGIN;
SET LOCAL ROLE user_technicien;
SELECT * FROM vue_superviseur LIMIT 3;
ROLLBACK;


-- 5. Technicien : modifier une table directement
--    Vérification : ERROR  permission denied for table interventions
BEGIN;
SET LOCAL ROLE user_technicien;
UPDATE interventions SET statut = 'terminée';
ROLLBACK;


-- 6. Superviseur : ce qui est AUTORISÉ
--    Vérification : trois lignes, puis 100.
BEGIN;
SET LOCAL ROLE user_superviseur;
SELECT * FROM vue_superviseur ORDER BY id_appareil LIMIT 3;
SELECT nombre_interventions_appareil(1);
ROLLBACK;


-- 7. Superviseur : lire une table
--    Vérification : ERROR  permission denied for table interventions
BEGIN;
SET LOCAL ROLE user_superviseur;
SELECT * FROM interventions LIMIT 3;
ROLLBACK;


-- 8. Superviseur : lire la vue de l'autre rôle
--    Vérification : ERROR  permission denied for view vue_technicien
BEGIN;
SET LOCAL ROLE user_superviseur;
SELECT * FROM vue_technicien LIMIT 3;
ROLLBACK;


-- 9. Superviseur : clôturer une intervention (il contrôle, il ne modifie pas)
--    Vérification : ERROR  permission denied for procedure cloturer_intervention
BEGIN;
SET LOCAL ROLE user_superviseur;
CALL cloturer_intervention(3, 'Test');
ROLLBACK;
