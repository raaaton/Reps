# Calisthenics Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for native execution, or superpowers:subagent-driven-development if the user selects delegation. Implement task-by-task; retain checkbox progress.

**Goal:** Livrer quatre parcours guidés modifiables, les skills personnels, leur entraînement en séance ou seul, et un historique durable.

**Architecture:** Un domaine Skills distinct des exercices de force, servi par le même acteur SportRepository et SQLite. Catalogue, suivi et affectations préparent des instantanés ; un moteur de transitions commun exécute les blocs intégrés et autonomes. Réutiliser le flux de force et ses repos existants sans convertir artificiellement les skills en exercices de force.

**Tech Stack:** Swift 6.4, SwiftUI, SQLite, SwiftPM/xtool, iOS 26 minimum ; aucune dépendance ajoutée.

**Spec:** [Spécification approuvée](2026-10-23-calisthenics-skills-design.md).

**Status:** Plan et méthode native approuvés (« vasy »). Implémentation locale en cours ; revue indépendante et iPhone restent à vérifier. Méthode recommandée : exécution native dans cette conversation, puis revue indépendante finale, les tâches partageant leurs modèles et transitions.

## Global Constraints

- Quatre parcours : Handstand, L-sit, Planche et Front Lever, avec étapes et prolongements praticables définis dans la spécification.
- Consignes hors ligne, liens facultatifs HTTPS dans le navigateur externe ; aucune vidéo embarquée ni requête automatique.
- « Les réglages sont propres à chaque affectation de séance. »
- « Aucune modification d'étape, de figure ou de planning ne réécrit une pratique commencée ou l'historique. »
- Free Practice : repère initial 5 minutes, modifiable ou sans limite ; fin explicite et pauses explicites exclues de la durée.
- Timed Holds : préparation 3–2–1 ; résultats réels, objectifs facultatifs. Repetitions : résultats réels et objectifs facultatifs.
- Interface anglaise, quatre onglets conservés, Skills dans Progress ; composants natifs, Dynamic Type, VoiceOver et Reduce Motion.
- Conserver les changements locaux, schema16/Stretching et les trois comportements du selective revert ; aucun nettoyage de caches, rollback, push ou changement de signature.

## Review Focus

1. Deux commandes ou deux connexions simultanées : une seule activité indépendante ; pas de double résultat (tâche 2).
2. Suppression d'une étape affectée : planning cohérent et instantanés inchangés (tâche 1).
3. Dernier Feeling, étirements désactivés et skills après la force : séance encore active jusqu'au dernier bloc (tâche 3).
4. Import CSV remplaçant une séance mixte : pratiques Skills conservées et jamais déclarées comme pratiques autonomes initiales (tâche 4).
5. Sauvegarde en activité, repos expiré et compte à rebours en cours : restauration reprenable sans performance inventée (tâche 4).

## Préparation et organisation

- [x] Lire tous les Markdown Sport applicables avant les éditions source, y compris les ExecPlans historiques ; les archives Expo restent du contexte, jamais une méthode de build. Conserver un inventaire de lecture dans /tmp.
- [x] Sauvegarder dans /tmp les fichiers locaux modifiés/non suivis et leurs empreintes avant édition ; relever git status/diff. Travailler dans ce checkout pour conserver son état validé, sans créer une worktree depuis origin/main qui omettrait les changements locaux.
- [x] Exécuter `swift test --package-path Tests/Host` comme référence initiale ; distinguer une régression nouvelle d'un défaut déjà présent.

Fichiers nouveaux du domaine : `Sources/SportCore/SkillModels.swift`, `SkillCatalogue.swift`, `SkillSchema.swift`, `SkillRepository.swift`, `SkillPractice.swift`, `SkillPracticeRepository.swift`, `WorkoutSkillRepository.swift`, `SkillTransfer.swift`. Si un fichier dépasse une responsabilité, extraire les validations/lectures dans le même dossier ; pas de refactorisation générale.

