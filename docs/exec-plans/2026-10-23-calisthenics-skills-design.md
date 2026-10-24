# Sport — Skills de calisthénie

Date : 23 octobre 2026. Statut : spécification approuvée par l’utilisateur le 23 octobre 2026 (« c bon »), avant implémentation. Ce document remplace les arbitrages ouverts de la synthèse pour le périmètre ci-dessous ; il ne transforme pas les autres idées en engagements.

## 1. Résultat attendu et décisions

Choisir une figure, trouver son point de départ, retrouver un bloc prêt à pratiquer dans une séance, enregistrer sans saisies répétitives et savoir quoi reprendre ensuite. Les skills restent une pratique guidée et modifiable, sans certification de la technique par l'app.

Décisions utilisateur déjà prises :
- Quatre parcours préchargés : Handstand, L-sit, Planche et Front Lever.
- Consignes et repères hors ligne, liens facultatifs vers les démonstrations sources ; aucune vidéo embarquée.
- Création de skills personnels avec étapes.
- Ajout aux séances, au début par défaut.

Choix proposés dans cette spécification : pratique autonome incluse, quatre onglets conservés, nouvelle destination Skills depuis Progress, interface et contenu préchargé en anglais comme le reste de Sport. Aucune nouvelle dépendance. Swift 6.4, SwiftUI, SQLite, SwiftPM/xtool, iOS 26 minimum.

## 2. Catalogue et parcours

Une figure possède un nom, une présentation, des indications de matériel/préparation et des étapes ordonnées. Une étape contient son nom, une explication originale courte, les principaux repères observables, un exemple de pratique, le matériel et éventuellement un lien source HTTPS. L'ordre guide la lecture sans bloquer l'accès.

Parcours initiaux :

| Figure | Parcours principal proposé | Prolongements facultatifs |
| --- | --- | --- |
| Handstand | Appui inversé progressif au mur et sortie contrôlée ; alignement au mur ; décollages contrôlés des pieds ; entrées et équilibre libre | Handstand Push-up ; Press to Handstand |
| L-sit | Appui avec pieds soutenus ; tuck ; extension partielle ; une jambe tendue ; L-sit complet | V-sit |
| Planche | Planche lean ; tuck avec assistance ; tuck ; advanced tuck ; straddle ; full planche | Full Planche Push-up |
| Front Lever | Tuck ; advanced tuck ; straddle ; full front lever | Front Lever Pull-up |

La préparation précède le travail, mais ne constitue pas un niveau à débloquer. Les alternatives assistées restent possibles sans prétendre qu'elles ont toutes un rang universel. Pour chaque prolongement, inclure une fiche explicative et un bloc configurable praticable (tenue ou répétitions), sans inventer un programme avancé complet ni un nouveau catalogue caché. La figure principale reste identifiable.

Sources éditoriales :
- Handstand : https://gmb.io/handstand/
- L-sit : https://gmb.io/l-sit/
- Planche : https://gmb.io/planche/
- Front Lever : tutoriel de l'auteur FitnessFAQs https://www.youtube.com/watch?v=AGhb8V8M758

Ces méthodes servent de références, pas de consensus ni de prescription universelle. Rédiger les consignes en propres mots ; ne copier ni texte long ni média. Pas de test maximal, durée garantie d'apprentissage ou seuil chiffré universel de passage. Les liens s'ouvrent uniquement après action explicite dans le navigateur externe ; aucune prévisualisation réseau ni lecteur embarqué. Les consignes restent utilisables sans réseau.

Les quatre parcours sont présents une seule fois après migration, avec identifiants stables. Une sauvegarde/restauration et un redémarrage ne doivent pas recréer de doublons ni annuler des changements personnels.

## 3. Consulter, choisir et personnaliser

Progress → Skills montre les figures suivies et le catalogue. Une fiche présente le point actuellement travaillé, la roadmap, les dernières pratiques, le matériel et les actions Practice, Add to Workout, Edit/Duplicate selon le contenu.

Choisir directement une étape ou choisir « Not Sure » pour lire la première proposition et l'essayer. Aucun examen ni déclaration automatique de maîtrise des étapes antérieures. Toute étape reste consultable et praticable. Une étape courante est un choix de travail, pas un certificat.

