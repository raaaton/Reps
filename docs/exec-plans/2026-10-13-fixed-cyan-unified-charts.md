# Sport0.11.5 — cyan fixe et courbes unifiées

Demandes utilisateur : conserver uniquement Icy Cyan(#4DD9E8), supprimer son réglage ; supprimer le regroupement/filtre Workout Conditions des graphiques ; symbole Pause blanc pendant le repos.

Couleur fixe dans l'app et le widget, sans lecture de l'ancienne préférence. Autres palettes et écran/settings retirés du produit ; ancienne clé UserDefaults laissée intacte, plus utilisée. Champ optionnel de couleur ActivityKit conservé pour compatibilité de décodage, mais le rendu utilise le cyan fixe même pour les anciennes activités. Variantes de contraste existantes conservées ; icône Pause explicitement blanche dans l'app et Live Activities. Le contraste de cette icône est inférieur sur le cyan clair, choix utilisateur explicite ; texte de Pause reste lisible et sombre dans l'app.

Courbes : toutes les séances des filtres période/lest retenus reliées dans une seule série, pour Volume, Repetitions, Duration et Added Weight. Plus de filtre ni état Workout Conditions. Total de répétitions de tous les points affichés, avec addition protégée contre overflow ; volume cumulé sur période et valeurs par séance inchangés. Conditions historiques toujours conservées dans les données. Cache de projection et publication atomique maintenus pour éviter le flash au changement de filtre.

Vérification : test de palette unique rouge avant correction ; tests existants de calcul/conditions/volumes et suite complète, lint, compilation xtool, metadata/inspection, revue puis préflight/installationUSB/postflight. Aucun test SwiftUI simulé sousLinux. Rendu des courbes, Pause blanche, relance et Live Activities à confirmer sur iPhone. Aucune migration, permission, clé du coffre ni format d'export modifié. Icône d'app reste en todo ; sauvegarde privée abandonnée.


## Vérifications locales

Test palette unique : échec observé avant correction, puis suite complète155tests/0échec5,445s. Lintstrict0 ; xtool22,40s puis metadata/empaquetage2,31s codes0 ;6testsmetadata/0échec et verify-foundation0. Revue indépendante : aucun défaut concret, calcul/sélection/filtres/compatibilité cohérents ; Pause blanche et rendu des activités restent physiques. Préflight0.11.4 même app/certificatvalide réussi. Installation terminée, aucune nouvelle permission ou identité.


LivraisonUSB : device-run.sh code0, rebuild2,62s/install-vérification100%. Postflightdirect0.11.5(39) code0 : même identité/certificat, profilsvalides CMSvérifiés, app/widget et permissionsinchangées. Caches/SDK/HelloSport préservés. Arrêt pour recette : cyan partout sans réglage, courbes/drag/totaux avec historiques aux conditions variées, Pause blanche et Pause/Resume app/Lock Screen/Dynamic Island, relance et régressions habituelles. Aucun rendu iPhone revendiqué à partir des seuls tests/builds.
