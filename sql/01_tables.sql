-- IoTLab · 01 · Tables
-- On crée d'abord les tables qu'on référence, puis celles qui pointent vers elles.

CREATE TABLE appareils (
    id_appareil   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom           varchar(100) NOT NULL UNIQUE,
    type_appareil varchar(50)  NOT NULL,
    localisation  varchar(100) NOT NULL,
    etat          varchar(20)  NOT NULL DEFAULT 'fonctionnel',

    CONSTRAINT chk_etat_appareil
        CHECK (etat IN ('fonctionnel', 'en panne', 'en maintenance'))
);

CREATE TABLE techniciens (
    id_technicien integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom           varchar(100) NOT NULL,
    prenom        varchar(100) NOT NULL,
    specialite    varchar(100) NOT NULL
);

-- La table centrale : une intervention = un appareil + un technicien.
CREATE TABLE interventions (
    id_intervention   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_appareil       integer     NOT NULL REFERENCES appareils (id_appareil),
    id_technicien     integer     NOT NULL REFERENCES techniciens (id_technicien),
    description_panne text        NOT NULL,
    date_intervention timestamp   NOT NULL,
    statut            varchar(20) NOT NULL DEFAULT 'en attente',
    compte_rendu      text,

    CONSTRAINT chk_statut_intervention
        CHECK (statut IN ('en attente', 'en cours', 'terminée'))
);

-- Une ligne par changement de statut d'une intervention.
CREATE TABLE historique (
    id_historique   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_intervention bigint      NOT NULL REFERENCES interventions (id_intervention),
    ancien_statut   varchar(20) NOT NULL,
    nouveau_statut  varchar(20) NOT NULL,
    date_changement timestamp   NOT NULL DEFAULT now(),
    commentaire     text,

    CONSTRAINT chk_historique_ancien
        CHECK (ancien_statut  IN ('en attente', 'en cours', 'terminée')),
    CONSTRAINT chk_historique_nouveau
        CHECK (nouveau_statut IN ('en attente', 'en cours', 'terminée'))
);
