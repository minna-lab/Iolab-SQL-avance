-- ===== VUES =====

CREATE OR REPLACE VIEW vue_technicien AS
SELECT i.id_intervention,
       a.nom AS appareil,
       i.description_panne,
       t.nom AS technicien,
       i.date_intervention,
       i.statut
FROM interventions i
JOIN appareils a ON a.id_appareil = i.id_appareil
JOIN techniciens t ON t.id_technicien = i.id_technicien
WHERE i.statut <> 'terminee';

CREATE OR REPLACE VIEW vue_superviseur AS
SELECT a.id_appareil,
       a.nom AS appareil,
       COUNT(i.id_intervention) AS total_interventions,
       COUNT(i.id_intervention) FILTER (WHERE i.statut = 'terminee') AS interventions_terminees
FROM appareils a
LEFT JOIN interventions i ON i.id_appareil = a.id_appareil
GROUP BY a.id_appareil, a.nom;

-- ===== ROLES ET UTILISATEURS =====

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_technicien') THEN
        CREATE ROLE role_technicien;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_superviseur') THEN
        CREATE ROLE role_superviseur;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user_technicien') THEN
        CREATE USER user_technicien WITH PASSWORD 'technicien123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user_superviseur') THEN
        CREATE USER user_superviseur WITH PASSWORD 'superviseur123';
    END IF;
END
$$;

GRANT role_technicien TO user_technicien;
GRANT role_superviseur TO user_superviseur;

-- ===== DROITS =====

GRANT USAGE ON SCHEMA public TO role_technicien;
GRANT USAGE ON SCHEMA public TO role_superviseur;

GRANT SELECT ON vue_technicien TO role_technicien;
GRANT SELECT ON vue_superviseur TO role_superviseur;

-- ===== INDEX =====

CREATE INDEX IF NOT EXISTS idx_interventions_appareil ON interventions (id_appareil);
CREATE INDEX IF NOT EXISTS idx_interventions_date ON interventions (date_intervention);

ANALYZE interventions;
