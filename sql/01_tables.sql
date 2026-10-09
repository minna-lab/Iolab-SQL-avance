

-- TABLE 1 : APPAREILS
-- Contient les equipements du laboratoire.

CREATE TABLE IF NOT EXISTS appareils (
    id_appareil INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    type_appareil VARCHAR(50) NOT NULL,
    localisation VARCHAR(100) NOT NULL,
    etat VARCHAR(20) NOT NULL DEFAULT 'fonctionnel',

    CONSTRAINT chk_etat_appareil
    CHECK (etat IN (
        'fonctionnel',
        'en panne',
        'en maintenance'
    ))
);


-- TABLE 2 : TECHNICIENS
-- Contient les techniciens de maintenance.

CREATE TABLE IF NOT EXISTS techniciens (
    id_technicien INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    specialite VARCHAR(100) NOT NULL
);


-- TABLE 3 : INTERVENTIONS
-- Contient les pannes et reparations.

CREATE TABLE IF NOT EXISTS interventions (
    id_intervention BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    id_appareil INTEGER NOT NULL,
    id_technicien INTEGER NOT NULL,

    description_panne TEXT NOT NULL,
    date_intervention TIMESTAMP NOT NULL,

    statut VARCHAR(20) NOT NULL DEFAULT 'en attente',
    compte_rendu TEXT,

    CONSTRAINT fk_intervention_appareil
    FOREIGN KEY (id_appareil)
    REFERENCES appareils(id_appareil),

    CONSTRAINT fk_intervention_technicien
    FOREIGN KEY (id_technicien)
    REFERENCES techniciens(id_technicien),

    CONSTRAINT chk_statut_intervention
    CHECK (statut IN (
        'en attente',
        'en cours',
        'terminée'
    ))
);


-- TABLE 4 : HISTORIQUE
-- Conserve les changements de statut.

CREATE TABLE IF NOT EXISTS historique (
    id_historique BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    id_intervention BIGINT NOT NULL,

    ancien_statut VARCHAR(20) NOT NULL,
    nouveau_statut VARCHAR(20) NOT NULL,

    date_changement TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    commentaire TEXT,

    CONSTRAINT fk_historique_intervention
    FOREIGN KEY (id_intervention)
    REFERENCES interventions(id_intervention),

    CONSTRAINT chk_historique_ancien
    CHECK (ancien_statut IN (
        'en attente',
        'en cours',
        'terminée'
    )),

    CONSTRAINT chk_historique_nouveau
    CHECK (nouveau_statut IN (
        'en attente',
        'en cours',
        'terminée'
    ))
);
