-- IOLAB - 04 TRIGGER (membre 2, logique conservée)
DROP TRIGGER IF EXISTS trg_verifier_cloture ON interventions;
CREATE TRIGGER trg_verifier_cloture
BEFORE INSERT OR UPDATE OF statut, compte_rendu ON interventions
FOR EACH ROW EXECUTE FUNCTION verifier_cloture_intervention();
