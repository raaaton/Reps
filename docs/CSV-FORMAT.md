# Données d’entraînement — CSV Sport v1 et archive JSON v1

Sport0.7.4 : remplacement complet de l’historique CSV demandé et confirmé par l’utilisateur ;124tests hôte/lint/build réussis, installationUSB et postflight réussis ; recette iPhone attendue. Formats CSV/JSON inchangés ; voir ExecPlan cumul/remplacement.

## Photos privées

**Les photos privées sont exclues de l’export CSV.** Aucun média, miniature, chemin photo ou clé ne figure dans ces formats. L’interface affiche cette exclusion avant l’export, dans l’aperçu et après enregistrement. Le JSON proposé ici est une sauvegarde d’entraînement uniquement : le futur coffre ne fait pas partie de ce format. Une clé biométrique et une autorisation iOS ne sont jamais transférées.

## Fichier de test

[Sport-demo-2026.csv](fixtures/Sport-demo-2026.csv) :117séances fictives,752séries,13janvier–11octobre2026. Noms DEMO et IDs demo-2026-. Répétitions et durées, charges0/3,9/4,5/5,1kg, Feelings6,5/7,5/8 et quelques anciennes notes7,3/7,9, séances partielles et jours neutres. Certaines compositions sont connues, d’autres explicitement non renseignées. La copie embarquée dans Sources/Sport/Resources est identique.

Réglages→Import et export→Prévisualiser le CSV de démonstration présente le même fichier. Importer remplace tout l’historique après aperçu et confirmation native centrée, en conservant planning/catalogue/inventaire/objectifs/réglages. Une seconde importation identique est sans effet et conserve la copie avant import précédente. Des versions différentes sous les mêmes anciens IDs remplacent les anciennes ; des IDs dupliqués ou conflictuels au sein du CSV restent refusés. Rien n’est injecté automatiquement. Enregistrer le CSV de démonstration permet d’obtenir le fichier par Fichiers. scripts/generate-test-csv.py le régénère sans vraie donnée personnelle.

## CSV

UTF8 (BOM facultatif à la lecture, présent à l’export), virgule comme séparateur, CRLF ou LF pour les enregistrements, règles de guillemets CSV : un guillemet intérieur est doublé. Les champs multi-lignes sont entre guillemets. 31colonnes dans l’ordre exact ci-dessous ; version1 sur chaque ligne. Ligne set pour une série ; exercise pour un exercice annulé sans série ; workout pour une séance annulée sans exercice. Métadonnées répétées identiques obligatoires. Aucun champ supplémentaire accepté, notamment aucun champ photo.

| Colonnes | Contenu |
| --- | --- |
| sport_csv_version, row_type | 1 et set/exercise/workout |
| workout_id, workout_name, date, status, schedule_id | IDs stables, nom, date grégorienne ASCII YYYY-MM-DD, completed/cancelled, planning d’origine ou manual |
| started_at_ms, ended_at_ms, rest_seconds | Timestamps Unix en millisecondes conservés, repos enregistré ; manual ne prouve pas une durée/repos réel |
| exercise_id, catalogue_id, exercise_name, mode | ID instantané global, ID du catalogue, nom archivé, repetitions/duration |
| set_count, min_reps, max_reps, duration_target_seconds | Définition archivée ; colonnes inutiles pour le mode laissées vides |
| feeling | Note historique0–10 au dixième, champ vide autorisé seulement pour exercice annulé |
| set_id, set_number, repetitions, duration_seconds | ID série, numéro1..N, répétitions positives OU durée positive au millième de seconde |
| weight_kg, completed_at_ms | Lest ajouté au millième dekg, timestamp original |
| components_json, goal_json | Instantanés JSON ; vide=inconnu/absent, []=poids du corps sans composant |
| pending_start_ms, pending_weight_kg, pending_end_ms, pending_components_json | État figé d’une série annulée ; jamais utilisé pour relancer un timer |

Décimales exportées avec point, import décimal accepte point/virgule si le champ reste correctement cité. Les IDs/séries/exercices sont uniques et les numéros de séries sont continus. La date de classement reste indépendante des timestamps après correction historique.

Protection tableur : pour tout texte commençant par apostrophe,=,+,-,@,tabulation, CR/LF ou formule précédée d’espaces, une apostrophe est ajoutée à l’export puis retirée à la lecture Sport. Ce mécanisme est réversible ; l’interopérabilité réelle avec Numbers/Excel doit être vérifiée sur appareil. CSV reste un export d’historique, **pas une sauvegarde du planning/réglages/catalogue/inventaire**. Les formats CSV arbitraires et les archives d’anciennes apps ne sont pas pris en charge.

## JSON

Envelopeformat sport.training,version1,includesPrivatePhotos=false,createdAt etcontents(configuration,notifications,workouts). Schéma fermé, clés inconnues refusées. Encodage compact trié ; données typées, compositions/objectifs et catalogue/planning/réglages conservés. Seules les séances terminales sont admises, pas d’ancienne LiveActivity/notification de fin ni d’état d’autorisation iOS. Un transfert pendant une séance active est refusé : terminer ou abandonner explicitement d’abord.

Restauration JSON = remplacement des données d’entraînement avec aperçu et alerte centrée explicite. La copie avant import est sauvegardée dans import_recovery dans la même transaction ; elle est exportable dans l’app, sans fichier temporaire extérieur. Réimporter cette copie permet de revenir à cet état après la même confirmation. Une seule copie précédente est conservée ; chaque import effectif la remplace. CSV et JSON sans différence ne doivent pas écraser cette copie. Le remplacement CSV conserve également une copie JSON complète de l’état précédent dans la même transaction ; import valide vide peut vider l’historique après confirmation explicite. Aperçu périmé ou séance active refuse la mutation. Les photos et clés du futur coffre ne sont pas concernées.

