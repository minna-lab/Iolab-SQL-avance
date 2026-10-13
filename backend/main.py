"""IoTLab API — API locale de démonstration SQL avancé.

Ne pas exposer sur Internet sans authentification et sans compte de base
de données à privilèges restreints.
"""

import logging
import os
from datetime import date, timedelta
from typing import Literal

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError, IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from database import get_db

load_dotenv()
log = logging.getLogger("iolab")


# ------------------------------------------------------------
# Application et CORS
# ------------------------------------------------------------
app = FastAPI(
    title="IoTLab API",
    description="Gestion des interventions de maintenance",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv(
        "CORS_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173",
    ).split(","),
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["Content-Type"],
)


# ------------------------------------------------------------
# Modèles de données (validation des requêtes)
# ------------------------------------------------------------
class NouvelleIntervention(BaseModel):
    id_appareil: int = Field(gt=0)
    id_technicien: int = Field(gt=0)
    description_panne: str = Field(min_length=3, max_length=2000)

    @field_validator("description_panne")
    @classmethod
    def description_non_vide(cls, value):
        value = value.strip()
        if len(value) < 3:
            raise ValueError("La description doit contenir au moins 3 caractères.")
        return value


class ChangementStatut(BaseModel):
    statut: Literal["en cours", "terminée"]
    compte_rendu: str | None = Field(default=None, max_length=10000)


# ------------------------------------------------------------
# Fonctions utilitaires
# ------------------------------------------------------------
def all_rows(db, sql, params=None):
    """Exécute une requête et renvoie toutes les lignes sous forme de dict."""
    result = db.execute(text(sql), params or {})
    return [dict(row) for row in result.mappings().all()]


def one_row(db, sql, params=None):
    """Exécute une requête et renvoie une seule ligne (ou None)."""
    result = db.execute(text(sql), params or {})
    row = result.mappings().one_or_none()
    return dict(row) if row else None


def db_error(exc, message="Erreur de base de données"):
    log.exception(message)
    raise HTTPException(status_code=503, detail=message) from exc


# ------------------------------------------------------------
# Santé de l'API
# ------------------------------------------------------------
@app.get("/")
def accueil():
    return {
        "application": "IoTLab",
        "documentation": "/docs",
        "statut": "fonctionnel",
    }


@app.get("/api/health")
def health():
    return {"statut": "OK", "application": "IoTLab"}


