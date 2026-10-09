# IoTLab — Gestion des interventions de maintenance

> **Projet SQL avancé — Bachelor 2 · Groupe de 3 · PostgreSQL + Beekeeper Studio**  
> **Dépôt GitHub public :** `iolab-sql-avance`  
> **Présentation :** jeudi 15 octobre 2026 · **Rendu Moodle :** vendredi 16 octobre 2026 à 23 h 59.

## 1. Présentation du projet

IoTLab est une base de données PostgreSQL qui permet de gérer les équipements électroniques d'un laboratoire (ESP32, Arduino, Raspberry Pi), leurs pannes et les interventions des techniciens. Les interventions terminées doivent avoir un compte rendu ; les changements de statut peuvent être tracés dans un historique.

**Objectif pédagogique :** démontrer les notions SQL avancées étudiées en cours : fonction/procédure, trigger, index, rôles, privilèges et vues. L'interface Beekeeper Studio sert uniquement à se connecter au serveur et à exécuter les requêtes : aucun site web ou montage électronique n'est requis.

## 2. Organisation et responsabilités

| Personne | Rôle dans le groupe | Responsabilités principales |
|---|---|---|
| **Minna — [Minna]** | **responsable architecture et intégration** | Tables, relations, données, dépôt GitHub, assemblage du script, coordination et validation finale |
| **Raïssa — [Raïssa]** | Développeur SQL / responsable logique métier | Fonction SQL, trigger de contrôle, tests positifs et négatifs, éventuellement historisation automatique |
| **Mariam — [Mariam]** | Responsable sécurité et performances | Vues, rôles, utilisateurs, privilèges, index, mesures avant/après et tests d'accès |

**Décision de coordination : le Minna dirige le projet.** Il organise le travail et les revues, mais chaque membre reste responsable de son code, de ses tests, de ses commits et de sa capacité à expliquer tout le projet.

### Minna —  responsable base de données

**A. Préparer l'environnement**

1. Vérifier que le serveur PostgreSQL fonctionne (local ou Docker).
2. Configurer la connexion PostgreSQL dans Beekeeper Studio : hôte, port, utilisateur, mot de passe, base.
3. Tester `SELECT current_database(), current_user, version();`.
4. Créer la base de projet `iolab` séparément de la base de cours `festival`, avec un compte autorisé.
5. Créer le dépôt **public** `iolab-sql-avance` ; inviter les deux collaborateurs.
6. Définir la convention des noms SQL, les branches et les issues GitHub.

**B. Concevoir les quatre tables et les relations**

- `appareils` : `id_appareil` (PK), `nom`, `type_appareil`, `localisation`, `etat`.
- `techniciens` : `id_technicien` (PK), `nom`, `prenom`, `specialite`.
- `interventions` : `id_intervention` (PK), `id_appareil` (FK), `id_technicien` (FK), `description_panne`, `date_intervention`, `statut`, `compte_rendu`.
- `historique` : `id_historique` (PK), `id_intervention` (FK), `ancien_statut`, `nouveau_statut`, `date_changement`, `commentaire`.

**Relations :** un appareil → plusieurs interventions ; un technicien → plusieurs interventions ; une intervention → plusieurs lignes d'historique. Prévoir `NOT NULL`, des clés primaires et étrangères, ainsi que des contraintes `CHECK` pour limiter les états et statuts à des valeurs valides. Utiliser des identifiants générés automatiquement (`GENERATED ... AS IDENTITY`) si approprié.

**C. Créer les données**

1. Ajouter environ 20 appareils (ESP32, Arduino, Raspberry Pi).
2. Ajouter environ 10 techniciens fictifs.
3. Générer **au moins 10 000 lignes** cohérentes dans `interventions` avec `generate_series()`.
4. Répartir les interventions entre appareils et techniciens existants, avec des dates variées.
5. S'assurer que les interventions déjà `terminee` disposent d'un compte rendu non vide.
6. Ajouter quelques lignes d'historique cohérentes avec les interventions et leur évolution ; elles peuvent être générées explicitement, le trigger d'audit étant facultatif.

**D. Tester et intégrer**

