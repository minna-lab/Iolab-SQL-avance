-- IoTLab · projet.sql (script complet, à lancer sur une base vide)
-- Il rassemble, dans l'ordre, les sept fichiers du dossier sql/.


-- IoTLab · 01 · Tables
-- On crée d'abord les tables qu'on référence, puis celles qui pointent vers elles.

CREATE TABLE appareils (
    id_appareil   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom           varchar(100) NOT NULL UNIQUE,
    type_appareil varchar(50)  NOT NULL,
    localisation  varchar(100) NOT NULL,
    etat          varchar(20)  NOT NULL DEFAULT 'fonctionnel',

    CONSTRAINT chk_etat_appareil
        CHECK (etat IN ('fonctionnel', 'en panne', 'en maintenance'))
);

CREATE TABLE techniciens (
    id_technicien integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom           varchar(100) NOT NULL,
    prenom        varchar(100) NOT NULL,
    specialite    varchar(100) NOT NULL
);

-- La table centrale : une intervention = un appareil + un technicien.
CREATE TABLE interventions (
    id_intervention   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_appareil       integer     NOT NULL REFERENCES appareils (id_appareil),
    id_technicien     integer     NOT NULL REFERENCES techniciens (id_technicien),
    description_panne text        NOT NULL,
    date_intervention timestamp   NOT NULL,
    statut            varchar(20) NOT NULL DEFAULT 'en attente',
    compte_rendu      text,

    CONSTRAINT chk_statut_intervention
        CHECK (statut IN ('en attente', 'en cours', 'terminée'))
);

-- Une ligne par changement de statut d'une intervention.
CREATE TABLE historique (
    id_historique   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_intervention bigint      NOT NULL REFERENCES interventions (id_intervention),
    ancien_statut   varchar(20) NOT NULL,
    nouveau_statut  varchar(20) NOT NULL,
    date_changement timestamp   NOT NULL DEFAULT now(),
    commentaire     text,

    CONSTRAINT chk_historique_ancien
        CHECK (ancien_statut  IN ('en attente', 'en cours', 'terminée')),
    CONSTRAINT chk_historique_nouveau
        CHECK (nouveau_statut IN ('en attente', 'en cours', 'terminée'))
);


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


-- IoTLab · 03 · Fonctions et procédure

-- 1. Une fonction : combien d'interventions pour un appareil ?
--    SECURITY DEFINER : elle lit la table avec les droits de son propriétaire.
--    Un rôle sans accès aux tables peut donc quand même l'appeler.
CREATE OR REPLACE FUNCTION nombre_interventions_appareil(p_id_appareil int)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT count(*)
    FROM interventions
    WHERE id_appareil = p_id_appareil;
$$;


-- 2. La fonction du trigger (il est créé dans 04_trigger.sql).
--    NEW est la ligne qui arrive : on refuse un statut « terminée » sans compte rendu.
CREATE OR REPLACE FUNCTION verifier_cloture_intervention()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.statut = 'terminée'
       AND (NEW.compte_rendu IS NULL OR btrim(NEW.compte_rendu) = '') THEN
        RAISE EXCEPTION 'Impossible de terminer une intervention sans compte rendu.';
    END IF;
    RETURN NEW;
END;
$$;


