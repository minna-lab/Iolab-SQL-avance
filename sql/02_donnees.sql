-- IoTLab · 02 · DONNÉES

BEGIN;

-- 1) Appareils (100)
INSERT INTO appareils (nom, type_appareil, localisation, etat)
SELECT
    'APPAREIL-' || LPAD(i::TEXT, 3, '0'),
    CASE i % 4
        WHEN 0 THEN 'ESP32'
        WHEN 1 THEN 'Arduino'
        WHEN 2 THEN 'Raspberry Pi'
        ELSE        'Module IoT'
    END,
    'Salle ' || CHR(65 + ((i - 1) / 4) % 5),
    CASE i % 10
        WHEN 0 THEN 'en panne'
        WHEN 5 THEN 'en maintenance'
        ELSE        'fonctionnel'
    END
FROM generate_series(1, 100) AS i;

-- 2) Techniciens (10, saisis à la main)
INSERT INTO techniciens (nom, prenom, specialite) VALUES
    ('Martin',  'Thomas', 'Electronique'),
    ('Dupont',  'Marie',  'Informatique'),
    ('Bernard', 'Lucas',  'Reseaux'),
    ('Petit',   'Emma',   'Maintenance'),
    ('Robert',  'Hugo',   'Electronique'),
    ('Richard', 'Lea',    'IoT'),
    ('Durand',  'Nathan', 'Reseaux'),
    ('Moreau',  'Sarah',  'Informatique'),
    ('Simon',   'Adam',   'Maintenance'),
    ('Laurent', 'Ines',   'IoT');

-- 3) Interventions (10 000)
--    La plus grosse table : c'est elle qui sert aux mesures d'index.
WITH liste_appareils AS (
    SELECT id_appareil,
           ROW_NUMBER() OVER (ORDER BY id_appareil) AS numero
    FROM appareils
),
liste_techniciens AS (
    SELECT id_technicien,
           ROW_NUMBER() OVER (ORDER BY id_technicien) AS numero
    FROM techniciens
)
INSERT INTO interventions (
    id_appareil, id_technicien, description_panne,
    date_intervention, statut, compte_rendu
)
SELECT
    a.id_appareil,
    t.id_technicien,

    CASE (i / 4) % 4
        WHEN 0 THEN 'Probleme de connexion'
        WHEN 1 THEN 'Panne alimentation'
        WHEN 2 THEN 'Defaut capteur'
        ELSE        'Dysfonctionnement logiciel'
    END,

    TIMESTAMP '2026-01-01 08:00:00'
        + ((i - 1) % 270) * INTERVAL '1 day'
        + ((i - 1) % 10)  * INTERVAL '1 hour',

    CASE i % 7
        WHEN 0 THEN 'terminée'
        WHEN 1 THEN 'terminée'
        WHEN 2 THEN 'en cours'
        WHEN 3 THEN 'en cours'
        ELSE        'en attente'
    END,

    -- Une intervention terminée a toujours un compte rendu
    -- (sinon le trigger refuserait la ligne).
    CASE
        WHEN i % 7 IN (0, 1)
            THEN 'Intervention realisee, tests effectues et valides'
    END
FROM generate_series(1, 10000) AS i
JOIN liste_appareils    a ON a.numero = 1 + ((i - 1) % 100)
JOIN liste_techniciens  t ON t.numero = 1 + (((i - 1) / 3) % 10)
ORDER BY i;  -- l'identifiant de l'intervention suit alors le numéro i

-- 4) Historique : une ligne par intervention terminée
INSERT INTO historique (
    id_intervention, ancien_statut, nouveau_statut,
    date_changement, commentaire
)
SELECT
    id_intervention,
    'en cours',
    'terminée',
    date_intervention + INTERVAL '2 hours',
    'Intervention cloturee apres verification'
FROM interventions
WHERE statut = 'terminée';

COMMIT;
