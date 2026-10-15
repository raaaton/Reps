# Couleur d'accent — Sport0.11.4(38)

## Objectif et décisions

Demande : réglage avec sept couleurs, appliqué immédiatement et conservé après relance. Settings → Appearance → Accent Color, liste native avec pastille, nom et coche accessible. App anglaise : Apple Blue, Mint(#46D7A7, vert malgré le nom « jaune pâle » de la demande), Energy Orange(#FF873D), Lime Yellow(#D7F75B), Violet(#A78BFA), Coral(#FF647C), Icy Cyan(#4DD9E8). Apple Blue utilise la couleur système et reste le défaut.

Les six valeurs personnalisées sont conservées exactement pour pastilles et fonds de boutons. Texte noir/blanc sur ces fonds selon contraste. Liens, onglets, symboles et courbes utilisent des variantes lisibles sur les fonds système clair/sombre et avec Increase Contrast ; pas de changement des couleurs sémantiques/destructives. Choix limité à cette liste, pas de ColorPicker libre ni changement d'apparence système.

Préférence UserDefaults/AppStorage, comme les haptics : cosmétique locale, hors exportJSON d'entraînement. Pas de migration, données métier ou permission. Champ optionnel dans le ContentState des Live Activities, absent = Apple Blue pour anciennes activités. État du repos, échéances, pause/reprise et identité d'app restent inchangés. Rafraîchissement des activités au changement de palette ; choix transmis depuis l'app sans App Group.

## Implémentation et vérification

Palette/RGB et calcul de contraste testés sous Linux ; couleur système fournie par UIKit. Environnement d'accent SwiftUI, boutons prominent natifs avec foreground contrasté, intégration courbes/grille/séries et widget. Légende de grille indépendante du mot Blue. Réglage avec sélection explicite en plus de la couleur et cibles44pt.

Trois tests ciblés ont échoué avant implémentation, puis réussi : valeurs exactes/fallback, contraste sur fonds clairs/sombres/élevés et valeurs de référence sRGB. Seuils4,5 et7 issus des recommandations d'accessibilité ; marge numérique sans arrondi du ratio. [HIG Color](https://developer.apple.com/design/human-interface-guidelines/color), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), [WCAG contraste](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Palette/cible44pt propres à ce réglage ; référence HIG locale consultée, sources Apple web partiellement dépendantes deJavaScript.

Suite complète, lint, revue indépendante, xtool réel, métadonnées, préflight, installationUSB et postflight terminés. Aucun résultat de rendu, persistance sur appareil, glass ou Live Activity revendiqué depuis Linux.

## Recette iPhone

Choisir chaque couleur puis revenir dans Today/Progress : onglets, bouton Prepare/Resume, séries, courbes/grille doivent suivre ; texte et Play lisibles. Quitter/réouvrir Sport : choix conservé. Tester clair/sombre et Increase Contrast, grand texte/VoiceOver. Pendant un repos, changer la couleur puis vérifier Lock Screen/Dynamic Island et Pause/Resume sans changement de temps. Retour Apple Blue possible à tout moment. Arrêt pour retour physique avant toute autre évolution ; icône personnalisée reste dans la todo.


## Livraison réelle

Sport0.11.4(38) installé.155tests hôte/0échec(5,941s),3tests couleur ciblés positifs après échec observé avant implémentation ;6testsmetadata/0échec, lintstrict0 et verify-foundation0. xtool initial28,07s, variantes11,23s, retouchePlay9,18s, empaquetage final2,33s, tous codes0. Revue indépendante sans constat bloquant : vérifier boutons désactivés, contraste augmenté et activités déjà présentes sur appareil.

USB d'abord bloqué : serviceusbmuxd inactif, démarrage automatique refuse « sudo: a password is required ». L'utilisateur confirme le démarrage manuel ; préflight répété0 sur0.11.3/mêmecertificatvalide. device-run.sh0/rebuild2,37s/install-vérification100%. Postflightdirect0.11.4 : même identité/certificat, profilsvalidesCMSvérifiés, uneextension et permissionsinchangées. Aucun App Group, migration ou accès aux données personnelles. Caches/HelloSport/SDK conservés.

Fonction et build livrées avant demande de review ; recette iPhone attendue. Pas de reprise de sauvegarde privée ni de création de l'icône dans ce périmètre.