Fichiers UI nouveaux dans `Sources/Sport/Features/Skills/` : `SkillsView.swift`, `SkillDetailView.swift`, `SkillEditor.swift`, `SkillBlockEditor.swift`, `SkillPracticeView.swift`, `SkillHistoryView.swift`. Adaptateur `Sources/Sport/Shared/TrainingStore+Skills.swift` ; exposer en interne le point de mutation/refresh du store plutôt que dupliquer sa gestion de génération.

Chaque tâche suit RED → implémentation → GREEN. Ajouter les tests dans `Tests/Host/Tests/SportCoreTests/` ; les sources de Tests/Host sont déjà des liens vers les vrais fichiers. Les noms ci-dessous sont les interfaces nouvelles à garder cohérentes, sans reprendre l'ancien modèle catalogue-wide setCount.

## Tâche 1 — Catalogue, suivi et affectations persistants

**Fichiers :** nouveaux modèles/catalogue/schema/repository ; adapter `TrainingModels.swift`, `TrainingSchema.swift` et les lecteurs/sauvegardes de `SportRepository.swift`. Tests : `SkillCatalogueTests.swift`, `SkillRepositoryTests.swift`.

**Interfaces produites :**
- `SkillDefinition`, `SkillStep`, `SkillProgress`, `SkillAssignment`, `SkillConfiguration` : Codable, Equatable, Sendable ; IDs stables, références par ID.
- `SkillFormat`: freePractice, timedHolds, repetitions ; `SkillPlacement`: beforeForce, afterForce ; `SkillAchievement`: unrecorded, firstSuccess, consistent.
- `TrainingSnapshot.skills: [SkillDefinition]`, `skillProgress: [SkillProgress]` ; `TrainingSchedule.skills: [SkillAssignment]`, `skillPlacement: SkillPlacement`. Décodage rétrocompatible des champs absents.
- Sur SportRepository : `saveSkill(_ proposed: SkillDefinition, original: SkillDefinition?) throws`, `archiveSkill(id: String) throws`, `saveSkillProgress(_ proposed: SkillProgress, adoptingIn scheduleIDs: [String]) throws`.

- [x] Écrire les tests : quatre IDs préchargés uniques après réouverture ; création nom+une étape ; refus noms vides/IDs dupliqués/liens non HTTPS ; duplication à IDs neufs ; étape directe ne validant pas les précédentes ; mardi et samedi gardant des formats/volumes distincts.
- [x] Écrire les scénarios suppression d'étape : retirer ses affectations futures après confirmation, repositionner le choix courant vers la première étape restante, conserver les pratiques figées ; interdire le retrait de la dernière étape. L'éditeur annonce les séances affectées avant Save.
- [x] Lancer `swift test --package-path Tests/Host --filter Skill` ; constater l'échec avant implementation.
- [x] Implémenter une migration additive schema17 : tables `skill_definitions(id,payload)`, `skill_progress(skill_id,payload)`, `schedule_skills(schedule_id,payload)`, `workout_skills(workout_id,payload)` et `skill_sessions(id,status,payload)`. Contraintes FK sur les propriétaires de configuration ; instantanés sans FK vers les définitions mutables. Index unique pour une session autonome active. Payloads JSON validés suivant le précédent workout_support.
- [x] Insérer le catalogue une fois dans la migration ; IDs préchargés protégés des collisions avec les copies UUID. Conserver les archives de définitions, sans réactivation automatique. Écriture transactionnelle des affectations et du suivi ; adoption seulement dans les séances sélectionnées, avec conservation de leurs paramètres.
- [x] Rédiger les fiches des quatre parcours et de leurs prolongements selon la spec, formulations originales et sources citées ; relire repères et matériel sans ajouter de critères chiffrés de maîtrise.
- [x] Assertions repères dans `testCataloguePersistsAndIsUnique` : `XCTAssertEqual(snapshot.skills.count, 4)` ; `XCTAssertEqual(Set(snapshot.skills.map(\.id)).count, 4)` ; dans `testAssignmentsKeepIndependentVolumes`, comparer les nombres d’essais mardi=2 et samedi=4 et les instantanés après réouverture.
- [x] Relancer le filtre : zéro échec ; tests de migration vérifiant les données force/support inchangées et rollback intégral en cas d'erreur.

