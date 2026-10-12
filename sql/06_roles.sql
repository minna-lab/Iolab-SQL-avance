-- IOLAB - 06 ROLES (membre 3, corrigé)
-- Les utilisateurs LOGIN sont créés SANS mot de passe dans le dépôt public.
-- Pour les connexions directes, l'administrateur définit ensuite leurs mots de passe
-- localement via pgAdmin ou psql (\password user_technicien).
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
