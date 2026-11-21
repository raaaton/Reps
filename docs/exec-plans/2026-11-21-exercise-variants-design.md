# Progressions par exercice et fusion ciblée L-sit / V-sit

Date : 21 novembre 2026. Statut : conception acceptée par la demande « implémente mtn », implémentée et livrée en 1.5.9 (131). Voir l’ExecPlan associé pour les preuves et la recette physique restante.

## Objectif

Donner à chaque exercice des variantes manuelles, avec réglages, objectifs et
historique indépendants. Réunir les deux exercices personnels L-sit et V-sit sous
le parent actif L-sit sans perdre leurs résultats ni leurs identités historiques.
Le cahier des charges du message utilisateur est la référence fonctionnelle.
Les modifications préexistantes de docs/ROADMAP.md restent intactes.

## État constaté

- Dépôt réel Reps, HEAD 9792aed, version documentée 1.5.8 (130).
- TrainingSchema.swift migre actuellement jusqu’au schéma SQLite 21.
- TrainingExercise porte actuellement les réglages ; TrainingSchedule porte les
  affectations, le nombre de séries et des objectifs indexés par exercice.
- WorkoutExercise.id identifie une occurrence historique ; definition.id porte
  l’identité catalogue capturée. Séries, repos et décisions référencent l’occurrence.
- workout_exercises impose UNIQUE(workout_id,catalogue_id). La validation des
  transferts impose aussi l’unicité des exercices catalogue dans une séance.
- LatestExerciseGoals recherche par catalogue_id. GoalRepository ajoute notamment
  le contexte scheduleID et setCount. Tous ces chemins doivent intégrer la variante.
- TrainingArchive est en version 10 ; TrainingCSV écrit le format 2 et lit 1/2.
- Les identifiants réels personnels et la présence éventuelle d’une séance active
  ne sont pas encore établis. Le seed « l-sit » ne prouve pas l’identité actuelle.

## Choix d’architecture

Approche retenue proposée : une entité ExerciseVariant explicite, rattachée au
parent, et une correspondance persistante des anciennes identités. Cela représente
correctement les variantes sans transformer artificiellement chacune en exercice.
Deux alternatives écartées : dupliquer les exercices garderait un faux catalogue ;
utiliser seulement un libellé dans les séances mélangerait encore les objectifs.

ExerciseVariant contient un identifiant stable, exerciseID, nom, mesure décimale
facultative, unité libre facultative, réglages de répétitions/durée et état archivé.
La variante de base reprend les réglages existants sans intervention utilisateur.
La mesure se stocke en texte décimal canonique, sans arrondi flottant ni conversion
d’unité ; virgule et point sont acceptés à la saisie. Une mesure exige une unité
non vide. Sans mesure, aucune unité n’est stockée. Le nom seul n’est jamais une clé.
Les mesures 15 et 20 d’une même progression représentent deux identités distinctes.

Les nombres de séries restent portés par les affectations au programme. Les
objectifs persistés sont indexés par variante et contexte de programme existant,
avec conservation des règles actuelles liées au nombre de séries. Changer la
variante sélectionnée ne supprime pas les objectifs des variantes précédentes.
Une requête sans résultat pour une variante ne retombe jamais sur une autre.

## Séances et instantanés

Chaque affectation sélectionne une variante ; les anciennes prennent la base.
Au démarrage, une occurrence capture l’identité de variante, son nom, sa mesure,
son unité, ses réglages et les objectifs de son contexte de programme.
Le changement en séance ne modifie que cet instantané et recharge les objectifs
de la variante choisie, en conservant le nombre de séries de l’affectation.

Le verrouillage est contrôlé dans le repository : choix interdit dès le lancement
de la première série, y compris son compte à rebours. Une marque persistante évite
qu’une correction supprimant une série ne déverrouille ensuite le choix. Une
séance migrée dont une série a déjà commencé ou a été enregistrée est verrouillée.
Un redémarrage ne déverrouille pas l’occurrence.

