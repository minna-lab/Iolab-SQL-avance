import { useCallback, useEffect, useState } from 'react';
import {
  Activity,
  ArrowDownRight,
  ArrowRight,
  ArrowUpRight,
  BarChart3,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  ClipboardCheck,
  Clock3,
  Cpu,
  Database,
  FileCode2,
  Filter,
  Gauge,
  HardDrive,
  History,
  LayoutDashboard,
  ListChecks,
  LoaderCircle,
  Menu,
  Plus,
  RefreshCw,
  Search,
  Server,
  Settings2,
  ShieldCheck,
  Sparkles,
  Users,
  Wrench,
  X,
} from 'lucide-react';
import { api } from './services/api';
import './App.css';

// Entrées du menu latéral
const navigation = [
  { id: 'dashboard', nom: 'Tableau de bord', icon: LayoutDashboard },
  { id: 'interventions', nom: 'Interventions', icon: Wrench },
  { id: 'appareils', nom: 'Appareils', icon: Cpu },
  { id: 'techniciens', nom: 'Techniciens', icon: Users },
  { id: 'historique', nom: 'Historique', icon: History },
  { id: 'sql', nom: 'Administration', icon: Database },
];

const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');

const date = (value) =>
  value
    ? new Date(value).toLocaleString('fr-FR', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '—';

function Status({ statut }) {
  const key =
    statut === 'terminée'
      ? 'done'
      : statut === 'en cours'
        ? 'progress'
        : statut === 'en attente'
          ? 'pending'
          : statut === 'fonctionnel'
            ? 'done'
            : statut === 'en panne'
              ? 'danger'
              : 'progress';

  return (
    <span className={`status status-${key}`}>
      <span className="status-dot" />
      {statut}
    </span>
  );
}

function Spinner() {
  return <LoaderCircle size={18} className="spin" />;
}

function Empty({ text = 'Aucun résultat pour les filtres sélectionnés.' }) {
  return (
    <div className="empty">
      <Search size={24} />
      <p>{text}</p>
    </div>
  );
}

function Modal({ title, subtitle, onClose, children }) {
  return (
    <div
      className="modal-backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="modal" role="dialog" aria-modal="true" aria-label={title}>
        <div className="modal-top">
          <div>
            <h2>{title}</h2>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <button className="icon-button" onClick={onClose} aria-label="Fermer">
            <X size={19} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function Card({ icon: Icon, label, value, meta, accent = 'blue' }) {
  return (
    <div className={`kpi kpi-${accent}`}>
      <div className="kpi-top">
        <span>{label}</span>
        <span className="kpi-icon">
          <Icon size={19} />
        </span>
      </div>
      <strong>{fmt(value)}</strong>
      <p>{meta}</p>
    </div>
  );
}

function PageHeader({ eyebrow, title, description, actions }) {
  return (
    <div className="page-header">
      <div>
        <div className="eyebrow">{eyebrow}</div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      <div className="page-actions">{actions}</div>
    </div>
  );
}

// ------------------------------------------------------------
// Application : état, chargement des données, actions, affichage
// ------------------------------------------------------------
export default function App() {
  // ----- État de l'interface -----
  const [page, setPage] = useState('dashboard');
  const [menu, setMenu] = useState(false);
  const [stats, setStats] = useState(null);
  const [appareils, setAppareils] = useState([]);
  const [techniciens, setTechniciens] = useState([]);
  const [liste, setListe] = useState({
    items: [],
    total: 0,
    page: 1,
    pages: 1,
  });
  const [historique, setHistorique] = useState([]);
  const [diagnostic, setDiagnostic] = useState(null);
  const [vueSuperviseur, setVueSuperviseur] = useState([]);
  const [vueTechnicien, setVueTechnicien] = useState([]);
  const [indexPlans, setIndexPlans] = useState(null);
  const [indexAppareil, setIndexAppareil] = useState('5');
  const [indexDebut, setIndexDebut] = useState('2026-03-01');
  const [indexFin, setIndexFin] = useState('2026-03-07');
  const [plansLoading, setPlansLoading] = useState(false);
  const [sqlLoading, setSqlLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [fonctionId, setFonctionId] = useState('1');
  const [fonctionResultat, setFonctionResultat] = useState(null);
  const [comptagesAppareils, setComptagesAppareils] = useState({});
  const [comptageEnCours, setComptageEnCours] = useState(null);
  const [erreursComptage, setErreursComptage] = useState({});
  const [filtreRecherche, setFiltreRecherche] = useState('');
  const [filtreStatut, setFiltreStatut] = useState('tous');
  const [numeroPage, setNumeroPage] = useState(1);
  const [rechercheAppareil, setRechercheAppareil] = useState('');
  const [etatAppareil, setEtatAppareil] = useState('tous');
  const [rechercheTech, setRechercheTech] = useState('');
  const [modalCreation, setModalCreation] = useState(false);
  const [modalCloture, setModalCloture] = useState(null);
  const [modalHistorique, setModalHistorique] = useState(null);
  const [historiqueDetail, setHistoriqueDetail] = useState([]);
  const [form, setForm] = useState({
    id_appareil: '',
    id_technicien: '',
    description_panne: '',
  });
  const [rapport, setRapport] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [listLoading, setListLoading] = useState(false);
  const [error, setError] = useState('');
  const [toast, setToast] = useState('');

  // ----- Chargement des données depuis l'API -----
  const notify = (msg) => {
    setToast(msg);
    setError('');
  };

  const chargerGlobal = useCallback(async () => {
    const [s, a, t] = await Promise.all([
      api.stats(),
      api.appareils(),
      api.techniciens(),
    ]);
    setStats(s);
    setAppareils(a);
    setTechniciens(t);
  }, []);

  const chargerListe = useCallback(async () => {
    setListLoading(true);
    try {
      const r = await api.interventions({
        page: numeroPage,
        limit: 15,
        statut: filtreStatut,
        recherche: filtreRecherche,
      });
      setListe(r);
    } catch (e) {
      setError(e.message);
    } finally {
      setListLoading(false);
    }
  }, [numeroPage, filtreStatut, filtreRecherche]);

  const chargerSQL = useCallback(async () => {
    setSqlLoading(true);
    try {
      // Un diagnostic peut être visible même si une vue de données échoue.
      const d = await api.diagnostic();
      setDiagnostic(d);
      const [v, t] = await Promise.allSettled([
        api.vueSuperviseur(),
        api.vueTechnicien(),
      ]);
      if (v.status === 'fulfilled') setVueSuperviseur(v.value);
      if (t.status === 'fulfilled') setVueTechnicien(t.value);
      const erreurs = [v, t]
        .filter((x) => x.status === 'rejected')
        .map((x) => x.reason?.message || 'Vue indisponible');
      if (erreurs.length) throw new Error(erreurs.join(' • '));
      return d;
    } finally {
      setSqlLoading(false);
    }
  }, []);

  useEffect(() => {
    let live = true;
    (async () => {
      try {
        await chargerGlobal();
        if (live) setError('');
      } catch (e) {
        if (live) setError(e.message);
      } finally {
        if (live) setLoading(false);
      }
    })();
    return () => {
      live = false;
    };
  }, [chargerGlobal]);

  useEffect(() => {
    chargerListe();
  }, [chargerListe]);

  useEffect(() => {
    if (page === 'historique')
      api
        .historique()
        .then(setHistorique)
        .catch((e) => setError(e.message));
    if (page === 'sql') chargerSQL().catch((e) => setError(e.message));
  }, [page, chargerSQL]);

  // ----- Actions de l'utilisateur -----
  async function refresh() {
    if (refreshing) return;
    setRefreshing(true);
    setError('');
    setToast('');
    try {
      // On attend le résultat de toutes les requêtes réellement nécessaires
      // avant d'afficher la confirmation d'actualisation.
      const taches = [chargerGlobal(), chargerListe()];
      if (page === 'historique')
        taches.push(api.historique().then(setHistorique));
      if (page === 'sql') taches.push(chargerSQL());
      const resultats = await Promise.allSettled(taches);
      const echecs = resultats.filter((r) => r.status === 'rejected');
      if (echecs.length) {
        setError(
          echecs
            .map((r) => r.reason?.message || 'Actualisation impossible')
            .join(' • '),
        );
      } else {
        setComptagesAppareils({});
        setErreursComptage({});
        setIndexPlans(null);
        setFonctionResultat(null);
        notify('Données actualisées depuis PostgreSQL.');
      }
    } finally {
      setRefreshing(false);
    }
  }

  async function creer(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      const newRow = await api.creer({
        id_appareil: Number(form.id_appareil),
        id_technicien: Number(form.id_technicien),
        description_panne: form.description_panne.trim(),
      });
      setModalCreation(false);
      setForm({ id_appareil: '', id_technicien: '', description_panne: '' });
      setFiltreRecherche('');
      setFiltreStatut('tous');
      setNumeroPage(1);
      await Promise.all([
        chargerGlobal(),
        api
          .interventions({ page: 1, limit: 15, statut: 'tous', recherche: '' })
          .then(setListe),
      ]);
      notify(`Intervention #${newRow.id_intervention} créée avec succès.`);
      setPage('interventions');
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function updateStatut(id, statut, compte_rendu = null) {
    setBusy(true);
    setError('');
    try {
      await api.statut(id, { statut, compte_rendu });
      setModalCloture(null);
      setRapport('');
      await Promise.all([chargerGlobal(), chargerListe()]);
      if (page === 'historique') setHistorique(await api.historique());
      notify(`Intervention #${id} : statut « ${statut} » enregistré.`);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function voirHistorique(id) {
    setError('');
    try {
      const data = await api.historiqueIntervention(id);
      setHistoriqueDetail(data);
      setModalHistorique(id);
    } catch (e) {
      setError(e.message);
    }
  }

  async function executerFonction() {
    try {
      setFonctionResultat(await api.fonction(Number(fonctionId)));
      setError('');
    } catch (e) {
      setError(e.message);
    }
  }

  async function compterInterventionsAppareil(appareil) {
    const id = appareil.id_appareil;
    setComptageEnCours(id);
    setErreursComptage((previous) => ({ ...previous, [id]: '' }));
    try {
      // Appel réel de la fonction stockée nombre_interventions_appareil(id).
      const resultat = await api.fonction(id);
      if (
        resultat?.nombre_interventions === undefined ||
        resultat?.nombre_interventions === null
      ) {
        throw new Error(
          'La réponse de la fonction SQL ne contient pas de résultat.',
        );
      }
      setComptagesAppareils((previous) => ({
        ...previous,
        [id]: Number(resultat.nombre_interventions),
      }));
    } catch (e) {
      setErreursComptage((previous) => ({
        ...previous,
        [id]: e.message || 'Calcul indisponible.',
      }));
    } finally {
      setComptageEnCours(null);
    }
  }

  async function executerPlans() {
    setPlansLoading(true);
    setError('');
    setIndexPlans(null);
    try {
      if (!indexAppareil) throw new Error('Sélectionnez un appareil.');
      if (!indexDebut || !indexFin) throw new Error('Sélectionnez deux dates.');
      if (indexFin < indexDebut)
        throw new Error(
          'La date de fin doit être postérieure à la date de début.',
        );
      const resultat = await api.indexPlan({
        id_appareil: Number(indexAppareil),
        date_debut: indexDebut,
        date_fin: indexFin,
      });
      setIndexPlans(resultat);
      notify('Plans EXPLAIN ANALYZE recalculés avec vos critères.');
    } catch (e) {
      setError(e.message);
    } finally {
      setPlansLoading(false);
    }
  }

  // ----- Filtres locaux (appareils, techniciens) -----
  const filtreAppareils = appareils.filter(
    (a) =>
      (etatAppareil === 'tous' || a.etat === etatAppareil) &&
      [a.nom, a.type_appareil, a.localisation]
        .join(' ')
        .toLowerCase()
        .includes(rechercheAppareil.toLowerCase()),
  );

  const filtreTechs = techniciens.filter((t) =>
    [t.nom, t.prenom, t.specialite]
      .join(' ')
      .toLowerCase()
      .includes(rechercheTech.toLowerCase()),
  );

  const currentNav = navigation.find((n) => n.id === page);

  // ----- Affichage -----
  return (
    <div className="shell">
      <aside className={`sidebar ${menu ? 'show' : ''}`}>
        <button
          className="brand"
          onClick={() => {
            setPage('dashboard');
            setMenu(false);
          }}
        >
          <span className="brand-mark">
            <Activity size={25} />
          </span>
          <span>
            <strong>IoTLab</strong>
            <small>MAINTENANCE HUB</small>
          </span>
        </button>
        <div className="side-label">ESPACE DE TRAVAIL</div>
        <nav className="nav">
          {navigation.map(({ id, nom, icon: Icon }) => (
            <button
              key={id}
              className={`nav-link ${id === page ? 'active' : ''}`}
              onClick={() => {
                setPage(id);
                setMenu(false);
                setToast('');
                setError('');
              }}
            >
              <Icon size={19} />
              <span>{nom}</span>
              {id === page && <span className="nav-active-dot" />}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="sidebar-system">
            <span className="online-dot" /> Système local{' '}
            <span className="system-badge">DEV</span>
          </div>
          <div className="sidebar-user">
            <span className="avatar">IL</span>
            <div>
              <strong>IoTLab</strong>
              <small>Projet SQL avancé</small>
            </div>
          </div>
        </div>
      </aside>
      {menu && (
        <button
          aria-label="Fermer le menu"
          className="mobile-shade"
          onClick={() => setMenu(false)}
        />
      )}
      <div className="workspace">
        <header className="topbar">
          <div className="topbar-left">
            <button
              className="icon-button mobile-menu"
              onClick={() => setMenu(!menu)}
              aria-label="Menu"
            >
              <Menu size={21} />
            </button>
            <span className="breadcrumb">Espace de travail</span>
            <ChevronRight size={14} className="breadcrumb-sep" />
            <strong>{currentNav?.nom}</strong>
          </div>
          <div className="topbar-right">
            <span className="live-label">
              <span className="online-dot" /> API connectée
            </span>
            <button
              className="icon-button"
              title="Actualiser les données PostgreSQL"
              aria-label="Actualiser les données"
              disabled={refreshing}
              onClick={refresh}
            >
              <RefreshCw size={19} className={refreshing ? 'spin' : ''} />
            </button>
            <span className="avatar avatar-top">IL</span>
          </div>
        </header>
        <div className="main">
          {toast && (
            <div className="alert success">
              <CheckCircle2 size={18} />
              <span>{toast}</span>
              <button onClick={() => setToast('')} aria-label="Masquer">
                <X size={16} />
              </button>
            </div>
          )}
          {error && (
            <div className="alert fail">
              <CircleAlert size={18} />
              <span>{error}</span>
              <button onClick={() => setError('')} aria-label="Masquer">
                <X size={16} />
              </button>
            </div>
          )}

          {page === 'dashboard' && (
            <>
              <PageHeader
                eyebrow="VUE D'ENSEMBLE"
                title="Tableau de bord"
                description="Une vision claire de l'activité de maintenance de votre laboratoire."
                actions={
                  <button
                    className="button primary"
                    onClick={() => setModalCreation(true)}
                  >
                    <Plus size={17} /> Nouvelle intervention
                  </button>
                }
              />
              <div className="hero">
                <div>
                  <span className="hero-tag">
                    <Sparkles size={13} /> PILOTAGE EN TEMPS RÉEL
                  </span>
                  <h2>
                    Gardez le contrôle sur
                    <br />
                    votre maintenance.
                  </h2>
                  <p>
                    Suivez les équipements, les équipes et les interventions à
                    partir de votre base PostgreSQL.
                  </p>
                  <button onClick={() => setPage('interventions')}>
                    Voir les interventions <ArrowRight size={16} />
                  </button>
                </div>
                <div className="hero-visual">
                  <div className="hero-circle">
                    <Activity size={80} strokeWidth={1} />
                  </div>
                  <div className="float-badge">
                    <CheckCircle2 size={16} /> Données en direct
                  </div>
                </div>
              </div>
              <div className="kpi-grid">
                <Card
                  icon={Cpu}
                  label="Appareils"
                  value={stats?.total_appareils}
                  meta="Équipements référencés"
                  accent="blue"
                />
                <Card
                  icon={Users}
                  label="Techniciens"
                  value={stats?.total_techniciens}
                  meta="Collaborateurs actifs"
                  accent="purple"
                />
                <Card
                  icon={Wrench}
                  label="Interventions"
                  value={stats?.total_interventions}
                  meta="Total enregistré"
                  accent="orange"
                />
                <Card
                  icon={Clock3}
                  label="En cours"
                  value={stats?.interventions_en_cours}
                  meta="Interventions actives"
                  accent="teal"
                />
              </div>
              <div className="dashboard-grid">
                <section className="panel">
                  <div className="panel-heading">
                    <div>
                      <h3>Répartition des interventions</h3>
                      <p>État global des opérations</p>
                    </div>
                    <ListChecks size={19} className="muted-icon" />
                  </div>
                  <div className="stacked-bar">
                    <span
                      style={{
                        width: `${(100 * (stats?.interventions_en_attente || 0)) / Math.max(1, stats?.total_interventions || 1)}%`,
                        background: '#f59e0b',
                      }}
                    />
                    <span
                      style={{
                        width: `${(100 * (stats?.interventions_en_cours || 0)) / Math.max(1, stats?.total_interventions || 1)}%`,
                        background: '#3b82f6',
                      }}
                    />
                    <span
                      style={{
                        width: `${(100 * (stats?.interventions_terminees || 0)) / Math.max(1, stats?.total_interventions || 1)}%`,
                        background: '#10b981',
                      }}
                    />
                  </div>
                  {[
                    ['En attente', stats?.interventions_en_attente, '#f59e0b'],
                    ['En cours', stats?.interventions_en_cours, '#3b82f6'],
                    ['Terminées', stats?.interventions_terminees, '#10b981'],
                  ].map(([name, n, color]) => (
                    <div className="legend-row" key={name}>
                      <span>
                        <i style={{ background: color }} />
                        {name}
                      </span>
                      <strong>{fmt(n)}</strong>
                    </div>
                  ))}
                </section>
                <section className="panel">
                  <div className="panel-heading">
                    <div>
                      <h3>Indicateurs du laboratoire</h3>
                      <p>Équipements et traçabilité</p>
                    </div>
                    <Gauge size={19} className="muted-icon" />
                  </div>
                  <div className="indicator">
                    <span>
                      <CircleAlert size={18} /> Équipements en panne
                    </span>
                    <strong>{fmt(stats?.appareils_en_panne)}</strong>
                  </div>
                  <div className="indicator">
                    <span>
                      <History size={18} /> Entrées d'historique
                    </span>
                    <strong>{fmt(stats?.total_historique)}</strong>
                  </div>
                  <div className="indicator">
                    <span>
                      <CheckCircle2 size={18} /> Interventions terminées
                    </span>
                    <strong>{fmt(stats?.interventions_terminees)}</strong>
                  </div>
                  <button
                    className="text-action"
                    onClick={() => setPage('sql')}
                  >
                    Explorer les fonctionnalités SQL <ArrowRight size={16} />
                  </button>
                </section>
              </div>
            </>
          )}

          {page === 'interventions' && (
            <>
              <PageHeader
                eyebrow="OPÉRATIONS"
                title="Interventions"
                description="Créez, recherchez et faites évoluer les demandes de maintenance."
                actions={
                  <button
                    className="button primary"
                    onClick={() => setModalCreation(true)}
                  >
                    <Plus size={17} /> Nouvelle intervention
                  </button>
                }
              />
              <section className="panel panel-table">
                <div className="list-tools">
                  <div className="search-box">
                    <Search size={17} />
                    <input
                      placeholder="ID, panne, appareil ou technicien..."
                      value={filtreRecherche}
                      onChange={(e) => {
                        setFiltreRecherche(e.target.value);
                        setNumeroPage(1);
                      }}
                    />
                  </div>
                  <div className="select-wrap">
                    <Filter size={16} />
                    <select
                      value={filtreStatut}
                      onChange={(e) => {
                        setFiltreStatut(e.target.value);
                        setNumeroPage(1);
                      }}
                    >
                      <option value="tous">Tous les statuts</option>
                      <option value="en attente">En attente</option>
                      <option value="en cours">En cours</option>
                      <option value="terminée">Terminée</option>
                    </select>
                  </div>
                </div>
                <div className="panel-caption">
                  <strong>{fmt(liste.total)} interventions</strong>
                  <span>Recherche sur toute la base · 15 par page</span>
                  {listLoading && <Spinner />}
                </div>
                <div className="table-scroller">
                  <table>
                    <thead>
                      <tr>
                        <th>INTERVENTION</th>
                        <th>APPAREIL / PANNE</th>
                        <th>TECHNICIEN</th>
                        <th>DATE</th>
                        <th>STATUT</th>
                        <th>ACTIONS</th>
                      </tr>
                    </thead>
                    <tbody>
                      {liste.items.map((i) => (
                        <tr key={i.id_intervention}>
                          <td>
                            <strong className="id-text">
                              #{i.id_intervention}
                            </strong>
                          </td>
                          <td>
                            <div className="cell-main">{i.appareil}</div>
                            <div className="cell-sub truncate">
                              {i.description_panne}
                            </div>
                          </td>
                          <td>{i.technicien}</td>
                          <td className="cell-date">
                            {date(i.date_intervention)}
                          </td>
                          <td>
                            <Status statut={i.statut} />
                          </td>
                          <td>
                            <div className="action-cell">
                              {i.statut === 'en attente' && (
                                <button
                                  className="action-link"
                                  disabled={busy}
                                  onClick={() =>
                                    updateStatut(i.id_intervention, 'en cours')
                                  }
                                >
                                  <ArrowRight size={15} /> Démarrer
                                </button>
                              )}
                              {i.statut === 'en cours' && (
                                <button
                                  className="action-link"
                                  disabled={busy}
                                  onClick={() => {
                                    setModalCloture(i);
                                    setRapport('');
                                    setError('');
                                  }}
                                >
                                  <ClipboardCheck size={15} /> Clôturer
                                </button>
                              )}
                              {i.statut === 'terminée' && (
                                <span className="cell-sub">Clôturée</span>
                              )}
                              <button
                                title="Historique"
                                className="icon-button small"
                                onClick={() =>
                                  voirHistorique(i.id_intervention)
                                }
                              >
                                <History size={17} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {liste.items.length === 0 && <Empty />}
                </div>
                <div className="pagination">
                  <span>
                    Page {liste.page} sur {liste.pages}
                  </span>
                  <div>
                    <button
                      disabled={numeroPage <= 1 || listLoading}
                      onClick={() => setNumeroPage((p) => p - 1)}
                    >
                      <ChevronLeft size={17} /> Précédent
                    </button>
                    <button
                      disabled={numeroPage >= liste.pages || listLoading}
                      onClick={() => setNumeroPage((p) => p + 1)}
                    >
                      Suivant <ChevronRight size={17} />
                    </button>
                  </div>
                </div>
              </section>
            </>
          )}

          {page === 'appareils' && (
            <>
              <PageHeader
                eyebrow="PARC MATÉRIEL"
                title="Appareils"
                description="Consultez les équipements, leurs emplacements et leur état."
              />
              <section className="panel panel-table">
                <div className="list-tools">
                  <div className="search-box">
                    <Search size={17} />
                    <input
                      placeholder="Nom, type ou localisation..."
                      value={rechercheAppareil}
                      onChange={(e) => setRechercheAppareil(e.target.value)}
                    />
                  </div>
                  <div className="select-wrap">
                    <Filter size={16} />
                    <select
                      value={etatAppareil}
                      onChange={(e) => setEtatAppareil(e.target.value)}
                    >
                      <option value="tous">Tous les états</option>
                      <option value="fonctionnel">Fonctionnel</option>
                      <option value="en panne">En panne</option>
                      <option value="en maintenance">En maintenance</option>
                    </select>
                  </div>
                </div>
                <div className="panel-caption">
                  <strong>{filtreAppareils.length} appareils</strong>
                  <span>Inventaire PostgreSQL</span>
                </div>
                <div className="table-scroller">
                  <table>
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>APPAREIL</th>
                        <th>TYPE</th>
                        <th>LOCALISATION</th>
                        <th>ÉTAT</th>
                        <th>INTERVENTIONS</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filtreAppareils.map((a) => (
                        <tr key={a.id_appareil}>
                          <td>
                            <strong className="id-text">
                              #{a.id_appareil}
                            </strong>
                          </td>
                          <td>
                            <div className="device-cell">
                              <span className="device-icon">
                                <Cpu size={18} />
                              </span>
                              <strong>{a.nom}</strong>
                            </div>
                          </td>
                          <td>{a.type_appareil}</td>
                          <td>{a.localisation}</td>
                          <td>
                            <Status statut={a.etat} />
                          </td>
                          <td>
                            <div
                              style={{
                                display: 'flex',
                                flexDirection: 'column',
                                alignItems: 'flex-start',
                                gap: 5,
                              }}
                            >
                              {comptagesAppareils[a.id_appareil] !==
                                undefined && (
                                <strong aria-live="polite">
                                  {fmt(comptagesAppareils[a.id_appareil])}{' '}
                                  interventions
                                </strong>
                              )}
                              <button
                                type="button"
                                className="action-link"
                                disabled={comptageEnCours !== null}
                                onClick={() => compterInterventionsAppareil(a)}
                              >
                                {comptageEnCours === a.id_appareil
                                  ? 'Calcul en cours…'
                                  : comptagesAppareils[a.id_appareil] !==
                                      undefined
                                    ? 'Recompter'
                                    : 'Compter'}{' '}
                                <ArrowRight size={14} />
                              </button>
                              {erreursComptage[a.id_appareil] && (
                                <span
                                  role="alert"
                                  style={{
                                    color: '#b91c1c',
                                    fontSize: 12,
                                    maxWidth: 220,
                                  }}
                                >
                                  {erreursComptage[a.id_appareil]}
                                </span>
                              )}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filtreAppareils.length === 0 && <Empty />}
                </div>
              </section>
            </>
          )}

          {page === 'techniciens' && (
            <>
              <PageHeader
                eyebrow="ÉQUIPES"
                title="Techniciens"
                description="Les spécialistes mobilisés pour vos interventions."
              />
              <section className="panel panel-table">
                <div className="list-tools">
                  <div className="search-box">
                    <Search size={17} />
                    <input
                      placeholder="Rechercher un nom ou une spécialité..."
                      value={rechercheTech}
                      onChange={(e) => setRechercheTech(e.target.value)}
                    />
                  </div>
                </div>
                <div className="panel-caption">
                  <strong>{filtreTechs.length} techniciens</strong>
                  <span>Équipe de maintenance</span>
                </div>
                <div className="table-scroller">
                  <table>
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>TECHNICIEN</th>
                        <th>SPÉCIALITÉ</th>
                        <th>STATUT</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filtreTechs.map((t) => (
                        <tr key={t.id_technicien}>
                          <td>
                            <strong className="id-text">
                              #{t.id_technicien}
                            </strong>
                          </td>
                          <td>
                            <div className="person-cell">
                              <span className="person-initials">
                                {t.prenom?.[0]}
                                {t.nom?.[0]}
                              </span>
                              <strong>
                                {t.prenom} {t.nom}
                              </strong>
                            </div>
                          </td>
                          <td>{t.specialite}</td>
                          <td>
                            <span className="mini-active">
                              <span className="online-dot" /> Référencé
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filtreTechs.length === 0 && <Empty />}
                </div>
              </section>
            </>
          )}

          {page === 'historique' && (
            <>
              <PageHeader
                eyebrow="TRAÇABILITÉ"
                title="Historique"
                description="Suivez les changements d'état et les comptes rendus des interventions."
                actions={
                  <button
                    className="button ghost"
                    onClick={refresh}
                    disabled={refreshing}
                  >
                    <RefreshCw size={16} /> Actualiser
                  </button>
                }
              />
              <section className="panel panel-table">
                <div className="panel-caption">
                  <strong>100 changements les plus récents</strong>
                  <span>Table historique de PostgreSQL</span>
                </div>
                <div className="table-scroller">
                  <table>
                    <thead>
                      <tr>
                        <th>ÉVÉNEMENT</th>
                        <th>INTERVENTION</th>
                        <th>CHANGEMENT</th>
                        <th>DATE</th>
                        <th>COMMENTAIRE</th>
                      </tr>
                    </thead>
                    <tbody>
                      {historique.map((h) => (
                        <tr key={h.id_historique}>
                          <td className="id-text">#{h.id_historique}</td>
                          <td>
                            <strong>#{h.id_intervention}</strong>
                          </td>
                          <td>
                            <div className="change">
                              <Status statut={h.ancien_statut} />
                              <ArrowRight size={15} />
                              <Status statut={h.nouveau_statut} />
                            </div>
                          </td>
                          <td>{date(h.date_changement)}</td>
                          <td className="truncate">{h.commentaire || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {historique.length === 0 && (
                    <Empty text="Pas encore de changement dans l'historique." />
                  )}
                </div>
              </section>
              <div className="info-note">
                <CircleAlert size={17} /> Les transitions réalisées depuis
                l'application sont enregistrées dans cette table. Les
                modifications SQL directes ne sont pas automatiquement
                historisées par le trigger de clôture.
              </div>
            </>
          )}

          {page === 'sql' && (
            <>
              <PageHeader
                eyebrow="POSTGRESQL • ADMINISTRATION"
                title="Administration"
                description="Rôles, vues, fonctions, triggers et index présents dans votre base PostgreSQL."
                actions={
                  <button
                    className="button ghost"
                    disabled={refreshing || sqlLoading}
                    onClick={refresh}
                  >
                    <RefreshCw
                      size={17}
                      className={refreshing || sqlLoading ? 'spin' : ''}
                    />{' '}
                    {refreshing || sqlLoading ? 'Actualisation…' : 'Actualiser'}
                  </button>
                }
              />
              <div className="sql-summary">
                {[
                  ['Rôles', diagnostic?.roles?.length, ShieldCheck],
                  ['Vues', diagnostic?.vues?.length, BarChart3],
                  ['Index', diagnostic?.indexes?.length, HardDrive],
                  ['Triggers', diagnostic?.triggers?.length, Activity],
                  ['Fonctions', diagnostic?.fonctions?.length, FileCode2],
                ].map(([name, count, Icon]) => (
                  <div className="sql-mini" key={name}>
                    <Icon size={19} />
                    <strong>
                      {diagnostic === null ? '—' : fmt(count ?? 0)}
                    </strong>
                    <span>{name}</span>
                  </div>
                ))}
              </div>
              {!diagnostic && (
                <div className="info-note">
                  <CircleAlert size={18} /> Diagnostic non chargé : cliquez sur
                  Actualiser et consultez le message d'erreur éventuel.
                </div>
              )}
              <div className="sql-grid">
                <section className="panel">
                  <div className="panel-heading">
                    <div>
                      <h3>
                        <ShieldCheck size={19} /> Rôles PostgreSQL
                      </h3>
                      <p>Permissions métier définies dans 06_roles.sql</p>
                    </div>
                  </div>
                  {(diagnostic?.roles || []).map((r) => (
                    <div className="sql-row" key={r.nom}>
                      <span className="code-label">{r.nom}</span>
                      <span className="role-tag">
                        {r.connexion ? 'LOGIN' : 'NOLOGIN'}
                      </span>
                    </div>
                  ))}
                  <p className="sql-foot">
                    Les rôles sont définis dans PostgreSQL. L'interface n'usurpe
                    pas leurs permissions et ne réalise pas d'authentification.
                  </p>
                </section>
                <section className="panel">
                  <div className="panel-heading">
                    <div>
                      <h3>
                        <FileCode2 size={19} /> Fonction SQL
                      </h3>
                      <p>nombre_interventions_appareil(id)</p>
                    </div>
                  </div>
                  <div className="inline-form">
                    <select
                      value={fonctionId}
                      onChange={(e) => setFonctionId(e.target.value)}
                    >
                      {appareils.map((a) => (
                        <option key={a.id_appareil} value={a.id_appareil}>
                          {a.nom}
                        </option>
                      ))}
                    </select>
                    <button
                      className="button primary"
                      onClick={executerFonction}
                    >
                      Exécuter <ArrowRight size={16} />
                    </button>
                  </div>
                  {fonctionResultat && (
                    <div className="function-result">
                      <strong>
                        {fmt(fonctionResultat.nombre_interventions)}
                      </strong>
                      <span>interventions sur cet appareil</span>
                    </div>
                  )}
                  <p className="sql-foot">
                    Appel réel à la fonction stockée dans PostgreSQL.
                  </p>
                </section>
                <section className="panel">
                  <div className="panel-heading">
                    <div>
                      <h3>
                        <Activity size={19} /> Trigger métier
                      </h3>
                      <p>Vérification de la clôture</p>
                    </div>
                  </div>
                  {(diagnostic?.triggers || []).map((t) => (
                    <div className="trigger-box" key={t.nom}>
                      <span className="sql-check">
                        <CheckCircle2 size={17} /> Présent en base
                      </span>
                      <code>{t.nom}</code>
                      <small>{t.definition}</small>
                    </div>
                  ))}
                  <p className="sql-foot">
                    Une clôture sans compte rendu est bloquée en base (code
                    d'erreur 400 dans l'API).
                  </p>
                </section>
                <section className="panel">
                  <div className="panel-heading">
                    <div>
                      <h3>
                        <HardDrive size={19} /> Index
                      </h3>
                      <p>Optimisation des requêtes</p>
                    </div>
                  </div>
                  {(diagnostic?.indexes || []).map((i) => (
                    <div className="sql-row" key={i.nom}>
                      <span className="code-label">{i.nom}</span>
                      <Check size={16} className="good-icon" />
                    </div>
                  ))}
                  <div className="index-criteria">
                    <label>
                      Appareil
                      <select
                        value={indexAppareil}
                        onChange={(e) => setIndexAppareil(e.target.value)}
                      >
                        {appareils.map((a) => (
                          <option key={a.id_appareil} value={a.id_appareil}>
                            {a.nom} (#{a.id_appareil})
                          </option>
                        ))}
                      </select>
                    </label>
                    <label>
                      Date de début
                      <input
                        type="date"
                        value={indexDebut}
                        onChange={(e) => setIndexDebut(e.target.value)}
                      />
                    </label>
                    <label>
                      Date de fin
                      <input
                        type="date"
                        value={indexFin}
                        onChange={(e) => setIndexFin(e.target.value)}
                      />
                    </label>
                  </div>
                  <button
                    className="button ghost full-width"
                    disabled={plansLoading || !appareils.length}
                    onClick={executerPlans}
                  >
                    {plansLoading ? <Spinner /> : <Gauge size={16} />}{' '}
                    {plansLoading
                      ? 'Calcul en cours…'
                      : 'Analyser les index avec ces critères'}
                  </button>
                  <p className="sql-foot">
                    L'appareil est utilisé pour l'index sur id_appareil, la
                    période pour l'index sur date_intervention. PostgreSQL
                    choisit librement son plan.
                  </p>
                </section>
              </div>
              {indexPlans && (
                <section className="panel explain-panel">
                  <h3>Plans d'exécution PostgreSQL</h3>
                  <p className="sql-foot">
                    Appareil #{indexPlans.criteres?.id_appareil} · du{' '}
                    {indexPlans.criteres?.date_debut} au{' '}
                    {indexPlans.criteres?.date_fin} inclus
                  </p>
                  {Object.entries(indexPlans.plans).map(([name, lines]) => (
                    <div key={name}>
                      <h4>{name}</h4>
                      <pre>{lines.join('\n')}</pre>
                    </div>
                  ))}
                  <p className="sql-foot">{indexPlans.note}</p>
                </section>
              )}
              <section className="panel">
                <div className="panel-heading">
                  <div>
                    <h3>
                      <BarChart3 size={19} /> Vue superviseur
                    </h3>
                    <p>Statistiques par appareil calculées par vue SQL</p>
                  </div>
                  <span className="count-pill">
                    {vueSuperviseur.length} lignes
                  </span>
                </div>
                <div className="table-scroller">
                  <table>
                    <thead>
                      <tr>
                        <th>APPAREIL</th>
                        <th>INTERVENTIONS</th>
                        <th>TERMINÉES</th>
                        <th>AVANCEMENT</th>
                      </tr>
                    </thead>
                    <tbody>
                      {vueSuperviseur.map((v) => (
                        <tr key={v.id_appareil}>
                          <td>
                            <strong>{v.appareil}</strong>
                          </td>
                          <td>{fmt(v.total_interventions)}</td>
                          <td>{fmt(v.interventions_terminees)}</td>
                          <td>
                            <div className="progress-track">
                              <span
                                style={{
                                  width: `${v.total_interventions ? (100 * v.interventions_terminees) / v.total_interventions : 0}%`,
                                }}
                              />
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {vueSuperviseur.length === 0 && (
                    <Empty text="Vue indisponible ou aucune donnée." />
                  )}
                </div>
              </section>
              <section className="panel">
                <div className="panel-heading">
                  <div>
                    <h3>
                      <ListChecks size={19} /> Vue technicien
                    </h3>
                    <p>Interventions non terminées issues de vue_technicien</p>
                  </div>
                  <span className="count-pill">20 dernières</span>
                </div>
                <div className="table-scroller">
                  <table>
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>APPAREIL</th>
                        <th>PANNE</th>
                        <th>TECHNICIEN</th>
                        <th>STATUT</th>
                      </tr>
                    </thead>
                    <tbody>
                      {vueTechnicien.map((i) => (
                        <tr key={i.id_intervention}>
                          <td>#{i.id_intervention}</td>
                          <td>{i.appareil}</td>
                          <td className="truncate">{i.description_panne}</td>
                          <td>{i.technicien}</td>
                          <td>
                            <Status statut={i.statut} />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </section>
              <div className="info-note">
                <ShieldCheck size={18} /> Démonstration locale en lecture
                administrateur. Pour prouver les permissions accordées/refusées,
                exécuter <code>tests/tests_roles_vues.sql</code> dans pgAdmin.
                Pour mesurer les index avant/après, utiliser{' '}
                <code>tests/tests_index.sql</code> sur une base de validation.
              </div>
            </>
          )}
          <footer className="footer">
            <span>© 2026 IoTLab · Gestion des interventions</span>
            <span>
              React + FastAPI + PostgreSQL <span className="footer-dot">●</span>{' '}
              Projet SQL avancé
            </span>
          </footer>
        </div>
      </div>
      {modalCreation && (
        <Modal
          title="Nouvelle intervention"
          subtitle="Créez une demande de maintenance dans PostgreSQL."
          onClose={() => {
            if (!busy) {
              setModalCreation(false);
              setError('');
            }
          }}
        >
          <form className="modal-form" onSubmit={creer}>
            <label>
              Appareil concerné
              <select
                required
                value={form.id_appareil}
                onChange={(e) =>
                  setForm({ ...form, id_appareil: e.target.value })
                }
              >
                <option value="">Sélectionner un appareil</option>
                {appareils.map((a) => (
                  <option key={a.id_appareil} value={a.id_appareil}>
                    {a.nom} · {a.localisation}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Technicien responsable
              <select
                required
                value={form.id_technicien}
                onChange={(e) =>
                  setForm({ ...form, id_technicien: e.target.value })
                }
              >
                <option value="">Sélectionner un technicien</option>
                {techniciens.map((t) => (
                  <option key={t.id_technicien} value={t.id_technicien}>
                    {t.prenom} {t.nom} · {t.specialite}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Description de la panne
              <textarea
                rows="4"
                required
                minLength={3}
                maxLength={2000}
                placeholder="Décrivez le problème constaté..."
                value={form.description_panne}
                onChange={(e) =>
                  setForm({ ...form, description_panne: e.target.value })
                }
              />
            </label>
            {error && <div className="modal-error">{error}</div>}
            <div className="modal-actions">
              <button
                type="button"
                className="button ghost"
                disabled={busy}
                onClick={() => setModalCreation(false)}
              >
                Annuler
              </button>
              <button
                className="button primary"
                disabled={busy || !form.description_panne.trim()}
                type="submit"
              >
                {busy ? <Spinner /> : <Plus size={16} />} Enregistrer
              </button>
            </div>
          </form>
        </Modal>
      )}
      {modalCloture && (
        <Modal
          title={`Clôturer l'intervention #${modalCloture.id_intervention}`}
          subtitle="Essayez une clôture sans compte rendu : PostgreSQL doit la refuser et afficher une erreur."
          onClose={() => {
            if (!busy) {
              setModalCloture(null);
              setError('');
            }
          }}
        >
          <form
            className="modal-form"
            onSubmit={(e) => {
              e.preventDefault();
              updateStatut(
                modalCloture.id_intervention,
                'terminée',
                rapport.trim(),
              );
            }}
          >
            <div className="context-box">
              <strong>{modalCloture.appareil}</strong>
              <p>{modalCloture.description_panne}</p>
            </div>
            <label>
              Compte rendu de maintenance
              <textarea
                rows="5"
                placeholder="Réparation, vérifications et résultat des essais..."
                value={rapport}
                onChange={(e) => setRapport(e.target.value)}
              />
            </label>
            {error && <div className="modal-error">{error}</div>}
            <div className="modal-actions">
              <button
                type="button"
                className="button ghost"
                disabled={busy}
                onClick={() => setModalCloture(null)}
              >
                Annuler
              </button>
              <button className="button primary" disabled={busy} type="submit">
                {busy ? <Spinner /> : <CheckCircle2 size={16} />} Confirmer la
                clôture
              </button>
            </div>
          </form>
        </Modal>
      )}
      {modalHistorique !== null && (
        <Modal
          title={`Historique #${modalHistorique}`}
          subtitle="Transitions enregistrées dans la table historique."
          onClose={() => setModalHistorique(null)}
        >
          <div className="history-detail">
            {historiqueDetail.length ? (
              historiqueDetail.map((h) => (
                <div className="timeline-item" key={h.id_historique}>
                  <div className="timeline-circle" />
                  <div>
                    <strong>
                      {h.ancien_statut} → {h.nouveau_statut}
                    </strong>
                    <p>{date(h.date_changement)}</p>
                    <small>{h.commentaire || 'Aucun commentaire'}</small>
                  </div>
                </div>
              ))
            ) : (
              <Empty text="Pas d'historique pour cette intervention." />
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