-- 3. Une procédure : clôturer une intervention « en cours » et garder une trace.
--    Si le compte rendu est vide, le trigger refuse et tout est annulé,
--    y compris la ligne d'historique.
CREATE OR REPLACE PROCEDURE cloturer_intervention(
    p_id_intervention bigint,
    p_compte_rendu    text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_statut varchar(20);
BEGIN
    -- FOR UPDATE verrouille la ligne pendant qu'on la lit
    SELECT statut INTO v_statut
    FROM interventions
    WHERE id_intervention = p_id_intervention
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intervention % introuvable.', p_id_intervention;
    END IF;

    IF v_statut <> 'en cours' THEN
        RAISE EXCEPTION
            'Seule une intervention en cours peut être clôturée (statut actuel : %).',
            v_statut;
    END IF;

    UPDATE interventions
    SET statut = 'terminée', compte_rendu = p_compte_rendu
    WHERE id_intervention = p_id_intervention;

    INSERT INTO historique (id_intervention, ancien_statut, nouveau_statut, commentaire)
    VALUES (p_id_intervention, v_statut, 'terminée', p_compte_rendu);
END;
$$;


-- IoTLab · 04 · Trigger
-- Règle : pas de clôture sans compte rendu, quel que soit le canal
-- (application, pgAdmin, script). La fonction est dans 03_fonctions.sql.

DROP TRIGGER IF EXISTS trg_verifier_cloture ON interventions;

CREATE TRIGGER trg_verifier_cloture
BEFORE INSERT OR UPDATE OF statut, compte_rendu ON interventions
FOR EACH ROW
EXECUTE FUNCTION verifier_cloture_intervention();


-- IoTLab · 05 · Vues (une par rôle)
-- Attention : la valeur du statut est 'terminée', avec accent.

-- Vue du technicien : le travail à faire.
-- Elle cache les interventions terminées, les comptes rendus et les prénoms.
CREATE OR REPLACE VIEW vue_technicien AS
SELECT i.id_intervention,
       a.nom AS appareil,
       i.description_panne,
       t.nom AS technicien,
       i.date_intervention,
       i.statut
FROM interventions i
JOIN appareils   a ON a.id_appareil   = i.id_appareil
JOIN techniciens t ON t.id_technicien = i.id_technicien
WHERE i.statut <> 'terminée';

-- Vue du superviseur : des chiffres par appareil, aucun détail.
-- Elle cache les descriptions, les techniciens et les dates.
CREATE OR REPLACE VIEW vue_superviseur AS
SELECT a.id_appareil,
       a.nom AS appareil,
       count(i.id_intervention) AS total_interventions,
       count(i.id_intervention) FILTER (WHERE i.statut = 'terminée')
           AS interventions_terminees
FROM appareils a
LEFT JOIN interventions i ON i.id_appareil = a.id_appareil
GROUP BY a.id_appareil, a.nom;


-- IoTLab · 06 · Rôles et droits
-- Les rôles existent pour tout le serveur PostgreSQL, pas seulement pour une base.
-- Pour rejouer le script, supprimez-les d'abord :
--   DROP OWNED BY user_technicien, user_superviseur, role_technicien, role_superviseur;
--   DROP ROLE user_technicien, user_superviseur, role_technicien, role_superviseur;

-- 1. Les rôles-métiers : on leur donne les droits, on ne se connecte pas avec
CREATE ROLE role_technicien  NOLOGIN;
CREATE ROLE role_superviseur NOLOGIN;

-- 2. Les utilisateurs : ils se connectent et héritent du rôle-métier
CREATE ROLE user_technicien  LOGIN PASSWORD 'technicien'  IN ROLE role_technicien;
CREATE ROLE user_superviseur LOGIN PASSWORD 'superviseur' IN ROLE role_superviseur;

-- 3. Les droits vont aux rôles-métiers : une vue chacun.
--    Aucun droit sur les tables : un rôle qui n'a rien reçu n'a droit à rien.
GRANT SELECT ON vue_technicien  TO role_technicien;
GRANT SELECT ON vue_superviseur TO role_superviseur;

-- 4. Les routines : EXECUTE est donné à tout le monde par défaut.
--    On le retire, puis on le donne aux seuls rôles concernés.
REVOKE EXECUTE ON FUNCTION  nombre_interventions_appareil(int)  FROM PUBLIC;
REVOKE EXECUTE ON PROCEDURE cloturer_intervention(bigint, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION  nombre_interventions_appareil(int)
    TO role_technicien, role_superviseur;
GRANT EXECUTE ON PROCEDURE cloturer_intervention(bigint, text)
    TO role_technicien;


-- IoTLab · 07 · Index
-- PostgreSQL n'indexe pas les clés étrangères tout seul : id_appareil est le premier candidat.

-- Pour les recherches par appareil
CREATE INDEX idx_interventions_appareil ON interventions (id_appareil);

-- Pour les recherches par période
CREATE INDEX idx_interventions_date ON interventions (date_intervention);

-- Met à jour les statistiques, pour que PostgreSQL choisisse bien ses plans
ANALYZE interventions;