## Tâche 2 — Moteur de pratique et activité autonome

**Fichiers :** `SkillPractice.swift`, `SkillPracticeRepository.swift`. Tests : `SkillPracticeTests.swift`.

**Interfaces produites :**
- `SkillPractice` : instantané définition/étape/configuration, origine, état, révision, dernier ID de commande, chronologie, essais et bilan facultatif. Origine : autonome, séance liée, ou séance antérieure détachée avec ID/nom/date d'origine.
- `SkillAction` : begin, acknowledgePreparation, pause, resume, beginAttempt, cancelCountdown, recordAttempt, changeRest, finish, skip, cancel, reviseConfiguration ; les données requises portent nombre/durée/bilan selon le cas.
- `SkillCommand` : practiceID, commandID, expectedRevision, action.
- SportRepository : `startSkillPractice(assignment: SkillAssignment, now: Int) throws -> SkillPractice`, `applySkillCommand(_ command: SkillCommand, now: Int) throws -> SkillPractice`, `skillPractices(skillID: String?) throws -> [SkillPractice]`, `activeSkillPractice() throws -> SkillPractice?`.

- [x] Écrire les tests : 1 s actif + 2 s pause + 1 s actif = 2 s enregistrées ; repère 300 s sans fin automatique ; tenir 3 s n'est pas pratiquer 300 s ; chronologie inversée refusée ; reprise par une nouvelle instance repository.
- [x] Écrire les tests : commande rejouée sans résultat doublé ; commande périmée ne terminant pas la tentative suivante ; deux connexions ne lançant pas deux activités ; repos absolu réconcilié ; annulation du 3–2–1 sans résultat ; meilleure tenue déclarée sans confusion avec temps mesuré.
- [x] Observer RED avec `swift test --package-path Tests/Host --filter SkillPracticeTests`.
- [x] Implémenter un réducteur de transitions pur validant format/état/révision et une persistance BEGIN IMMEDIATE. Toujours relire l'état courant. Rejouer la dernière commande réussie retourne l'état existant ; une ancienne révision différente est refusée.
- [x] Détailler uniquement les formats choisis : pas de séries inventées, répétitions positives, objectifs facultatifs, préparation relisible/validable avant pratique, pas de pause au milieu d'une tenue mesurée ; pause proposée entre essais et en pratique libre. Les pauses de repos restent possibles.
- [x] Conserver origine, assistance et métrique dans le résultat ; aucune auto-validation d'étape. Une session indépendante active empêche un nouveau workout et inversement ; une pratique enfant de la séance n'est pas une seconde activité indépendante.
- [x] Assertions de `testPausedFreePracticeSurvivesReopen` : `XCTAssertEqual(practice.elapsedMS(at: now), 2000)` ; `XCTAssertNil(practice.endedAt)` après dépassement du repère ; `testRepeatedCommandDoesNotDuplicateAttempt` : `XCTAssertEqual(practice.attempts.count, 1)`. Définir `elapsedMS(at: Int) -> Int` sur SkillPractice.
- [x] Relancer le filtre : zéro échec.

## Tâche 3 — Séances mixtes et fin de séance

**Fichiers :** `WorkoutSkillRepository.swift`, `WorkoutModels.swift`, `WorkoutRepository.swift`, `WorkoutSupportRepository.swift`, `RestActivitySnapshot.swift` uniquement si nécessaire pour ignorer un repos de skill. Tests : `WorkoutSkillTests.swift`.

**Interfaces produites :** `WorkoutSkills` (placement et blocs ordonnés figés), `WorkoutSession.skills: WorkoutSkills? = nil`, `WorkoutSession.currentSkill: SkillPractice?`, `WorkoutPhase.skills`. Le moteur tâche 2 reste unique pour les pratiques intégrées et autonomes.

