# Reps — design et interactions

## Corrections0.11.6

Menus et actions destructives inline : SF et titre rouges explicitement ; swipe blanc sur rouge natif conservé. Cancel neutre choisi par l'utilisateur : blanc sombre/noir clair. Confirmations SwiftUI.alert et callbacks inchangés ; UIColor.label appliqué au UIAlertController public par un adaptateur transparent à recherche bornée. Les autres actions non destructives de ces confirmations deviennent aussi neutres ; erreurs OK inchangées. Pas d'UIAppearance/swizzling/API privée. Rendu/fermeture au verrouillage à confirmer physiquement.

Graphique : RuleMark zIndex−1 avant les courbes ; PointMark/annotation sélectionnés2, autres1. Bulle opaque et fit conservés. Repetitions inclut tous les lests/charges mixtes sans sélecteur, courbe par séance et total période ; Duration garde son filtre. Chargement stable et haptics conservés.


## Cyan fixe et courbes sans conditions — 0.11.5

À la demande de l'utilisateur, seul Icy Cyan4DD9E8 reste ; aucun réglage de couleur. Fonds cyan exacts et tints lisibles conservés pour app/widget, sans suivre les anciennes préférences. Icône Pause blanche explicitement dans le repos et les Live Activities, texte sombre dans le bouton plein : cette exception utilisateur réduit le contraste de l'icône sur fond cyanclair.

Graphiques : filtre et regroupement Workout Conditions retirés pour toutes les mesures. Une seule courbe chronologique avec tous les points des filtres période/lest. Repetitions totalise tous les points affichés ; valeurs par séance, détail au drag, cache de chargement et volume sur période inchangés. Conditions historiques restent dans les données, sans gouverner l'affichage. Recette iPhone après installation.


## Couleur d'accent0.11.4

Settings → Appearance → Accent Color, liste native de sept pastilles/labels/coche sélectionnée accessible, cibles≥44pt. Apple Blue système par défaut ; Mint46D7A7, Energy OrangeFF873D, Lime YellowD7F75B, VioletA78BFA, CoralFF647C, Icy Cyan4DD9E8. Valeurs sRGB exactes pour fonds/pastilles ; ink noir/blanc selon contraste. Tints des liens/onglets/courbes ajustés pour les fonds système clair/sombre et Increase Contrast, sans recolorer textes sémantiques ni actions destructives. Boutons prominent natifs conservés ; Play explicitementcontrasté. Aucun mouvement global ajouté au changement de choix. Grille : légende Filled plutôt que Blue ; valeur sélectionnée transmise aux activités existantes et futures. Rendu réel du glass/disabled/contraste et persistance appareil à confirmer.


## Audit global 0.11.3

Grille d'assiduité : chaque jour est un Button SwiftUI avec cible ≥28pt (minimum HIG pour conserver la densité, cible recommandée44pt), case visuelle18pt évoluant avec Dynamic Type, espacement3pt et défilement horizontal. Calcul de coordonnées du tap retiré, libellé date/état et alternative liste conservés. Trois erreurs de validation et unité VoiceOver de lest traduites en anglais ; noms personnels inchangés. Aucun nouveau mouvement décoratif ni changement des courbes. Rendu, grand texte et VoiceOver à vérifier sur iPhone : [rapport](audits/2026-10-13-global-audit.md).

## Référence permanente

