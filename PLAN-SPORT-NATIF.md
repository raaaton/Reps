# Sport natif — audit et plan proposé

> Mise à jour du 15 octobre : échauffement unique et étirement ajoutés sur demande explicite, livrés en 0.12.0 (48) après 169tests/lint/revue/xtool et installation USB ; retour physique attendu. [Plan courant](docs/exec-plans/2026-10-15-warmups-stretches.md). Les anciennes conclusions de périmètre ci-dessous sont historiques.

> Périmètre actuel, 13 octobre 2026 : sauvegarde privée portable abandonnée à la demande de l’utilisateur. Anglais/SF Symbols et transferts simplifiés livrés ; audit global et corrections installés en0.11.3(37), réglage de couleur d’accent ajouté en0.11.4 puis retiré sur demande en0.11.5(39), cyan fixe et courbes sans conditions. Recette finale et couleurs sur iPhone attendues, aucun nouveau jalon prévu. Les paragraphes suivants conservent le plan et les décisions historiques ; voir le [rapport actuel](docs/audits/2026-10-13-global-audit.md).


Audit initial : 11 octobre 2026. Plan accepté, réorganisé le 12 octobre 2026 à la demande de l’utilisateur pour ajouter Progression et Animations/haptics. Jalons 1–5 confirmés sur iPhone ; jalon6 installé en0.6.1 et jalon7 autorisé explicitement. Progression0.7.0(16) installée,96tests+6metadata/lint/build/revue/postflight réussis, attente de confirmation physique avant8 ; scénarios iOS individuels du6 non rapportés restent à vérifier.

## Objectif

Créer Sport en Swift/SwiftUI pour remplacer les workflows personnels d'entraînement utilisant Raccourcis, Rappels, Notes, Photos et Numbers. Application locale, hors ligne, sans compte, backend, analytics ou runtime JavaScript. Compilation et installation USB depuis Linux avec xtool. Chaque jalon reste non validé jusqu'au retour explicite de l'utilisateur après essai sur iPhone.

## Audit documentaire

Lecture des 23 documents qui décrivent Sport : README.md, PROJECT.md, AGENTS.md, .agents/PLANS.md et les 19 plans de .agents/exec-plans/. L'inventaire récursif a aussi identifié 55 fichiers Markdown de skills génériques sous .agents/skills/ ; ce sont des guides d'outillage/design, pas le cahier des charges Sport, et leur lecture intégrale n'a pas été effectuée. Aucun dossier généré ou de dépendances n'a été utilisé comme spécification.

Les fichiers docs/DESIGN.md, docs/SECURITY.md, docs/BUILD.md et docs/ROADMAP.md cités dans les anciens documents sont absents. Le format ExecPlan existe sous .agents/PLANS.md, contrairement au chemin .agent/PLANS.md cité par certains documents. Aucun dépôt Git exploitable ni source d'application n'est présent dans le workspace Sport actuel. Les mentions « implémenté », « tests réussis » ou « validé sur iPhone » concernent l'ancienne application Expo et ne valident aucun élément de la future app Swift.

### Spécifications retenues

