-- Exécuter avec un compte administrateur autorisé à SET ROLE.
-- Chaque SELECT refusé doit être testé SEUL, puis RESET ROLE.
SET ROLE role_technicien;
SELECT * FROM vue_technicien LIMIT 3;
RESET ROLE;
SET ROLE role_superviseur;
SELECT * FROM vue_superviseur LIMIT 3;
RESET ROLE;

-- Tests négatifs : décommenter UN SEUL SELECT à la fois ; erreur attendue.
-- SET ROLE role_technicien;
-- SELECT * FROM interventions LIMIT 3; -- permission denied
-- RESET ROLE;
-- SET ROLE role_technicien;
-- SELECT * FROM vue_superviseur LIMIT 3; -- permission denied
-- RESET ROLE;
-- SET ROLE role_superviseur;
-- SELECT * FROM interventions LIMIT 3; -- permission denied
-- RESET ROLE;
-- SET ROLE role_superviseur;
-- SELECT * FROM vue_technicien LIMIT 3; -- permission denied
-- RESET ROLE;
