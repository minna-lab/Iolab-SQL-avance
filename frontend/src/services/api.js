const BASE = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

async function request(path, options = {}) {
  let response;
  try {
    response = await fetch(`${BASE}${path}`, options);
  } catch {
    throw new Error(
      'Serveur FastAPI inaccessible. Vérifier http://127.0.0.1:8000/docs.',
    );
  }
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    let detail = data?.detail;
    if (Array.isArray(detail)) detail = detail.map((x) => x.msg).join(', ');
    throw new Error(
      typeof detail === 'string' ? detail : `Erreur HTTP ${response.status}`,
    );
  }
  return data;
}
const json = (method, data) => ({
  method,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
});
const qs = (values) => new URLSearchParams(values).toString();

export const api = {
  health: () => request('/api/db-test'),
  stats: () => request('/api/statistiques'),
  appareils: (recherche = '', etat = 'tous') =>
    request(`/api/appareils?${qs({ recherche, etat })}`),
  techniciens: (recherche = '') =>
    request(`/api/techniciens?${qs({ recherche })}`),
  interventions: ({
    page = 1,
    limit = 15,
    statut = 'tous',
    recherche = '',
  } = {}) =>
    request(`/api/interventions?${qs({ page, limit, statut, recherche })}`),
  creer: (data) => request('/api/interventions', json('POST', data)),
  statut: (id, data) =>
    request(`/api/interventions/${id}/statut`, json('PATCH', data)),
  historique: () => request('/api/historique?limit=100'),
  historiqueIntervention: (id) => request(`/api/historique/${id}`),
  vueTechnicien: () => request('/api/vues/technicien?limit=20'),
  vueSuperviseur: () => request('/api/vues/superviseur'),
  diagnostic: () => request('/api/sql/diagnostic'),
  indexPlan: ({
    id_appareil = 5,
    date_debut = '2026-03-01',
    date_fin = '2026-03-07',
  } = {}) =>
    request(
      `/api/sql/index-performance?${qs({ id_appareil, date_debut, date_fin })}`,
    ),
  fonction: (id) => request(`/api/fonction/${id}`),
};