- Vérifier `SELECT COUNT(*) FROM interventions;` (résultat attendu : **≥ 10000**).
- Tester qu'une intervention avec `id_appareil` inexistant est refusée par la clé étrangère.
- Relire les PR des membres 2 et 3 et assembler les contributions dans `projet.sql`.
- Rejouer `projet.sql` sur **une base vide**, corriger toutes les erreurs, notamment les dépendances entre objets.
- Vérifier que le dépôt est public, que chaque membre a commité et que le README présente les preuves.
- Organiser la répétition de la démonstration et le dépôt final sur Moodle.

**Livrables personnels :** structure SQL, données d'exemple, génération des 10 000 interventions, issues et revue d'intégration, vérification du script final.

### Raïssa — Développeur SQL et logique métier

**A. Fonction obligatoire : `nombre_interventions_appareil(id_appareil)`**

1. Recevoir du Minna les noms définitifs des colonnes et statuts.
2. Créer une fonction SQL (ou PL/pgSQL) acceptant un identifiant d'appareil.
3. Compter les interventions associées à cet appareil et retourner un entier.
4. Tester un appareil ayant plusieurs interventions, un appareil sans intervention et éventuellement un identifiant inconnu.
5. Comparer le résultat de la fonction à un `SELECT COUNT(*) ... WHERE id_appareil = ...`.

**B. Trigger obligatoire : `trg_verifier_cloture`**

1. Définir une fonction de trigger appelée lors des `INSERT`/`UPDATE` de `interventions`.
2. Refuser toute ligne dont le statut devient `terminee` et dont `compte_rendu` vaut `NULL`, une chaîne vide ou seulement des espaces.
3. Émettre un message d'erreur explicite (`RAISE EXCEPTION`), pour expliquer le refus.
4. Autoriser les interventions `en_attente` ou `en_cours` sans compte rendu.
5. Autoriser une intervention `terminee` avec compte rendu renseigné.
6. Effectuer des tests positifs **et** négatifs, sans laisser de données de test incohérentes.

**C. Historique — fonctionnalité facultative**

- En priorité, renseigner des lignes d'historique de test pour illustrer les changements de statut.
- Si le temps le permet, créer un **deuxième trigger** qui journalise automatiquement les transitions de statut dans `historique` ; le tester après le trigger obligatoire.
- Ne pas risquer la livraison de la fonction et du trigger obligatoires pour cette option facultative.

**D. Preuves et intégration**

- Conserver les commandes SQL de démonstration et leurs résultats attendus.
- Expliquer pourquoi la règle de clôture est imposée **dans PostgreSQL**, plutôt que seulement dans une application.
- Ouvrir sa propre PR et documenter sa contribution au README.

**Livrables personnels :** fonction, trigger, scénarios de tests, explication métier et commits personnels.

### Mariam — Responsable sécurité, vues et performances

**A. Deux vues distinctes**

