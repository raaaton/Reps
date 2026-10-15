# Sport — jalon10A : anglais et SF Symbols

## Objectif et autorisation

Après0.10.5 l’utilisateur autorise la suite (« ok continue »), puis choisit explicitement « Interface en anglais + SF Symbols d’abord » parmi sauvegarde/finition. Appliquer les deux premiers points du jalon10 déjà décrits dans PLAN-SPORT-NATIF.md. Sauvegarde privée portable différée ; aucun changement de règle métier ou cryptographique.

## Design

Interface anglaise cohérente : Today, History, Progress, Settings ; Workout/Workouts, Exercise, Set, Rest, Added Weight et Feeling (vocabulaire conservé). Textes courts, erreurs donnant l’action utile, confirmation destructive explicite. Traduire aussi notifications, Live Activities, prompts sensibles et VoiceOver. Ne traduire ni noms saisis/persistés, ni noms des objets initiaux personnels, ni clés JSON/CSV/SQL, IDs/enums/bruits/chemins.

Coche pour enregistrer/valider un éditeur, crayon pour modifier, xmark pour fermer/annuler un écran. Button avec nom accessible et labelStyle iconOnly dans les toolbars ; conserver intitulés dans menus, alertes et grandes actions (Start Workout, Finish Set) dont l’icône seule serait ambiguë. Même rôles, disabled, confirmation et contrôles système ; pas de nouvelle animation/layout. Symboles Apple existants, couleurs système ; Play blanc conservé.

Les textes obsolètes À propos/Repos/Notifications affirmant que entraînement/minuteur/coffre ne sont pas livrés deviennent factuels. Dates et nombres doivent rester lisibles ; dates techniques ASCII/payloads inchangés.

## Étapes

- [x] Audit des textes Sources app/core/live/widget et plists, identifiants/persistance exclus.
- [x] Traduction des libellés, explications et erreurs ; symboles des commandes courantes.
- [x] Contrôles ciblés des changements sans migration ni altération des données ; tests métier, lint strict et xtool.
- [x] Métadonnées natives, revue indépendante, préflight, installation USB et postflight sur la même app.
- [x] Documentation et recette iPhone présentée ; confirmation utilisateur encore attendue.

## Vérification et limites

Tests hôte existants pour les règles de données ; pas de tests artificiels copiant tous les libellés. Examiner les changements et rechercher les textes français restants, en distinguant contenus personnels et texte applicatif. Compiler app/widget avec xtool ; inspecter langue/version/permissions/métadonnées. Recette physique : tous onglets, création/édition/suppression/Annuler, confirmations, erreurs, VoiceOver/grand texte, coffre/masque, notifications et Live Activities, imports CSV/JSON inchangés. Aucun test Linux ne valide le rendu natif ou les permissions existantes ; ne pas lancer de purge/import sur données personnelles.

## Progression

Sources et spécifications relues ; inventaire584 textes candidats, dont identifiants/unités/contenus personnels à exclure. Implémentation en cours.


## Livraison0.11.0(34) — jalon10A

Choix utilisateur explicite : « Interface en anglais + SF Symbols d’abord ». Traductions app/core/live/widget/plists, commandes toolbar iconOnly nommées ; menus/confirmations et grandes actions textuelles conservés. Erreurs/dates/VoiceOver inclus ; contenus personnels, nombres régionaux, schéma/IDs/formats et cryptographie inchangés. Revue indépendante a trouvé quatre omissions (combinaisons, reminder mensuel/sync, fallback date) corrigées avant livraison. Comparaisons exactes des fichiers VaultCryptography/VaultKeychain/TrainingSchema et CSV démo positives ; pas de modification des médias réels.

146tests hôte/0échec, passage final5,362s ; lintstrict code0. xtool initial25,36s, retouches9,08s puis7,94s codes0 ; métadonnées finales depuis constvalues réels puis empaquetage2,14s/code0. Six testsmetadata réussis. Inspection unsigned a d’abord refusé le nouveau texte anglais FaceID car contrôle attendait l’ancien français ; attente exacte actualisée, inspection0.11.0(34)/English réussie. Ce refus était un contrôle de copie, pas un changement de permission.

Préflight lecture seule0.10.5 code0 : même identité Sport, certificat existant valide>24h/présent Apple. device-run.sh code0, rebuild2,17s, installation/vérification100%. Postflight direct code0 :0.11.0(34), mêmes app/widget, profilsvalides CMSvérifiés et certificatpréflight/local inchangés ; mêmes déclarations FaceID/camera/Photos add-only. Aucun cache/SDK/HelloSport supprimé, aucune restauration/import/purge exécutée sur données personnelles.

Installée avant review. Recette : onglets et réglages anglais ; créer/éditer puis Annuler/Sauver via xmark/coche ; confirmations restent explicites, VoiceOver nomme les icônes ; séance/graphique/historique/import/export/coffre/masque et LiveActivityPause/Resume sans régression. Les textes propres à iOS gardent sa langue, contenus personnels peuvent rester français. Pas de réussite de rendu/VoiceOver ou FaceID déduite du build. Sauvegarde portable privée différée, ne pas poursuivre avant confirmation physique.


Retour utilisateur : « ok parfait continue ».10A accepté, poursuite autorisée ; ne pas inventer un compte rendu détaillé de chaque parcours/VoiceOver à partir de cette réponse.
