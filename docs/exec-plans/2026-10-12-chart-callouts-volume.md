# Informations au toucher et volume par séance — correction du jalon 7

## Objectif et autorisation

Demande utilisateur : afficher de petites informations près du point en glissant, conserver le détail sélectionné ; calculer le volume réel du lest (48 répétitions à 6kg=288kg) et le temps total des exercices statiques. Ajustement du même jalon7, aucun8/9. Sources/docs Sport et ancien ExecPlan relus ; autorisation d'implémentation et d'installation déjà donnée. Brainstorming/HIG/test-first/executing-plans appliqués à ce périmètre borné, sans gate d'approbation supplémentaire. Git indisponible/read-only, aucun commit/worktree/reset ; baseline /tmp/sport-volume-before.

## Décisions

Le grand chiffre0.7.2 affichait explicitement la dernière séance, la courbe comportait déjà un total de toutes les séries par séance. Clarifier le libellé « par séance », aucun cumul de toute la période. Nouveau volume = somme(répétitions × grammes ajoutés), conversionkg à l'affichage, calcul exact/overflow contrôlé ; poids du corps non enregistré donc exclu,0kg ne signifie pas zéro effort. Charges mixtes admises pour volume, aucune extrapolation de force. Volume par défaut pour répétitions ; Répétitions à lest uniforme et Lest maximal conservés. Pour statiques, totalms de travail par séance, tous les lests par défaut et filtre uniforme facultatif ; aucune multiplication temps×kg, repos exclu. Contexte sets/objectifs/repos historiques conserve sa séparation.

Swift Charts : annotation date/valeur native près du point sélectionné, placement et débordement contrôlés, appel accessible sans doublonner les marks. Courbe/points/ligne de sélection/détail conservés ; en-tête explicitement consacré à la dernière séance, bulle et détail pour la sélection (hauteur du résumé stable pendant le glissement). Pas d'animation/haptics ajoutés, nouvelles permissions, dépendances, écritureDB, format export ou règle d'objectif.

## Étapes / vérification

1. Tests avant nouvelle métrique : volume288kg, grammes précis, charges mixtes/corps seul, ordre/dates/contexte/annulations/mauvaismode, overflow produit/somme ; durée totale touslestset filtre conservé. Domaine SessionTrends et suite hôte.
2. Prototype annotation/overflow dans SDK par compilationxtool avant UI finale ; intégrer filtre/labels/résumé/bulle. Lint, suite et build réel. Rendu et doigt/VoiceOver/grandtexte exigent iPhone, aucun test SwiftUI Linux fictif.
3. Revue indépendante unique mandatée executing-plans ; corriger importants et vérifier. Version0.7.3(19) app/widget, metadata réelle→package→6tests/inspectionunsigned. Préflight même identité/certificat, device-run.sh USB puis postflight ; docs et recette. Arrêt pour confirmationphysique avant8/9.

## Review focus

Volume réel sérieparserie/chargesmixtes, précision/overflow/0kg, exclusioncancel/mauvaismode ; aucun«gainforce». Durées exactes ms sansrepos/touspoids oufiltre, contexteinconnu distinct. Sélection/vieuxindices/reload/versionrequest/retry et valeurscalloutheaderdetail concordantes. Annotationprèsbords/maxvaleur/grandtexte/unpoint, pascapturedugeste quiempêchele scrubnatif ni bulledoublon VoiceOver.

## Ledger

- [x] Domaine/tests
- [x] Prototype/interface
- [x] Revue/compilation/contrôles
- [x] Installation/docs
- [ ] Confirmation iPhone

Interfaces : somme de grammesrépétés/ms → présentation etCharts ; choix de poids facultatif en durée → points, volume ignorepoids. Conditions/ordre/sessionIDs inchangés. Aucun schéma ou média touché.

Task1 : nouvelleAPI.volume manquante observée en compilation, puis casenum seul ajouté et 8assertions comportementales RED (totauxvolume/touslestsdurée manquants). Calcul produit/somme exacts avec gardes overflow → GREEN118tests,0échec (/tmp/sport-volume-domain-green.log), suite complète. Ancien totalrep n'était pas limité à une dernière série : libellé de la dernière séance clarifié.
Task2 : prototypeannotation/overflow confirmé SDK réel et xtool14,68s code0, puis prototype retiré ; interfaceintégrée14,83s code0. Sandboxbloque cachextool (read-only), escaladeautomatique normale réussie, pasbypass. Préflightlectureseule même0.7.2/certificatexistant>24h/présentApple code0. Résumédernièrestable pendant scrub ; bulles/détail portent valeurs sélectionnées. UIgestes/accessibilité pasexécutablesLinux.

Revue indépendante finale unique :0Critical/Important/Minor, aucun défaut concret. Journal118tests examiné par reviewer sans réexécution. Final:Ruling: rendu bords/max/unpoint/grandtexte/gestes/VoiceOver déclinés car appareil indispensable — compilation et contrôles SDK ne constituent pas validation ; coût : bulle/gestes à tester avant prochainjalon. Version/docs/installation déclinées car en cours — vérifiées par l'exécutant avant livraison, jamais déduites de la revue.
Compilation finale6,77s code0 ; lintstrictcode0 ; générationmetadata depuis vraiesconstvalues et6testsmetadata code0. Packaging2,22s/inspectionunsigned code0, préflight même0.7.2/certificatpréservé réussi.

Livraison : device-run.sh code0,rebuild2,08s,installation/vérification100% ; postflightdirectcode0Sport0.7.3(19)surmêmeidentité effective,mêmeWidgetKit,profilsvalidesCMSvérifiés,mêmecertificatpréflightetlocalinchangé. Aucunecapacité/dépendance/permission/migration/formattransfert modifié. README/PROJECT/DESIGN/BUILD/SECURITY/ROADMAP/planactualisés. VérificationsUIphysiquesnonprétendues ; recetteglissementpremierdernier/unpoint/grandtexte/VO/volume288kg/duréeexacte/filtres/repriseimport attendue. STOPavant8/9.