États personnels explicites par étape : non renseigné, première réussite, maîtrisé régulièrement. Ils sont déclarés manuellement et réversibles ; aucun mauvais résultat ni absence ne rétrograde automatiquement. Changer d'étape courante propose ensuite d'adopter cette étape pour les affectations futures sélectionnées, en conservant leurs réglages propres. Refuser garde les séances telles quelles.

Créer un skill demande un nom et au moins une étape nommée. Consignes, matériel, préparation et repères sont facultatifs pour un skill personnel. Ajouter, renommer, réordonner et retirer des étapes dans un formulaire natif. Dupliquer un parcours préchargé produit une copie personnelle indépendante ; les ajustements de durée ou d'assistance n'imposent pas une duplication.

Les parcours préchargés restent des références ; leurs copies personnelles peuvent être éditées. Archiver une figure la retire des choix futurs et de ses affectations après confirmation nommant les séances affectées. Les enregistrements actifs et historiques gardent leurs instantanés. Les éléments terminés ne disparaissent pas quand une étape est supprimée d'une copie personnelle.

## 4. Séances et pratique autonome

L'éditeur du planning reçoit une section Skills : ajouter une figure et une étape, choisir le format, ajuster les réglages, réordonner les blocs et les retirer. Le groupe Skills est au début par défaut ; il peut être placé après la force. L'ordre des blocs Skills est libre. Les réglages sont propres à chaque affectation de séance.

À la préparation de séance, afficher les blocs prévus, leur matériel et leur durée indicative lorsqu'elle est connue. La préparation adaptée au skill est présentée avant sa pratique ; l'échauffement de force existant reste avant les exercices de force. Ne pas considérer l'un comme remplacement silencieux de l'autre. Pour une figure personnelle sans préparation renseignée, ne pas inventer de consignes spécifiques.

Un bloc peut être commencé, mis en pause, repris, terminé ou passé. Passer ne retire pas le bloc du planning et ne produit aucune réussite. Modifier sa variante ou son travail pendant la séance s'applique uniquement à l'instantané actif ; le planning se modifie dans son éditeur. Annuler la séance conserve la pratique déjà enregistrée.

Practice depuis une fiche lance le même bloc sans séance de force fictive. Une seule activité est active à la fois : si une séance ou pratique existe déjà, proposer de la reprendre plutôt que d'en démarrer une seconde. Les pratiques autonomes ne modifient pas les rappels du planning de force et ne sont pas comptées comme séances de force accomplies dans Consistency.

Les séances de force existantes conservent leur comportement quand aucun skill n'est affecté. Il reste possible de retirer tous les blocs d'une séance ; une séance planifiée vide n'est pas rendue valide artificiellement. Les pratiques exclusivement Skills se lancent via Practice dans cette première version.

## 5. Formats, chronométrage et historique

Trois formats :
- Free Practice : bloc libre ; durée de repère initiale 5 minutes, modifiable ou sans limite. Ce chiffre est une valeur d'interface, pas une prescription. Fin explicite, aucune fin automatique au repère. Début/Pause/Resume/Finish ; aucune saisie entre essais. La durée enregistrée mesure le temps de pratique, repos spontanés compris, pauses explicites exclues.
- Timed Holds : essais chronométrés avec préparation 3–2–1, fin explicite, durée réelle par essai ; objectif de durée facultatif. Le nombre d'essais et le repos sont configurables par séance.
- Repetitions : saisie du nombre effectivement réalisé par série ; nombre de séries et repos configurables. Un objectif de répétitions reste facultatif et modifiable.

Par défaut, le travail proposé utilise Free Practice pour commencer sans exiger de choisir des objectifs inconnus. Passer au suivi détaillé demande les réglages applicables ; aucune série ou performance n'est fabriquée. Les exemples et consignes du parcours fournissent le guidage, même en pratique libre. Les prolongements dynamiques proposent le format Repetitions.

Le bilan peut être enregistré sans note, meilleure tenue ni répétitions ajoutées. Les résultats facultatifs saisis sont déclaratifs et libellés comme tels. La durée du bloc n'alimente jamais les statistiques des tenues. Les performances sont regroupées par étape et contexte d'assistance ; pas de record fusionnant tenue au mur et tenue libre.

Persister l'état de pratique, ses horodatages et ses pauses avant de confirmer une action. Reprendre correctement après mise en arrière-plan, fermeture ou relancement. Les repos détaillés utilisent des échéances persistées, sans compteur indépendant. Les Live Activities existantes restent dédiées aux repos pris en charge ; aucune nouvelle promesse de minuteur Skills visible sur écran verrouillé.

