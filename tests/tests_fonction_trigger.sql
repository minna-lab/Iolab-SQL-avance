-- IoTLab · Tests · fonction, trigger et procédure
-- Jeu de données initial : n° 1 terminée · n° 3 en cours · n° 4 en attente.
-- Exécutez un bloc à la fois (sélection, puis F5).
-- Chaque test qui écrit est entouré de BEGIN ... ROLLBACK : rien n'est modifié.


-- 1. La fonction donne le même résultat qu'un count direct
--    Vérification : les deux colonnes sont identiques (100).
SELECT nombre_interventions_appareil(1) AS par_la_fonction,
       (SELECT count(*) FROM interventions WHERE id_appareil = 1) AS count_direct;


-- 2. Trigger : terminer SANS compte rendu
--    Vérification : ERROR  Impossible de terminer une intervention sans compte rendu.
BEGIN;
UPDATE interventions SET statut = 'terminée', compte_rendu = NULL
WHERE id_intervention = 3;
ROLLBACK;


-- 3. Trigger : un compte rendu fait d'espaces ne compte pas
--    Vérification : la même erreur.
BEGIN;
UPDATE interventions SET statut = 'terminée', compte_rendu = '   '
WHERE id_intervention = 3;
ROLLBACK;


-- 4. Trigger : terminer AVEC compte rendu
--    Vérification : UPDATE 1, et le statut affiché est « terminée ».
BEGIN;
UPDATE interventions SET statut = 'terminée', compte_rendu = 'Capteur remplace'
WHERE id_intervention = 3;
SELECT id_intervention, statut FROM interventions WHERE id_intervention = 3;
ROLLBACK;


-- 5. Trigger : il surveille aussi les nouvelles lignes (INSERT)
--    Vérification : la même erreur.
BEGIN;
INSERT INTO interventions (id_appareil, id_technicien, description_panne,
                           date_intervention, statut)
VALUES (1, 1, 'Test du trigger', now(), 'terminée');
ROLLBACK;


-- 6. Les autres statuts n'ont pas besoin de compte rendu
--    Vérification : UPDATE 1, sans erreur.
BEGIN;
UPDATE interventions SET statut = 'en cours' WHERE id_intervention = 4;
ROLLBACK;


-- 7a. Procédure : clôture SANS compte rendu
--     Vérification : ERROR  Impossible de terminer une intervention sans compte rendu.
BEGIN;
CALL cloturer_intervention(3, NULL);
ROLLBACK;


-- 7b. Procédure : clôture AVEC compte rendu
--     Vérification : statut « terminée », et une ligne d'historique « en cours → terminée ».
BEGIN;
CALL cloturer_intervention(3, 'Capteur remplace, essais valides');
SELECT statut FROM interventions WHERE id_intervention = 3;
SELECT ancien_statut, nouveau_statut
FROM historique
WHERE id_intervention = 3
ORDER BY id_historique DESC
LIMIT 1;
ROLLBACK;


-- 7c. Procédure : l'intervention n° 4 est « en attente », pas « en cours »
--     Vérification : ERROR  Seule une intervention en cours peut être clôturée
--     (statut actuel : en attente).
BEGIN;
CALL cloturer_intervention(4, 'Test');
ROLLBACK;
