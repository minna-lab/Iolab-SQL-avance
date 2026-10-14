-- IoTLab · 03 · Fonctions et procédure

-- 1. Une fonction : combien d'interventions pour un appareil ?
--    SECURITY DEFINER : elle lit la table avec les droits de son propriétaire.
--    Un rôle sans accès aux tables peut donc quand même l'appeler.
CREATE OR REPLACE FUNCTION nombre_interventions_appareil(p_id_appareil int)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT count(*)
    FROM interventions
    WHERE id_appareil = p_id_appareil;
$$;


-- 2. La fonction du trigger (il est créé dans 04_trigger.sql).
--    NEW est la ligne qui arrive : on refuse un statut « terminée » sans compte rendu.
CREATE OR REPLACE FUNCTION verifier_cloture_intervention()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.statut = 'terminée'
       AND (NEW.compte_rendu IS NULL OR btrim(NEW.compte_rendu) = '') THEN
        RAISE EXCEPTION 'Impossible de terminer une intervention sans compte rendu.';
    END IF;
    RETURN NEW;
END;
$$;


-- 3. Une procédure : clôturer une intervention « en cours » et garder une trace.
--    Si le compte rendu est vide, le trigger refuse et tout est annulé,
--    y compris la ligne d'historique.
CREATE OR REPLACE PROCEDURE cloturer_intervention(
    p_id_intervention bigint,
    p_compte_rendu    text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_statut varchar(20);
BEGIN
    -- FOR UPDATE verrouille la ligne pendant qu'on la lit
    SELECT statut INTO v_statut
    FROM interventions
    WHERE id_intervention = p_id_intervention
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Intervention % introuvable.', p_id_intervention;
    END IF;

    IF v_statut <> 'en cours' THEN
        RAISE EXCEPTION
            'Seule une intervention en cours peut être clôturée (statut actuel : %).',
            v_statut;
    END IF;

    UPDATE interventions
    SET statut = 'terminée', compte_rendu = p_compte_rendu
    WHERE id_intervention = p_id_intervention;

    INSERT INTO historique (id_intervention, ancien_statut, nouveau_statut, commentaire)
    VALUES (p_id_intervention, v_statut, 'terminée', p_compte_rendu);
END;
$$;
