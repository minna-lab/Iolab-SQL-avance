


-- 1. Fonction de comptage
--    Attendu : les deux colonnes sont identiques.
SELECT nombre_interventions_appareil(1) AS via_fonction,
       (SELECT COUNT(*) FROM interventions WHERE id_appareil = 1) AS via_count;


-- 2. Trigger : clôture SANS compte rendu
--    Attendu : ERREUR « Impossible de terminer une intervention
--    sans compte rendu. »
BEGIN;

INSERT INTO interventions (
    id_appareil, id_technicien, description_panne,
    date_intervention, statut, compte_rendu
)
VALUES (
    1, 1, 'Test negatif du trigger',
    CURRENT_TIMESTAMP, 'terminée', NULL
);

ROLLBACK;


-- 3. Trigger : clôture AVEC compte rendu
--    Attendu : insertion acceptée (puis annulée).
BEGIN;

INSERT INTO interventions (
    id_appareil, id_technicien, description_panne,
    date_intervention, statut, compte_rendu
)
VALUES (
    1, 1, 'Test positif du trigger',
    CURRENT_TIMESTAMP, 'terminée', 'Reparation effectuee et tests valides'
);

ROLLBACK;


-- 4. Les autres statuts n'ont pas besoin de compte rendu
--    Attendu : insertion acceptée (puis annulée).
BEGIN;

INSERT INTO interventions (
    id_appareil, id_technicien, description_panne,
    date_intervention, statut, compte_rendu
)
VALUES
    (1, 1, 'Test en attente', CURRENT_TIMESTAMP, 'en attente', NULL),
    (2, 2, 'Test en cours',   CURRENT_TIMESTAMP, 'en cours',   NULL);

ROLLBACK;


-- 5. Procédure cloturer_intervention
--    Dans le jeu de données : n° 3 = « en cours », n° 4 = « en attente »,
--    n° 1 = « terminée ».

-- 5a. Sans compte rendu : le trigger refuse, rien n'est écrit.
--     Attendu : ERREUR « Impossible de terminer ... »
BEGIN;
CALL cloturer_intervention(3, NULL);
ROLLBACK;

-- 5b. Avec compte rendu : l'intervention passe à « terminée »
--     et une ligne d'historique est créée (puis annulée).
BEGIN;
CALL cloturer_intervention(3, 'Capteur remplace, essais valides');

SELECT id_intervention, statut, compte_rendu
FROM interventions
WHERE id_intervention = 3;

SELECT ancien_statut, nouveau_statut, commentaire
FROM historique
WHERE id_intervention = 3;

ROLLBACK;

-- 5c. Intervention « en attente » (n° 4) : refus avec un message clair.
--     Attendu : ERREUR « Seule une intervention en cours peut être clôturée ... »
BEGIN;
CALL cloturer_intervention(4, 'Test');
ROLLBACK;