1. Créer `vue_technicien` : interventions non terminées, appareil, description de panne, technicien, date et statut.
2. Créer `vue_superviseur` : bilan par appareil (nombre total d'interventions et nombre terminées).
3. Vérifier que les vues donnent des résultats cohérents et ne divulguent pas de colonnes superflues.
4. Vérifier les jointures et les calculs d'agrégation.

**B. Deux rôles-métiers et un utilisateur par rôle**

1. Créer `role_technicien` et `role_superviseur`.
2. Créer `user_technicien` et `user_superviseur`, puis affecter chaque utilisateur à son rôle.
3. Accorder à chaque rôle uniquement le droit `SELECT` sur **sa** vue.
4. Configurer le droit d'accès au schéma (`USAGE`) nécessaire, sans donner de droits de lecture directs sur les quatre tables métier.
5. Vérifier les privilèges hérités, le propriétaire des vues et les autorisations PostgreSQL : les vues doivent fonctionner avec les rôles choisis sans exposer les tables.
6. Tester avec `SET ROLE` (et revenir au rôle initial avec `RESET ROLE`) : `SELECT` sur la vue autorisée = **réussi** ; `SELECT` sur la table ou l'autre vue = **refusé**.
7. Éviter de tester uniquement en superutilisateur, car celui-ci peut contourner les vérifications de privilèges.

**C. Deux index et preuves de performance**

1. Utiliser la table `interventions`, remplie avec au moins 10 000 lignes.
2. Choisir une requête sélective par `id_appareil` et une recherche par période sur `date_intervention`.
3. Exécuter `EXPLAIN (ANALYZE, BUFFERS)` **avant** la création de chaque index ; noter le temps et le type de parcours (`Seq Scan`, etc.).
4. Créer `idx_interventions_appareil` sur `id_appareil` et `idx_interventions_date` sur `date_intervention`.
5. Relancer les **mêmes** requêtes, avec les mêmes filtres ; noter les temps après et les plans obtenus.
6. Si PostgreSQL n'utilise pas l'index, examiner la sélectivité et la distribution des données ; ne jamais inventer de gains de temps.
7. Reporter les résultats réels dans le README.

**Livrables personnels :** deux vues, deux rôles, deux utilisateurs, droits contrôlés, deux index, plans et durées avant/après, commits personnels.

## 3. Ordre de collaboration et dépendances

1. **Minna** crée la base et fixe le schéma. Il partage les noms exacts des tables/colonnes et quelques données.
2. **Raïssa** développe la fonction et le trigger en s'appuyant sur ce schéma ; il transmet ses requêtes de test.
3. **Mariam** développe les vues et les rôles dès que les tables existent ; il attend le chargement des 10 000 lignes pour mesurer les index.
4. **Minna** intègre les PR dans le fichier final `projet.sql` ; le groupe teste le script complet sur une base vide.
5. **Tous les membres** relisent le README et répètent la démonstration ensemble.

> **Attention à l'ordre du fichier final :** le sujet impose **tables → données → fonction/procédure → trigger → vues → rôles → index**. Les données initiales doivent être cohérentes avec la règle du trigger, même si celui-ci est créé après leur insertion. Les rôles PostgreSQL sont globaux au serveur : prévoir une création robuste si le script est rejoué.

## 4. GitHub : méthode commune

- Une seule personne (Minna) crée le **dépôt public** puis invite les deux autres.
- Chaque membre travaille dans sa propre branche, par exemple `feature/tables-donnees`, `feature/fonction-trigger`, `feature/roles-vues-index`.
- Chaque membre ouvre une **pull request** vers `main`, avec description des changements et tests exécutés.
- Le chef de projet relit et fusionne après validation ; personne ne pousse directement sur `main` pendant l'intégration, sauf accord explicite.
- Chaque membre utilise son **propre compte GitHub** et fait ses **propres commits** : l'historique doit montrer la contribution individuelle.
- Les fichiers de travail éventuels peuvent être stockés dans `travail/`, mais le **rendu officiel** repose sur `projet.sql` et `README.md` à la racine du dépôt.

**Format de commit conseillé :** `feat: creer les tables`, `feat: ajouter trigger de cloture`, `test: verifier les privileges`, `docs: documenter les index`.

## 5. Calendrier

| Date | Objectif | Responsable(s) |
|---|---|---|
| **Vendredi 9 octobre** | Connecter Beekeeper, créer la base et le dépôt, préparer le schéma, répartir les tâches | Minna, avec toute l'équipe |
| **Lundi 12 octobre** | Tables + données, fonction et trigger, premier contrôle en classe | Membres 1 et 2 ; Mariam prépare son travail |
| **Mardi 13 octobre** | Vues, rôles, tests d'autorisation, index et mesures, première version du README | Mariam ; membres 1 et 2 en support |
| **Mercredi 14 octobre** | Assemblage, exécution complète sur base vide, corrections, répétition | Tous |
| **Jeudi 15 octobre** | Présentation : **8 min de démo + 4 min de questions**, sans diaporama | Tous |
| **Vendredi 16 octobre, 23 h 59** | Date limite Moodle : `.txt` avec URL du dépôt **public** et noms/prénoms des trois membres | Minna vérifie ; un membre dépose |

### Proposition pour les 8 minutes de démonstration

Le professeur demande de montrer **dans cet ordre** : 1) rôle avec action autorisée et refusée ; 2) vue montrant ce qu'elle expose et cache ; 3) index avec temps avant/après ; 4) trigger avec action et résultat observé.

- **Minna :** introduction et présentation très brève de la base (30 s à 1 min).
- **Mariam :** rôles, vue et index (environ 4 à 5 min).
- **Raïssa :** trigger et démonstration du refus de clôture (environ 2 à 3 min).

Tous doivent savoir expliquer toutes les parties : le professeur peut interroger n'importe quel membre.

## 6. Checklist de conformité

