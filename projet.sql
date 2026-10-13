-- IoTLab · projet.sql (script complet, à lancer sur une base vide)


-- IoTLab · 01 · TABLES
-- Ordre de création : les tables référencées d'abord,
-- puis celles qui pointent vers elles.

CREATE TABLE IF NOT EXISTS appareils (
    id_appareil   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom           VARCHAR(100) NOT NULL UNIQUE,
    type_appareil VARCHAR(50)  NOT NULL,
    localisation  VARCHAR(100) NOT NULL,
    etat          VARCHAR(20)  NOT NULL DEFAULT 'fonctionnel',

    CONSTRAINT chk_etat_appareil
        CHECK (etat IN ('fonctionnel', 'en panne', 'en maintenance'))
);

CREATE TABLE IF NOT EXISTS techniciens (
    id_technicien INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom           VARCHAR(100) NOT NULL,
    prenom        VARCHAR(100) NOT NULL,
    specialite    VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS interventions (
    id_intervention   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_appareil       INTEGER      NOT NULL,
    id_technicien     INTEGER      NOT NULL,
    description_panne TEXT         NOT NULL,
    date_intervention TIMESTAMP    NOT NULL,
    statut            VARCHAR(20)  NOT NULL DEFAULT 'en attente',
    compte_rendu      TEXT,

    CONSTRAINT fk_intervention_appareil
        FOREIGN KEY (id_appareil)   REFERENCES appareils (id_appareil),
    CONSTRAINT fk_intervention_technicien
        FOREIGN KEY (id_technicien) REFERENCES techniciens (id_technicien),
    CONSTRAINT chk_statut_intervention
        CHECK (statut IN ('en attente', 'en cours', 'terminée'))
);

CREATE TABLE IF NOT EXISTS historique (
    id_historique   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_intervention BIGINT      NOT NULL,
    ancien_statut   VARCHAR(20) NOT NULL,
    nouveau_statut  VARCHAR(20) NOT NULL,
    date_changement TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    commentaire     TEXT,

    CONSTRAINT fk_historique_intervention
        FOREIGN KEY (id_intervention) REFERENCES interventions (id_intervention),
    CONSTRAINT chk_historique_ancien
        CHECK (ancien_statut  IN ('en attente', 'en cours', 'terminée')),
    CONSTRAINT chk_historique_nouveau
        CHECK (nouveau_statut IN ('en attente', 'en cours', 'terminée'))
);


-- IoTLab · 02 · DONNÉES
-- À exécuter sur des tables vides.
-- Volumes : 100 appareils, 10 techniciens, 10 000 interventions
--           et une ligne d'historique par intervention terminée.
--

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


-- IoTLab · 03 · FONCTIONS ET PROCÉDURE
--   1. nombre_interventions_appareil : fonction de comptage
--   2. verifier_cloture_intervention : fonction appelée par le trigger
--   3. cloturer_intervention         : procédure utilisée par le technicien

-- 1) Compte les interventions d'un appareil.
--    SECURITY DEFINER : les rôles métier peuvent l'appeler sans avoir
--    de droit direct sur la table interventions.
CREATE OR REPLACE FUNCTION nombre_interventions_appareil(p_id_appareil INTEGER)
RETURNS BIGINT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)
    FROM interventions
    WHERE id_appareil = p_id_appareil;
$$;


-- 2) Refuse la clôture d'une intervention sans compte rendu.
--    Cette fonction n'a de sens que branchée sur le trigger (fichier 04).
CREATE OR REPLACE FUNCTION verifier_cloture_intervention()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.statut = 'terminée'
       AND NULLIF(BTRIM(NEW.compte_rendu), '') IS NULL
    THEN
        RAISE EXCEPTION
            'Impossible de terminer une intervention sans compte rendu.';
    END IF;

    RETURN NEW;
END;
$$;


