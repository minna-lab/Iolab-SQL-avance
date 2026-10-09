
BEGIN;

-- 1. INSERTION DES 20 APPAREILS

INSERT INTO appareils
    (nom, type_appareil, localisation, etat)
SELECT
    'APPAREIL-' || LPAD(i::TEXT, 2, '0'),
    CASE
        WHEN i % 4 = 0 THEN 'ESP32'
        WHEN i % 4 = 1 THEN 'Arduino'
        WHEN i % 4 = 2 THEN 'Raspberry Pi'
        ELSE 'Module IoT'
    END,
    'Salle ' || CHR(65 + ((i - 1) % 4)),
    CASE
        WHEN i % 5 = 0 THEN 'en panne'
        WHEN i % 5 = 1 THEN 'en maintenance'
        ELSE 'fonctionnel'
    END
FROM generate_series(1, 20) AS i;

-- 2. INSERTION DES 10 TECHNICIENS

INSERT INTO techniciens
    (nom, prenom, specialite)
VALUES
    ('Martin', 'Thomas', 'Electronique'),
    ('Dupont', 'Marie', 'Informatique'),
    ('Bernard', 'Lucas', 'Reseaux'),
    ('Petit', 'Emma', 'Maintenance'),
    ('Robert', 'Hugo', 'Electronique'),
    ('Richard', 'Lea', 'IoT'),
    ('Durand', 'Nathan', 'Reseaux'),
    ('Moreau', 'Sarah', 'Informatique'),
    ('Simon', 'Adam', 'Maintenance'),
    ('Laurent', 'Ines', 'IoT');


-- 3. GENERATION DE 10 000 INTERVENTIONS


WITH liste_appareils AS (
    SELECT
        id_appareil,
        ROW_NUMBER() OVER (
            ORDER BY id_appareil
        ) AS numero
    FROM appareils
),
liste_techniciens AS (
    SELECT
        id_technicien,
        ROW_NUMBER() OVER (
            ORDER BY id_technicien
        ) AS numero
    FROM techniciens
)

INSERT INTO interventions (
    id_appareil,
    id_technicien,
    description_panne,
    date_intervention,
    statut,
    compte_rendu
)

SELECT
    a.id_appareil,
    t.id_technicien,

    CASE
        WHEN i % 4 = 0 THEN 'Probleme de connexion'
        WHEN i % 4 = 1 THEN 'Panne alimentation'
        WHEN i % 4 = 2 THEN 'Defaut capteur'
        ELSE 'Dysfonctionnement logiciel'
    END,

    TIMESTAMP '2026-01-01 08:00:00'
        + ((i - 1) % 270) * INTERVAL '1 day'
        + ((i - 1) % 10) * INTERVAL '1 hour',

    CASE
        WHEN i % 5 = 0 THEN 'terminée'
        WHEN i % 3 = 0 THEN 'en cours'
        ELSE 'en attente'
    END,

    CASE
        WHEN i % 5 = 0
        THEN 'Intervention realisee, tests effectues et valides'
        ELSE NULL
    END

FROM generate_series(1, 10000) AS i

JOIN liste_appareils a
    ON a.numero = 1 + ((i - 1) % 20)

JOIN liste_techniciens t
    ON t.numero = 1 + ((i - 1) % 10);

-- 4. INSERTION DES HISTORIQUES

INSERT INTO historique (
    id_intervention,
    ancien_statut,
    nouveau_statut,
    date_changement,
    commentaire
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