- [ ] Les 4 tables métier sont reliées par des clés étrangères.
- [ ] La table `interventions` contient **≥ 10 000 lignes**.
- [ ] Une fonction ou procédure est opérationnelle, avec un test documenté.
- [ ] Le trigger protège une vraie règle métier et affiche une erreur explicite.
- [ ] Deux index sont créés et **chacun** est mesuré avant et après.
- [ ] Deux rôles-métiers ont des droits distincts, avec **un utilisateur chacun**.
- [ ] Une vue existe pour chaque rôle ; les utilisateurs n'ont pas accès directement aux tables.
- [ ] Chaque rôle a au moins un test autorisé et un test refusé.
- [ ] `projet.sql` respecte l'ordre du sujet et **s'exécute sans erreur sur une base vide**.
- [ ] `README.md` comprend les explications et les preuves (voir section suivante).
- [ ] Chaque membre possède des commits identifiables sur GitHub.
- [ ] Le dépôt est **public** et accessible sans connexion spéciale.
- [ ] Le groupe est prêt pour la démo en direct du jeudi 15.
- [ ] Le fichier `.txt` Moodle contient le lien GitHub et les noms complets ; remis avant la date limite.

## 7. Documentation technique et preuves à compléter avant le rendu

> **Cette section est un modèle de travail, pas encore une preuve de fonctionnement.** Chaque responsable doit ajouter les requêtes exécutées et les résultats réellement observés. Pour chaque élément, le professeur demande : **ce qu'il fait, pourquoi il existe, la preuve**.

### Fonction `nombre_interventions_appareil`

- **Ce qu'elle fait :** calcule le nombre d'interventions associées à un appareil.
- **Pourquoi :** obtenir rapidement un indicateur de maintenance.
- **Preuve à compléter :** commande `SELECT nombre_interventions_appareil(1);`, résultat observé et comparaison à `COUNT(*)`.

### Trigger `trg_verifier_cloture`

- **Ce qu'il fait :** interdit une intervention `terminee` sans compte rendu non vide.
- **Pourquoi dans la base :** contrôle la règle quel que soit l'outil utilisé pour modifier les données.
- **Preuve à compléter :** insertion ou mise à jour refusée avec erreur PostgreSQL ; scénario avec compte rendu accepté.

### Vues `vue_technicien` et `vue_superviseur`

- **Ce qu'elles font :** présentent, respectivement, les interventions ouvertes et le bilan par appareil.
- **Pourquoi :** limiter les données visibles selon le métier.
- **Preuve à compléter :** `SELECT` réussi sur la vue attribuée au rôle et tentative interdite d'accès à une table métier.

### Rôles et privilèges

- **Ce qu'ils font :** distinguent les droits du technicien et du superviseur.
- **Pourquoi :** appliquer le principe du moindre privilège.
- **Preuve à compléter :** `SET ROLE role_technicien;` puis action autorisée et refusée ; idem pour `role_superviseur` ; `RESET ROLE;` entre les tests.

### Index et mesures de performance

- **Ce qu'ils font :** peuvent accélérer les recherches par appareil et par date.
- **Pourquoi :** travailler efficacement sur 10 000 interventions ou plus.
- **Preuve :** coller les requêtes `EXPLAIN (ANALYZE, BUFFERS)` utilisées et compléter le tableau avec les **temps réels**, en précisant les plans.

| Index | Requête testée | Avant (ms) | Après (ms) | Plan avant / après |
|---|---|---:|---:|---|
| `idx_interventions_appareil` | À renseigner | À mesurer | À mesurer | À renseigner |
| `idx_interventions_date` | À renseigner | À mesurer | À mesurer | À renseigner |

### Qualité du script

- **Ce qu'il fait :** crée toute la base et ses objets dans l'ordre imposé.
- **Pourquoi :** permettre au professeur de tout reproduire.
- **Preuve à compléter :** commande d'exécution de `projet.sql` sur une base PostgreSQL vide et résultat sans erreur.

## 8. Rappel : les deux fichiers du rendu

```text
iolab-sql-avance/
├── projet.sql    # Script PostgreSQL complet, exécutable sur une base vide
└── README.md     # Projet, organisation, explications et preuves
```

Un fichier `.txt` séparé contenant l'URL du dépôt et les noms/prénoms des trois membres sera déposé sur Moodle par une seule personne.
