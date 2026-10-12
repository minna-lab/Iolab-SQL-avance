-- IOLAB - 03 FONCTIONS (membre 2, logique conservée)
CREATE OR REPLACE FUNCTION nombre_interventions_appareil(p_id_appareil INTEGER)
RETURNS BIGINT LANGUAGE SQL AS $$
    SELECT COUNT(*) FROM interventions WHERE id_appareil = p_id_appareil;
$$;

CREATE OR REPLACE FUNCTION verifier_cloture_intervention()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.statut = 'terminée'
       AND NULLIF(BTRIM(NEW.compte_rendu), '') IS NULL THEN
        RAISE EXCEPTION 'Impossible de terminer une intervention sans compte rendu.';
    END IF;
    RETURN NEW;
END;
$$;
