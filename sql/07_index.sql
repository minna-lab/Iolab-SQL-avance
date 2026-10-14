-- IoTLab · 07 · Index
-- PostgreSQL n'indexe pas les clés étrangères tout seul : id_appareil est le premier candidat.

-- Pour les recherches par appareil
CREATE INDEX idx_interventions_appareil ON interventions (id_appareil);

-- Pour les recherches par période
CREATE INDEX idx_interventions_date ON interventions (date_intervention);

-- Met à jour les statistiques, pour que PostgreSQL choisisse bien ses plans
ANALYZE interventions;
