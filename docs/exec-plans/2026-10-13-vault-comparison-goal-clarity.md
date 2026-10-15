# Sport 0.10.1 — piles photo et objectifs lisibles

## Autorisation et périmètre

0.10.0 confirmée sur iPhone. L’utilisateur demande un reset rouge avec SF Symbol, une pile par jour et une comparaison de deux photos de même pose, ainsi que des objectifs moins confus. Présentation proposée puis explicitement approuvée par « vas-y » : Face au repos / Face contractée / Dos, piles datées, comparaison côte à côte entre deux dates ; résumé Objectif ·4×10·+6kg, écran objectif actuel/proposition distincte et personnalisation séparée. Pas de traduction globale, d’archive privée, de changement de recommandations ou de rappel mensuel.

## Décisions

- Ajouter une pose optionnelle aux métadonnées déjà chiffrées. Les anciennes photos restent sans pose jusqu’à attribution explicite ; aucune analyse/reclassification automatique ni modification des originaux. Toute photo conservée dans la pile de sa date, sans limite artificielle de trois photos.
- La comparaison choisit une pose et deux photos de dates différentes. Doublons de pose conservés et sélectionnables. Chargement d’aperçus bornés dans le store, lease/session/requête validés avant publication, effacement au lock et à la fermeture. Le masque protège aussi les nouvelles routes.
- Réutiliser le stockage AES-GCM et l’édition transactionnelle de métadonnées. Aucun schéma SQLite, Keychain, entitlement ou permission supplémentaire.
- Un objectif concret remplace la plage de programme sur Aujourd’hui/préparation ; la plage reste consultable dans le détail. Suggestion distincte adoptable, édition manuelle dans un écran séparé ; aucune adoption silencieuse.
- Pas de dépôt Git utilisable ici : modifications dans le workspace demandé, sans init/reset/worktree. Suivi dans ce document plutôt qu’outils de ledger dépendants de Git.

## Étapes et vérification

1. Modèle de métadonnées compatible et projections de piles/poses/comparaison. Tests hôte utiles : ancien JSON préservé, pose enregistrée, regroupement sans perte, tri et rejet de comparaison incompatible.
2. UI coffre : reset rouge, piles/détail d’un jour, pose à l’ajout/édition, comparaison et lifecycle privé. Revue indépendante de sécurité avant installation.
3. Objectifs : résumé commun et écran simplifié, personnalisation détaillée séparée ; garder les règles/adoption et gardes de brouillon existantes.
4. Tests hôte, lint Swift strict, xtool dev build réel, métadonnées app/widget, inspection bundle ; préflight lecture seule identité/certificat, device-run.sh puis postflight.
5. Installer0.10.1 avant review. Recette iPhone : anciennes photos, dates/poses, comparaison et changement de sélection, interruption/background de nouvelles routes, reset/Annuler, objectifs/adoption/personnalisation, régressions séance/Live Activities. Attendre retour avant prochain jalon.

## Progression

Documentation et vues concernées relues ; preuve0.10.0 validée par l’utilisateur. APIs existantes réutilisées, aucun nouveau framework ni dépendance. Implémentation en cours. Le rendu et lifecycle SwiftUI ne sont pas testables sous Linux.


Modèle ajouté et tests exécutés : cinq assertions RED attendues avant projections, puis suite140tests/0échec (5,200s). Test de compatibilité ancien JSON positif dès le premier passage ; il n’est pas présenté comme RED. Premier run sandbox interrompu (CFSocket/caches readonly), suite réellement exécutée hors sandbox autorisé. Lint strict code0. Build xtool avec cache existant en cours ; revue indépendante unique demandée.


UI complète et pose chiffrée ajoutées, modèle ancien compatible. Comparaison : deux aperçus2400px, état central effacé et requêtes périmées refusées ; contrôles natifs et ScrollView adaptatif sans hauteur fixe pour les libellés. Revue indépendante statique : aucun constat Critical/Important/Minor ; pas de runtime iOS. Build initial refusé par cache readonly dans sandbox, puis exécuté après escalade autorisée. Une surcharge NavigationLink absente du SDK a été remplacée par destination + Label standard : xtool20,81s/code0. Dernier ajustement des libellés des sélecteurs en compilation finale ; aucune modification du domaine après les140tests.


## Livraison0.10.1 (29) — 13 octobre

140 tests hôte/0échec (5,200s), lint strict code0. Compatibilité de métadonnées sans pose, attribution persistée, regroupement sans perte et rejet des comparaisons date/pose incompatibles couverts ; cinq assertions RED observées avant les projections. Pas de tests artificiels de texte UI. CompilationAPI initiale a signalé une surcharge NavigationLink absente, corrigée par Label standard ; rebuild20,81s puis dernier build7,53s codes0. Génération metadata réelle, empaquetage2,19s, six tests metadata et inspection du bundle0.10.1/29 réussis.

Revue indépendante unique statique : aucun constat Critical/Important/Minor. Préflight lecture seule0.10.0, identité effective et certificat existants valides/présentApple code0. device-run.sh code0, rebuild2,20s, installation et vérification100%. Postflight direct code0 :0.10.1(29) même app/widget, profils valides CMS vérifiés, certificat préflight/local inchangés ; permissions FaceID/caméra/Photos add-only inchangées, aucun AppGroup/push. Aucun média personnel lu/importé, aucun cache ou source HelloSport supprimé.

Piles/poses/comparaison et objectifs simplifiés installés avant review conformément au workflow. Contrôles de modèle/compilation et revue ne prouvent pas rendu, VoiceOver, DynamicType, caméra ou masquage réel des feuilles empilées. Recette README : anciennes photos/date/pose, deux dates par pose, changements rapides de sélection et interruption/background, reset/Annuler, objectif/adoption/personnalisation et régressions training/Live Activities. Arrêt jusqu’au retour utilisateur ; jalon10 non commencé.