- Quatre onglets : Aujourd'hui, Historique, Progression, Réglages. Navigation, listes, formulaires, sélecteurs, feuilles, SF Symbols, typographie et matériaux natifs ; respect des zones sûres, du clavier, du mode sombre et de Dynamic Type. Défilement adapté au contenu, sans recopier les contournements React Native.
- Planning initial : mardi Legs, samedi Push, dimanche Pull + Abs. Exercices : Bulgarians, Push-ups, Pike Push-ups, Chin-ups, L-sit. Les trois séances peuvent être déplacées, renommées, désactivées et recomposées avec un ordre choisi ; au maximum une séance par jour. Exercices et repos par défaut modifiables dans Réglages.
- Préparation explicite, démarrage, reprise d'une séance active, saisie de séries de répétitions ou de durée, charge par série, Feeling de 0 à 10. Une seule séance active. Une séance déjà terminée aujourd'hui ne redémarre que sur confirmation, en conservant la précédente.
- Machine à états explicite : inactif, séance/série active, série terminée, repos, exercice terminé, séance terminée ou annulée. Actions rapides idempotentes. Annuler une séance ne supprime pas les séries enregistrées.
- Repos initial de 180 secondes, pause/reprise et « Passer le repos ». Échéance absolue persistée, temps restant conservé en pause, restauration après fermeture/suspension. La dernière série passe au Feeling ; aucun ancien repos terminé ne doit masquer l'étape suivante. Annuler le repos et abandonner la séance ne sont pas deux boutons équivalents à présenter.
- SQLite comme source de vérité, transactions et migrations versionnées. Historique conservé après redémarrage ; ordre des exercices/séries et valeurs historiques figés malgré les changements de planning, objectifs ou inventaire.
- Historique par séance et par exercice ; ajout manuel, modification et suppression confirmée. Dates calendaires réelles, pas de séances futures. Une saisie manuelle ne verrouille pas artificiellement la séance planifiée. Les performances manuelles alimentent les mêmes calculs de progression.
- Progression initiale livrée au jalon 5 : séries complètes au maximum prévu avec Feeling ≤ 7. Évolution livrée au nouveau jalon 7 : objectif précis de prochaine séance, adoption explicite du prochain lest disponible quand toutes les séries atteignent le maximum et Feeling < 8 ; saisie numérique par pas de 0,5, sans arrondir l’historique. Durées évaluées séparément, aucune recommandation inventée pour données incomplètes ou séance annulée.
- Lest : sac fixe de 3 000 g, poids du corps à 0 g, objets initiaux de 900 g, 2 100 g et 1 500 g. Gestion des noms/poids/activation/suppression. Combinaisons uniques en grammes, triées ; charge proposée strictement supérieure à la plus forte charge de la performance précédente. Aucun poids fictif si aucune combinaison supérieure n'existe. Instantané de composition par série, indépendant de l'inventaire futur. Historique manuel autorisant d'anciennes charges absentes de l'inventaire.
- Rappels locaux opt-in : heure facultative à la minute par séance ; horizon glissant de 28 jours, sans rappel pour une séance déjà commencée à cette date. Photo mensuelle le premier du mois à 06:00 par défaut, heure modifiable. Gestion du refus de permission, resynchronisation et liens vers Aujourd'hui/Progression sans contenu privé.
- Coffre : déverrouillage Face ID explicite, clé AES-256 aléatoire protégée dans le Keychain pour cet appareil et le jeu biométrique courant ; CryptoKit AES-GCM, originaux et miniatures chiffrés. Galerie par date/mois, import Photos et caméra, consultation/suppression, export explicite confirmé vers Photos. Nettoyage des données déchiffrées, fichiers temporaires protégés, aucune clé/photo/chemin privé dans les logs. Une clé inaccessible ne doit jamais être remplacée automatiquement. Réinitialisation destructive distincte et confirmée.
- Live Activities : compte à rebours natif, exercice/prochaine série, retour à la séance, pause/reprise persistée. Dernière exigence visuelle : icône seule en compact, REST/PAUSE sans icône redondante en développé/écran verrouillé, espacement suffisant, un bouton Pause/Reprendre, aucun Stop. Fin locale programmée « Repos terminé », sans serveur.
- App Intents/Raccourcis utiles et export/synchronisation Rappels restent optionnels. Sauvegarde/restauration complète des données Sport et CSV lisible sont désormais prévus au jalon 10, après le coffre pour couvrir aussi les médias privés. Import d’anciennes apps/fichiers externes reste un périmètre distinct à préciser. Aucune suppression automatique des données dans les anciennes apps.

## Constats techniques vérifiés

- Swift --version : Swift 6.4, cible hôte x86_64-unknown-linux-gnu.
- xtool --version : commit f0a1f90efdbb0dc023e276ff529da92618da7a87.
- xtool sdk status : SDK Darwin installé, variante slim, epoch=2, darwinTools=1.1.0, oam=1.3.0.
- SDKSettings.json du SDK iPhoneOS installé annonce **27.1**, et non 27.0. Aucune mise à jour ou réinstallation n'a été effectuée.
- ~/Projects/HelloSport n'existe pas. Le squelette a été retrouvé dans /home/raton/Documents/Code/iOS/HelloSport : Package.swift, xtool.yml, Sources/HelloSport avec App et ContentView SwiftUI.
- Configuration existante : swift-tools-version 6.0, iOS 17 minimum, produit bibliothèque HelloSport, bundleID com.example.HelloSport. Ce sont les fichiers de départ à adapter, pas à remplacer par un projet Xcode.
- Le script /home/raton/omarchy-apple-dev/device-run.sh existe et a été lu. Son mode USB normal appelle xtool dev run, donc il compile, provisionne/signe et installe : il ne doit pas être lancé pendant l'audit.
- xtool dev build permet une compilation sans signature par défaut ; --sign est une option séparée.
- La documentation Appex.md des sources de la version locale de xtool décrit bien un produit bibliothèque supplémentaire, une entrée extensions/product/infoPath dans xtool.yml et un plist WidgetKit.
- L'interface ActivityKit du SDK installé contient la requête locale avec start et alertConfiguration. Cela prouve la présence de l'API, pas son fonctionnement sur l'iPhone.
- Aucun build, test de domaine, déploiement, contrôle du contenu de l'iPhone ou test Face ID n'a été exécuté pendant cet audit.