@app.get("/api/db-test")
def db_test(db: Session = Depends(get_db)):
    try:
        return one_row(
            db,
            """
            SELECT current_database()   AS base,
                   current_user         AS utilisateur,
                   inet_server_port()   AS port
            """,
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Connexion PostgreSQL impossible")


# ------------------------------------------------------------
# Tableau de bord
# ------------------------------------------------------------
@app.get("/api/statistiques")
def statistiques(db: Session = Depends(get_db)):
    try:
        return one_row(
            db,
            """
            SELECT
                (SELECT count(*) FROM appareils)     AS total_appareils,
                (SELECT count(*) FROM techniciens)   AS total_techniciens,
                (SELECT count(*) FROM interventions) AS total_interventions,

                (SELECT count(*) FROM interventions
                  WHERE statut = 'en attente')       AS interventions_en_attente,
                (SELECT count(*) FROM interventions
                  WHERE statut = 'en cours')         AS interventions_en_cours,
                (SELECT count(*) FROM interventions
                  WHERE statut = 'terminée')         AS interventions_terminees,

                (SELECT count(*) FROM appareils
                  WHERE etat = 'en panne')           AS appareils_en_panne,
                (SELECT count(*) FROM historique)    AS total_historique
            """,
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Statistiques indisponibles")


# ------------------------------------------------------------
# Appareils et techniciens
# ------------------------------------------------------------
@app.get("/api/appareils")
def appareils(
    recherche: str = Query("", max_length=100),
    etat: str = Query("tous"),
    db: Session = Depends(get_db),
):
    if etat not in ("tous", "fonctionnel", "en panne", "en maintenance"):
        raise HTTPException(422, "Etat invalide")

    try:
        return all_rows(
            db,
            """
            SELECT id_appareil, nom, type_appareil, localisation, etat
            FROM appareils
            WHERE (:etat = 'tous' OR etat = :etat)
              AND (
                    :recherche = ''
                 OR nom           ILIKE :terme
                 OR type_appareil ILIKE :terme
                 OR localisation  ILIKE :terme
              )
            ORDER BY id_appareil
            """,
            {"etat": etat, "recherche": recherche, "terme": f"%{recherche}%"},
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Lecture des appareils impossible")


@app.get("/api/techniciens")
def techniciens(
    recherche: str = Query("", max_length=100),
    db: Session = Depends(get_db),
):
    try:
        return all_rows(
            db,
            """
            SELECT id_technicien, nom, prenom, specialite
            FROM techniciens
            WHERE :recherche = ''
               OR nom        ILIKE :terme
               OR prenom     ILIKE :terme
               OR specialite ILIKE :terme
            ORDER BY id_technicien
            """,
            {"recherche": recherche, "terme": f"%{recherche}%"},
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Lecture des techniciens impossible")


# ------------------------------------------------------------
# Interventions
# ------------------------------------------------------------
@app.get("/api/interventions")
def interventions(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    statut: str = Query("tous"),
    recherche: str = Query("", max_length=100),
    db: Session = Depends(get_db),
):
    if statut not in ("tous", "en attente", "en cours", "terminée"):
        raise HTTPException(422, "Statut invalide")

    params = {
        "statut": statut,
        "recherche": recherche,
        "terme": f"%{recherche}%",
        "limit": limit,
        "offset": (page - 1) * limit,
    }

    # Partie commune au comptage et à la liste paginée.
    filtre = """
        FROM interventions i
        JOIN appareils   a ON a.id_appareil   = i.id_appareil
        JOIN techniciens t ON t.id_technicien = i.id_technicien
        WHERE (:statut = 'tous' OR i.statut = :statut)
          AND (
                :recherche = ''
             OR a.nom                          ILIKE :terme
             OR i.description_panne            ILIKE :terme
             OR t.nom                          ILIKE :terme
             OR t.prenom                       ILIKE :terme
             OR CAST(i.id_intervention AS TEXT) ILIKE :terme
          )
    """

    try:
        total = db.execute(text("SELECT count(*) " + filtre), params).scalar_one()

        lignes = all_rows(
            db,
            """
            SELECT i.id_intervention,
                   i.id_appareil,
                   i.id_technicien,
                   a.nom                              AS appareil,
                   CONCAT(t.prenom, ' ', t.nom)       AS technicien,
                   i.description_panne,
                   i.date_intervention,
                   i.statut,
                   i.compte_rendu
            """
            + filtre
            + """
            ORDER BY i.id_intervention DESC
            LIMIT :limit OFFSET :offset
            """,
            params,
        )

        return {
            "items": lignes,
            "total": total,
            "page": page,
            "limit": limit,
            "pages": max(1, (total + limit - 1) // limit),
        }
    except SQLAlchemyError as exc:
        db_error(exc, "Lecture des interventions impossible")


@app.get("/api/interventions/{identifiant}")
def intervention_detail(identifiant: int, db: Session = Depends(get_db)):
    try:
        row = one_row(
            db,
            """
            SELECT i.*,
                   a.nom                        AS appareil,
                   CONCAT(t.prenom, ' ', t.nom) AS technicien
            FROM interventions i
            JOIN appareils   a USING (id_appareil)
            JOIN techniciens t USING (id_technicien)
            WHERE i.id_intervention = :id
            """,
            {"id": identifiant},
        )
        if not row:
            raise HTTPException(404, "Intervention introuvable")
        return row
    except SQLAlchemyError as exc:
        db_error(exc, "Lecture de l’intervention impossible")


@app.post("/api/interventions", status_code=201)
def creer_intervention(
    payload: NouvelleIntervention,
    db: Session = Depends(get_db),
):
    try:
        row = one_row(
            db,
            """
            INSERT INTO interventions (
                id_appareil, id_technicien, description_panne,
                date_intervention, statut, compte_rendu
            )
            VALUES (
                :id_appareil, :id_technicien, :description_panne,
                CURRENT_TIMESTAMP, 'en attente', NULL
            )
            RETURNING id_intervention, id_appareil, id_technicien,
                      description_panne, date_intervention,
                      statut, compte_rendu
            """,
            payload.model_dump(),
        )
        db.commit()
        return row
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            400,
            "Appareil ou technicien inexistant, ou données invalides",
        ) from exc
    except SQLAlchemyError as exc:
        db.rollback()
        db_error(exc, "Création impossible")


@app.patch("/api/interventions/{identifiant}/statut")
def changer_statut(
    identifiant: int,
    payload: ChangementStatut,
    db: Session = Depends(get_db),
):
    if identifiant < 1:
        raise HTTPException(400, "Identifiant invalide")

    try:
        # Les transitions autorisées sont contrôlées dans la requête elle-même :
        # pas de délai entre la lecture du statut et sa modification.
        row = one_row(
            db,
            """
            UPDATE interventions
            SET statut = :statut,
                compte_rendu = CASE
                    WHEN :statut = 'terminée' THEN :rapport
                    ELSE compte_rendu
                END
            WHERE id_intervention = :id
              AND (
                    (statut = 'en attente' AND :statut = 'en cours')
                 OR (statut = 'en cours'   AND :statut = 'terminée')
              )
            RETURNING id_intervention, statut, compte_rendu
            """,
            {
                "id": identifiant,
                "statut": payload.statut,
                "rapport": payload.compte_rendu,
            },
        )

        if row is None:
            db.rollback()
            raise HTTPException(
                409,
                "Intervention introuvable ou transition interdite "
                "(en attente → en cours → terminée)",
            )

        # Les changements faits depuis l'application sont tracés ici,
        # dans la même transaction que la mise à jour du statut.
        precedent = "en attente" if payload.statut == "en cours" else "en cours"
        commentaire = (
            payload.compte_rendu
            if payload.statut == "terminée"
            else "Démarrage depuis l’application IoTLab"
        )

        db.execute(
            text("""
                INSERT INTO historique (
                    id_intervention, ancien_statut, nouveau_statut, commentaire
                )
                VALUES (:id, :ancien, :nouveau, :commentaire)
                """),
            {
                "id": identifiant,
                "ancien": precedent,
                "nouveau": payload.statut,
                "commentaire": commentaire,
            },
        )

        db.commit()
        return row

    except HTTPException:
        raise
    except DBAPIError as exc:
        db.rollback()
        # P0001 = RAISE EXCEPTION lancé par le trigger de clôture.
        if getattr(exc.orig, "sqlstate", None) == "P0001":
            raise HTTPException(
                400,
                "Le trigger PostgreSQL interdit la clôture sans compte rendu",
            ) from exc
        db_error(exc, "Modification impossible")
    except SQLAlchemyError as exc:
        db.rollback()
        db_error(exc, "Modification impossible")


# ------------------------------------------------------------
# Historique
# ------------------------------------------------------------
@app.get("/api/historique")
def historique(
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    try:
        return all_rows(
            db,
            """
            SELECT id_historique, id_intervention, ancien_statut,
                   nouveau_statut, date_changement, commentaire
            FROM historique
            ORDER BY id_historique DESC
            LIMIT :limit
            """,
            {"limit": limit},
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Historique indisponible")


@app.get("/api/historique/{identifiant}")
def historique_intervention(identifiant: int, db: Session = Depends(get_db)):
    try:
        return all_rows(
            db,
            """
            SELECT *
            FROM historique
            WHERE id_intervention = :id
            ORDER BY date_changement DESC
            """,
            {"id": identifiant},
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Historique indisponible")


# ------------------------------------------------------------
# Fonction SQL et vues
# ------------------------------------------------------------
@app.get("/api/fonction/{id_appareil}")
def fonction_sql(id_appareil: int, db: Session = Depends(get_db)):
    try:
        appareil = one_row(
            db,
            "SELECT id_appareil FROM appareils WHERE id_appareil = :id",
            {"id": id_appareil},
        )
        if not appareil:
            raise HTTPException(404, "Appareil introuvable")

        nombre = db.execute(
            text("SELECT nombre_interventions_appareil(:id)"),
            {"id": id_appareil},
        ).scalar_one()

        return {"id_appareil": id_appareil, "nombre_interventions": nombre}
    except SQLAlchemyError as exc:
        db_error(exc, "Fonction SQL indisponible")


@app.get("/api/vues/technicien")
def vue_technicien(
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    try:
        return all_rows(
            db,
            """
            SELECT *
            FROM vue_technicien
            ORDER BY id_intervention DESC
            LIMIT :limit
            """,
            {"limit": limit},
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Vue technicien indisponible")


@app.get("/api/vues/superviseur")
def vue_superviseur(db: Session = Depends(get_db)):
    try:
        return all_rows(
            db,
            """
            SELECT *
            FROM vue_superviseur
            ORDER BY total_interventions DESC, id_appareil
            """,
        )
    except SQLAlchemyError as exc:
        db_error(exc, "Vue superviseur indisponible")


# ------------------------------------------------------------
# Administration : diagnostic et plans d'exécution
# ------------------------------------------------------------
@app.get("/api/sql/diagnostic")
def diagnostic_sql(db: Session = Depends(get_db)):
    """Diagnostic en lecture seule : rôles, index, trigger, vues, routines.

    pg_catalog liste les objets réellement présents dans le schéma public,
    même quand information_schema masque des vues pour des raisons de droits.
    """
    try:
        roles = all_rows(
            db,
            """
            SELECT rolname AS nom, rolcanlogin AS connexion
            FROM pg_catalog.pg_roles
            WHERE rolname IN (
                'role_technicien', 'role_superviseur',
                'user_technicien', 'user_superviseur'
            )
            ORDER BY rolname
            """,
        )

        index = all_rows(
            db,
            """
            SELECT indexname AS nom, tablename AS table, indexdef AS definition
            FROM pg_catalog.pg_indexes
            WHERE schemaname = 'public'
              AND indexname IN (
                  'idx_interventions_appareil', 'idx_interventions_date'
              )
            ORDER BY indexname
            """,
        )

        trigger = all_rows(
            db,
            """
            SELECT t.tgname AS nom, pg_get_triggerdef(t.oid) AS definition
            FROM pg_catalog.pg_trigger t
            JOIN pg_catalog.pg_class     c ON c.oid = t.tgrelid
            JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relname = 'interventions'
              AND t.tgname  = 'trg_verifier_cloture'
              AND NOT t.tgisinternal
            """,
        )

        vues = all_rows(
            db,
            """
            SELECT c.relname AS nom
            FROM pg_catalog.pg_class     c
            JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relkind = 'v'
              AND c.relname IN ('vue_technicien', 'vue_superviseur')
            ORDER BY c.relname
            """,
        )

        fonctions = all_rows(
            db,
            """
            SELECT DISTINCT p.proname AS nom
            FROM pg_catalog.pg_proc      p
            JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.proname IN (
                  'nombre_interventions_appareil',
                  'verifier_cloture_intervention',
                  'cloturer_intervention'
              )
            ORDER BY p.proname
            """,
        )

        return {
            "roles": roles,
            "indexes": index,
            "triggers": trigger,
            "vues": vues,
            "fonctions": fonctions,
        }
    except SQLAlchemyError as exc:
        db_error(exc, "Diagnostic SQL indisponible")


@app.get("/api/sql/index-performance")
def performance_index(
    id_appareil: int = Query(5, ge=1),
    date_debut: date = Query(date(2026, 3, 1)),
    date_fin: date = Query(date(2026, 3, 7)),
    db: Session = Depends(get_db),
):
    """EXPLAIN ANALYZE sur un appareil et une période choisis.

    Pas de DROP/CREATE d'index ici : la comparaison avant/après se fait
    sur une base de validation avec tests/tests_index.sql.
    """
    if date_fin < date_debut:
        raise HTTPException(
            422,
            "La date de fin doit être supérieure ou égale à la date de début.",
        )
    if (date_fin - date_debut).days > 3660:
        raise HTTPException(
            422,
            "La période sélectionnée ne doit pas dépasser 10 ans.",
        )

    try:
        appareil = one_row(
            db,
            "SELECT id_appareil FROM appareils WHERE id_appareil = :id",
            {"id": id_appareil},
        )
        if not appareil:
            raise HTTPException(404, "Appareil introuvable")

        fin_exclusive = date_fin + timedelta(days=1)

        requetes = {
            "idx_interventions_appareil": (
                "SELECT * FROM interventions WHERE id_appareil = :id_appareil",
                {"id_appareil": id_appareil},
            ),
            "idx_interventions_date": (
                "SELECT * FROM interventions "
                "WHERE date_intervention >= :date_debut "
                "AND date_intervention < :date_fin",
                {"date_debut": date_debut, "date_fin": fin_exclusive},
            ),
        }

        plans = {}
        for nom, (requete, params) in requetes.items():
            lignes = db.execute(
                text("EXPLAIN (ANALYZE, BUFFERS) " + requete),
                params,
            ).all()
            plans[nom] = [ligne[0] for ligne in lignes]

        return {
            "plans": plans,
            "criteres": {
                "id_appareil": id_appareil,
                "date_debut": date_debut.isoformat(),
                "date_fin": date_fin.isoformat(),
            },
            "note": (
                "Plans réels calculés avec vos critères. PostgreSQL peut "
                "choisir un Seq Scan même si un index existe. Les comparaisons "
                "avant/après sont dans tests/tests_index.sql."
            ),
        }
    except HTTPException:
        raise
    except SQLAlchemyError as exc:
        db_error(exc, "Plans SQL indisponibles")