-- 3) Clôture une intervention « en cours » et trace le changement.
--    SECURITY DEFINER : la procédure s'exécute avec les droits de son
--    propriétaire. Le technicien peut donc clôturer une intervention
--    sans avoir le moindre droit direct sur les tables.
--    Si le compte rendu est vide, c'est le trigger qui refuse :
--    tout est annulé, y compris la ligne d'historique.
CREATE OR REPLACE PROCEDURE cloturer_intervention(
    p_id_intervention BIGINT,
    p_compte_rendu    TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ancien_statut VARCHAR(20);
BEGIN
    SELECT statut
    INTO v_ancien_statut
    FROM interventions
    WHERE id_intervention = p_id_intervention
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intervention % introuvable.', p_id_intervention;
    END IF;

    IF v_ancien_statut <> 'en cours' THEN
        RAISE EXCEPTION
            'Seule une intervention en cours peut être clôturée (statut actuel : %).',
            v_ancien_statut;
    END IF;

    UPDATE interventions
    SET statut       = 'terminée',
        compte_rendu = p_compte_rendu
    WHERE id_intervention = p_id_intervention;

    INSERT INTO historique (
        id_intervention, ancien_statut, nouveau_statut, commentaire
    )
    VALUES (
        p_id_intervention, v_ancien_statut, 'terminée', p_compte_rendu
    );
END;
$$;


-- IoTLab · 04 · TRIGGER
-- Règle : une intervention ne peut pas passer à « terminée »
-- sans compte rendu (vide ou fait uniquement d'espaces).



DROP TRIGGER IF EXISTS trg_verifier_cloture ON interventions;

CREATE TRIGGER trg_verifier_cloture
BEFORE INSERT OR UPDATE OF statut, compte_rendu ON interventions
FOR EACH ROW
EXECUTE FUNCTION verifier_cloture_intervention();


-- IoTLab · 05 · VUES (une par rôle)
-- Valeur exacte du statut dans la base : 'terminée' (avec accent).

-- Vue du technicien : le travail en cours.
-- Cache : les interventions terminées, les comptes rendus,
--         les prénoms des techniciens.
CREATE OR REPLACE VIEW vue_technicien AS
SELECT
    i.id_intervention,
    a.nom AS appareil,
    i.description_panne,
    t.nom AS technicien,
    i.date_intervention,
    i.statut
FROM interventions i
JOIN appareils    a ON a.id_appareil   = i.id_appareil
JOIN techniciens  t ON t.id_technicien = i.id_technicien
WHERE i.statut <> 'terminée';


-- Vue du superviseur : des chiffres par appareil, aucun détail.
-- Cache : les descriptions de panne, les techniciens, les dates.
CREATE OR REPLACE VIEW vue_superviseur AS
SELECT
    a.id_appareil,
    a.nom AS appareil,
    COUNT(i.id_intervention) AS total_interventions,
    COUNT(i.id_intervention) FILTER (WHERE i.statut = 'terminée')
        AS interventions_terminees
FROM appareils a
LEFT JOIN interventions i ON i.id_appareil = a.id_appareil
GROUP BY a.id_appareil, a.nom;


-- IoTLab · 06 · RÔLES ET DROITS
--
--   role_technicien   (NOLOGIN)  -> user_technicien   (LOGIN)
--     lit vue_technicien, clôture via cloturer_intervention()
--   role_superviseur  (NOLOGIN)  -> user_superviseur  (LOGIN)
--     lit vue_superviseur, ne modifie rien

-- 1) Création des rôles et des utilisateurs
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_technicien') THEN
        CREATE ROLE role_technicien NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_superviseur') THEN
        CREATE ROLE role_superviseur NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user_technicien') THEN
        CREATE ROLE user_technicien LOGIN INHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user_superviseur') THEN
        CREATE ROLE user_superviseur LOGIN INHERIT;
    END IF;
END
$$;

-- 2) Chaque utilisateur reçoit son rôle-métier
GRANT role_technicien  TO user_technicien;
GRANT role_superviseur TO user_superviseur;

GRANT USAGE ON SCHEMA public TO role_technicien, role_superviseur;

-- 3) On retire tout sur les tables : les rôles n'y ont aucun droit.
--    Le propriétaire et les superutilisateurs restent administrateurs.
REVOKE ALL ON TABLE appareils, techniciens, interventions, historique
    FROM PUBLIC;

REVOKE ALL ON TABLE appareils, techniciens, interventions, historique
    FROM role_technicien, role_superviseur, user_technicien, user_superviseur;

REVOKE ALL ON vue_technicien, vue_superviseur
    FROM PUBLIC;

REVOKE ALL ON vue_technicien, vue_superviseur
    FROM role_technicien, role_superviseur, user_technicien, user_superviseur;

-- 4) Les droits accordés : une vue par rôle...
GRANT SELECT ON vue_technicien  TO role_technicien;
GRANT SELECT ON vue_superviseur TO role_superviseur;

-- 5) ... et les routines. EXECUTE est donné à PUBLIC par défaut :
--    on le retire, puis on l'accorde aux seuls rôles concernés.
REVOKE ALL ON FUNCTION nombre_interventions_appareil(INTEGER) FROM PUBLIC;
REVOKE ALL ON PROCEDURE cloturer_intervention(BIGINT, TEXT)   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION nombre_interventions_appareil(INTEGER)
    TO role_technicien, role_superviseur;

GRANT EXECUTE ON PROCEDURE cloturer_intervention(BIGINT, TEXT)
    TO role_technicien;


-- IoTLab · 07 · INDEX
-- Mesures AVANT index : lancer tests/tests_index.sql avant ce fichier,
-- puis le relancer APRÈS. Les résultats sont dans le README.
--
--   idx_interventions_appareil : recherche des interventions d'un appareil
--                                (aussi utilisé par nombre_interventions_appareil)
--   idx_interventions_date     : recherche des interventions d'une période

CREATE INDEX IF NOT EXISTS idx_interventions_appareil
    ON interventions (id_appareil);

CREATE INDEX IF NOT EXISTS idx_interventions_date
    ON interventions (date_intervention);

-- Met à jour les statistiques pour que l'optimiseur choisisse les index.
ANALYZE interventions;