## Conflits et décisions proposées

1. **Ancienne stack** : les instructions Expo/TypeScript/npm/CI/SideStore sont remplacées par la demande actuelle Swift/SwiftUI/SwiftPM/xtool. Le produit et les règles métier sont conservés. Les contrôles TypeScript deviennent des tests Swift et de vraies compilations iOS.
2. **Emplacement de travail** : proposition de reprendre le squelette retrouvé dans le workspace Sport en conservant HelloSport local intact. Ne pas déplacer/supprimer son code ni ses caches. La copie/adaptation de configuration se fera seulement au jalon 1.
3. **Version minimum** : iOS 26 minimum proposé, conformément à la dernière spécification Live Activities. Le SDK installé reste celui réellement enregistré. Le seul appareil de référence est l'iPhone de l'utilisateur.
4. **Feeling** : PROJECT.md évoque une valeur possible par série ; les plans de séance/progression utilisent une valeur décimale par exercice. Proposition : Feeling par exercice, conformément au fonctionnement détaillé documenté.
5. **Objectifs initiaux** : 4 x 8–12 est présenté comme exemple puis adopté par un ancien plan. Proposition provisoire : quatre séries et 8–12 répétitions pour les exercices à répétitions, quatre séries pour L-sit sans inventer sa durée cible ; réglages modifiables au jalon 2.
6. **Confidentialité à l'arrière-plan** : conflit historique tranché explicitement le 13 octobre : verrouillage immédiat à la sortie/background, aperçu masqué dès inactive. Protection limitée aux vues du coffre, sans écran bloquant sur les autres onglets.
7. **Anciennes données** : aucune base personnelle ni fichier Numbers/Notes à importer n'est fourni. Construire leur remplacement ne constitue pas une migration. Définir séparément un import si nécessaire avant de retirer les anciens workflows.
8. **Signature** : com.raaaton.sport est l'identifiant configuré définitif ; contrôler aussi l'identifiant effectif après le traitement xtool, qui peut appliquer un préfixe d'équipe. Aucune promesse de mise à jour en place d'une ancienne app Expo signée sous un autre identifiant. Aucune révocation de certificat ni opération de réparation automatique de provisioning.

## Architecture proposée

Critère transversal confirmé : expérience aussi proche que possible d'une application Apple native. Composants système, hiérarchie sobre, navigation/gestes familiers, Dynamic Type et matériaux natifs ; vérifier cette qualité à chaque jalon sans la déduire de l'utilisation de SwiftUI.

SwiftUI pour toute l'interface, code organisé par fonctionnalité sous Sources/. Un module de domaine Swift testable sur Linux contient les transitions de séance/repos, calculs de charge, progression et calendrier. Un accès SQLite isolé porte les migrations et transactions ; aucune dépendance externe prévue initialement. Les adaptateurs iOS portent UserNotifications, ActivityKit/AppIntents, Keychain/LocalAuthentication, CryptoKit et Photos/caméra. Une extension WidgetKit possède son produit SwiftPM et sa configuration xtool/plist explicites.

Éviter une architecture dépendante d'App Groups avant preuve que la signature actuelle les permet. Éprouver le LiveActivityIntent exécuté dans le processus de l'app, avec accès à la même base, avant d'en faire une hypothèse d'intégration. La vue WidgetKit reçoit un instantané ActivityKit et ne devient jamais propriétaire du timer.

## Jalons et critères d'acceptation

### 1 — Base Sport compilable et installable

- Vérifier le build du squelette sans signature avec xtool dev build ; respecter le périmètre de permissions si le dossier/cache est hors workspace.
- Adapter ses vrais fichiers dans Sport, conserver la structure Sources/, définir Sport et com.raaaton.sport, créer les quatre onglets et la navigation native minimale.
- Mettre à jour les documents de référence pour la nouvelle stack et écrire l'ExecPlan détaillé de ce seul jalon.
- Compiler Sport et inspecter le bundle produit : identifiants, nom affiché, architecture, plist et absence de configuration de signature inattendue.
- Avant le premier déploiement : demander explicitement confirmation que **HelloSport a été supprimée de l'iPhone**, jamais du disque Linux. Seulement ensuite lancer le script USB.
- Test utilisateur : lancement, quatre onglets, navigation, présentation claire/sombre et gros texte. Aucun historique, coffre ou timer annoncé comme disponible.