Renommer ou archiver une variante ne réécrit ni instantané ni décision historique.
Une variante archivée reste consultable et exportable ; elle n’est plus proposée
pour de nouvelles sélections. Une affectation existante vers cette variante reste
lisible et demande un choix explicite avant une nouvelle séance, sans remplacement
silencieux. La variante de base reste disponible afin de garantir un repli valide.

## Consultation et interface native

L’éditeur d’exercice contient une section Progressions et un éditeur natif par
variante. Les champs ont des libellés persistants ; mesure et unité sont distinctes.
Le clavier numérique facilite la mesure sans interdire le collage avec point ou
virgule ; l’unité utilise un clavier texte. Le nombre de séries n’y est pas édité.

Le programme et la préparation d’un exercice offrent un menu natif de variantes.
En séance, le contrôle devient indisponible au verrouillage, avec une explication
accessible. Les vues de séance et d’historique montrent le libellé capturé.

Progression sélectionne la dernière variante effectivement entraînée selon l’ordre
chronologique existant, puis une variante affectée au programme, puis la base.
En cas de plusieurs programmes sans historique, utiliser un ordre stable des
programmes et rendre le contexte visible. Les variantes archivées avec historique
restent dans le menu. Courbes, détails, précédentes performances et objectifs
reçoivent tous explicitement l’identité sélectionnée.

Référence consultée : HIG Pickers et Text fields, 21 novembre 2026.
Apple recommande les menus déroulants pour de courtes listes et des champs munis
de libellés. Le choix précis des écrans et la règle de verrouillage sont propres
à Reps. Conserver composants natifs, Dynamic Type, VoiceOver, couleurs et quatre
onglets existants. Aucune nouvelle animation décorative.

Sources :
- https://developer.apple.com/design/human-interface-guidelines/pickers
- https://developer.apple.com/design/human-interface-guidelines/text-fields

## Migration et fusion personnelle

1. Acquérir une copie cohérente des données d’entraînement par le workflow USB
   existant, sans lire le coffre privé. Conserver une copie de récupération avant
   toute écriture ; ne pas copier seulement le fichier principal d’une base WAL.
2. Examiner cette copie en lecture seule : identités actives et archivées,
   affectations, objectifs, occurrences et état des séances. Établir un manifeste
   ciblé contenant les deux identifiants exacts et leurs correspondances.
   Aucun identifiant personnel n’est inventé à partir du seul nom ou du seed.
3. Migrer transactionnellement les exercices, y compris archives et identités
   présentes seulement dans les anciens historiques, vers leurs variantes de base.
   Préserver les instantanés déjà capturés et les contextes d’objectifs.
4. Exécuter la fusion ciblée dans une transaction distincte complète, après
   vérification du manifeste et absence de séance active concernée. Si elle est
   active, différer la fusion sans bloquer la migration générale des variantes.
5. Réactiver le parent L-sit avec son identité vérifiée ; créer/réutiliser sa base
   nommée L-sit et rattacher la variante V-sit à l’ancien exercice V-sit. Remplacer
   ses affectations de programme en conservant objectifs et nombres de séries.
6. Conserver catalogue_id historique comme identité d’origine et utiliser la
   correspondance vers parent/variante pour la lecture canonique. Ne pas remplacer
   brutalement les deux catalogue_id par le même parent : cela violerait l’unicité
   lorsqu’une séance contient les deux. Les occurrences, séries, repos et décisions
   conservent leurs identifiants ; leurs anciennes définitions restent capturées.
7. Si un programme contient déjà les deux exercices, préserver les deux entrées,
   leur ordre et leurs nombres de séries via des affectations à identité propre.
   Cela impose de faire évoluer l’ancienne clé (schedule_id,exercise_id), et les
   dictionnaires associés, plutôt que de supprimer ou d’écraser une affectation.
8. Inscrire le marqueur d’exécution et la correspondance dans la transaction de
   fusion. Une seconde ouverture/exécution n’ajoute aucune variante ni occurrence.
   Un échec annule toute la fusion. La copie de récupération reste conservée.

La correspondance et le marqueur doivent survivre à une sauvegarde/restauration.
Une restauration ancienne peut réintroduire les identités d’origine : le manifeste
doit permettre leur normalisation idempotente, sans fusion d’identités inconnues.
Aucun écran ni outil général de fusion n’est ajouté.