Reps doit sembler aussi familier et cohérent qu’une app Apple comme Santé, Fitness ou Repss. Les [Human Interface Guidelines Apple](https://developer.apple.com/design/human-interface-guidelines) sont la référence permanente demandée par l’utilisateur ; consulter les chapitres concernés à chaque retouche. La référence porte sur la qualité de l’expérience, pas une copie de leur marque.

- TabView, NavigationStack, List, Section, Form, DatePicker et présentations système en priorité.
- Typographie système avec styles sémantiques, SF Symbols, couleurs qui suivent les réglages iOS.
- Liquid Glass fourni par les barres/contrôles ; pas de faux verre ou de verre dans le contenu.
- Hiérarchie claire, actions peu nombreuses, détails secondaires accessibles par navigation native.
- Pas de hauteur fixe sur le texte, dimensions d’écran codées en dur ou offsets de safe area.
- Respect de Dark Mode, Dynamic Type, VoiceOver, contraste/transparence et animations réduites.

## Jalon 1

Quatre onglets toujours accessibles : Aujourd’hui, Historique, Progression, Réglages. Une NavigationStack par onglet préserve le contexte. Les trois premières destinations utilisent ContentUnavailableView ; texte honnête, aucune donnée fictive ou commande non opérationnelle.

Réglages utilise une liste native groupée : Entraînement (Planning, Exercices, Lest, Repos), Rappels et confidentialité (Notifications, Coffre photo), À propos. Les lignes poussent des pages complètes avec retour système. À propos lit la version réelle du bundle.

Les grandes tailles de texte peuvent défiler ; scrollBounceBehavior(.basedOnSize) limite le rebond au contenu débordant. Titres, insets, barres et transitions sont gérés par SwiftUI. Pas de palette artificielle ni surcharge du comportement natif.

## Jalon 2

Aujourd’hui affiche les objectifs de la séance du jour local et un aperçu des séances configurées. Jour libre ou séance désactivée : repos, sans fausse commande de démarrage. Les autres onglets gardent leur navigation.

Planning, Exercices et Repos utilisent listes et formulaires natifs. Édition dans une feuille avec Annuler/Enregistrer ; brouillon local, enregistrement atomique, formulaire bloqué pendant la sauvegarde, message d’erreur en cas de refus. Les exercices sélectionnés se réordonnent avec le mode Modifier natif. Le choix d’heure est explicite : activer un rappel sans choisir d’heure ne peut pas enregistrer un horaire inventé. Une heure enregistrée reste modifiable avec DatePicker. Aucune notification n’est envoyée à ce jalon.

Chargement avec ProgressView ; erreur d’accès avec ContentUnavailableView et Réessayer. Aucune réinitialisation des données proposée.

Retouches demandées après test iPhone : noms en couleur système primaire (blanc en sombre, noir en clair), jours et objectifs en gris secondaire. Boutons de ligne en style plain pour supprimer la teinte bleue automatique, zone tactile sur toute la ligne ; commandes de swipe en style automatique natif. Bouton + en haut à droite du Planning ; désactivé quand les sept jours sont occupés, avec explication. Les listes vides indiquent comment ajouter un élément.

Balayage à gauche → Supprimer, ou appui long → menu Modifier/Supprimer. Pas de suppression immédiate par balayage complet ; alerte native centrée Annuler/Supprimer puis écriture, commandes bloquées pendant l’opération. La confirmation d’exercice annonce les séances affectées et celles qui seront désactivées faute d’exercice actif. Supprimer une séance conserve le catalogue. Les gestes n’effacent pas automatiquement de données pendant l’installation d’une nouvelle build.

## Jalon 3

Préparer la séance du jour, puis démarrer dans une présentation plein écran avec navigation système. Fermer conserve la séance ; Aujourd’hui propose Reprendre même si elle a commencé un autre jour. Le menu Options propose Abandonner avec confirmation et conservation des séries. Un nouveau démarrage d’une séance terminée aujourd’hui exige Recommencer confirmé et conserve la précédente.

La liste concentre les actions sur l’exercice et la série courants. Répétitions : clavier numérique ; durée : chrono basé sur le timestamp enregistré. Charge manuelle en kg, clavier décimal, 0 kg pour poids du corps. La série n’est enregistrée qu’à Terminer la série. Les brouillons non validés des champs ne sont pas persistés quand la présentation est fermée ; série active et timestamp le sont. À partir de 0.3.4, le lest choisi avant le départ d’une série de durée est également persisté.

Entre les séries : chrono lisible, Pause/Reprendre et Passer le repos. Dernière série d’un exercice : directement Feeling (0–10, pas de 0,1) ; validation explicite puis prochain exercice ou séance terminée. Les séries courantes et la dernière performance d’une séance terminée sont consultables dans des DisclosureGroup repliés au départ ; ajout/suppression d’historique actualise la dernière performance. Un son local bref et retour haptique signalent l’expiration au premier plan ; reprise après suspension reconciliée, aucune alerte d’arrière-plan encore.

Historique : séances terminées/abandonnées, détails des séries/charges/durées/Feeling, date locale capturée au départ. Configuration supprimée/renommée ne change pas les instantanés. Ni filtre ni modification d’une séance historique existante, ni recommandations de charge à ce jalon.

Retouches après captures iPhone (0.3.2) : Préparer reste un bouton système prominent pleine largeur, placé juste sous Entre les séries ; les objectifs le précèdent. Commencer reste mis en avant dans la préparation. Contenus opaques et boutons à fond transparent occupent des Sections distinctes pour conserver les coins arrondis système des groupes, y compris champs, repos, Feeling et reprise. Suivi : nom de l’exercice en titre, Exercice N sur M et progression des séries enregistrées de l’exercice courant. Un point gris par série devient bleu et coché uniquement après sauvegarde ; VoiceOver annonce le nombre enregistré. Une barre native remplace les points si leur nombre (>12) ou la largeur disponible le nécessite. Une seule commande Masquer le clavier dans la toolbar de l’écran, distincte de Terminer la série. Chronos agrandis avec ScaledMetric et chiffres monospaces ; informations secondaires repliables.

Historique : + en haut à droite, feuille Annuler/Enregistrer pour une séance déjà réalisée. Nom, DatePicker jusqu’à aujourd’hui, sélection d’exercices, une première série vide par exercice puis ajout/retrait. Chaque exercice ouvre un formulaire avec saisie directe des répétitions ou secondes, kg et Feeling obligatoire laissé vide au départ (0–10 au dixième). Aucune répétition, durée ou valeur de Feeling inventée. Brouillon local ; Annuler ne crée rien. Séance manuelle indépendante du planning et de la séance active, date seule au début du jour local, pas de durée totale fictive. Swipe gauche/appui long → Supprimer, alerte native centrée Annuler/Supprimer indiquant nom/date et conséquences ; pas de full swipe destructif. Supprimer ne modifie pas la configuration ni les autres séances. Une fiche ouverte depuis un autre onglet indique Séance supprimée après effacement.

## Finition HIG et décompte (0.3.3)

Corrections 0.3.2 confirmées par l’utilisateur ; nouvelles retouches en recette. [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) guide regroupement, importance et détails secondaires ; [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) guide styles, libellés et feedback. Le choix du décompte et les valeurs d’espacement propres à Reps ne sont pas des prescriptions Apple.

- Aujourd’hui : résumé de séance active avant sa commande Reprendre, avec exercice et nombre de séries enregistrées ; Sections séparées et espacements natifs compacts. Préparer reste immédiatement après le repos ; suppression du texte explicatif générique.
- Préparation : objectifs puis repos, et Commencer juste après, cohérent avec Aujourd’hui.
- Séance : titre title2 semibold avec trait de titre VoiceOver, en-tête rapproché du contenu, espacement compact système entre les Sections. Séries enregistrées, dernière performance et exercice suivant regroupés sous Repères ; performances repliables. Points gris en couleur secondary sans opacité supplémentaire, bleu et coche après sauvegarde.
- Libellés et aides raccourcis ; une seule action prominent par étape. ProgressView pendant démarrage/enregistrement, commande Terminer désactivée si répétitions/charge laissées vides. Validation des autres valeurs par la logique existante, sans performance inventée. Clavier dismissible par défilement interactif ; icône Masquer le clavier cohérente en séance et saisie historique.
- Historique : nom headline, date et nombre de séries sur la même ligne secondaire ; Abandonnée indiqué uniquement pour les séances concernées.
- Chaque série de durée : Commencer → Préparez-vous, 3–2–1 → chrono à zéro. Annuler le décompte revient à prêt et ne crée ni série ni repos. Départ prévu SQLite conservé en fermeture/suspension/relance ; les trois secondes ne sont jamais incluses dans la durée sauvegardée. Les séries de répétitions commencent immédiatement. Feedback haptique et annonces VoiceOver prévus au premier plan, à vérifier sur l’appareil ; aucune alerte pendant suspension promise. Aucun rebond, zoom ou animation ajoutée.

## Lest avant les séries chronométrées (0.3.4)

Prêt : champ Charge ajoutée (kg), aide 0 kg = poids du corps, puis Commencer la série. Validation décimale avant lancement ; le décompte ne débute pas avec une charge invalide. Lest capturé dans SQLite avec le départ prévu. Pendant le décompte et le chrono, aucun champ à remplir ; chrono puis charge en lecture seule et action Terminer la série. Terminer conserve cette charge, enregistre la durée et démarre le repos atomiquement. Annuler le décompte efface la charge capturée sans ajouter de performance.

Pour une série déjà active dans la version précédente sans charge capturée : Terminer arrête et persiste le chrono, puis un formulaire demande la charge et Enregistrer la série. Le chrono arrêté reste figé après fermeture/relance ; le temps de saisie ne gonfle pas la performance et le repos compte depuis la fin de l’effort. Les répétitions gardent leur saisie habituelle. Ces changements ont été confirmés sur iPhone en 0.3.4.

## Jalons ultérieurs

Rappels et finition Live Activities. Dynamic Island : icône seule en compact, REST/PAUSE sans icône redondante en développé, compte à rebours système, un Pause/Reprendre sans Stop. Le comportement de confidentialité du sélecteur d’apps reste à confirmer avant le coffre (archives contradictoires).

## Validation

Jalons 1 et 2 validés sur iPhone, y compris les couleurs, + et suppression de la version 0.2.1 (« parfait »). Jalon 3 : corrections 0.3.2 confirmées par l’utilisateur ; finitions HIG/décompte puis lest avant départ 0.3.4 confirmés sur iPhone par « ok parfait on continue ». Vérifier lest décimal avant démarrage, absence de saisie pendant l’effort, charge sauvegardée après reprise et série héritée arrêtée avant saisie. Tester 3–2–1, annulation, reprise pendant/après décompte, durée enregistrée sans préparation, titres, Repères, clavier et informations lisibles. Vérifier déroulement, clavier, chrono après fermeture/relance, pause/reprise/skip, sauvegarde réglages pendant repos, Feeling et abandon/recommencer. Vérifier VoiceOver sur chronos, grand texte, clair/sombre et stabilité de la date après changement de fuseau. Build/revue ne valident aucun de ces comportements physiques.


## Prototype Live Activities (0.4.0)

[HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities) consultées : informations essentielles et action simple. Choix Reps : REST/PAUSE en développé, icône seule en compact/minimal, compteur système, exercice et prochaine série. Écran verrouillé avec marge 14 points ; développé avec espace intérieur, couleurs système et un seul bouton Pause/Reprendre. Pas de Stop. Toucher le contenu ouvre la séance concernée par lien reps://workout/identifiant. L’état terminé affiche une coche et Repos terminé ; le bouton de pause disparaît.

SQLite fournit identifiant et échéance absolue. Le widget n’a pas de minuterie propre ni accès à la base ; le LiveActivityIntent agit dans Reps. L’activité standard rend le repos ; une seconde présentation transitoire est programmée pour la fin par l’API iOS26. C’est une solution technique du prototype, pas une prescription HIG. En suspension, la fermeture exacte de l’activité standard reste une limite : elle est réconciliée au retour, et iOS contrôle la présentation/alerte de fin. Vérifier interactions, annulation, Always-On, accessibilité et rendu sur iPhone avant validation ; finition finale au jalon 6.


### Retouches iPhone 0.4.1

En compact, supprimer la largeur52 et l’intervalle depuis epoch ; un label invisible dimensionne la largeur réelle minutes:secondes avec la même police monospacée, le compteur natif en overlay aligne ses chiffres à droite. Le placeholder seul est exclu de VoiceOver, le vrai compteur reste la présentation accessible à vérifier sur iPhone. En développé : inset latéral8 pour REST et timer, vertical4, timer ancré trailing. En Lock Screen : même compteur intrinsèque ancré par Spacer, padding14 conservé ; aucune autre retouche au contenu apprécié. Ces valeurs du développé sont un choix Reps, pas une exigence chiffrée Apple. Pause : correction de métadonnées de routage ; essai de reprise, persistance et annulation de l’ancienne alerte requis.

### Retour d’attente 0.4.2

Pause/Reprendre fonctionne selon l’essai utilisateur 0.4.1, avec délai ressenti. Appliquer `invalidatableContent()` au statut et au timer afin que WidgetKit signale l’attente d’un contenu actualisé, suivant la [documentation Apple sur l’interactivité](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities). Aucun état optimiste, animation personnalisée ou timer indépendant. Cette indication ne garantit pas une réduction de la latence ; nouvel essai iPhone requis. VoiceOver doit vérifier la durée restante en pause et le compteur visible en overlay ; l’annonce numérique n’est pas encore confirmée.


### Confirmations uniformisées 0.4.3

Demande explicite : alertes système centrées pour toutes les confirmations actuelles. Abandonner et Recommencer étaient les deux dernières présentations ancrées ; elles utilisent maintenant `alert`, comme les suppressions. Annuler ferme sans mutation ; abandon conserve les séries et arrête le repos, recommencer conserve l’ancienne séance. Messages inchangés. Aucun nouveau dialogue ajouté. Ce choix de cohérence est demandé par l’utilisateur ; les HIG distinguent confirmation d’une action destructive et présentation de plusieurs choix intentionnels. Rendu centré, boutons et conservation de l’état à confirmer sur iPhone.

## Historique, lest et progression (0.5.0)

Jalon 4 et confirmations 0.4.3 confirmés par « parfait, on continue ». Les [listes](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [sélecteurs](https://developer.apple.com/design/human-interface-guidelines/pickers) et [alertes](https://developer.apple.com/design/human-interface-guidelines/alerts) guident navigation, sélection et confirmations ; règles de progression et seuils propres à Reps.

Historique : contrôle segmenté Séances/Exercices, listes natives par date, performances réelles et liens vers la séance. Modifier ouvre un formulaire prérempli Annuler/Enregistrer ; ancien snapshot de l’exercice conservé, même archivé. Date, séries, charge et Feeling modifiables sans changer le statut ni les autres séances. Brouillon local ; refus explicite si la séance a changé ou disparu. Une composition connue se déplie dans le détail ; une charge positive sans provenance indique Composition non renseignée.

Réglages → Lest : sac fixe de 3 kg, objets éditables avec activation, + et suppression swipe/appui long confirmée par alerte centrée. Charges disponibles et leurs composants consultables. En séance, une ligne Charge ajoutée ouvre une liste native de choix avec coche et composition, initialement Poids du corps. Aucune recommandation appliquée automatiquement ; durée sélectionnée avant 3–2–1, aucune saisie pendant le chrono. L’historique manuel garde une saisie libre en kg au gramme près.

Recommandations sobres dans Aujourd’hui, préparation, exercice courant, Feeling et résultat de fin. Séries réelles comparées à l’objectif actuel : toutes au maximum, Feeling ≤ 7, puis plus petite charge disponible supérieure à la plus lourde série. Aucun lest fictif ni graphique ajouté. Durée : objectif atteint/à poursuivre seulement lorsqu’un objectif est défini. Modification/suppression d’historique actualise les repères. L’onglet Progression demeure réservé au coffre photo.

Date de classement authoritative conservée indépendamment des timestamps originaux ; nouvelles clés grégoriennes avec fuseau local, présentation au format système. Anciennes clés inchangées faute de marqueur de calendrier ; ancienne date non grégorienne potentiellement à corriger manuellement. Calcul des combinaisons borné en nombre de charges et travail sur les composants, avec erreur visible avant mutation si inventaire excessif. Rendu, gestes, grand texte, VoiceOver et régression des repos à tester sur l’iPhone installé avant jalon 6.

## Rappels et Live Activities (0.6.0)

HIG Notifications consultées : « Avoid sending multiple notifications for the same thing » et contenu concis sans informations privées. Les [Notifications Apple](https://developer.apple.com/design/human-interface-guidelines/notifications) guident la permission contextuelle et la sobriété ; horizon28jours et heures choisies sont règles Reps, pas prescriptions HIG.

Réglages → Notifications : formulaire natif avec autorisation actuelle, opt-in séances et rendez-vous mensuel, DatePicker système, accès Planning pour les heures individuelles, nombre de rappels programmés et Resynchroniser. Réponse refusée : état explicite et accès aux réglages iOS, aucun nouveau prompt automatique. Les préférences restent sauvegardées même si iOS bloque les notifications. Deux opt-ins désactivés initialement ; photo06:00 modifiable, coffre non encore disponible clairement indiqué. L’autorisation n’est jamais demandée par le lancement, le retour ou la resynchronisation.

Les taps par défaut ouvrent Aujourd’hui ou Progression, jamais une photo ni une action destructive. Delegate installé avant fin du lancement, destination en attente consommée par TabView à froid. Au premier plan : banner/list sans son ni badge, conformément à la spécification Reps. Hors app : son système facultatif selon réglages iOS ; aucune interruption critique ou Time Sensitive.

Live Activities conservent les marges et alignements validés. Demande additionnelle utilisateur : retire la coche du timer à droite en état terminé ; la coche de statut à gauche est conservée en compact/minimal. Aucun faux timer ajouté. La pause expose une valeur VoiceOver minutes/secondes, la politique de retrait élimine anciens repos, completions à mauvaise échéance, pauses et doublons ; retry au foreground. iOS garde le contrôle de latence, terminaison en suspension et présentation coordonnée des deux activités. Coche, annonces et fin sur appareil à confirmer.

### Retouche Notifications 0.6.1

Suppression demandée de la ligne permanente Autorisation iOS : ce n’est plus un état affiché dans la liste. Si les notifications sont refusées, présenter seulement le message utile et Ouvrir les réglages iOS ; sinon aucun groupe d’autorisation vide ni pied de section orphelin. Permission et rappels inchangés. Les idées de graphiques/objectifs/grille/import-export sont un brainstorming séparé, sans UI ni moteur implémentés.

## Organisation des futurs jalons, 12 octobre 2026

Progression guidée/visualisation au jalon 7, coffre au 8 (ancien 7), harmonisation Animations/haptics au 9, sauvegarde complète et finition au 10 (ancien 8). Le périmètre et la recette de chaque étape sont dans PLAN-REPS-NATIF.md ; détails fonctionnels retenus dans PROJECT.md §21. Les principes Apple natifs/accessibilité s’appliquent à chaque étape ; le jalon 9 ne justifie pas une UI brute ou des comportements inaccessibles avant lui. Aucun nouveau flux, écran, animation ou retour tactile implémenté par ce changement de documents. Les rapports 0.6.x conservent leurs références historiques ; la recette du jalon 6 reste à confirmer sur iPhone.

## Progression guidée (0.7.0)

Références consultées : [Charts](https://developer.apple.com/design/human-interface-guidelines/charts) et [Swift Charts](https://developer.apple.com/documentation/charts). Les HIG guident lisibilité, contexte et accès aux valeurs ; les règles <8, un ajout de répétition et les13semaines sont des choix Reps.

Quatre onglets conservés. Progression affiche l’assiduité puis les exercices, avec une destination Photos privées explicitement indisponible. Objectif dans un formulaire système Annuler/Enregistrer, proposition expliquée et adoption volontaire. Aucun changement de séance en cours après adoption. Sac et composants se déplient ; un lest ponctuel n’écrase pas l’objectif. Résultat précédent visible, confirmation du nombre ciblé explicite ; aucun résultat préenregistré.

Swift Charts natif : points de séries réelles, mesures séparées, filtres de période et de charge. Pas de tonnage global, extrapolation de force ou liaison artificielle entre charges. Sélection donnant accès aux valeurs/historique. Grille récente : bleu/coche pour terminé, point pour partiel, neutre pour absence de résultat ; état lisible sans couleur seule, labels VoiceOver et liste de jours alternative. Tailles adaptées au texte ; rendu et sélection restent à vérifier physiquement.

Correction en feuille native ; l’édition ne redémarre pas les timers. Feeling numérique0,5, anciens dixièmes préservés. Fin de séance avec durée totale réelle et chiffres comparables. Pas d’animation personnalisée ni nouvelle haptique dans ce jalon ; harmonisation au9.

Limite retenue après revue : les graphiques sont des résultats bruts par série ; les changements de repos et de nombre de séries n’ont pas encore de marqueur distinct. Le bilan cherche la dernière session réellement comparable et n’utilise pas le repos supposé d’une saisie manuelle. Une diminution de Feeling ne devient un fait positif que si la performance est au moins équivalente.

## Import/export entraînement — prototype en vérification

HIG [File management](https://developer.apple.com/design/human-interface-guidelines/file-management) et [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) : sélecteurs Fichiers système, aperçu en feuille Annuler/Importer, alerte centrée explicite pour remplacementJSON. UI sobre en Réglages, formats et exclusion des photos annoncés avant export ; CSVdémo clairementfictif, jamaisinjectéautomatiquement. NativeFileDocument/fileImporter/fileExporter, lecture URLscoped limitée à10Mo horsmainactor. APIs passées à la compilation, liaison échouée sur disqueplein ; UIfinale pasencorebuild/installée, recetteiPhone requise.

La compilation finale0.7.1 est désormais réussie avec xtool (16,66s) : FileDocument et les deux sélecteurs natifs sont intégrés/liaison vérifiée. La recetteiPhone Fichiers, annulation, grande police,VoiceOver/clair-sombre reste requise.

## Courbes par séance —0.7.2

RetouriPhone : import bien, graphiques tropconfus. HIGCharts/charting-data : résumer et communiquer clairement avantd’explorer. Une valeur parséance remplace les points de chaque série ; totauxrépétitions/ms àlestuniforme, maxlest séparé, courbe linéaire sansinventiondonnées. Les anciennescharges ne sontpasagrégéesdansunscoreforce. Dernièrevaleur/date/variationarithmétique visibles. Période etmesures viaPicker natifs, conditionsrepos/nombre/plageobjectif distinguées, manualrest nonrenseigné. Chargesmixtes restentdansvueLestmax/historique ; courbesdetotauxutilisentuniformeuniquement.

AxeX parordre de séance, espacementsréguliersexplicités etdatesréelles auxrepères ; distingueplusieurs séancesmêmejour sansfakeheure. Courbe/points/axes discrets, VOparséanceetdétail lisible sanssélection. Selectionindexnative révèle les séries etlienhistorique. Projectioncalculée horsmainactor puisgardecancellation, pasrecalculdesséries auscrub. Champsrest lusexclusivementdepuisinstantanéSQLite ; schéma/transferts etobjectifs inchangés. Les filtres/modetracking sont réconciliés aprèschangements.

L’affirmationancienne « résultatsbrutspar série sans marqueursderepos/nombre » décrit0.7.0/0.7.1 ; cetteversionla remplace parunecomparaisondeséancesfiltrées. Pas degraphiqueprouvantàlui seul ungainphysiologique. Rendu, scrubbing, axes, grilleetgrands caractères encoretestiPhoneobligatoire.

## Informations au glissement et volume par séance (0.7.3)

[HIG Charting data](https://developer.apple.com/design/human-interface-guidelines/charting-data) : « Keep a chart simple, letting people choose when they want details. » Application Reps : petite annotation native Swift Charts près du point sélectionné, date et valeur ; débordement ajusté aux limites du graphique. La ligne, le point sélectionné et les détails complets restent accessibles ; l’annotation est exclue de VoiceOver pour ne pas doubler les marques déjà nommées. Résumé « Dernière séance » stable pendant glissement, unités/titres « par séance » explicites. Débordement/gestes/grand texte/VoiceOver à vérifier physiquement.

Volume / Répétitions / Lest pour exercices répétitions, Volume par défaut. Volume de lest = somme réelle répétitions×lest de chaque série, toutes charges admises, poids du corps exclu et0 expliqué. Ce n’est pas un indicateur de force estimée. Durée : total de travail par séance tous lests par défaut, filtre uniforme facultatif, repos exclu. Conditions historiques conservées. Aucun changement de recommandations, haptics/animations, média ou format de transfert.

## Cumul et remplacement CSV (0.7.4)

Clarification utilisateur : total des séances sur période choisie, pas volume d’une seule séance. Résumé Volume total de lest + période, courbe de cumul et bulle au point ; détail « Cumul à cette séance » et « Volume de cette séance » distincts. Volume regroupe toutes conditions enregistrées, sans sélecteur de contexte qui réduirait silencieusement le total. Les autres mesures gardent leurs filtres. Le cumul est une quantité consignée, pas une progression de force.

Import CSV : aperçu donne Séances dans le fichier et Séances actuelles remplacées ; Remplacer ouvre une alerte système centrée précisant les deux nombres et les réglages conservés. Annuler ferme sans écriture. CSVvide affiche que l’historique sera vidé ; contenu identique affiche aucune mutation nécessaire, bouton désactivé. JSON garde la confirmation de restauration d’entraînement complet. Avertissement photos privées exclues, copie récupérable et gardes active/périmée conservés. Vérifier ces rendus/gestes sur iPhone, pas déduits de la compilation.

## Résumé de période et courbe par séance (0.7.5)

Clarification utilisateur : le grand chiffre représente un total ; le tracé représente l’évolution des résultats individuels. Volume total de lest additionne la période entière, mais chaque point/bulle/détail affiche le volume de sa seule séance. Répétitions au total additionne les points dans les filtres affichés ; la courbe conserve les répétitions par séance. Total et détail ne portent plus le même libellé ambigu ; ancienne ligne Cumul à cette séance retirée. La variation sous le total Répétitions précise qu’elle concerne la dernière séance.

Le résumé est stable pendant le glissement, les valeurs VoiceOver correspondent aux points. L’état vide Volume indique absence de séance sur la période et n’offre plus de changer un lest sans filtre disponible. Aucun nouveau geste, matériau, transition ou composant ; annotation native et accessibilité existantes conservées. Contrôle physique iPhone toujours requis.


## Animations et haptics — 0.9.0

Jalon avancé le 13 octobre avant le coffre. Choix Reps suivant HIG Motion / Playing haptics : transitions de contenu courtes (0,25 s, ressort smooth sans rebond), coches de séries SF Symbols, 3–2–1 numérique, états de séance/exercice, objectif adopté et bilan en fondu. Les chiffres du chrono actif/repos restent stables ; aucun compteur artificiel de résultat, zoom, confetti ou cascade. Les vues de navigation, feuilles et contrôles restent natives. Les changements de filtres Progression animent l’arrivée du contenu ; aucun mouvement retardé du point sous le doigt ni interpolation de résultats entre unités.

Retours système : succès à l’enregistrement d’une série, fin de séance, objectif réellement modifié ; sélection au démarrage/passage d’exercice, pause/reprise/skip et changement de point du graphique ou jour de grille. Décompte et expiration existants centralisés, sans doublon. Sélection limitée à 80 ms entre taps sans file d’attente. Pas de retour pour une actualisation passive, annulation, correction de valeurs ou simple ouverture d’un historique. Feedback après lecture du commit SQLite et avant réconciliation ActivityKit ; état initial de l’action capturé et événements dédupliqués.

Réglages → Retours tactiles : préférence locale initialement active, conservée sur l’appareil ; ne remplace pas les réglages des contrôles/alertes iOS. Réduire les animations, VoiceOver ou scène inactive désactivent les animations ajoutées. État décompte observé effacé à la sortie pour éviter un signal de départ périmé au retour. Aucune modification du stockage métier, des notifications, des Live Activities ou du coffre. Rendu et perception exigent la recette iPhone.


Correction 0.9.1 (13 octobre) : transitions des filtres reprises sans animation globale de List. Bref fondu du graphique seul (0,15 s), axes/valeurs instantanés, identité par requête ; Reduce Motion/VoiceOver respectés. Données et haptics conservés. Recette iPhone après installation ; voir [ExecPlan](exec-plans/2026-10-13-chart-filter-motion.md).


### Chargement stable des graphiques — 0.9.2

Correction après retour iPhone : conserver les résultats et leur mesure/période pendant toute actualisation. Le bloc au-dessus de Prochaine séance ne disparaît plus pendant la requête ; les nouveaux résultats/libellés/contexte/sélection sont publiés ensemble. Indicateur en overlay sans ligne supplémentaire ; erreurs gardent le dernier résultat et proposent Réessayer. Réponses périmées/annulées refusées. Le premier chargement et les véritables états vides restent explicites. Calculs, données, haptics et bref fondu conservés ; rendu à confirmer après installation.


### Répétitions compactes — 0.9.3

Tous les tableaux d’objectifs utilisent la même notation : 10·10·10·10 devient4×10, 10·10·9·9 devient2×10 2×9. Seules les valeurs identiques adjacentes sont regroupées pour préserver l’ordre. Objectifs configurés :4×10 ou4×8–12. La vue partagée couvre Aujourd’hui, préparation, séance, propositions/prochaine séance et bilan ; détail et saisie par série restent accessibles, sans fusionner charges/compositions. VoiceOver explicite les groupes d’objectifs. Aucun stockage/format/algorithme de progression modifié. Rendu à confirmer sur iPhone.


### Accès au repos depuis Aujourd’hui — 0.9.4

« Entre les séries » devient une ligne NavigationLink native, chevron système, texte primaire et durée actuelle. Ouvre exactement RestSettingsView, déjà utilisée depuis Réglages → Repos, avec le même éditeur et la même sauvegarde. Aucun écran ou chemin de persistance dupliqué. Navigation/rendu à confirmer sur iPhone.


### Photos privées — preuve8A

Destination native depuis Progression, déverrouillage explicite FaceID. Prototype clairement signalé et limité aux données synthétiques ; aucun bouton d’import ou galerie trompeuse. ZStack stable porte le lifecycle, masque immédiat à inactive sans animation et verrouillage à background/sortie. Le passage inactive du prompt biométrique ne doit pas être traité comme un abandon ; callbacks périmés ne réouvrent pas l’écran. Menu d’effacement limité aux données de test, alerte centrée. Résultats techniques de validation visibles seulement une fois les opérations réelles terminées ; le test iPhone est nécessaire avant le coffre de production.


## Galerie privée — 0.10.0

Photos privées s’ouvre depuis Progression dans une présentation plein écran native, indépendante des statistiques. Déverrouillage FaceID explicite, grille adaptative datée, détail avec zoom/doubletap, date modifiable et actions SF Symbols nommées pour VoiceOver. Plus propose PhotosPicker ou caméra ; permissions à la demande. Alertes système centrées pour suppression, reset et export hors coffre, sans bulle triangulaire. Annuler n’écrit rien. Pas d’alerte OK après chaque import : la nouvelle vignette et le retour tactile matérialisent la réussite.

Toutes les surfaces privées partagent un masque stable sans animation dès inactive ; arrière-plan/sortie ferment les routes et verrouillent immédiatement. Les autres onglets restent publics. Import choisit la date ; originaux Photos conservés et caméra non enregistrée automatiquement dans Photos. Aperçu downsampled2400px, original pleine résolution conservé pour export ; image fixe seulement pour Live Photos. Grand texte, VoiceOver, zoom, permissions et aperçu multitâche doivent être testés sur iPhone ; compilation ne valide pas le rendu. Sauvegarde portable du coffre différée au10.


## Piles, comparaison et objectifs — 0.10.1

Retouche demandée/approuvée après validation0.10.0. Galerie : une pile datée et son nombre de photos, ouvrant la grille de ce jour. Trois poses explicites (Face au repos / Face contractée / Dos), aucune attribution automatique aux anciennes photos. À l’ajout, la prochaine pose absente est présélectionnée mais reste modifiable. Date/pose se modifient ensemble depuis le détail.

Comparer utilise les sélecteurs natifs de pose et de deux photos prises à des dates différentes ; images côte à côte sans recadrage ni transformation. Choix initial ancien/récent, ou photo ouverte et une autre date. Doublons restent sélectionnables par numéro à leur date. Vue scrollable et labels adaptatifs, pas de hauteur fixe des contrôles ; masque immédiat commun et état privé vidé à la fermeture. Pas de surimpression morphologique, mesure corporelle ou alignement artificiel. Contrôles/rendu/grand texte/VoiceOver à tester physiquement.

Aujourd’hui/préparation : nom de l’exercice, libellé secondaire Objectif, résumé compact4×10·+6kg et chevron ouvrant les détails ; la plage du programme n’est plus affichée en doublon. Écran objectif : cible actuelle, proposition seulement si différente, adoption explicite ; Personnaliser ouvre lest et cibles par série. Pas d’adoption automatique ni nouvelle règle de coaching. Plage configurée visible sous Programme. Reset du coffre rouge avec arrow.counterclockwise et confirmation centrée conservée. Ce sont des choix Reps s’appuyant sur les recommandations HIG de hiérarchie/divulgation progressive et boutons destructifs, pas des mises en page imposées par Apple.


## Comparaison agrandie — 0.10.2

Toucher une des deux images ouvre sa comparaison plein écran. Pincement1–4× et déplacement dans une ScrollView SwiftUI ; toucher simple alterne les deux images. Canvas commun indépendant des dimensions des photos : zoom et géométrie de défilement restent identiques pendant alternance, sans recadrage corporel automatique. Fermeture revient aux dates/pose choisies. Indication courte du geste, commande SF d’alternance et menu de zoom accessibles ; VoiceOver dispose aussi d’une action d’alternance et d’ajustement du zoom. Le toucher d’alternance est explicitement demandé par l’utilisateur, pas présenté comme une convention Apple. Gestes, cadrage et rendu restent à tester physiquement.


## Zoom ancré et appui long — 0.10.3

Retour iPhone0.10.2 : le changement de taille SwiftUI zoomait depuis le coin haut gauche. Remplacé par UIScrollView/UIImageView natifs intégrés dans l’écran SwiftUI ; pincement et déplacement gérés par iOS, image seule changée lors de l’alternance, commandes de zoom autour du centre courant. Canvas commun conservé au changement de photo, ajusté à une nouvelle taille de viewport. Pas de geste de zoom artificiel ni doubletap retardant l’alternance.

Piles et photos de leur grille proposent Supprimer par contextMenu natif. Aperçu de menu explicitement neutre (SF Symbol + Pile/Photo privée), sans image ni date : la présentation système ne doit pas porter une photo hors du masque du coffre. Confirmation centrée annonce les copies privées supprimées et conserve les originaux Photos. Annuler n’écrit rien ; une pile est supprimée atomiquement. Ancrage du pincement/rotation/retour/VoiceOver et interruption pendant appui long restent à vérifier physiquement.


## Archives et finition de listes — 0.10.4

Réglages → Exercices présente le catalogue puis Archivés (définitions présentes seulement dans l’historique), avec accès aux performances. Swipe gauche/appui long des archives dans Réglages et Progression ouvre la même alerte centrée ; demande explicite utilisateur d’effacer aussi les anciennes performances. Alerte distingue suppression définitive des performances et retrait des séances devenues vides, tout en conservant les autres exercices. Suppression du catalogue garde son archivage et l’annonce désormais.

Voir les jours en liste affiche uniquement jours terminés/partiels, avec état vide ; grille neutre inchangée. Rubrique Planning renommée Séance, y compris titre/liens d’aide. Préparer conserve son style natif et perd ses insets de ligne pour rejoindre les bords de la ligne de repos. Largeur et accessibilité à constater sur iPhone.

Retour utilisateur0.10.3 : zoom incorrect dans les deux vues. Détail classique migré vers le contrôle natif commun, cadre fixe GeometryReader dans les deux vues. Retrait du recalcul de zoom/offset dans layoutSubviews ; configureViewport agit seulement lors d’une vraie taille SwiftUI nouvelle. Pincement/pan iOS seuls pendant le geste, doubletap local dans détail et tap d’alternance en comparaison. Il s’agit d’un correctif à tester, pas d’une résolution physique déjà prouvée.


## Finition 0.10.5

SF Play explicitement blanc dans le bouton Préparer bleu. Catégorie et renvois Réglages → Séances au pluriel, vocabulaire d’une séance conservé ailleurs. Crash iPhone de mise à jour de lignes après suppression : identité déterministe sur les deux List Exercices/Progression, basée uniquement sur les IDs ordonnés catalogue/archives, pour recréer le conteneur natif lors d’un changement de composition. Objectifs et rafraîchissements temporels gardent l’identité ; alertes/éditeur restent hors de cette reconstruction. Le scroll peut revenir en haut après ajout/suppression. Contournement du batch iOS constaté, disparition réelle du crash à confirmer sur appareil.


## Anglais et commandes — 0.11.0

Choix explicite utilisateur : anglais et SF Symbols avant sauvegarde complète. Today/History/Progress/Settings, Workouts/Exercises/Set/Rest/Added Weight, Feeling conservé. Interface, erreurs applicatives, notifications/Live Activities, prompts explicatifs et VoiceOver traduits ; noms personnels et contenus persistés restent tels quels. Dates affichées en anglais, nombres et saisie gardent la région appareil ; dates techniques/CSV inchangés. Les textes fournis par iOS suivent ses propres réglages.

Toolbars : Save/Done → checkmark, Edit → pencil, Cancel/Close → xmark, Button nommé et iconOnly ; menus/alertes et grandes actions gardent un libellé pour éviter l’ambiguïté. Contrôles natifs, rôles/disabled/confirmation inchangés. Play blanc conservé, aucune animation ajoutée. About/Rest/Notifications deviennent factuels au lieu d’annoncer des fonctions déjà livrées comme futures. Ce sont des choix Reps fondés sur HIG Writing/Buttons/SF Symbols ; compréhension, VoiceOver et grand texte à constater sur iPhone.


## Preuve de sauvegarde portable — 0.11.1

Settings → Import and Export → Encrypted Backup Test expose temporairement une preuve explicitement synthétique, pas une sauvegarde réelle. Form/SecureField et transfert Fichiers natifs ; mot de passe/confirmation pour export, fichier à sélectionner puis password à réentrer pour vérification. Expliquer que confirmation ne concerne que l’export et que les champs sont vidés au lancement d’un travail, à inactive et sortie. Noms des fichiers sélectionnés non affichés, aucune date/photo privée.

Checks ne devient Passed qu’après exécution native réelle. Travail KDF hors MainActor, cancellation et requestUUID par présentation ; interruption annule la présentation et interdit tout vieux résultat. Ciphertext exporté épinglé à son document ; aucune garantie que l’OS annule une écriture déjà acceptée. Si un picker produit une transition inactive, il sera volontairement annulé ; ce cycle doit être vérifié sur iPhone avant données réelles. Pas de bouton de restauration/purge ni accès au coffre dans cette preuve.


## Import/export simplifié — 0.11.2

Demande utilisateur : uniquement Import from Files et Export to Files. Une seule section/deux lignes ; import direct, menu d’export CSV/JSON et ancienne copie JSON si présente. Exclusion des photos privées dans le footer ; retour factuel de réussite dans ce même footer, aucun modal OK supplémentaire. Progression en overlay pendant préparation, erreurs et preview/confirmation de remplacement conservés. Aucun bouton de démo, preuve de chiffrement, sous-section technique ou écran de test dans le produit.


## Bulle au-dessus de toutes les marques — 0.11.7

La previewcard est maintenant dans chartOverlay et non dans l'annotation du PointMark : elle passe devant points/courbe/ligne. ChartProxy donne l'ancrage ; Layout SwiftUI mesure et positionne en une passe, largeur≤260pt et clamp dans le cadre. Pas de state de mesure différé, nouveau geste/animation ou changement de calcul. Fond opaque, date/valeur et haptics conservés ; overlay noninteractif/masquéVoiceOver, vraies marques accessibles. Rendu aux extrémités/en haut et grand texte à vérifier physiquement.


15 octobre — 0.11.8 : symboles des actions explicites des barres d’outils Liquid Glass blancs, sauf coches accentuées. Style limité aux boutons/libellés de déclenchement ; menus destructifs rouges conservés. Aucun verre personnalisé. Lisibilité claire/sombre et états désactivés à confirmer sur iPhone.

15 octobre — retour 0.11.8 : foregroundStyle sur les boutons ne donne pas le blanc attendu sur l’iPhone. 0.11.9 remplace ce style par tint(.white) sur les contrôles de toolbar eux-mêmes ; déclencheurs Menu également, sans changement des coches. Recette physique nécessaire.

15 octobre — prototype 0.11.10 : icône exacte de Kavi en couches menthe/anthracite installée temporairement dans Reps à la demande utilisateur, pour comparaison physique du rendu Linux. Ce n’est pas l’icône finale de Reps. Pas de SF Symbol copié comme logo, ni d’aplatissement arbitraire du catalogue ; sources Icon Composer conservées et compilées par actool Linux existant.

15 octobre — icône Reps 0.11.11 : haltère Phosphor plein, adapté en corps Icy Cyan et poids extérieurs argentés, incliné −32°. Fond et paramètres de verre du prototype Kavi confirmé. Couches SVG natives 1024 px, sans texte, compilées par actool Linux. Aperçu PNG réel inspecté après correction de taille ; rendu Home Screen sombre/teinté à confirmer sur iPhone. Sources/licence MIT conservées et licence embarquée ; aucune dépendance d’exécution.

15 octobre — 0.11.12 : icône sur trois plans avec vrais recouvrements. Poignée arrière séparée, poids argentés intermédiaires, poids cyan devant ; recouvrement de 16 unités entre chaque paire, transparence/ombre de groupe ajustées, fin liseré clair sur les formes. Le masque et la bordure extérieure restent système. Fond, inclinaison et cadrage conservés. Aperçu compilé inspecté, effet natif à confirmer sur iPhone.

15 octobre — 0.11.13 : haltère agrandi uniformément à 112,5 % du rendu précédent, trois couches centrées, échelle 1,3275 au lieu de 1,18. Aperçu compilé inspecté sans découpe ; matériaux et superpositions conservés.


0.12.0 — un seul échauffement issu du premier exercice, avant le travail. Cibles du premier objectif figé au lancement ; lesté : une série à vide pleine cible, à vide : deux demi-cibles avec demi-repos entre puis repos complet. Répétitions impaires arrondies vers le bas (minimum 1), demi-durées et demi-repos conservés en ms, durée libre inchangée. Préparation montre la règle et propose un étirement (mouvement/durée pour cette séance). Trois mouvements de base, 30 s par défaut, deux côtés si unilatéral. Étirement après le dernier Feeling ; fin et durée totale de séance après ce maintien. Chrono/countdown natifs partagés, liserés/icône/couleurs inchangés. Historique séparé des séries de travail, aucun impact des résultats d’accompagnement sur les graphiques ou les propositions. Anciennes séances actives/historiques gardées telles quelles. Rendu et transitions à valider physiquement.


17 October — local 1.0.1: between-exercise rest shares the existing persisted deadline and native controls/Live Activity, targeting the next exercise while Feeling remains editable. Stretch has a remaining-time display and automatic stop rather than an open-ended finish button. Customization navigation uses a native NavigationStack path: parent Close hidden while pushed and no duplicate Cancel. Confirmation toolbar glyphs use a shared black symbol label, and filled workout action labels override inherited tint with accent ink. Timed chart load selection removed without clearing the previous chart projection during updates. Physical appearance, sound and navigation still require iPhone review.

18 October — 1.0.2 local Lock Screen-only presentation: explicit `.activityBackgroundTint(.clear)` replaces the default opaque-looking system tint. Content and layout unchanged; no synthetic glass background or changes to Dynamic Island. Native translucency, wallpaper contrast and accessibility settings remain subject to iPhone review.

18 October — Export to Files is a direct native Button, not a format Menu. It saves the complete current training/settings JSON through the standard Files destination picker. Footer names the included data and excluded private photos; no new exporter format or private-media access. Import compatibility and confirmations retained.

1.0.3: attendance dots now mean missed scheduled past days, starting at the first completed workout. Current enabled nonempty schedule is used; today stays neutral until completed or past. No partial state. Confirmation tint is scoped declaratively to a clear native SwiftUI alert presenter, replacing late UIKit controller inspection; underlying controls retain Icy Cyan. Neutral primary text means white dark/black light, destructive roles remain red. Actual alert appearance and accessibility require iPhone review.

Follow-up54: remove the explanatory missed-days sentence per user request. Consistency grid defaults to full completed-workout history through today, aligned to Mondays. Week count is computed from displayed columns (singular/plural), not a fixed13. With no completion, show current week.

Follow-up55: prepend decorative neutral week columns when real history is narrower than the row. Measure available width synchronously with GeometryReader, preserve existing Dynamic Type cell sizing and seven-row height, keep current week trailing. Fillers have no dates or interactions and are hidden from accessibility; real week count and all attendance analytics remain unchanged.

Follow-up56: legend order is Filled:completed, Dot:missed, then actual week count; training semantics unchanged.

Follow-up57: add Other to photo pose selectors for import, editing and comparison. Reuse native CaseIterable pickers; preserve Front Relaxed/Front Flexed/Back and optional Not Assigned. Sort assigned categories in enum order with unassigned last.

1.0.3(58): Rest Duration uses native SwiftUI minutes/seconds wheel Pickers, seconds00/30 plus any saved off-step legacy value. Preserve saved durations on opening; Cancel discards draft, Save disabled at0:00. Same editor from Today and Settings, changes future workouts only. No keyboard needed.

Build60: native load-goal update confirmation appears directly in the live completion summary, one batch of applicable increased/decreased loads with explicit Update Goals/Cancel. Existing goal rows refresh after adoption; historic summaries do not prompt. Shared toolbar confirmation buttons now explicitly use native glassProminent/circular border shape/Accent tint and black Image foreground only; remove the black tint on the label.

Correction61: load-goal popup moves to the transition button click in FeelingForm; no completion-summary prompt. Native buttons Update Goal and Keep Current Goal, the latter cancel role/neutral ink. Choice commits together with Feeling before next exercise/stretch. Explicit choice is preserved on later completion; active goal snapshots unchanged. Last action with support is labelled Continue to Stretching.

1.0.4 : Customize Goal permet aussi de saisir les secondes (vide=Untimed) depuis les objectifs chronométrés, avec clavier numérique natif. Les changements concernent les futures séances. Notifications offre un lien natif vers les réglages iOS, qui contrôlent les emplacements et la visibilité. Aucun épinglage permanent promis.

Notification test : bouton explicite, autorisation native si nécessaire, notification standard unique après10s, retour indiquant la programmation (pas la livraison), erreurs actionnables. Aucune modification des rappels enregistrés.

1.0.5 : durées des séries isométriques arrondies au dixième de seconde à l’enregistrement, correction et import ; anciennes durées converties transactionnellement. Totaux/bulles/écarts de progression affichent au plus une décimale. Les totaux additionnent les résultats arrondis ; horodatages et échéances de repos restent exacts.

Correction65 : Total Work Time affiche le cumul des séries isométriques des séances de la période choisie, avec libellé de période. Graphique, bulle et séance sélectionnée restent des mesures par séance. Même publication atomique des données pour éviter le flash des filtres.


## Séries par workout — 1.0.6 (66)

Sets se règle dans Settings → Workouts, sous chaque exercice affecté, avec un Stepper natif et un libellé VoiceOver nommant l'exercice. Le catalogue conserve les répétitions/durée par série, sans champ ni résumé d'un nombre global de séries. Today et préparation présentent les objectifs propres au workout ; Progress et l'historique donnent accès aux objectifs par workout, en gardant l'historique de l'exercice unifié. Un changement de workout à minuit recharge son contexte. Les séries conservées gardent leurs cibles ; les séries ajoutées reprennent le minimum configuré. Les séances déjà commencées et les instantanés historiques ne changent pas. Cette organisation est un choix Reps ; composants natifs, lisibilité et accessibilité suivent les références HIG. Rendu et interactions à confirmer sur iPhone.


## Sélection compacte des séries — 1.0.6 (67)

Après capture et accord utilisateur, le Stepper de66 est remplacé par un menu natif affichant 4 sets, avec nom d'exercice et métrique brève. Picker intégré au menu :1...8 en ordre, sélection cochée et valeur personnalisée conservée ; Custom… ouvre la saisie numérique1...1000 avec Cancel/Apply. Le brouillon ne change qu'après sélection/application. Le footer et la ligne Sets redondants sont retirés. ViewThatFits replie la ligne pour largeur insuffisante ; les tailles d'accessibilité empilent d'emblée nom/métrique/commande, avec libellés VoiceOver et contrôle44pt.

Références : [Pop-up buttons](https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons) (« If necessary, offer Custom » dans le guide local), [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) pour sélection/ellipse, [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) pour adaptation. Presets et composition sont des choix Reps. Aucun fond décoratif ou faux verre. Revue statique sans défaut concret ; rendu menu/alerte/tailles/édition à confirmer physiquement.


## Body Weight — 1.1.0 (68)

Chaque surface a été confrontée aux références Apple : [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) pour l'entrée Progress et l'historique ; [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) et [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) pour hiérarchie/actions ; [Charts](https://developer.apple.com/design/human-interface-guidelines/charts) pour dates réelles, points accessibles, inspection facultative et axeY dynamique ; [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls)/[Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers) pour3périodes et menu adaptatif ; [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)/[Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) pour saisie étiquetée/validation ; [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)/[Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) pour le rappel opt-in avec choix explicites.

Ligne Body Weight après Consistency, dernier poids/date, NavigationStack et+ natifs ; détail période/dernière mesure/delta/graphe/historique. Formulaire date+kg, clavier décimal, virgule/point, Cancel/Save, date occupée→édition explicite. Graphique linéaire sans interpolation lissée, vraies dates surX, bornesY adaptées pour voir les variations ; marge minimale0.5kg/15% de l'étendue et fenêtres3/6/12 sont des choix Reps, pas des valeurs imposées Apple. Courbe absente avec un seul point, état vide explicite. Texte système/DynamicType, points VoiceOver, pas de verre ou cartes décoratives.

Rappel : section Body Weight dans Notifications, toggle et configuration native ; jour à choisir, heure confirmée dans DatePicker. Permission uniquement au Save explicite, erreur actionnable si refus, aucune mesure dans la notification. Le rendu, le scrub, les feuilles, le grand texte et VoiceOver restent à valider physiquement.


## Main workout subtitle — build 69

Progress retains its native navigation row and existing compact GoalDescription (Dynamic Type subheadline, accessible full repetition/load description). It now chooses the workout goal with the highest total target: sum of repetitions × added grams for weighted repetition goals, sum of repetitions for bodyweight goals, sets × seconds for isometrics. Weighted repetition goals take priority over bodyweight ones by explicit user choice. This identifies the main workout; the subtitle shows its original goal, not the score. Equal totals or untimed goals retain workout order; missing/incompatible goals are skipped. Configured workouts, including disabled workouts, remain in the same candidate scope as before. No goal is adopted or changed.

HIG Lists and tables: “Keep item text succinct.” Typography: “Consider using the built-in text styles.” Existing native row, text style and accessibility are preserved. Ranking and tie rules are Reps product choices, not Apple recommendations. Physical rendering remains to be checked.


## Accepted exercise changes and review status — build70

Saving an exercise accepts its new definition for all saved future goals. Each workout keeps its own set count and exact load composition. Repetition targets are clamped only when the configured range changes; otherwise retained, with the minimum for newly required targets. Duration/type changes use the new definition without a second confirmation. Existing mismatches are reconciled during migration13 and restore preview. Saved/active workouts remain unchanged. An unavailable load is never silently replaced by another composition.

Progress prioritizes the concise Review needed subtitle when any assigned goal needs review. Details say Review needed: load unavailable and explain that the saved composition must be selected again. Existing native list text, subheadline/caption styles, semantic secondary color and VoiceOver text remain. This applies the HIG Lists and tables preference for succinct item text and built-in text styles from Typography; automatic goal reconciliation is the user's Reps product rule. Device verification remains required.


## Per-set curves and latest exercise goals — build71

A point still represents one completed workout, positioned using its average per actual working set for volume, repetitions and duration. Maximum added weight is unchanged. Titles, axes/context and VoiceOver distinguish averages from exact workout totals; drag callout retains the latter with `• N sets`. Details include the set count and individual recorded results. Period totals retain exact integer sums and stay stable during selection. Delta text compares per-set values. This normalization is a Reps product rule; HIG Charts guidance supports clear descriptions, units and accessible exact details.

Goals follow the latest completed exercise across all workouts. Actual ordered repetitions and hold durations refresh on completion; assignment counts remain independent and extra sets repeat the last target. Timed goals render compact adjacent groups at tenth-second precision, including per-set target before/during a hold and first-set warm-up derivation. Learned timed goals can be edited per set or cleared together to untimed. Explicit changes to a different load retain associated targets. At unchanged load, refusing an increase still refreshes the actual performance baseline. New assignments seed from the same latest reference. Physical drag/layout/VoiceOver checks remain required after installation.


## Ceiling-average learned targets — build72

Learned goals show one repeated whole-number ceiling-average target instead of ordered per-set values. Compute from actual sets at the highest load in the latest completed exercise session, across workouts; repeat for each assignment's count. Rep ceiling and second ceiling are calculated once after averaging, never per input set. This is the user's Reps rule; no new visual control. Preserve tenth-second historical results, chart projections, manual per-set customization, exact saved load composition and explicit different-load decisions. Schema15 refreshes existing future goals once; no changes to active/historical snapshots.


## Global Stretching — build 73

Settings → Training adds a native Stretching switch, enabled by default, without a description beneath it (removed at the user’s request in build 74). The saved SQLite preference removes the preparation stretch section and stretch steps from every newly started workout when off. Warm-ups and rests keep their rules; final Feeling says Finish Workout and completes the session. Existing active/history snapshots are unchanged. The switch is disabled during saving and reports errors without showing an unsaved value. HIG reference: Toggles (“Use a toggle for two opposing values that affect the state of content or a view.”); native List/Toggle, system typography and VoiceOver state. This scope and future-only behavior are Reps product choices. Physical Dynamic Type, VoiceOver and flow validation pending.

## Audit corrections — build 75

Recorded-set labels retain tenths in minutes/seconds; rest timers retain whole seconds. The metric picker follows ChartPeriodPicker's native segmented/menu adaptation for width and text size. Consistency uses lazy week columns and a complete off-main projection keyed by history, schedule weekdays, local date and time zone; minute ticks retain it, and cancelled results never publish. Full historical range, gestures, day selection and native motion stay intact.

History mutations refresh inherited automatic goals transactionally. Matching ignores only exercise name/enabled metadata and preserves separately personalized targets/loads. Source deletion clears an inherited goal only when no completed rated source remains; an unavailable exact load never becomes guessed bodyweight. Correcting actual set count uses an in-memory completed-source projection, preserving stored program/goal snapshots. Renaming or moving a historical date preserves unchanged exercise decisions; changing results/order/Feeling invalidates that exercise's former decision. Preexisting goals of unknown provenance are conservatively retained, not guessed or repaired retroactively. Physical layout/interaction review remains required.

## Selective revert — build 76

User explicitly reverted only three audit changes. Historical add/edit/delete no longer recalculate future goals; normal live-workout completion still learns its next targets. Recorded-result labels use the original whole-second formatter, while stored tenth-second results and chart totals stay unchanged. Consistency restores the original eager HStack and per-minute full-span calculation. Decision preservation, camera error handling, adaptive metric picker and global Stretching/schema16 remain. No personal-data reverse migration. This scope supersedes only those three parts of the build75 design.

## Calisthenics Skills — 1.2.0 — build 78

Progress → Skills uses native lists, detail navigation and forms, preserving the four tabs. Four built-in roadmaps can be duplicated; custom roadmaps require only a name and at least one named step. Direct starting-step selection does not mark earlier steps acquired. Manual First Success/Consistent states are reversible. Adoption of a new current step into selected future workouts is explicit and preserves each block's settings.

Workout Skills form an ordered group before strength by default, optionally after strength and before stretches. Each practice shows its own preparation; existing strength warm-ups remain. During an active workout, adjustments apply only to that snapshot. Free Practice avoids interaction between attempts; detailed holds/repetitions use actual results and persisted rests. Ending a practice pauses elapsed time before optional result entry. Practice time and declared best hold have separate labels. Source demonstrations open externally only when selected.

HIG references consulted: Lists and tables (text and concise row content), Entering data (choices and defaults), Onboarding (postpone nonessential setup), Accessibility/Typography and Designing for iOS. The roadmap, placement and tracking policies are Reps choices. No new visual media or network service. Physical iPhone validation is pending.

## Skills interface refinement — 1.2.0 (79)

Skills appears immediately below Consistency and above Body Weight. The overview prioritizes the current/default starting step with a prominent Practice action, a numbered native roadmap, and separate Beyond the Goal extensions. Each step opens a focused detail with labeled guidance and manual progress; browsing does not adopt a step. Edit/archive live in the More menu. Destructive icon buttons reuse explicit red glyph/text styling. App-owned text uses US English; older preset wording is adapted for display without rewriting custom text or history.

## Skills lifecycle and creation — 1.2.0 (80)

Skills-only controls in `SkillButtons.swift` centralize black ink on accent-filled primary/confirmation buttons (cancel corrected in build81), neutral white icon menus, semantic destructive roles and red ink, and contrasting native destructive swipe actions. System alert actions and EditButton remain native exceptions to icon lists. No other section adopts the Skills visual system.

Add to Workout carries an immutable SkillAssignment in a typed sheet. The workout editor owns the block sheet and commits an isolated block draft only on Save. Context-menu progress actions reconcile ordered steps: predecessors become consistent; later consistency is demoted to first-success when moving back, preserving prior success evidence. All main and secondary steps must be consistent to enter Completed. Archive, confirmed permanent deletion, and confirmed progression reset remain distinct; reset also rewinds future blocks while retaining volumes and history. Recorded terminal practice deletion never removes strength results.

Create with AI adapts Kavi's actual external handoff: name, copied prompt, chosen provider app, explicit response paste, strict validation, review and single save. No backend, API credential or model SDK. Manual creation/editing remains available.

## Skills creation refinement — 1.2.0 (81)

Skills uses the inline centered title shared with Body Weight. The plus and cancel buttons use neutral native glass with white SF Symbols; only confirmation buttons retain accent fill and black symbols. Archived Skills follows Completed. Archive swipe deletion shows only its symbol; the whole row supports a long-press menu with confirmed permanent deletion.

The AI flow follows Kavi's NewDeckCreationFlow in iOS/Flashcards: name → provider → editable review. Bundled template provider logos reuse Kavi artwork. An opening/paste panel advances directly from an explicitly pasted response into the editor; parse/clipboard/opening errors use visible alerts. There is no raw JSON editor or inert separate Review Skill control. Back navigation preserves the edited draft with Continue Reviewing; saving closes the complete wizard. At accessibility text sizes the bottom panel joins the scrolling content. Parsing accepts prose-wrapped/fenced JSON while rejecting ambiguous distinct roadmaps and preserving strict field validation.

## Physical refinements — 1.2.2 (83)

Neutral Skills toolbar buttons now rely on native toolbar glass rather than nesting explicit glass styles. Provider logos resolve bundled PNG files directly. Destructive menu symbols carry original system-red image ink, retaining white contrast for filled destructive swipe actions. Achievement updates are independent of current-step selection and of other achievements; only explicit current selection uses ordered reconciliation. AI prompts explicitly request web research and verified demonstration URLs per step, with honest browsing limitations.

ChatGPT import tolerates copied Markdown hard breaks and encoded/nonbreaking indentation outside JSON strings. It preserves instruction/URL content and valid escapes, retaining strict schema validation and explicit errors.

## Accent content symbols — 1.2.3 (85)

SF Symbols beside normal content/action text use Reps's adaptive blue accent through a shared native LabelStyle; titles retain their existing style. Applied inside each tab's content only. Native tab icons/selection, standalone toolbar glyphs, destructive red ink and contrasting ink on filled buttons remain distinct. Hand-built roadmap symbol rows follow the same accent rule; numeric step markers retain their status styling.

## Native Skills menu symbols — 1.2.4 (86)

Device feedback shows native menu entries ignore the global template LabelStyle. Ordinary Skills menu/context-menu labels use original UIKit SF Symbol images precolored with Reps's adaptive accent, following the already-working destructive symbol rendering. Title text stays primary; toolbar plus/ellipsis stay white; destructive labels/images retain red. Other content styling and native tabs remain unchanged.

## Consistency photo days — 1.2.5 (87)

Remove the entire Filled/Dot/week legend. Missed scheduled workouts use xmark. Dates containing progress photos use camera.fill; completed-workout dates keep the accent background and contrasting ink. Other photo dates use the accent camera on a neutral background. Photo presence never completes a workout. The grid and day list include photo-only dates; their natural range starts at the earliest completed workout or indexed photo date. Current missed-day rules, fillers and horizontal navigation remain.

Day detail displays the photo count without loading media or bypassing Private Photos. VoiceOver/list summaries include both workout state and photo count when applicable. A short temporary message explains that older photo days require one normal vault unlock; generic activity-read errors expose no private details. Vault Settings explains that dates/counts are visible outside Face ID while images remain encrypted. camera.fill is Reps's product choice using a familiar system symbol, not an Apple-prescribed attendance metaphor. Physical small-cell readability, Dynamic Type and appearance checks remain required.

## White photo-day camera — 1.2.6 (88)

User-requested white camera.fill in Consistency, including completed dates. Visual-only retouch, separate versioned commit before the streak feature. Strict lint, nine metadata/style checks, real xtool build, regenerated/embedded App Intents metadata and unsigned app/widget inspection pass. Standard USB delivery tracked in the photo-activity ExecPlan; no new domain tests or private-data access. Physical rendering remains user validation.

## Current workout streak — 1.2.7(89)

Consistency now shows native LabeledContent("Streak", value:e.g."15 days") in place of the lifetime completed-day counter. Duration is inclusive calendar days from the first completion in the current run through today, including rest days. A completion resets consecutive misses; N missed planned workouts breaks the run, with N derived dynamically from current enabled nonempty workout weekdays. Today remains eligible until midnight. Photos/active/canceled workouts do not rescue a streak. No weekly schedule =>0days. Changing the current schedule recalculates historical attendance and streak; historical planning snapshots do not exist.

Settings→Progress→Streak Units uses a native in-context menu picker with Days (default) and Largest Unit. Largest Unit floors7/30/365-day conversions, preferring years then months then weeks; the user’s15→2weeks and372→1year examples are covered. A footer explains rest days, current-schedule break rules and unit lengths. This presentation choice follows the existing @AppStorage haptics convention and changes the value immediately without changing the actual streak. White camera glyph from the separate1.2.6commit is retained.

## Direct streak-unit menu —1.2.8(90)

At the user's request, tap the right-hand streak value (e.g.33days) directly to open a native menu containing the Days/Largest Unit picker with current selection. Settings no longer contains the Progress/Streak Units section or its footer. The existing preference key, saved choice, formatting and streak rules are retained. StreakSummaryRow owns the same @AppStorage value and exposes a VoiceOver label/value/hint; the native left-label/right-value row layout remains. Physical menu behavior and text size checks remain required.

## Private movement videos —1.3.0

Progress→Private Vault retains the four native tabs and existing full-screen Face ID boundary. A native segmented picker switches Physique/Movements. Movements is a native list of Following Skills, Custom Movements and Saved Movements; automatic entries reuse stable encrypted Skill links, with random vault row identifiers. Custom movement creation/rename never touches the training catalogue. Titles, forms and all video sheets are masked when inactive; movement navigation titles become generic under coverage.

Movement details show dated native rows with lazy thumbnails and durations; import is a system PhotosPicker restricted to video, followed by an editable progression date and explicit Save. One video uses AVPlayerViewController. Comparison preserves the original aspect ratios in two equal columns, with dates, native sliders,1/0.5/0.25xpicker, Link Playback and shared/separate controls. Manual seek establishes each gesture offset; shared start uses the same host clock, and a boundary/end callback pauses both at the first end. Comparison is muted. Secondary actions use native menus with original UIKit accent glyphs; destructive actions remain red. Dynamic Type and VoiceOver labels are present; visual/touch acceptance remains physical.

Apple HIG Playing video recommends the system player and original aspect ratio; Segmented controls supports related subviews. The two vault categories, limits, movement grouping and paired alignment policy are Reps choices. No custom glass/card system or decorative animation is introduced.

### Vault movement video corrections

Movement videos use the same dated stack layout as physique photos; a day's clips open in a native list supporting confirmed contextual and trailing-swipe deletion. The privacy mask no longer disables descendant animation transactions, so native sheet/editor transitions work normally, including system Reduce Motion behavior. Comparison uses stable player identities and per-scrubber updates, prepares both players, then schedules a common host-clock start while preserving independent alignments. Linked buffering pauses both rather than allowing one to continue drifting.

### Added-weight choice spacing

Inventory choices, selectors and progression proposals retain ascending exact totals at least500g apart, anchored to the last retained load, keeping the lighter option. Exactly500g remains. An existing valid picker selection remains visible even if the new-choice filter omits it. Full inventory validity, adopted goals and saved/active snapshots retain their exact grams and components. Filtering occurs after subset generation, so small items can still combine; exhaustive-generation complexity guards remain unchanged.

## Portrait and inventory quantities —1.4.0(100)

User explicitly requested portrait throughout. The iPhone plist allows only UIInterfaceOrientationPortrait; the registered app delegate also returns .portrait for system/fullscreen presentations. This is a product choice; media assets and video transforms are unchanged.

Added Weight uses native Form controls: Unit Weight (kg), Quantity with direct number entry and an adjacent native stepper, and the existing enable toggle. Default1; range1…1000. Inventory rows show count × unit kg; preparation, picker and history group names as Book × 10 with total component kg. A ten-copy100g item supplies0…10copies; each total appears once, backpack included once. Existing500g offered-choice spacing stays.

Quantity snapshots preserve original name, subtotal grams and count independently of current inventory. Existing components default1 and retain their previous display. Dynamic Type, VoiceOver and actual fullscreen rotation still require physical review.

## Minimum objects and ten-object cap —1.4.1(101)

Available Loads retains ascending total weight and500g choice spacing. For each exact total, use the minimum number of physical copies, up to10weight objects plus the fixed backpack; grouped lines count their quantities. Prefer1×1kg over10×100g. Inventory quantities stay1…1000; only proposed compositions are capped. Stable deterministic ties. The native list footer explains this rule without adding a setting.

Feasibility validation checks saved exact names/IDs/unit weights/enabled inventory/counts independently from the preferred composition. Old selections of≤10objects remain usable; the picker shows the preferred composition once when that same total is already offered. Feasible filtered-out selected totals stay available. Recorded/active snapshots and existing archives are unchanged; future over10choices require review. Portrait-only declaration and global mask remain intact.

## Object priority before spacing and Maximum Objects — 1.5.0 (102)

The user corrected the earlier same-weight-only interpretation. Rank exact compositions by physical copy count ascending, then grams ascending for ties. Process that order, retaining a candidate only when it is at least 500 g from every already accepted higher-priority choice. Finally display retained choices by ascending grams. Thus 10.2 kg with one object wins over 10 kg with five. The fixed backpack counts as zero added objects; bodyweight and the bag remain available. Existing feasible selected-load exceptions remain visible without changing snapshots.

Settings → Added Weight → Maximum Objects opens a native saved-draft form with numeric field, adjacent stepper, Cancel and Save. Default 10; range 1–1,000, excluding the backpack. No persistence until Save; disabled while saving and errors remain visible. Apply the preference to all generated options, goal availability/review, selection validation and progression. Inventory quantities do not change when the maximum changes. Portrait remains locked.

## Added Weight text cleanup — 1.5.0 (104)

At the user’s request the approved Maximum Objects modal remains. Remove only five explanatory Section footers in Added Weight and its item/maximum editors: fixed backpack weight, excluded backpack, choice algorithm, unit-weight/quantity help and maximum-range help. Labels, values, empty states, confirmations and errors stay. No domain/persistence/selection/portrait behavior changes.

## Grouped backpack settings — 1.5.1 (107)

Backpack and Maximum Objects are two native rows in one List Section, giving one system-rounded group. Both open saved-draft native forms with Cancel/Save; Backpack uses the existing decimal kilogram parser (up to three decimal places), current weight and keyboard dismissal. Default 3 kg, strictly positive; disabled during save, clear errors, no explanatory footer restored. Physical grouping, keyboard, Dynamic Type and VoiceOver remain user review.

The custom bag component is added once and remains excluded from object counts. Bodyweight0, configured object maximum and object-first filtering before500g are retained. Changing bag weight recalculates future choices; exact old goals become Review needed instead of silent substitution, and active/history snapshots retain their original bag weight.
