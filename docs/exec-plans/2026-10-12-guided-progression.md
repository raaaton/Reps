# Jalon7 — Progression guidée, graphiques et séance simplifiée

## Objectif / autorisation

« Parfait, implémente le prochain jalon » autorise explicitement le7 après le6 installé en0.6.1 ; les scénarios spécifiques iOS de livraison/VoiceOver n’ont pas de mesure individuelle rapportée. Références : PLAN-SPORT-NATIF.md jalon7, PROJECT.md §21, choix du brouillon12octobre. Exécution directe selon executing-plans/writing-plans, TDD domaine, revue indépendante finale. Aucun jalon8(coffre),9(animations/haptics nouveaux) ou10(sauvegarde) commencé.

## Décisions et interfaces

Swift/SwiftUI/SwiftPM/xtool Linux, SDK27.1 déjà installé, iOS26, SQLite. Même identités Sport/widget, capacités/certificat/permissions inchangées. Aucun backend/dépendance, pas de Git utilisable ou worktree : sources de comparaison /tmp/sport-jalon7-before, ledger ici.

Goal par exercice : charge/composition et cibles de répétitions par série, liée à définition actuelle, Codable indépendante. Adoption explicite avec vérification du contexte et de la charge disponibles, persistance SQLite ; snapshot par exercice au lancement, ni migration ni changement d’objectif ne réécrit une séance active. Objectif devenu incompatible/indisponible = message + modification explicite, pas de substitution silencieuse.

Règle<8 : quatre séries (ou nombre configuré) au maximum actuel, Feeling79qualifie/80non → nextload strictement au-dessus du plus lourd réel. Nouvelle charge suggère le minimum configuré par série ; en-dessous du max, séries toutes à même charge/comparables et Feeling<8 → proposer+1répétition à une des séries les plus faibles, sans dépassermaximum. Feeling≥8 = maintenir résultats précédents. Première utilisation = objectif initial de minimum configuré à0kg, adoption/édition explicite. Série/métrique/Feeling manquants : aucune progression numérique inventée, objectif initial/configuré seulement. Charges mixtes : hausse quand critères complets, sinon pas extrapoler résultats à une nouvelle charge. Durées : règle sollicitée à l’utilisateur ; préserver durée configurée et lest manuel en l’absence d’une nouvelle règle autorisée, aucun accroissement inventé.

Nouvelle saisie live Feeling0,5 ; anciens décimaux intacts (notamment historique si non modifié). Durée totale = endedAt-startedAt réels, arrêt finalFeeling ; manuels sans chronologiepasdedurée fictive. Bilan compare seulement séances terminales complètes, métriques/charges/count/repos compatibles, et rapporte chiffres précis.

Correction série active : repository.correctSet(workoutID,exerciseID,original:WorkoutSet,repetitions,durationMS,weightGrams,load?) compare original et état, autorise séries sauvegardées de la séance active, pas de nombre/status/timestamps/goal changés. Charge inchangée gardecomposition, charge modifiée inconnue si aucune combinaison explicitement choisie ; le repos et ses identifiants/échéances restent inchangés.

Visualisation : données de domaine pour points par série, charge/répétitions/durée distinctes, completed only par défaut et accès historique complet séparé ; pas de scoreglobal ni de durée inventée. Grille calendaire récente (13semaines, détailjours), jours terminés/partiels/neutres, aucun ancienplanninginféré, actions accessibles et secours listejours. Quatreonglets, Progressionpublic etaccèsPhotosplaceholder honnête pour8. PrototypeSwiftChartsréel avant intégration, pasprésumerSDK.

## Tâches et vérifications

1. Tests seuil79/80 RED avant changement ; migration5→6 additive, goals persistance/stale/adoption/snapshots/invalidinventory. ModelsGoal/Suggestion + GoalRepository etTrainingSnapshot.goals ; workout_exercise snapshot tableindépendante évitant modifierINSERTspositionnels. TestsavantAPIs (compile absent honnêtementdistinctREDcomportemental). Suitehôte etbuild.
2. Tests correctionactive/timeinvariant/staledoubleconnection/manualduration ; repository correction etfaits de progression/attendance/chartdata. Tests dates/fuseaux/nongregorien, partial/full multiple/day/empty, metricsmix/currenthistoricalchanges. Suitehôte etbuild.
3. PrototypeChartsSDK puis UI parfonction : GoalRow/Editor/Backpack, saisiepréciseetresultatprécédent, Feeling0,5, CorrectionSheet, ProgressionOverview/Charts/Attendance, résumétemps/bilan/prochainobjectif. Régressionciblée surrest/countdown/goalSnapshot/permission. Lintstrict, suite,xtoolbuild réel.
4. Revue finale indépendante mandatée parskills ; correctionsimportantes RED→GREEN etsuite. Version0.7.0(16), build→générationmetadata→packaging→6testsmetadata→inspectionunsigned. Préflightidentité/certificat, scriptUSB puispostflight. README/ROADMAP/DESIGN/SECURITY/BUILD/ledger, recette iPhone ; STOP avant8.

## Review focus

- Snapshotgoal après changement/suppressioninventaire ouexercice, migration/reprise etéditionhistorique, pasde réécriture anciennesperformances.
- Staleadoption/éditionconcurrente/doublesactions : transaction compares source etoriginal ; invalideload visible, pasde substitution.
- Correctionpendantrepos/countdown/chronoautre série : durée/phase etActivityKit restent cohérents, aucunclockoudatafact inventé.
- Chartcomparabilité/rest/mode/charge/count etdatesarchivées, grillerestneutre/doublons/manuels, borne/métriquesextrêmes.
- Coldrestore/UIgoalinitialisations etuserchoix, VoiceOver/grandtexte/petitappareil, adoptionseulementaprèsactionexplicite.

