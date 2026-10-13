-- IoTLab · 07 · INDEX

CREATE INDEX IF NOT EXISTS idx_interventions_appareil
    ON interventions (id_appareil);

CREATE INDEX IF NOT EXISTS idx_interventions_date
    ON interventions (date_intervention);

-- Met à jour les statistiques pour que l'optimiseur choisisse les index.
ANALYZE interventions;
