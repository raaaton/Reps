# Audit global — 0.11.3

## Objectif et périmètre

Demande utilisateur : abandonner la sauvegarde privée portable et auditer globalement Sport. Vérifier données, interruptions, confidentialité, performance, interface/accessibilité et régressions. Corriger les défauts confirmés sans nouveau chantier produit, sans toucher aux données personnelles ou aux clés du coffre.

## Décisions

Le CSV/JSON existant reste limité à l'entraînement, sans photos privées. La sauvegarde portable et son prototype sont abandonnés ; aucun nouveau test de cette preuve n'est demandé. Les HIG guident l'examen de l'accessibilité, des graphiques et du mouvement. Les résultats Linux et la revue statique ne prouvent ni rendu, ni Face ID, ni performances réelles sur iPhone.

## Étapes

1. Baseline, revue des parcours et revue indépendante des données/confidentialité.
2. Reproduire les noms incompatibles avec les transferts et le recul d'horloge ; corriger à l'écriture sans tronquer l'existant. Remplacer la relecture chaque seconde pendant le repos par un réveil à l'échéance. Retouches ciblées d'accessibilité/langue.
3. Tests, lint, compilation xtool, métadonnées, contrôle d'identité/certificat, installation USB et postflight.
4. Rapport d'audit avec défauts corrigés, limites et recette physique ; arrêt pour retour iPhone.

## Vérification et progression

- Baseline : 146 tests, 0 échec, 5,302 s.
- Revue indépendante : incohérence des limites de texte et dates de nouvelles séries/annulation après recul d'horloge. Aucun défaut supplémentaire de confidentialité étayé trouvé ; ce constat n'est pas une certification de sécurité.
- Performance : App recharge l'historique complet chaque seconde pendant le repos. Coût confirmé dans le code, aucun chiffre de batterie/FPS mesuré.
- Corrections livrées en0.11.3(37). Six tests ciblés : échec observé avant les corrections sur les quatre cas fautifs, puis six réussites. Suite complète152tests/0échec5,281s ; lintstrict0 ; xtool21,50s puis métadonnées/empaquetage2,12s ;6testsmetadata et inspectionunsigned0. Revue indépendante des corrections : aucun nouveau constat concret.
- Préflight0.11.2 réussi, device-run.sh0/rebuild2,21s/install-vérification100%, postflightdirect0.11.3 réussi : même app/certificat, profilsvalides/CMSvérifiés, permissionsinchangées. Aucun nouveau certificat, migration ou accès aux données personnelles.
- [Rapport global](../audits/2026-10-13-global-audit.md) publié et documents d'état actualisés. Audit statique et livraison terminés ; recette physique finale attendue. Aucune poursuite de sauvegarde privée ni nouveau jalon automatique.