## Progress / ledger

- [x] Task1 objectifs/migration/règle
- [x] Task2 correction/analyse/domain
- [x] Task3 prototype/interface
- [x] Task4 revue/livraison/docs
- [ ] Confirmation iPhone

Preflightinterfaces : Task1GoalRepository→Task3GoalUI etWorkoutsnapshot ; Task2setcorrection→Task3Sheet+HistoryRevision ; Task2analytics→Task3Charts/Grid/Summary. Goal compatible validé au lancement, pas d’adaptation automatique. Pas de gate de permission supplémentaire des skills car plan/jalon autorisés ; Git/commit/scriptsledgerrequérantGit inapplicables, notes ici etcomparaison/tmp. Maintien/reprise/notes techniques/versionscourtes/qualificatifsFeeling exclus comme demandé.

Task1 GREEN81tests ; migration/seuil vraisRED comportementaux (version5, tablesabsentes,75/79refusés), puisGREEN. NouveauxtestsAPIgoals d’abordcompilemissing, pasREDcomportemental. Domainextoolcode0,16,99s. Snapshotstable adopt/stale/invalidload/overridecontextueltéstés. Guardgoal1000séries max pourbornerallocation ; configurationau-delà peutresterstockée maispasgénérerunobjectifgéant automatiquement.
Task2 correction/analyse GREEN86tests ; premierruncomportaitAPIabsentesetappelrecordSeterroné avecdurationMS, fixture corrigée puisGREEN ; paspreuveRED comportemental decesAPIs. Tests bilanécrits avantAPI (compileabsente), à vérifier GREEN. Décisiondurées utilisateur : « garder durée configurée, lest manuellement ; aucune hausseautomatique », appliqué auGoalEngine.
Task3 prototypeCharts en compilation ; shader/APIimport natifs, aucunframeworkexterne. Pas denouveauxanimations/haptics, coffre ouexport.

Task2/3 final : 92 tests hôte sans échec (sport7-integration-tests3.log), dont correction chronométrée durant le décompte avec connexion SQLite concurrente, snapshot après édition/suppression catalogue, rollback lancement avec charge indisponible, présence séance active/calendrier non grégorien et DST. Deux premières fixtures d’intégration avaient une erreur await-autoclosure puis un mauvais jour de planning pour le fuseau +14 ; fixtures corrigées, aucun changement métier pour les faire passer. Prototype Swift Charts code0 16,03s ; interface complète xtool code0 10,52s, lint strict code0. Initialisateurs Section avec header/footer explicités après erreurs compiler réelles.
Revue indépendante interrompue par fermeture app : aucun résultat reçu, agent disparu ; une revue de remplacement lancée en contexte neuf. Aucune réinstallation ni revue répétée après fixes. Version préparée0.7.0(16), identité/capacités inchangées.

Revue indépendante finale : aucun Critical ; trois Important sur bilan (baisse d’effort avec baisse de performance, dernière séance masquant une ancienne comparable, repos manuel inconnu). Tous reproduits par tests comportementaux puis corrigés, RED→GREEN ; suite96tests code0. Premier Minor reclassé Important : charge choisie hors des modes/états admis produit un graphique vide avec données présentes. Extraction neutre du sélecteur UI dans le domaine, trois assertions observées RED puis correction, GREEN. Une seule passe de corrections, pas de re-review. Voir /tmp/sport7-review-full-red.log et /tmp/sport7-review-green.log.
Final: minor (deferred): les points des graphiques ne distinguent pas visuellement les changements de repos/nombre de séries ; ce sont des résultats bruts à lire via l’historique, pas des gains comparables. Limite documentée, pas de score extrapolé.
Final: Ruling: éléments declined — rendu, VoiceOver, toucher et Swift Charts attendent la recette iPhone ; packaging/signature/docs vérifiés ici avant livraison ; coffre/animations/export restent hors7. Coût : le rendu reste à confirmer physiquement, pas de promesse des jalons futurs.
Fixes : effortLower seulement si résultat au moins équivalent ; recherche dernière session comparable sans LIMIT1 prématuré ; séances manuelles exclues du bilan exigeant un repos connu, valeurs restent dans graphiques/historique. Sélecteur de charge issu uniquement des séances terminées au même mode ; conserve une sélection admissible.
Build final Sport0.7.0(16) code0,13,99s ; lint strict code0,96tests hôte0échec. Metadata et packaging finaux en cours. Préflight lecture seule après rebranchement utilisateur code0 : ancienne0.6.1, même identité xtool exacte/certificat existant valide>24h et présent chez Apple. Premier préflight échouait sur socketusbmuxd : appareil absent, service inactif, aucune tentative de provisioning. Connexion rétablie par l’utilisateur.

Task4 complete : génération metadata code0, packaging2,09s code0,6tests metadata0échec et inspection unsigned code0. ScriptUSB code0, rebuild2,15s, installation/vérification100%. Postflight direct code0 : Sport0.7.0(16), même identité exacte app, extension unique et profils valides/CMS vérifiés, certificat du profil identique au préflight et certificat local inchangé. README/ROADMAP/BUILD/DESIGN/SECURITY/PROJECT actualisés. Arrêt avant8 : confirmation physique non reçue ; rendu, gestes, clavier, VoiceOver/grandtexte et graphselection à tester. Aucun résultat iPhone simulé, pas de tests SwiftUI sous Linux.