### 2 — Planning, réglages métier et persistance

- SQLite, migrations, données initiales idempotentes ; éditeurs des séances/exercices/objectifs/repos. Préserver les réglages lors des relances.
- Tests du planning, collisions de jours, ordre, validation et migrations ; compilation xtool.
- Test utilisateur : modifier le planning et les objectifs, fermer/rouvrir, vérifier la conservation et Aujourd'hui.

### 3 — Séance complète et repos fiable

- Préparation, démarrage/reprise, séries, Feeling, récapitulatif, abandon confirmé, verrou de séance terminée et redémarrage explicite.
- Repos 180 s configurable, pause/reprise/skip, restauration par échéance et prévention des doublons. Historique permettant de revoir les séances enregistrées. Retouches explicitement demandées après 0.3.0 : ajout/suppression manuels avancés du jalon 5, Préparer plus visible et hiérarchie de séance améliorée ; recette supplémentaire avant jalon 4.
- Tests des transitions, transactions, échéance, fermeture/reprise et annulation sans perte ; compilation xtool.
- Test utilisateur : séance complète, app en arrière-plan, pause/reprise, dernière série, abandon, relance et conservation. Signalement explicite des limites de feedback en arrière-plan tant que le jalon natif n'est pas intégré.

### 4 — Faisabilité native ActivityKit et signature

- Prototype minimal dans la même app Sport : extension WidgetKit déclarée, LiveActivityIntent, compte à rebours et pause/reprise reliés au repos existant, puis demande de fin programmée.
- Vérifier produits, .appex embarquée, plist, signature et capacités nécessaires avant installation. Aucun nouvel identifiant d'app principale ni App Group ajouté sans justification vérifiée.
- Tester sur iPhone l'affichage, l'action suspendue et le déclenchement à échéance. Ce jalon valide une intégration minimale, pas le rendu final.
- En cas de blocage : conserver la séance utilisable, rapporter l'erreur exacte et proposer une alternative concrète à approuver (par exemple retour à l'app pour les contrôles, ou notification locale pour la fin). Ne pas déclarer cette alternative équivalente à la demande initiale.

### 5 — Historique complet, lest et progression

- Historique par exercice/séance et édition d’une performance existante ; conservation des dates, valeurs et instantanés. Ajout/suppression manuels avancés au jalon 3 sur demande explicite du 11 octobre 2026.
- Inventaire des objets, combinaisons en grammes, sélecteur de charge et recommandations selon les critères documentés.
- Tests des seuils, charges mixtes, absence de charge supérieure, modification d'inventaire sans réécriture du passé, mises à jour/suppressions et progression recalculée ; compilation xtool.
- Test utilisateur : saisir/éditer une ancienne performance, sélectionner les charges, changer un objet et vérifier que l'historique reste identique.

### 6 — Rappels et Live Activities finales

- Rappels locaux opt-in par séance et mensuels, permissions et resynchronisation ; suppression du rappel du jour quand une séance démarre.
- Finaliser le rendu ActivityKit validé au jalon 4 et sa gestion complète : pause/reprise, skip, échéance, abandon, réconciliation après relance, absence de doublons.
- Tester calendrier, changements d'heure et de planning, refus de permission et événements périmés ; compilation xtool.
- Test utilisateur : réception et ouverture des rappels, rendu compact/minimal/développé/verrouillé, boutons, fin en arrière-plan et nettoyage des activités.

### 7 — Progression guidée, visualisation et séance simplifiée

Dépendance : jalon 6 confirmé sur iPhone. Références : décisions du 12 octobre dans PROJECT.md §21 et docs/ideas/2026-10-12-progression-visualization-backup.md. Pas de démarrage sur la seule approbation de cette réorganisation.