- [x] Écrire les scénarios : avant force → préparation Skills/blocs → échauffement force → force → étirements ; après force → échauffement force → force → Skills → étirements ; aucun Skills = comportement actuel exact.
- [x] Écrire les tests du dernier Feeling sans étirements ; dernier skill fini/passé ; annulation après un bloc fini ; commandes de série reçues pendant Skills refusées ; édition planning/catalogue après lancement sans effet sur l'instantané.
- [x] Observer RED via `swift test --package-path Tests/Host --filter WorkoutSkillTests`.
- [x] Figer les blocs dans startWorkout, lire/écrire workout_skills avec la séance ; priorité de phase Skills avant les warm-ups si beforeForce, avant les stretches si afterForce. Le sélecteur currentSupport masque le support pendant Skills, pour que workoutOverview ne termine pas un stretch prématurément. Bloquer les mutations de force tant que la phase ne les permet pas.
- [x] Centraliser la finalisation transactionnelle dans `completeWorkoutIfReady(id: String, now: Int) throws` : force/Feeling, support et Skills tous terminés ou passés. Appeler depuis Feeling, support et commandes Skills ; apprendre les futurs objectifs de force exactement une fois à la vraie fin.
- [x] Conserver repos Skills dans les payloads Skills ; les repos/Live Activities force restent leur propre état. Inclure l'activité Skills dans les gardes de lancement et la réconciliation au retour foreground.
- [x] Assertions de `testAfterForceWithoutStretchWaitsForSkills` : après le dernier Feeling, `XCTAssertEqual(workout.status, .active)` et `XCTAssertEqual(workout.phase, .skills)` ; après le dernier bloc, `XCTAssertEqual(workout.status, .completed)`.
- [x] Relancer le filtre puis WorkoutSupportTests/WorkoutTests : zéro échec ; aucun changement au selective revert.

## Tâche 4 — Archives et protection contre la perte d'historique

**Fichiers :** `SkillTransfer.swift`, `TrainingTransferModels.swift`, `TrainingTransferRepository.swift`, `TrainingTransferValidation.swift`, `TrainingJSONShape.swift` ; ajuster les tests de versions existants sans masquer leurs assertions. Tests : `SkillTransferTests.swift`.

**Interface produite :** archive JSON v6 ; `TrainingDataSet.skillSessions: [SkillPractice]` pour autonome/détaché, mixed dans `WorkoutSession.skills`, configuration dans les champs tâche 1. Champs absents v1–v5 → catalogue initial/suivi vide/aucune affectation ou pratique inventée. V6 conserve explicitement les données fournies, y compris un catalogue archivé.

- [x] Écrire RED : round-trip des trois formats, noms Unicode, états pausés/countdown/repos ; anciennes archives ; unknown fields et IDs dupliqués refusés ; aperçu devenu périmé ; archive >10 Mo ; rollback de restauration.
- [x] Ajouter le test CSV remplaçant un workout mixte : transférer ses blocs vers skillSessions avec la même identité et une origine « ancienne séance » avant suppression ; aucun double enregistrement après CSV répété. Conserver aussi les autonomes et toute configuration.
- [x] Implémenter les whitelists v6 sans supprimer les champs légaux v4/v5. Valider limites : au plus 1000 figures, 100 étapes/figure, 1000 blocs/séance, 10000 sessions, 100000 essais au total ; textes/IDs selon TrainingText, repos et calculs temporels sans overflow.
- [x] Permettre l'export JSON pendant une activité, conformément à la spec : lecture cohérente atomique et état complet ; conserver le blocage d'import si une activité locale est active. Refuser dans une archive deux activités indépendantes actives. Restaurer les instantanés force/support/Skills sans gonfler les résultats ; réconcilier les échéances expirées au prochain refresh. Le CSV reste limité à l'historique de force.
- [x] Assertions de `testCSVPreservesMixedPractice` : comparer les IDs et résultats avant/après CSV, `XCTAssertEqual(after.skillSessions.count, beforeMixedCount + beforeIndependentCount)` ; `testArchiveRoundTrip` : `XCTAssertEqual(decoded.contents, original.contents)` y compris l’activité active.
- [x] Vérifier la sauvegarde de récupération et la restauration complète atomique. Adapter les validations d'activité aujourd'hui terminal-only, sans rendre valides des états contradictoires. Relancer SkillTransferTests et toute la suite host : zéro échec.

