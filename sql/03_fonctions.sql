-- IoTLab · 03 · FONCTIONS ET PROCÉDURE

CREATE OR REPLACE FUNCTION nombre_interventions_appareil(p_id_appareil INTEGER)
RETURNS BIGINT
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)
    FROM interventions
    WHERE id_appareil = p_id_appareil;
$$;


-- 2) Refuse la clôture d'une intervention sans compte rendu.
--    Cette fonction n'a de sens que branchée sur le trigger (fichier 04).
CREATE OR REPLACE FUNCTION verifier_cloture_intervention()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.statut = 'terminée'
       AND NULLIF(BTRIM(NEW.compte_rendu), '') IS NULL
    THEN
        RAISE EXCEPTION
            'Impossible de terminer une intervention sans compte rendu.';
    END IF;

    RETURN NEW;
END;
$$;


-- 3) Clôture une intervention « en cours » et trace le changement.
--    SECURITY DEFINER : la procédure s'exécute avec les droits de son
--    propriétaire. Le technicien peut donc clôturer une intervention
--    sans avoir le moindre droit direct sur les tables.
--    Si le compte rendu est vide, c'est le trigger qui refuse :
--    tout est annulé, y compris la ligne d'historique.
CREATE OR REPLACE PROCEDURE cloturer_intervention(
    p_id_intervention BIGINT,
    p_compte_rendu    TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_ancien_statut VARCHAR(20);
BEGIN
    SELECT statut
    INTO v_ancien_statut
    FROM interventions
    WHERE id_intervention = p_id_intervention
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intervention % introuvable.', p_id_intervention;
    END IF;

    IF v_ancien_statut <> 'en cours' THEN
        RAISE EXCEPTION
            'Seule une intervention en cours peut être clôturée (statut actuel : %).',
            v_ancien_statut;
    END IF;

    UPDATE interventions
    SET statut       = 'terminée',
        compte_rendu = p_compte_rendu
    WHERE id_intervention = p_id_intervention;

    INSERT INTO historique (
        id_intervention, ancien_statut, nouveau_statut, commentaire
    )
    VALUES (
        p_id_intervention, v_ancien_statut, 'terminée', p_compte_rendu
    );
END;
$$;