- Définir et persister un objectif concret pour la prochaine séance de chaque exercice, à partir d’une performance complète et comparable. Présenter la proposition, son motif, puis Adopter cet objectif ou Garder mon objectif ; adoption explicite, modifiable, sans réécrire le passé ni une séance en cours. Pour l’actuel 4×8–12 : quatre séries atteignant au moins 12, Feeling strictement inférieur à 8, proposer la plus petite charge disponible supérieure à la plus lourde réellement enregistrée. Pas de palier fictif ou nouvelle difficulté imposée pour les durées ; leur règle reste distincte et à préciser avant implémentation.
- Nouvelle saisie Feeling numérique de 0 à 10 par pas de 0,5 ; préserver les anciennes notes exactes. Aucun qualificatif ajouté. Un ancien Feeling de 7,9 satisfait la nouvelle règle, 8,0 non ; les anciennes performances peuvent être relues sans modifier leurs valeurs.
- Simplifier la saisie : objectif/lest prévus visibles, charge réelle conservée entre les séries, résultat précédent à proximité. Une action explicite peut confirmer Objectif réalisé ; aucune répétition ou note sauvegardée automatiquement depuis une suggestion.
- Préparer le sac avant la séance : compositions prévues, objets nécessaires et changements de charge. Équipement absent = alternative contextuelle explicite, aucune modification silencieuse de l’objectif ou de l’inventaire.
- Corriger immédiatement une série enregistrée pendant la séance sans quitter le suivi ; correction transactionnelle, sans relancer le repos, changer les timestamps ou détruire une autre série. Recalculer les repères et recommandations depuis les données corrigées.
- Repenser Progression avec graphiques par exercice, comparaisons pertinentes et grille d’assiduité inspirée de GitHub, en gardant quatre onglets. Swift Charts à prototyper avec xtool avant intégration. Lest, répétitions à charge comparable et durées séparés ; accès aux données exactes, aucune estimation de force maximale ou score global. Prévoir l’accès distinct au coffre du jalon 8 ; les statistiques ne déverrouillent jamais les photos.
- Grille : jour avec séance terminée, marque distincte pour performance partielle, jour sans entraînement neutre ; détail au toucher, plusieurs séances du même jour regroupées. Les jours de repos ne cassent pas une streak. Ne pas inventer des séances manquées ou un taux de conformité à partir du planning actuel pour des dates où son état passé n’est pas connu.
- Récapitulatif : durée totale réellement écoulée du lancement à la fin, incluant repos, saisies, pauses et arrière-plan ; bilan factuel des changements mesurés et prochain objectif adopté. Pas de durée fictive pour une saisie manuelle sans chronologie réelle.
- Exclusions : notes techniques, versions courtes, qualificatifs Feeling, adaptation automatique de programme et diagnostic de stagnation. Maintien/reprise reste une option non confirmée, hors périmètre obligatoire ; ne pas l’implémenter sans décision ultérieure.
- Avant exécution : ExecPlan découpé en tâches domaine/objectifs, parcours de saisie/correction, visualisation et bilan. Tests des seuils 7,5/8 et anciens décimaux, charges mixtes/indisponibles, adoption/reprise, correction pendant repos, conservation des données, comparabilité, dates/grille et durée après suspension. Lint et compilation xtool réels, installation puis recette iPhone : prochaine séance, matériel, correction, graphiques/grille, résumé, VoiceOver, grand texte et régressions Live Activities. Validation utilisateur obligatoire avant jalon 8.

### 8 — Coffre photo sécurisé (ancien jalon 7)

- Preuve minimale Face ID/Keychain/CryptoKit synthétique validée sur iPhone en0.9.5 par l’utilisateur. Verrouillage immédiat et aperçu masqué confirmés.
- Implémenter en0.10.0 le chiffrement des originaux/miniatures/métadonnées dans SQLite dédié, galerie datée, Photos/caméra, export confirmé, suppression, verrouillage immédiat et erreurs de clé sans régénération automatique.
- Revue de sécurité et tests des corruptions, refus/cancellation biométrique, verrouillage pendant une opération, échecs disque/base et temporaires. Aucun vrai média privé utilisé dans les logs ou captures de validation.
- Compilation xtool puis tests iPhone obligatoires : Face ID réel, app switcher, import/export, permissions et relances. Ne pas modifier les biométries personnelles pour un test sans accord spécifique.

### 9 — Animations et haptics cohérents

Actualisation du 13 octobre : sur demande explicite, ce jalon est avancé avant le coffre (8). Il harmonise les flux existants ; les futurs écrans du coffre reprendront ces conventions lors de leur propre validation. Les composants système/accessibilité restent une exigence à chaque jalon, pas un travail repoussé à la finition.

