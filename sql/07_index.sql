-- IOLAB - 07 INDEX (membre 3, corrigé)
-- Les mesures AVANT index doivent être réalisées en lançant tests/tests_index.sql
-- AVANT d'exécuter ce fichier. Le README attend vos vrais résultats.
CREATE INDEX IF NOT EXISTS idx_interventions_appareil ON interventions(id_appareil);
CREATE INDEX IF NOT EXISTS idx_interventions_date ON interventions(date_intervention);
ANALYZE interventions;