## Transferts et édition historique

Incrémenter le format d’archive et celui du CSV, en conservant la lecture des
versions précédentes. Les formats anciens produisent les variantes de base de
façon déterministe. Étendre validation de forme JSON, limites, références et
unicités aux variantes et affectations ; ne pas relâcher globalement les contrôles.
Le CSV conserve identité et libellé capturé, y compris nom, mesure et unité.
La sauvegarde portable reprend ces données d’entraînement sans modifier la crypto.
Les restaurations doivent conserver les variantes archivées et les correspondances.
L’édition historique préserve la variante capturée et les identifiants existants ;
les corrections ne recalculent pas automatiquement les objectifs futurs, conformément à la règle produit existante de docs/DESIGN.md. La lecture et toute suggestion restent filtrées sur la variante concernée.

## Périmètre des fichiers pour le futur plan

- RepsCore : TrainingModels/TrainingSchema, nouveaux modèle et repository de
  variantes et migration ciblée ; RepsRepository, WorkoutRepository/Models/Reading,
  HistoricalWorkoutEditing et écritures de séances manuelles.
- Objectifs : ExerciseGoal, GoalRepository, LatestExerciseGoals,
  GoalReconciliation, PrimaryExerciseGoal et analyses/suggestions dépendantes.
- Transferts : TrainingTransferModels/Repository/Validation, TrainingJSONShape,
  TrainingCSV, PortableBackupRepository et compatibilité des formats.
- Reps : TrainingStore, Settings/ExercisesView et PlanningView/WorkoutExerciseRow,
  écrans Workout, History et Progression, composants PreviousPerformance/Goal.
- Tests host : variantes, migration SQLite, fusion ciblée, objectifs, séances,
  édition historique, archives, JSON/CSV et sauvegarde portable.
- Documentation et livraison : README, DESIGN, BUILD, SECURITY et ExecPlan ;
  versions app/widget/inspection cohérentes. ROADMAP préexistant préservé.

## Vérifications et livraison prévues

Tests d’échec puis réussite sur : indépendance des variantes et contextes,
mesure absente, unités libres, virgule/point, changement avant première série,
verrouillage persistant, programme inchangé, renommage et archivage.
Fixtures de fusion : L-sit archivé, historiques séparés et séance avec les deux,
programme contenant les deux, décisions/repos conservés, séance active différée,
réouverture, deuxième exécution, rollback injecté et restauration ancien format.
Comparer les ensembles d’identifiants et nombres de séries avant/après fusion.
Tester les allers-retours JSON, CSV, sauvegarde portable et édition historique.

Commandes du projet : swift test --package-path Tests/Host ; swift format lint
--strict --recursive Package.swift Sources Tests/Host/Package.swift Tests/Host/Tests ;
tests Python Metadata ; xtool dev build ; génération/embarquement des métadonnées
et inspection unsigned selon scripts/release-local.sh.

Livraison prévue en 1.5.9, build au moins 131 après vérification de la dernière
livraison réelle. Avant installation : identité, capacités, certificat et profils.
Utiliser ~/omarchy-apple-dev/device-run.sh, arrêter sur erreur de signature ou de
provisioning, contrôler la version et l’identité après installation. Aucun push
ni publication GitHub demandés. Commit dédié après vérifications.

Recette iPhone nécessaire : menus natifs, grands textes, VoiceOver, choix en
séance/verrouillage, anciennes séances L-sit/V-sit et objectifs séparés. Ne pas
présenter une compilation ou une installation comme une validation physique.

## État d’avancement

- [x] Lire les documents et identifier les contraintes d’unicité et d’objectifs.
- [x] Écrire une proposition de conception couvrant les cas explicitement demandés.
- [ ] Relecture de la conception selon le workflow brainstorming.
- [ ] Écrire l’ExecPlan d’implémentation détaillé.
- [ ] Obtenir et lire la copie de sauvegarde ; établir le manifeste réel.
- [ ] Implémenter, tester, vérifier, livrer et recueillir le retour iPhone.
