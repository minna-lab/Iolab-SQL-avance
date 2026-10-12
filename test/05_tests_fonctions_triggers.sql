
-- 1. TEST DE LA FONCTION DE COMPTAGE

-- Compter les interventions de l'appareil numero 1
SELECT nombre_interventions_appareil(1);

-- Comparer avec le resultat attendu
SELECT COUNT(*) AS nombre_attendu
FROM interventions
WHERE id_appareil = 1;


-- 2. TEST DU TRIGGER : CLOTURE SANS COMPTE RENDU


-- Resultat attendu : erreur explicite
-- Impossible de terminer une intervention sans compte rendu.

INSERT INTO interventions (
    id_appareil,
    id_technicien,
    description_panne,
    date_intervention,
    statut,
    compte_rendu
)
VALUES (
    1,
    1,
    'Test negatif du trigger',
    CURRENT_TIMESTAMP,
    'terminée',
    NULL
);


-- 3. TEST DU TRIGGER : CLOTURE AVEC COMPTE RENDU

-- Resultat attendu : insertion autorisee, puis annulee

BEGIN;

INSERT INTO interventions (
    id_appareil,
    id_technicien,
    description_panne,
    date_intervention,
    statut,
    compte_rendu
)
VALUES (
    1,
    1,
    'Test positif du trigger',
    CURRENT_TIMESTAMP,
    'terminée',
    'Reparation effectuee et tests valides'
);

ROLLBACK;


-- 4. TEST DES STATUTS SANS COMPTE RENDU

-- Resultat attendu : insertion autorisee, puis annulee

BEGIN;

INSERT INTO interventions (
    id_appareil,
    id_technicien,
    description_panne,
    date_intervention,
    statut,
    compte_rendu
)
VALUES
    (1, 1, 'Test en attente', CURRENT_TIMESTAMP, 'en attente', NULL),
    (2, 2, 'Test en cours', CURRENT_TIMESTAMP, 'en cours', NULL);

ROLLBACK;