L'historique d'une séance montre ses blocs Skills, sans les additionner aux volumes de force ou aux durées de tenue des exercices existants. Les pratiques autonomes apparaissent avec un libellé distinct et sont aussi consultables depuis la figure. Un exercice existant tel que L-sit n'est ni déplacé ni recréé automatiquement. À l'ajout d'un bloc L-sit dans une séance contenant déjà cet exercice, signaler ce chevauchement sans supprimer l'exercice. Pas de rattachement rétroactif des anciennes séries.

## 6. Données, erreurs et compatibilité

SQLite reste l'autorité. Distinguer définitions de parcours, suivi personnel, affectations aux séances et instantanés de pratique. Les identifiants des étapes et affectations sont stables ; les noms ne servent pas de clés. Catalogue, étapes, états et résultats sont validés et enregistrés transactionnellement.

Étendre la migration de la version réellement présente (schema16 au moment de la lecture) et l'archive JSON (v5 actuellement) avec compatibilité des anciennes archives sans Skills. Une restauration complète d'une ancienne archive initialise le catalogue préchargé et un suivi vide, sans importer de faux résultats ; import CSV de l'historique de force conserve la configuration et les pratiques Skills existantes. Export inclut définitions personnelles, suivi, affectations, pratiques et instantanés actifs ; les limites et validations actuelles restent applicables. Toute restauration conserve son aperçu, sa confirmation et sa sauvegarde de récupération.

Aucune modification d'étape, de figure ou de planning ne réécrit une pratique commencée ou l'historique. Suppression/archivage et restauration sont atomiques. En cas d'échec de sauvegarde, ne pas afficher un résultat comme enregistré ; permettre de réessayer sans doublonner. Refuser une commande périmée sur une autre étape ou une activité déjà terminée.

Aucun changement au coffre, à ses clés, au provisioning ou aux capacités de l'app. Aucun compte, backend, analytics, téléchargement automatique ni nouvelle permission.

## 7. Présentation et validation

Choix Sport : section Skills dans Progress, fiches natives et formulaires, quatre onglets conservés, pas d'arbre graphique, de badges ou de pourcentage de maîtrise. Recommandation Apple consultée : « Prefer text in lists and tables. » (HIG Lists and tables). Application : roadmap en liste avec détails accessibles. Autre recommandation : « Postpone nonessential setup/customization and provide reasonable defaults. » (HIG Onboarding). Application : créer avec nom/étapes et approfondir ensuite. Ces règles ne dictent ni le catalogue ni la programmation sportive.

Respecter Dynamic Type, VoiceOver, Reduce Motion, tailles de contrôle et apparences existantes. Aucun renseignement essentiel ne repose sur la couleur ou un retour sonore seul. L'iPhone reste l'autorité pour l'interface.

Vérifications exigées avant livraison :
- Tests du catalogue idempotent, des validations, migrations et round-trips JSON anciens/nouveaux ; import CSV préservant les Skills.
- Séries/volumes indépendants par séance ; changement ponctuel et adoption explicite d'une étape ; snapshots après édition/suppression du catalogue.
- Bloc libre avec pauses, essais détaillés, repos, reprise après relancement et double action ; fin/skip/annulation sans perte ni double comptage.
- Séance mixte avant/après force, pratique autonome, séance sans Skills inchangée ; séparation statistiques force/Skills.
- Lint Swift strict, tests hôte et métadonnées applicables, xtool dev build et inspection du bundle.
- Installation via le workflow USB existant après identité/capacités ; arrêt sur erreur de signature/provisioning. Pas de push GitHub sans autorisation explicite.
- Recette iPhone : choisir/créer, ajouter au planning, pratiquer, reprendre après interruption, consulter l'historique, vérifier liens/hors ligne, Dynamic Type et VoiceOver.

## 8. Suite du travail

Après revue de ce document : écrire l'ExecPlan dans docs/exec-plans/ conformément au projet, puis faire relire ce plan avant exécution conformément au skill brainstorming. Les modifications locales préexistantes sont conservées. L'implémentation et sa recette forment le prochain jalon ; aucune autre fonctionnalité du brainstorming n'est ajoutée implicitement.
