-- IoTLab · Tests · index (avant / après)
-- Méthode du cours : EXPLAIN ANALYZE devant la requête, on note le plan et le temps.
-- Lancez chaque mesure DEUX fois et gardez la seconde (la première remplit le cache).
-- N'utilisez pas l'application pendant ce test : DROP INDEX verrouille la table.

ANALYZE interventions;


-- 1. Les deux index existent
--    Vérification : deux lignes.
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx_interventions_%'
ORDER BY indexname;


-- 2. Recherche par appareil : APRÈS (l'index est là)
--    Vérification : Bitmap Index Scan, environ 0,1 ms.
EXPLAIN ANALYZE
SELECT * FROM interventions WHERE id_appareil = 5;


-- 3. Recherche par appareil : AVANT (l'index est supprimé le temps de la transaction)
--    Vérification : Seq Scan, plus lent.
BEGIN;
DROP INDEX idx_interventions_appareil;
EXPLAIN ANALYZE
SELECT * FROM interventions WHERE id_appareil = 5;
ROLLBACK;


-- 4. Recherche par période (une semaine) : APRÈS
--    Vérification : Bitmap Index Scan.
EXPLAIN ANALYZE
SELECT * FROM interventions
WHERE date_intervention >= '2026-03-01' AND date_intervention < '2026-03-08';


-- 5. Recherche par période : AVANT
--    Vérification : Seq Scan, plus lent.
BEGIN;
DROP INDEX idx_interventions_date;
EXPLAIN ANALYZE
SELECT * FROM interventions
WHERE date_intervention >= '2026-03-01' AND date_intervention < '2026-03-08';
ROLLBACK;


-- 6. Les index sont revenus (le ROLLBACK a annulé les DROP INDEX)
--    Vérification : 2.
SELECT count(*) FROM pg_indexes
WHERE indexname IN ('idx_interventions_appareil', 'idx_interventions_date');


-- Justification à rédiger en quatre lignes, comme dans le cours.
-- Remplacez les points par VOS mesures :
--   Requête : SELECT * FROM interventions WHERE id_appareil = 5   (100 lignes sur 10 000)
--   Avant   : Seq Scan, … ms.
--   Index   : CREATE INDEX idx_interventions_appareil ON interventions (id_appareil);
--   Après   : Bitmap Index Scan, … ms.