- Inventorier les transitions/haptics existants et conserver les motifs natifs de navigation, feuilles, contrôles et menus. Compléter seulement les changements d’état utiles : série validée, progression des séries, passage série/repos/exercice, objectif adopté, sélection de données et récapitulatif final.
- Animations courtes, discrètes et interrompables ; aucune cascade décorative, faux verre, confettis, compteur de résultats inventés ou mouvement à chaque seconde du chrono. Maintenir stabilité du clavier et du contenu, interactions disponibles ; ne pas attendre une animation pour écrire en base.
- Haptics système cohérents avec leur signification, après succès réel de la sauvegarde/validation. Harmoniser décompte et expiration déjà présents, éviter les doublons avec les contrôles système ; retours ajoutés désactivables. Aucune information uniquement tactile, aucun engagement sur la vibration pendant suspension sans preuve native.
- Respecter Réduire les animations, VoiceOver, Dynamic Type et les préférences système. Vérifier le coffre pendant une transition interrompue ou background : aucune photo déchiffrée exposée, aucun délai de verrouillage ajouté pour une animation.
- Avant exécution : ExecPlan, inventaire des événements et prototypes API incertaines. Tests seulement pour logique/événements le nécessitant (ne pas tester une capture de texte qui reproduit le code), lint et xtool build réels. Installation USB puis recette physique : fluidité, intensité, répétitions rapides d’actions, interruptions, clair/sombre, Reduce Motion, haptics coupés et confidentialité. Validation iPhone obligatoire avant jalon 10.

### 10 — Sauvegarde complète, finition et intégrations optionnelles (ancien jalon 8)

- Todo ajoutée le 13 octobre : passer toute l’interface en anglais, y compris messages d’erreur, confirmations, notifications, Live Activities/WidgetKit et libellés d’accessibilité. Conserver les contenus saisis par l’utilisateur et les identifiants/formats de données.
- Remplacer les commandes textuelles courantes telles que « Enregistrer » et « Modifier » par des SF Symbols natifs adaptés (par exemple coche et crayon), avec libellés VoiceOver explicites en anglais et zones tactiles accessibles. Vérifier la compréhension des actions sur iPhone ; conserver une explication textuelle lorsque l’icône seule rend l’action ambiguë.
- Sauvegarde/restauration versionnée via Fichiers de toutes les données Sport : historique, instantanés, planning, inventaire, réglages, objectifs et médias du coffre. Format portable chiffré des données privées à prototyper/revoir indépendamment ; ne pas exporter une clé Keychain biométrique ni des photos en clair. CSV lisible dans Numbers en complément, jamais présenté comme une sauvegarde complète.
- Import : validation version/intégrité et aperçu avant écriture, sauvegarde de l’état précédent, restauration explicitement confirmée et atomique. Fusion de deux historiques, formats d’anciennes apps et politique de reprise d’une séance active à préciser avant leur exécution ; ne pas rejouer un vieux repos/une alerte, restaurer les permissions comme si elles étaient accordées, ou écraser des données silencieusement.
- Tester aller-retour, ancienne/nouvelle version de format, doublons/conflits, erreurs et corruptions, rollback ; essais physiques Fichiers, Face ID/Photos et récupération. Si le format complet est bloqué par le SDK/xtool, expliquer précisément et proposer une solution avant de changer le périmètre.
- Audit global accessibilité, ergonomie, états vides/erreurs, performance et régressions ; documentation finale du workflow local et des limites.
- App Intents/Raccourcis et export vers Rappels seulement si confirmés utiles, chacun après prototype de compilation et découverte sur iPhone.
- Validation utilisateur du parcours complet avant de considérer Sport comme remplaçant les anciens outils.

## Procédure commune à chaque jalon

1. Ne réaliser que le périmètre autorisé ; tenir l'ExecPlan à jour.
2. Exécuter les tests Swift du domaine concerné et les régressions applicables. Compiler réellement avec xtool dev build ; conserver les caches.
3. Inspecter les changements de bundle/capacités et préparer une liste concrète de tests iPhone. Une compilation n'est jamais une preuve du rendu ou du fonctionnement natif.
4. Déployer avec le script USB seulement quand les préconditions sont remplies. En cas d'erreur de signature/provisioning, arrêter et rapporter le message exact avant toute opération risquant de changer les certificats.
5. Rapporter modifications, commandes et résultats réels, limitations et actions manuelles.
6. Arrêter jusqu'à la confirmation explicite du fonctionnement sur iPhone. Un retour négatif rouvre ce même jalon ; il n'autorise pas le suivant.

