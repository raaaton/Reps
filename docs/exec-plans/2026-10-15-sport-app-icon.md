# Icône Sport — haltère en couches

Autorisation : trouver un SVG adapté et réaliser directement l’icône comme Kavi ; demander à l’utilisateur de chercher seulement si aucun candidat satisfaisant. Prototype Kavi 0.11.10 confirmé « c parfait », rendu Linux accepté.

Choix : silhouette pleine Phosphor barbell-fill, dont les volumes épais et les coins arrondis restent lisibles en petit. Source et licence MIT conservées sous Resources/IconSources ; licence embarquée dans l’app, aucune bibliothèque ajoutée. Adaptation en deux couches SVG sous Resources/SportIcon.icon : corps cyan Icy Cyan et poids extérieurs argentés, rotation −32° ; réglages verre, ombres, translucidité et fond anthracite repris du prototype Kavi accepté. Échelle centrée 1,18, aucun texte ou SF Symbol dans le logo. Les effets restent décrits dans le catalogue natif, sans image aplatie comme source.

build-app-icon.py compile le nouveau nom SportIcon ; xtool.yml et CFBundleIcons pointent vers ce catalogue. App/widget 0.11.11 (45), identité et capacités inchangées. Ancienne référence Kavi conservée mais non embarquée. Aucune logique d’entraînement/coffre/timer ou donnée modifiée.

Vérification prévue : contrôle visuel du PNG de secours réellement compilé, lint strict et 6 tests metadata, build xtool réel, vérification des ressources et de la licence dans l’app, préflight identité/certificat, installation USB et postflight. Attendre le retour iPhone sur cadrage, couleurs, relief, variantes sombre/teintée avant de considérer le rendu validé. Pas de nouvelle suite de tests de domaine pour un remplacement de ressources.

Progression : sources et configuration en place ; lint et 6 metadata réussis. Compilation d’icône en cours.

Inspection du PNG réel : première silhouette trop petite car les SVG 512 px restaient centrés dans le canevas Icon Composer 1024. Couches passées en 1024 px en conservant leur viewBox, pour occuper environ 70 % de l’icône ; nouveau rendu compilé et inspecté avant installation.

Livraison : rendu final du PNG réellement compilé inspecté, cadrage corrigé puis actool code 0. Lint strict et 6 metadata réussis, builds xtool 2,09 s puis 2,13 s, inspection unsigned app/widget/catalogue/licence code 0. device-run.sh code 0 (rebuild 2,09 s), installation/vérification 100 %. Postflight direct : Sport 0.11.11 (45), même identité/certificat, profils CMS valides et aucune nouvelle capacité. Aucune donnée/photo personnelle consultée. Recette visuelle Home Screen en attente ; l’icône est créée/intégrée mais pas encore validée physiquement.
