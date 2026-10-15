# Jalon 5 — Historique, lest et progression

> Exécution directe avec executing-plans, tests avant domaine et une revue indépendante finale. Plan global accepté ; « parfait, on continue » valide 0.4.3 et autorise ce jalon. Aucun jalon 6/7 commencé.

## Objectif et spécification

PROJECT.md §6–9, PLAN-SPORT-NATIF.md jalon5, anciens plans métier weight-system/progression-engine/history-2. Ceux-ci sont des références fonctionnelles seulement, pas des instructions Expo ou preuves Swift. Ajouter l’édition des performances terminales, historique par exercice, objets lestés et sélecteur de charges avec compositions figées, recommandations déterministes. SQLite local reste la source de vérité.

## Architecture et contraintes

Swift 6.4, SwiftUI, SwiftPM, xtool Linux, iOS26 minimum, SDK installé27.1. Sport/com.raaaton.sport et extension existante inchangés. Aucun backend, nouvelle dépendance, permission, capacité ou certificat. Migration v3→v4 transactionnelle additive ; anciens grammes et dates conservés. Pas de Git exploitable : travailler dans le workspace autorisé, pas de reset/init/worktree/commit ; conserver copies de sources de comparaison dans /tmp et ledger ici.

- Sac fixe3000g et trois objets initiaux900g/2100g/1500g, chacun une fois. Équipement en grammes entiers, prix/score/calories absents.
- Charges uniques croissantes :0,3000,3900,4500,5100,5400,6000,6600,7500g initialement. Compositions sérialisées indépendantes de l’inventaire. Un lest chronométré est capturé avant3–2–1 ; les anciens efforts actifs et leurs charges restent compatibles.
- Historique éditable conserve statut, identité et planning d’origine ; une séance abandonnée ne devient pas terminée. Exercices archivés restent éditables depuis leurs instantanés. Brouillon Annuler sans écriture, sauvegarde atomique, refus si une autre modification a changé la séance. Anciennes compositions conservées si leur charge n’a pas changé, autrement provenance inconnue explicitement.
- Ordre historique et dernière performance : day_key d’abord, puis timestamp/rowid. Filtre construit depuis l’historique, incluant les exercices supprimés du catalogue.
- Répétitions : séries exactes et métriques cohérentes, toutes au maximum actuel, Feeling≤70/100. Proposer la plus petite charge disponible strictement supérieure au maximum réellement enregistré ; aucune charge fictive si indisponible. Durées : comparer à un objectif défini, jamais d’augmentation automatique ; sans objectif, données insuffisantes.
- UI : listes/formulaires/navigation natifs, Annuler/Enregistrer et + ; confirmation centrée partout, gestes de suppression conservés. Pas de carte décorative ni diagramme artificiel. Recommandations dans Aujourd’hui, préparation, séance et résultat ; onglet Progression demeure le futur coffre.

## Tâches et interfaces

### 1 — Inventaire et instantanés

Fichiers : TrainingSchema.swift, nouveaux WeightInventory.swift/WeightRepository.swift, WorkoutModels.swift/WorkoutRepository.swift/ManualWorkout.swift ; Tests/Host/Tests/SportCoreTests/WeightInventoryTests.swift.

Interfaces : WeightItem(id,name,grams,isEnabled) ; LoadComponent Codable ; AvailableLoad(grams,components) ; WeightInventory.loads(items:) throws ; TrainingSnapshot.weightItems ; repository.saveWeightItem/deleteWeightItem ; beginSet/recordSet ajoutent load optionnel compatible avec les anciens appels.

- [x] Test migration v3 indépendante avant implémentation : version4, anciennes séries/charges intactes, seed unique après réouverture.
- [x] Tester charges initiales, déduplication/désactivation, précision/overflow, CRUD/reprise, charge capturée et composition conservée après suppression d’objet ; puis implémenter.
- [x] `swift test --package-path Tests/Host` : suite sans échec. `xtool dev build` compile le domaine.

### 2 — Historique et progression

Fichiers : nouveau HistoricalWorkoutEditing.swift/Progression.swift, ManualWorkout.swift, WorkoutRepository.swift ; nouveaux HistoryUpdateTests.swift/ProgressionTests.swift.

Interfaces : repository.updateHistoricalWorkout(draft, original:WorkoutSession, now,calendar) ; exerciseHistory(exerciseID:)→[ExercisePerformance] ; historyExercises()→[TrainingExercise] ; Progression.assess(target,previous,loads,feelingTenths:)→ProgressionAssessment. ManualWorkoutSet.sourceID permet de préserver les compositions inchangées.

- [x] Tests avant implémentation : édition atomique, refus séance active/périmée/future/donnée invalide, archivé conservé, statut abandonné, rollback, ordre dates et fraîcheur après édition/suppression.
- [x] Tests seuil70/71, séries incomplètes/données absentes, durées distinctes, charges mixtes et aucune supérieure ; implémenter.
- [x] Suite hôte verte ; lint et build xtool réels.

### 3 — Interface native

