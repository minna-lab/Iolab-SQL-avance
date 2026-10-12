-- IOLAB - 05 VUES (membre 3, corrigé)
-- Valeur exacte du statut dans la base : 'terminée' (avec accent).
CREATE OR REPLACE VIEW vue_technicien AS
SELECT i.id_intervention, a.nom AS appareil, i.description_panne,
       t.nom AS technicien, i.date_intervention, i.statut
FROM interventions i
JOIN appareils a ON a.id_appareil = i.id_appareil
JOIN techniciens t ON t.id_technicien = i.id_technicien
WHERE i.statut <> 'terminée';

CREATE OR REPLACE VIEW vue_superviseur AS
SELECT a.id_appareil, a.nom AS appareil,
       COUNT(i.id_intervention) AS total_interventions,
       COUNT(i.id_intervention) FILTER (WHERE i.statut = 'terminée') AS interventions_terminees
FROM appareils a
LEFT JOIN interventions i ON i.id_appareil = a.id_appareil
GROUP BY a.id_appareil, a.nom;
