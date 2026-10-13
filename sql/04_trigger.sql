-- IoTLab · 04 · TRIGGER
-- Règle : une intervention ne peut pas passer à « terminée »
-- sans compte rendu (vide ou fait uniquement d'espaces).


DROP TRIGGER IF EXISTS trg_verifier_cloture ON interventions;

CREATE TRIGGER trg_verifier_cloture
BEFORE INSERT OR UPDATE OF statut, compte_rendu ON interventions
FOR EACH ROW
EXECUTE FUNCTION verifier_cloture_intervention();