## Références techniques consultées

- Documentation de la version locale de xtool : Documentation/xtool.docc/Appex.md, dans son checkout de cache ; configuration officielle des produits et extensions.
- Documentation Apple : https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- API de planification : https://developer.apple.com/documentation/activitykit/activity/request(attributes:content:pushtype:style:alertconfiguration:start:)
- API locale : interface ActivityKit.swiftinterface du SDK iPhoneOS installé.

## État de sortie

Le jalon 1 est validé sur iPhone, suivi dans docs/exec-plans/2026-10-11-native-foundation.md. La suppression de HelloSport de l’iPhone a été confirmée ; son code local reste préservé. Le jalon 2 est suivi dans docs/exec-plans/2026-10-11-native-planning.md. Installer chaque build prête avant la review utilisateur, puis attendre sa confirmation physique avant le jalon suivant. Les ambiguïtés du coffre et des intégrations seront tranchées avant leurs jalons.

## Réorganisation du 12 octobre 2026

Demande explicite : ajouter les deux jalons Progression et Animations/haptics à des positions logiques. Ordre restant : 6 Rappels/Live Activities → 7 Progression → 8 Coffre (ancien 7) → 9 Animations/haptics → 10 Sauvegarde/finitions (ancien 8). Les numéros des rapports et ExecPlans historiques sont conservés comme références à l’ordre de leur création. Aucun code, schéma, build ou installation effectué pour cette modification documentaire ; jalon 6 encore en attente de confirmation physique. Les ExecPlans d’implémentation sont à préparer avant l’exécution de chaque futur jalon.

## Livraison du jalon7

L’autorisation explicite « implémente le prochain jalon » a lancé Progression après la réorganisation. Sport0.7.0(16) installée par USB sous la même identité et le même certificat, avec contrôles locaux/revue/postflight consignés dans docs/exec-plans/2026-10-12-guided-progression.md. Durées : conserver la configuration, lest manuel, aucune hausse automatique (décision utilisateur). Attendre le fonctionnement réel sur iPhone avant8. La validation physique détaillée du rendu n’est pas déduite des builds.

## Extension import/export autorisée après0.7.0

Demande suivante : avancer import/export avant les jalonscoffre/animations afin de testerProgression surunCSVfictif volumineux. Sport0.7.1(17) installé avec107tests etcontrôlesbuild/metadata/lint/inspection/postflight réussis ; mêmeidentité/certificat. CSVhistorique photosprivéesexplicitementexclues etJSONentraînement/configuration avecconfirmation/copieprécédente. Archivesmédiasprivéschiffrés etfinitionsrestentau10 aprèscoffre. RecetteiPhone du7 etde sonextensionattendue ; aucun8/9 commencé. Référence docs/exec-plans/2026-10-12-training-import-export.md etdocs/CSV-FORMAT.md.

Correctiondu7aprèsretouriPhone :0.7.2(18) livré. Lesamasdepointsparsérie sontremplacésparcourbesparsessionsavecconditionscomparables etrésumés. Aucuneanticipationcoffre/animations ni nouvellepolitiqueprogression ; sourceSQLite/transferts conservés. Recettecourbes utilisateurattendueavantjalons8/9, suivi docs/exec-plans/2026-10-12-session-charts.md.

Retouchedu7après0.7.2 :0.7.3(19)livrée pourbulleaupoint etVolume parséance. Sum(répétitions×lest ajouté),pas depoidscorporelougainforceestimé ; durée statique totale repos exclu. Contrôles118tests+6metadata/lint/build/revue/postflight,mêmeapp/certificat. Recette utilisateurrequiseavant8/9 ; docs/exec-plans/2026-10-12-chart-callouts-volume.md.

Clarification ultérieure du7 :0.7.4(20)installée. L’utilisateur choisit le cumul de volume sur la période affichée et confirme CSV remplace tout l’historique, configuration conservée.124tests+6metadata/lint/xtool/revue/postflight réussis, mêmeidentité/certificat ; aucun import personnel exécuté par l’agent. Copies précédentes protégées même si CSVidentique réordonné. Texte d’état vide à harmoniser ; recette physique attendue avant8/9, suivi docs/exec-plans/2026-10-12-cumulative-volume-csv-replacement.md.

0.7.5(21)livrée aprèsclarification : totals enhaut etresultatsparseance surcourbe/bulle. Reps totalise mêmesfiltres que ses points, Volumetotal touteperiode ; données/transferts inchangés.126tests+6metadata/lint/build/revue/postflight réussis,mêmeidentité/certificat. AttendreconfirmationiPhoneavant8/9 ; docs/exec-plans/2026-10-12-period-summary-session-curves.md.


