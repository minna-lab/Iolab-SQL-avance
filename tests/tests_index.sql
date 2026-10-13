-- IoTLab · TESTS · index (mesure avant / après)
-
ANALYZE interventions;


-- Recherche par appareil
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM interventions
WHERE id_appareil = 5;


-- Recherche par période (une semaine)
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM interventions
WHERE date_intervention >= TIMESTAMP '2026-03-01'
  AND date_intervention <  TIMESTAMP '2026-03-08';