Fichiers : nouveaux Features/Weights/*, History/ExerciseHistoryView.swift, Shared/ProgressionRow.swift ; TrainingStore, SettingsView, TodayView, WorkoutFlowView, WorkoutControls, TimedSetPreparation, ManualWorkoutEditor et HistoryView.

- [x] Réglages Lest CRUD avec charge/composition consultable, sélecteur natif en séance, lest avant décompte inchangé.
- [x] Historique Séances/Exercices, édition préremplie et détails des compositions ; recommandations dérivées partagées, actualisation après changements.
- [x] Vérifier API par compilation SDK ; lint, suite complète, metadata et bundle.

### 4 — Livraison et recette

- [x] Revue indépendante finale sur sources et tests ; corriger risques de perte/altération de données avant livraison.
- [x] Version0.5.0(13) app/extension ; xtool build→génération metadata→build→6 tests metadata→inspection unsigned.
- [x] Préflight identité/certificat, USB device-run.sh autorisé puis postflight profils app/enfant. Arrêter sur erreur provisioning.
- [x] Documentation résultats réellement exécutés, limites et checklist iPhone ; attendre confirmation avant jalon6.

## Review focus

1. Migration et INSERT positionnels après colonnes ajoutées : aucune série existante perdue ; tester fixture v3 et reprise v2.
2. Inventaire modifié pendant série chronométrée : instantané capturé conservé ; tester suppression/relance/fin.
3. Historique d’un exercice supprimé : édition utilise le snapshot historique ; conserver statut et autres séances.
4. Deux éditeurs ou save après suppression : refus atomique sans recréer ni écraser ; comparer original à l’état stocké.
5. Grand inventaire et entiers extrêmes : calcul borné, erreur visible sans mutation ; pas de gel exponentiel.

## Ledger / décisions

Préflight interfaces : sélecteur→AvailableLoad→snapshot du domaine ; historique→instantanés indépendants ; recommandations→mêmes charges calculées ; types partagés cohérents. Autorisation d’exécution préexistante conservée, pas de nouvelle gate de permission de skill. Git et scripts de ledger dépendant de commits inapplicables ici : conserver ce ledger et copie des sources avant changements.

Ruling révisé après revue : borne de4096 charges distinctes et budget200000 opérations pondérées par longueur de composition, y compris les totaux déjà rencontrés. La seule limite du nombre de charges ne bornait pas le coût des objets de même poids. Erreur visible avant mutation, invitant à désactiver certains objets ; aucune limite arbitraire très basse sur leur nombre.

Recette prévue : modifier/retirer/activer un objet et vérifier les charges ; sélectionner un lest reps/durée, enregistrer et revoir sa composition après modification d’inventaire ; modifier une ancienne performance (y compris exercice supprimé), Annuler sans changement, vérifier recommandation/date après édition/suppression ; terminer/reprendre une séance et tester repos/Live Activity ; gros texte, clair/sombre, VoiceOver. Ces scénarios ne sont pas démontrés par Linux.


Task1 domaine livré : migration RED comportemental (version3≠4 et table absente), puis GREEN ; nouveaux tests API écrits avant implémentation ont d’abord échoué à compiler sur symboles absents, ce n’est pas un RED comportemental. Suite56 tests sans échec et build domaine réussi. Migration4 additive, snapshots JSON, compositions capturées avant chrono ; imports/oldcalls compatibles, INSERTs adaptés.
Task2 domaine livré : tests écrits avant APIs, premier échec de compilation sur APIs absentes (pas preuve comportementale RED), puis suite62tests sans échec. Édition archive/statut/périmée/future, ordre calendaires et règles progression couverts. Timestamps d’origine conservés lors d’édition de date ; day_key reste la date autoritative, aucun déplacement d’heure inventé.
Task3 UI compilée réellement : xtool code0,14,12s. Revue indépendante en cours, interface physique non encore testée. Sélecteur de charge initialement poids du corps, recommandation lisible mais jamais appliquée automatiquement. Les anciennes charges au gramme près restent intactes ; valeurs manuelles de l’historique libres. Les recommandations de résultat apparaissent en fin de séance, pas sur chaque vieille séance consultée.

Task4 revue finale : revue indépendante effectuée selon executing-plans/requesting-code-review. Trois P2 reproduits en tests comportementaux (suite65,3 échecs attendus), corrigés puis suite65 sans échec : clés de date grégoriennes respectant le fuseau fourni ; progression fondée sur séries réellement corrigées malgré snapshot d’origine ; borne de travail des composants pour nombreux objets identiques. Remarque mineure de provenance traitée : Composition non renseignée pour charge positive sans snapshot. Anciennes clés calendaires conservées faute de marqueur : pas de migration destructive par supposition ; limitation non grégorienne documentée.
Vérifications finales : lint strict code0 ; suite65tests code0 ; build xtool8,55s, génération metadata code0, packaging1,92s code0 ;6tests metadata sans échec et inspection unsigned code0. App/extension0.5.0(13), identités/capacités inchangées.
Préflight code0 : version installée0.4.3, identité effective et certificat existant conformes. Script USB code0 : rebuild1,91s, installation/vérification100%. Sources HelloSport/caches/authentification conservés. Aucun jalon6 commencé.
- [x] Confirmation physique utilisateur de la recette jalon5 ; aucune preuve de fonctionnement SwiftUI/iPhone déduite du build.

Postflight0.5.0 code0 : version13 confirmée directement sur iPhone sous la même identité effective ; profils app/enfant valides, CMS vérifiés, même certificat existant et certificat local inchangé. Une seule extension WidgetKit, aucune permission sensible, App Group ou push. Attendre la confirmation physique du jalon5 avant le jalon6.

Retour du 12 octobre 2026 : « continue au prochain jalon » valide la recette 0.5.0 et autorise le jalon 6. Cela ne constitue pas une mesure spécifique VoiceOver ou un test de tous les cas limites.