## Tâche 5 — Interface, documentation, build et iPhone

**Fichiers :** vues Skills et adaptateur store listés plus haut ; adapter `ProgressionView.swift`, `PlanningView.swift`, `TodayView.swift`, `WorkoutFlowView.swift`, `HistoryView.swift` et la préparation de séance. Aucun nouvel onglet. Garder les vues petites ; extraire les sections plutôt que grossir les écrans existants.

**Interfaces consommées :** tâches 1–4 via TrainingStore ; publier l'activité autonome et l'historique Skills dans les refresh cohérents existants. Fournir les mêmes actions/busy/errors pour autonome et séance liée.

- [x] Relire les références HIG concernées et write-swift avant les vues ; aucune nouvelle librairie ni API incertaine sans prototype.
- [x] Intégrer catalogue/figures suivies, point de départ direct/Not Sure, statuts manuels réversibles, éditeur personnel avec réordonnancement, duplication et archivage confirmé. Choisir les séances concernées lors de l'adoption d'une étape.
- [x] Intégrer Skills au planning avec placement avant/après force, format et configuration propres à chaque bloc. Signaler le doublon L-sit par identité connue du catalogue, jamais en supprimant automatiquement un exercice.
- [x] Brancher pratique et reprise depuis Today/Skills ; présentation de préparation, pause/reprise/fin/skip, détails facultatifs. Une activité existante mène à Resume. Ouvrir les sources uniquement sur action explicite ; pas de chargement réseau.
- [x] Afficher mixed/autonome/ancienne séance sans double comptage ; détails par étape et assistance. Garder Consistency et les statistiques de force indépendants, sans présenter une pratique autonome comme une séance de force accomplie.
- [x] Mettre à jour PROJECT, DESIGN, ROADMAP, TESTING, BUILD et README avec le livré réel ; SECURITY mentionne les liens externes explicites et l'absence de nouveau média privé. Ne pas annoncer la recette appareil comme effectuée.
- [x] Exécuter `swift test --package-path Tests/Host`, `swift format lint --strict --recursive Package.swift Sources Tests/Host/Package.swift Tests/Host/Tests`, puis `python3 -m unittest discover -s Tests/Metadata -v` : zéro échec.
- [x] Exécuter `xtool dev build`, `python3 scripts/build-live-metadata.py`, `xtool dev build`, `python3 scripts/verify-foundation.py` : tous code 0, identité et capacités attendues. Adapter les assertions de schema/version de l'inspecteur si nécessaires, sans les supprimer.
- [x] Faire une revue indépendante ciblée des données/transitions/imports, reproduire puis corriger les problèmes et relancer leurs régressions. Aucun push ni publication.
- [x] Installer via `~/omarchy-apple-dev/device-run.sh` avec les profils/certificats existants ; relever la vraie version installée et effectuer le postflight d'identité. Arrêter sur erreur de signature sans réparer les comptes/profils ; escalader seulement après un blocage sandbox réel.
- [x] Livrer la checklist iPhone : quatre parcours ; création/duplication ; deux séances à volumes distincts ; avant/après force et Stretching off ; pratique libre écran quitté puis relancée ; essais détaillés/repos ; annulation/skip ; sauvegarde/reprise ; liens sans réseau ; Dynamic Type et VoiceOver. Attendre le retour physique avant un autre jalon.

## Progression et limites de validation

- [x] Spécification approuvée ; sources d'intégration inspectées ; plan relu contre ses exigences.
- [x] Revue utilisateur du plan et méthode native approuvées.
- [x] Tâches 1–5 et preuves RED/GREEN/build consignées ici au fil du travail.
- [x] Installation et postflight de la 1.2.0 (78).
- [ ] Retour physique iPhone sur les parcours et interactions.