## Limites et garanties à vérifier

10MiB de fichier/dataset sérialisé,100000séries,10000séances,1000exercices/inventaire,7jours de planning. Le résultat d’un import doit rester exportable sous la même limite avant commit. Validation avant écriture ; transaction, comparaison de l’état de l’aperçu et rollback en cas d’échec. Dates non canoniques, mode/métrique incohérents, conflits dans le fichier ou JSONprivé/versioninconnue refusés. Les nouvelles corrections sont couvertes par la suite124tests et le build iOS réel ; le rendu, Fichiers et les gestes restent à confirmer sur iPhone.


0.11.1 propose séparément un fichier .sporttest contenant un échantillon synthétique chiffré. Ce n’est ni un CSV/JSON ni une sauvegarde de vos données. Les formats d’entraînement restent identiques et excluent toujours les photos privées ; aucun remplacement de données n’est permis dans la preuve.


Depuis0.11.2 : Import and Export contient seulement Import from Files et Export to Files. Choisir CSV(historique), JSON(entraînement/configuration) ou Before Last Import(JSON si disponible) dans le menu Export. Import/preview/confirmation/remplacement inchangés. Les commandes de démo et l’échantillon.sporttest sont retirés du produit ; fichiersCSV de test locaux conservés. Les références à ces boutons dans les paragraphes précédents sont historiques.


## Échauffements et étirements — CSV v2 (0.12.0)

Les exports ajoutent la colonne finale `support_json` (version de ligne 2). Elle contient l’instantané borné des étapes d’accompagnement, leurs cibles, départs et résultats réellement enregistrés ; les photos privées restent exclues. Ce JSON est identique sur les lignes d’une même séance et validé avant import. Les séries de travail restent les seules lignes `set` et les seules données de progression. La lecture de CSV v1 à 31 colonnes reste supportée, sans créer d’échauffements ou d’étirements rétroactifs. Les anciennes versions de Sport ne savent pas importer CSV v2. Les archives internes de récupération conservent aussi l’accompagnement et continuent d’exclure le coffre.


## Export direct — 18 octobre 2026

Choix utilisateur : Export to Files enregistre directement une archive JSON de toutes les données actuelles d’entraînement et de configuration, sans choix de format ni choix Before Last Import. Les photos privées restent exclues et cette exclusion est affichée. Import CSV et JSON reste compatible avec aperçu/confirmation et transactions. La copie avant import reste stockée en interne mais n’est plus sélectionnable dans l’export ; les textes ne promettent plus son export via un menu supprimé. Les paragraphes précédents décrivent l’historique des versions. Finir/annuler la séance active avant export reste requis par le format existant.


## Configuration par workout — 19 octobre 2026

Les nouveaux exports JSON utilisent la version2 de sport.training. Chaque schedule contient setCounts (nombre positif par exerciseID) et goals (objectifs par exercice affecté). Les versions1 restent importables : affectations initialisées depuis les anciens nombres et objectifs du catalogue, sans modifier les instantanés historiques. Les objectifs incompatibles restent conservés pour révision. IDs dupliqués refusés avant construction des dictionnaires. Les anciennes versions de Sport ne restaurent pas ces JSONv2. Les CSV historiques v1/v2 et leur remplacement de l'historique restent inchangés ; ils ne remplacent pas la configuration par workout. Photos et clés toujours exclues.


## Body Weight — JSONv3

Les nouveaux exports sport.training version3 contiennent contents.bodyWeights : tableau d'objets id/dayKey/grams (date canoniqueYYYY-MM-DD unique, poids positif en grammes entiers). Les notifications ajoutent weightEnabled, weightWeekday (ISO1=lundi...7=dimanche) et weightMinutes (minute du jour) ; jour/heure requis si activé. Fichiers v3 incomplets, doublons ou valeurs invalides refusés avant mutation.

Lecture v1/v2 maintenue : la provenance ancienne est interne, jamais un champ modifiable du JSON. À la prévisualisation, mesures et rappel actuels sont conservés puis intégrés au jeu final ; le reste de la restauration garde sa sémantique. L'import CSV remplace uniquement l'historique des séances et conserve poids/rappel. Nouveaux JSONv3 restaurent aussi les pesées/rappel ; la copie recovery et le garde contre les données modifiées incluent ces éléments. Photos privées et clés restent exclues. Les anciennes versions de Sport ne restaurent pasJSONv3.


Build70: JSON restore preview reconciles future goals against the imported exercise definition and each workout's set count, matching the accepted exercise-edit policy. Exact saved load compositions are retained for explicit review if unavailable. Historical and active workout snapshots are not normalized; CSV history calculations and format remain unchanged. JSON remains v3.


## JSON training v4 — per-set duration goals

New exports use sport.training version4. ExerciseGoal adds optional `durationsMS` for duration tracking: positive multiples of100ms, exactly one per configured goal set, with repetitions absent. Missing durationsMS retains the legacy configured duration/untimed behavior. Definition.durationSeconds remains program configuration; learned actual durations do not rewrite it. Goal payloads in configuration and historical workout snapshots preserve the array through JSON export/preview/restore/recovery. Strict shape/validation rejects malformed targets before writes. Versions1/2/3 remain readable; v1/v2 preserve body-weight provenance as before. Version4 requires the same body-weight/reminder fields asv3. Older apps rejectv4. CSV remains a history format and does not gain future-goal fields.
