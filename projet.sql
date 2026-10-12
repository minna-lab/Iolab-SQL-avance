-- IOLAB - 01 TABLES (Minna)
CREATE TABLE IF NOT EXISTS appareils (
    id_appareil INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    type_appareil VARCHAR(50) NOT NULL,
    localisation VARCHAR(100) NOT NULL,
    etat VARCHAR(20) NOT NULL DEFAULT 'fonctionnel',
    CONSTRAINT chk_etat_appareil CHECK (etat IN ('fonctionnel', 'en panne', 'en maintenance'))
);

CREATE TABLE IF NOT EXISTS techniciens (
    id_technicien INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    specialite VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS interventions (
    id_intervention BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_appareil INTEGER NOT NULL,
    id_technicien INTEGER NOT NULL,
    description_panne TEXT NOT NULL,
    date_intervention TIMESTAMP NOT NULL,
    statut VARCHAR(20) NOT NULL DEFAULT 'en attente',
    compte_rendu TEXT,
    CONSTRAINT fk_intervention_appareil FOREIGN KEY (id_appareil) REFERENCES appareils(id_appareil),
    CONSTRAINT fk_intervention_technicien FOREIGN KEY (id_technicien) REFERENCES techniciens(id_technicien),
    CONSTRAINT chk_statut_intervention CHECK (statut IN ('en attente', 'en cours', 'terminée'))
);

CREATE TABLE IF NOT EXISTS historique (
    id_historique BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_intervention BIGINT NOT NULL,
    ancien_statut VARCHAR(20) NOT NULL,
    nouveau_statut VARCHAR(20) NOT NULL,
    date_changement TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    commentaire TEXT,
    CONSTRAINT fk_historique_intervention FOREIGN KEY (id_intervention) REFERENCES interventions(id_intervention),
    CONSTRAINT chk_historique_ancien CHECK (ancien_statut IN ('en attente','en cours','terminée')),
    CONSTRAINT chk_historique_nouveau CHECK (nouveau_statut IN ('en attente','en cours','terminée'))
);


-- IOLAB - 02 DONNEES (Minna)
-- Executer sur des tables vides : insertion initiale de 20 appareils, 10 techniciens,
-- 10 000 interventions et 2 000 historiques.
BEGIN;

INSERT INTO appareils (nom, type_appareil, localisation, etat)
SELECT 'APPAREIL-' || LPAD(i::TEXT, 2, '0'),
       CASE WHEN i % 4 = 0 THEN 'ESP32' WHEN i % 4 = 1 THEN 'Arduino'
            WHEN i % 4 = 2 THEN 'Raspberry Pi' ELSE 'Module IoT' END,
       'Salle ' || CHR(65 + ((i - 1) % 4)),
       CASE WHEN i % 5 = 0 THEN 'en panne' WHEN i % 5 = 1 THEN 'en maintenance' ELSE 'fonctionnel' END
FROM generate_series(1, 20) AS i;

INSERT INTO techniciens (nom, prenom, specialite) VALUES
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

WITH liste_appareils AS (
    SELECT id_appareil, ROW_NUMBER() OVER (ORDER BY id_appareil) AS numero FROM appareils
), liste_techniciens AS (
    SELECT id_technicien, ROW_NUMBER() OVER (ORDER BY id_technicien) AS numero FROM techniciens
)
INSERT INTO interventions (id_appareil, id_technicien, description_panne, date_intervention, statut, compte_rendu)
SELECT a.id_appareil, t.id_technicien,
       CASE WHEN i % 4 = 0 THEN 'Probleme de connexion'
            WHEN i % 4 = 1 THEN 'Panne alimentation'
            WHEN i % 4 = 2 THEN 'Defaut capteur'
            ELSE 'Dysfonctionnement logiciel' END,
       TIMESTAMP '2026-01-01 08:00:00' + ((i - 1) % 270) * INTERVAL '1 day'
           + ((i - 1) % 10) * INTERVAL '1 hour',
       CASE WHEN i % 5 = 0 THEN 'terminée'
            WHEN i % 3 = 0 THEN 'en cours' ELSE 'en attente' END,
       CASE WHEN i % 5 = 0 THEN 'Intervention realisee, tests effectues et valides' ELSE NULL END
FROM generate_series(1, 10000) AS i
JOIN liste_appareils a ON a.numero = 1 + ((i - 1) % 20)
JOIN liste_techniciens t ON t.numero = 1 + ((i - 1) % 10);

INSERT INTO historique (id_intervention, ancien_statut, nouveau_statut, date_changement, commentaire)
SELECT id_intervention, 'en cours', 'terminée',
       date_intervention + INTERVAL '2 hours', 'Intervention cloturee apres verification'
FROM interventions WHERE statut = 'terminée';
COMMIT;


-- IOLAB - 03 FONCTIONS (Raissa)
CREATE OR REPLACE FUNCTION nombre_interventions_appareil(p_id_appareil INTEGER)
RETURNS BIGINT LANGUAGE SQL AS $$
    SELECT COUNT(*) FROM interventions WHERE id_appareil = p_id_appareil;
$$;

CREATE OR REPLACE FUNCTION verifier_cloture_intervention()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.statut = 'terminée'
       AND NULLIF(BTRIM(NEW.compte_rendu), '') IS NULL THEN
        RAISE EXCEPTION 'Impossible de terminer une intervention sans compte rendu.';
    END IF;
    RETURN NEW;
END;
$$;


-- IOLAB - 04 TRIGGER (Raissa)
DROP TRIGGER IF EXISTS trg_verifier_cloture ON interventions;
CREATE TRIGGER trg_verifier_cloture
BEFORE INSERT OR UPDATE OF statut, compte_rendu ON interventions
FOR EACH ROW EXECUTE FUNCTION verifier_cloture_intervention();


-- IOLAB - 05 VUES (Mariam)
-- Valeur exacte du statut dans la base : 'terminée' (avec accent).
CREATE OR REPLACE VIEW vue_technicien AS
SELECT i.id_intervention, a.nom AS appareil, i.description_panne,
       t.nom AS technicien, i.date_intervention, i.statut
FROM interventions i
JOIN appareils a ON a.id_appareil = i.id_appareil
JOIN techniciens t ON t.id_technicien = i.id_technicien
WHERE i.statut <> 'terminée';

CREATE OR REPLACE VIEW vue_superviseur AS
SELECT a.id_appareil, a.nom AS appareil,
       COUNT(i.id_intervention) AS total_interventions,
       COUNT(i.id_intervention) FILTER (WHERE i.statut = 'terminée') AS interventions_terminees
FROM appareils a
LEFT JOIN interventions i ON i.id_appareil = a.id_appareil
GROUP BY a.id_appareil, a.nom;


-- IOLAB - 06 ROLES (Mariam)
-- Les utilisateurs LOGIN sont créés SANS mot de passe dans le dépôt public.
-- Pour les connexions directes, l'administrateur définit ensuite leurs mots de passe
-- localement via pgAdmin ou psql .
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
END $$;

GRANT role_technicien TO user_technicien;
GRANT role_superviseur TO user_superviseur;
GRANT USAGE ON SCHEMA public TO role_technicien, role_superviseur;

-- Réduire les droits sur les tables métier. Le propriétaire et les
-- superutilisateurs restent administrateurs : c'est normal.
REVOKE ALL ON TABLE appareils, techniciens, interventions, historique FROM PUBLIC;
REVOKE ALL ON TABLE appareils, techniciens, interventions, historique
    FROM role_technicien, role_superviseur, user_technicien, user_superviseur;
REVOKE ALL ON vue_technicien, vue_superviseur FROM PUBLIC;
REVOKE ALL ON vue_technicien, vue_superviseur
    FROM role_technicien, role_superviseur, user_technicien, user_superviseur;
GRANT SELECT ON vue_technicien TO role_technicien;
GRANT SELECT ON vue_superviseur TO role_superviseur;


-- IOLAB - 07 INDEX (Maraim)
-- Les mesures AVANT index doivent être réalisées en lançant tests/tests_index.sql
-- AVANT d'exécuter ce fichier. Le README attend vos vrais résultats.
CREATE INDEX IF NOT EXISTS idx_interventions_appareil ON interventions(id_appareil);
CREATE INDEX IF NOT EXISTS idx_interventions_date ON interventions(date_intervention);
ANALYZE interventions;