Les commandes ci-dessus sont des vérifications à exécuter, pas des résultats acquis. Les nombreuses modifications préexistantes rendent un commit global inadapté : aucun commit ni push automatique dans ce plan. Aucun test SwiftUI hôte ne remplace les interactions réelles sur iPhone.

### Preuves finales de développement, 23 octobre

Sauvegarde initiale : chemin dans `/tmp/sport-skills-run-path` ; 50 fichiers locaux sauvegardés avec empreintes. Les 86 documents Markdown ont été inventoriés et lus. Baseline : 284 tests hôte réussis. Les API nouvelles ont d’abord échoué à compiler ; les véritables RED comportementaux ont ensuite couvert la perte de suivi liée à SQLite REPLACE, l’export actif/CSV, le repos expiré et la chronologie des événements.

Les cinq tâches sont implémentées. La revue indépendante a identifié deux problèmes importants : validation insuffisante des états actifs importés et chronologie entre blocs/force/support. Ils ont été reproduits et corrigés avec régressions. Les descriptions des extensions, le matériel dans la préparation et le format suggéré des nouveaux blocs ont également été complétés.

Validation finale : **312 tests hôte, zéro échec**, lint Swift strict sans sortie, six tests de métadonnées réussis et `git diff --check` sans erreur. Journaux : `/tmp/sport-skills-final-tests.log`, `/tmp/sport-skills-final-lint.log`, `/tmp/sport-skills-120-metadata-tests.log`. La version **1.2.0 (78)** est compilée par xtool ; métadonnées Live Activity régénérées, réintégrées puis inspectées par `verify-foundation.py`, tous code 0. Inspection : app/widget arm64, identité configurée `com.raaaton.sport`, permissions déclarées conservées. Journaux : `/tmp/sport-skills-120-build.log`, `/tmp/sport-skills-120-embedded.log`, `/tmp/sport-skills-120-inspection.log`.

Le build précédent 1.1.0 (77) a été installé, avec une seule app Sport, identité effective et signature/capacités comparées à la baseline. Deux tentatives de réinstallation de 1.2.0 (78) ont atteint le transfert à 100 %, puis sont restées bloquées sans vérification finale ni message de signature. Après arrêt propre des deux processus, l’inventaire iPhone confirme encore 1.1.0 (77), profil validé. Après redémarrage complet et reconnexion par l’utilisateur, le troisième déploiement a réussi (code 0, installation et vérification 100 %). Postflight : une seule app Sport **1.2.0 (78)**, même identité effective, même signataire et mêmes entitlements que la baseline, `ProfileValidated=true`. Preuves : `/tmp/sport-skills-120-install-reboot.log` et `/tmp/sport-skills-120-postflight.json`. Journaux : `/tmp/sport-skills-120-install.log` et `/tmp/sport-skills-120-install-retry.log`. Aucune recette physique n’est déduite d’une compilation ou d’une installation.

Choix conservés après revue : maîtrise manuelle, définitions figées dans les séances, statistiques de force distinctes, aucune Live Activity Skills, échéances persistées avec état dérivé. Limite connue : modifier la configuration puis l’étape d’un bloc non démarré utilise deux sauvegardes ; une rare erreur de la seconde peut laisser la configuration modifiée et requiert de réessayer après le message d’erreur. Aucun commit, push ou publication. Détails d’exécution et revue : `/tmp/sport-skills-progress.md` et `/tmp/sport-skills-review/report.md`.

Recette iPhone encore à effectuer par l’utilisateur : quatre parcours et extensions ; création/duplication d’une figure ; deux séances à volumes distincts ; placement avant/après force avec Stretching désactivé ; pratique libre quittée puis reprise ; essais et repos ; annulation/skip ; sauvegarde/reprise ; liens externes ; Dynamic Type et VoiceOver. Attendre ce retour avant le prochain jalon.
