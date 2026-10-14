-- IoTLab · 02 · Données
-- À lancer sur une base vide : les identifiants commencent à 1.

-- 100 appareils, générés avec generate_series
INSERT INTO appareils (nom, type_appareil, localisation, etat)
SELECT 'APPAREIL-' || lpad(i::text, 3, '0'),
       (ARRAY['ESP32', 'Arduino', 'Raspberry Pi', 'Module IoT'])[1 + i % 4],
       'Salle ' || chr(65 + ((i - 1) / 4) % 5),
       CASE i % 10
           WHEN 0 THEN 'en panne'
           WHEN 5 THEN 'en maintenance'
           ELSE 'fonctionnel'
       END
FROM generate_series(1, 100) AS i;

-- 10 techniciens, saisis à la main
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

-- 10 000 interventions : la plus grosse table, celle des mesures d'index.
-- Une intervention terminée a toujours un compte rendu (sinon le trigger la refuserait).
INSERT INTO interventions
    (id_appareil, id_technicien, description_panne, date_intervention, statut, compte_rendu)
SELECT 1 + (i - 1) % 100,
       1 + ((i - 1) / 3) % 10,
       (ARRAY['Probleme de connexion', 'Panne alimentation',
              'Defaut capteur', 'Dysfonctionnement logiciel'])[1 + (i / 4) % 4],
       timestamp '2026-01-01 08:00' + ((i - 1) % 270) * interval '1 day'
                                    + ((i - 1) % 10)  * interval '1 hour',
       CASE
           WHEN i % 7 IN (0, 1) THEN 'terminée'
           WHEN i % 7 IN (2, 3) THEN 'en cours'
           ELSE 'en attente'
       END,
       CASE WHEN i % 7 IN (0, 1)
            THEN 'Intervention realisee, tests effectues et valides'
       END
FROM generate_series(1, 10000) AS i
ORDER BY i;

-- Une ligne d'historique par intervention terminée
INSERT INTO historique
    (id_intervention, ancien_statut, nouveau_statut, date_changement, commentaire)
SELECT id_intervention, 'en cours', 'terminée',
       date_intervention + interval '2 hours',
       'Intervention cloturee apres verification'
FROM interventions
WHERE statut = 'terminée';
