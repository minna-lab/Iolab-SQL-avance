-- IoTLab · 04 · Trigger
-- Règle : pas de clôture sans compte rendu, quel que soit le canal
-- (application, pgAdmin, script). La fonction est dans 03_fonctions.sql.

DROP TRIGGER IF EXISTS trg_verifier_cloture ON interventions;

CREATE TRIGGER trg_verifier_cloture
BEFORE INSERT OR UPDATE OF statut, compte_rendu ON interventions
FOR EACH ROW
EXECUTE FUNCTION verifier_cloture_intervention();
