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
