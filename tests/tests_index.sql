-- IMPORTANT : première mesure AVANT le fichier sql/07_index.sql,
-- puis même requêtes APRÈS. Conserver les temps réels et les plans.
ANALYZE interventions;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM interventions WHERE id_appareil = 5;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM interventions
WHERE date_intervention >= TIMESTAMP '2026-03-01'
  AND date_intervention < TIMESTAMP '2026-03-08';
