# Sport0.11.6 — actions rouges, confirmations neutres et graphiques

## Périmètre validé

Demandes : icônes des textes destructifs rouges (Delete All Photos/Delete et autres actions rouges), Cancel non teinté cyan dans les confirmations, bulle de sélection devant la ligne pointillée. Ajout : supprimer Load to Compare dans Repetitions. Clarification utilisateur : Cancel blanc en sombre/noir en clair (couleur neutre système), pas blanc illisible en clair.

## Implémentation

SportDestructiveButton garde Button.role.destructive, avec titre/SF explicitement rouges et tint rouge pour menus/contextes/actions inline. Swipe blanc sur fond rouge natif préservé, puisqu'il ne présente pas un texte rouge. Aucun changement des closures de suppression/validation.

SportConfirmation garde les SwiftUI.alert d'origine, leurs bindings, presenting et callbacks. Petit UIViewControllerRepresentable transparent/noninteractif : attente bornée≤60×16ms pour le UIAlertController présenté dans la même fenêtre, puis sa propriété UIKit publique view.tintColor=.label. Aucune UIAppearance, swizzling, API privée, interception d'action ou modification de présentation. Recherches de hiérarchie bornées, annulation à fermeture/dismantle/inactivité, contrôleur faible, pas de lecture de contenu/title ou de logs. Les actions non destructives de ces confirmations sont neutres ; les destructives gardent le rouge système. Erreurs/OK hors confirmations inchangés. Adaptation MainActor explicite après trois avertissements de compilation corrigés.

Graphique : RuleMark placé avant les autres marques et zIndex−1, PointMark/annotation sélectionnés2, autres points1 ; bulle opaque native existante, gestes/valeurs/haptics inchangés. Repetitions sans aucun filtre de lest : toutes les charges et charges mixtes sont incluses. Totaux additionnent tous les points de la période, ordre historique et détail par séance conservés. Duration garde son filtre ; conditions historiques conservées. État vide corrigé après revue pour ne plus proposer un lest dans Repetitions. Promesse de sauvegarde privée portable retirée du texte du coffre, conformément à l'abandon déjà demandé.

## Vérifications

Test ciblé Repetitions rouge avant correction : aucune séance affichée avec weight=nil. Après correction : poids du corps, séance lestée et charges mixtes aux conditions différentes, ordre attendu, total93, annulée exclue. Suite complète156tests/0échec5,77s ; lintstrict0 ; xtool initial20,82s puis9,14s sans avertissement d'isolation. Métadonnées/installation terminées. Revue indépendante : état vide mineur corrigé ; aucun autre défaut étayé. Aucune exécution de SwiftUI/UIKit/FaceID sousLinux.

## Recette iPhone

Menus Delete All Photos/Delete photo/pile, archives/historique/réglages : symbole et titre rouges. Ouvrir confirmations puis Cancel, sans suppression nécessaire ; vérifier blanc sombre/noir clair, aucune donnée modifiée. Depuis une confirmation du coffre, arrière-plan : masque immédiat et FaceID au retour, confirmation périmée fermée. Tester autre confirmation comme Start Again/Cancel et aperçuimport/Cancel. Graphique : drag près des extrémités et en haut, bulle devant la ligne/points ; Repetitions sans sélecteur de lest, toutes les séances et somme cohérentes, états vides/filtres stables. Await retour iPhone avant autre chantier.

Pas de migration, nouvelle permission, entitlement, format de transfert ou modification des clés/leases du coffre. Cyan fixe, Pause blanche, icône en todo et sauvegarde privée abandonnée conservés.


## Livraison0.11.6(40)

Après l'état vide corrigé : xtool final8,97s sans avertissement,6testsmetadata/0échec et inspectionunsigned0. Préflight0.11.5 même app/certificatvalide. device-run.sh code0/rebuild2,32s/install-vérification100%. Postflightdirect0.11.6 code0 : même app/widget/certificat, profilsvalides CMSvérifiés et permissionsinchangées. Caches/SDK/HelloSport conservés, aucune suppression/import de données personnelles. Textes du coffre ne promettent plus la sauvegarde privée abandonnée.

Installé avant review ; geste/teinte réelle des alertes et couche d'annotation restent essais physiques, aucune certification runtime. Le UIKit.tint neutre touche toutes les actions non destructives de ces confirmations ; les rôles destructifs/actions/bindings demeurent d'origine. Retour iPhone attendu avant nouvel ajout.