## Jalon animations avancé — 13 octobre 2026

L’utilisateur demande de réaliser maintenant les animations et haptics, avec sobriété et consommation limitée. Jalon 9 avancé avant 8, version 0.9.0 (22) ; coffre toujours non commencé. [ExecPlan](docs/exec-plans/2026-10-13-motion-haptics.md). Ne pas déduire de cette autorisation une validation individuelle de tous les scénarios iOS antérieurs. Validation physique obligatoire après installation.


## Correction des transitions graphiques — 0.9.1

Retour iPhone du 13 octobre : transitions de période/mesure buggées. Retrait du ressort sur toute la liste ; seul le nouveau graphique apparaît en fondu easeOut de 0,15 s, avec identité propre à la requête. Axes/tracé mis à jour directement, aucune interpolation entre unités ni animation de hauteur des sections. Pickers natifs, valeurs et haptics conservés ; Reduce Motion/VoiceOver désactivent le fondu. [ExecPlan](docs/exec-plans/2026-10-13-chart-filter-motion.md).


### Chargement stable des graphiques — 0.9.2

Correction après retour iPhone : conserver les résultats et leur mesure/période pendant toute actualisation. Le bloc au-dessus de Prochaine séance ne disparaît plus pendant la requête ; les nouveaux résultats/libellés/contexte/sélection sont publiés ensemble. Indicateur en overlay sans ligne supplémentaire ; erreurs gardent le dernier résultat et proposent Réessayer. Réponses périmées/annulées refusées. Le premier chargement et les véritables états vides restent explicites. Calculs, données, haptics et bref fondu conservés ; rendu à confirmer après installation.


### Répétitions compactes — 0.9.3

Tous les tableaux d’objectifs utilisent la même notation : 10·10·10·10 devient4×10, 10·10·9·9 devient2×10 2×9. Seules les valeurs identiques adjacentes sont regroupées pour préserver l’ordre. Objectifs configurés :4×10 ou4×8–12. La vue partagée couvre Aujourd’hui, préparation, séance, propositions/prochaine séance et bilan ; détail et saisie par série restent accessibles, sans fusionner charges/compositions. VoiceOver explicite les groupes d’objectifs. Aucun stockage/format/algorithme de progression modifié. Rendu à confirmer sur iPhone.


Jalon8 commencé après0.9.4, choix utilisateur confirmé : verrouillage immédiat et aperçu masqué. Phase8A installée en0.9.5(27), preuve FaceID/Keychain/AES sur données synthétiques, aucun média réel. 133tests hôte+6metadata/lint/xtool/revue sécurité/USBpostflight réussis. Attendre validation physique avant intégration galerie/imports, selon [ExecPlan](docs/exec-plans/2026-10-13-photo-vault.md).


0.10.0 confirmé fonctionnel sur iPhone par l’utilisateur. Retouche0.10.1(29) explicitement approuvée et installée : piles photo par date, trois poses et comparaison privée de deux dates identiques en pose, reset rouge/SF Symbol, objectifs compacts et personnalisation distincte.140tests/6metadata/lint/xtool/revue indépendante et pré/postflight réussis, même app/certificat. Recette des nouvelles vues attendue avant10 ; [ExecPlan](docs/exec-plans/2026-10-13-vault-comparison-goal-clarity.md).


0.10.3(31) installé : zoom natif de comparaison après bug d’ancrage rapporté sur0.10.2, suppression de piles/photos par appui long confirmé et atomique.142tests/6metadata/lint/xtool/inspection et pré/postflight réussis ; point de revue preview contextMenu corrigé par aperçu neutre. Même app/certificat, attente de recette iPhone. [ExecPlan](docs/exec-plans/2026-10-13-vault-long-press-pinch-anchor.md).


0.10.4(32) installé : archives aussi dans Réglages et purge des anciennes performances explicitement choisie, jours neutres absents de la liste, rubrique Séance et Préparer pleine largeur. Nouvel essai de zoom commun aux deux écrans après retour négatif0.10.3.146tests/6metadata/lint/xtool/revue/inspection/pré-postflight réussis, même app/certificat. Attendre les tests iPhone, sans déclarer le zoom validé ; [ExecPlan](docs/exec-plans/2026-10-13-archives-attendance-zoom.md).
