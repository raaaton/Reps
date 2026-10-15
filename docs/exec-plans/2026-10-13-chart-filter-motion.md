# Correction des transitions de filtres graphiques

## Objectif
Demande du 13 octobre : reprendre simplement les animations 1/3/12 mois et Volume/Répétitions/Lest, jugées buggées sur iPhone. Périmètre limité à la présentation des graphiques.

## Diagnostic et décision
La 0.9.0 applique sportAnimation(value:loading) à toute la List. Le chargement retire et réinsère sections, tracé et axes, donc le ressort affecte la géométrie de toute la page. Retirer cette animation ; conserver les pickers système. Une identité par requête recrée le graphique au changement de filtre ; tracé/axes sont instantanés, seul le conteneur apparaît en fondu easeOut de 0,15 s (choix Sport). Pas de délai, tâche d’animation ni interpolation entre unités. Sélection au doigt immédiate. Reduce Motion/VoiceOver/scène inactive désactivent le fondu. Calculs, données, haptics et concurrence de chargement conservés.

## Vérification
Lint, tests hôte applicables, xtool réel, génération/empaquetage metadata, 6 tests metadata et inspection unsigned. Préflight identité/certificat, device-run.sh puis postflight. Test physique : changer rapidement période/mesure, états vide/un point, drag/bulle, Reduce Motion. Linux ne peut pas reproduire le rendu SwiftUI sur iPhone ; ne pas écrire de tests de texte reproduisant les modificateurs de présentation.

## Progression
Sources et documentation du jalon lus ; animation globale identifiée et remplacée. Version 0.9.1 (23) installée et contrôlée ; recette physique en attente.


0.9.1 (23) : lint strict code0, 129tests hôte/0échec (5,631 s), xtool réel10,95 s, génération metadata puis empaquetage1,89 s, 6tests metadata/inspection unsigned code0. Préflight0.9.0 identité exacte/certificat existant valide>24h et présentApple code0. device-run.sh code0, installation/vérification100%. Postflight direct0.9.1 même app/widget, profilsvalides CMSvérifiés, même certificatpréflight/localinchangé, aucune permission/AppGroup/push. Deux vues uniquement, aucune modification du domaine/SQLite/exports/haptics. Pas de test artificiel de texte UI ou de nouvelle revue indépendante pour cette correction de présentation limitée ; comportement et rapidité réels à confirmer sur iPhone.


## Flash de chargement — 0.9.2

Retour iPhone : « Prochaine séance » remonte pendant chaque changement de filtre. Le retrait du ressort dans0.9.1 corrigeait l’animation, mais conservait deux trous de présentation : projection.request != request avant lancement de la tâche, puis branche loading remplaçant toutes les sections.

Correction : conserver la dernière projection complète durant l’actualisation, en utilisant sa mesure et sa période pour tous les libellés/calculs affichés. Indicateur discret en overlay du graphique, sans nouvelle ligne ni effondrement de sections. Publier contexte/projection/sélection/fin de chargement ensemble sans animation de liste ; refuser les réponses annulées ou qui ne correspondent plus à la requête. Échec de mise à jour : garder les résultats et afficher une erreur avec retry. Le premier chargement conserve son indicateur dédié. Données, calculs métier, haptics et navigation conservés.

Vérifications en cours : lint, tests hôte de régression, xtool et packaging/metadata/inspection, préflight/USB/postflight. Pas de test de texte SwiftUI miroir ; flash/rapidité/scroll/gestes demandent test physique. Recette : alterner rapidement période/mesure et filtres, vérifier que Prochaine séance reste sous les résultats pendant le chargement, unités cohérentes, drag/bulle et états vides.


Vérification 0.9.2 (24) : 129tests hôte/0échec (5,293s), lintstrict code0 ; xtool réel11,32s, génération metadata puis empaquetage1,94s codes0 ; 6tests metadata et inspection unsigned réussis. Préflight0.9.1 identité exacte et certificat existant valide>24h/présentApple code0. device-run.sh code0, installation/vérification100%. Postflight direct0.9.2 code0 : même app/widget, profils valides/CMS vérifiés, certificat préflight/local inchangés, aucune permission/AppGroup/push. Aucun changement SQLite/format/calcul/haptic. Contrôle statique des branches et guard de requête : résultat gardé même quand loading=true ou requête change, libellés issus de projection.request, publication groupée sans await et réponses périmées refusées. Rendu SwiftUI/scroll non testable Linux, recette iPhone en attente ; aucun test UI simulé.
