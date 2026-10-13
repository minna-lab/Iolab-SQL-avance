-- IoTLab · 06 · RÔLES ET DROITS


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
