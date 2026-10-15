# Sport 0.11.9 — teinte native des boutons Liquid Glass

Retour iPhone du 15 octobre : les symboles de History + et de fermeture sont restés cyan malgré 0.11.8. Lecture directe de l’app installée : 0.11.8 (42), même identité et certificat ; l’installation précédente était bien effective, son résultat visuel incorrect. La compilation n’avait pas prouvé ce rendu.

Hypothèse documentée : foregroundStyle sur le Button ne remplace pas la teinte du contrôle natif dans la barre d’outils ; Sport impose une teinte cyan à la racine. Correction : tint(.white) sur chaque bouton concerné et sur le Menu déclencheur (pas sur son Label). Coches non modifiées ; SportDestructiveButton garde ses foregroundStyle/tint rouges. Aucun changement de logique, données, coffre, navigation ou dépendances. Retour et composants de navigation générés par iOS ne sont pas remplacés.

Référence : [Apple tint(_:)](https://developer.apple.com/documentation/swiftui/view/tint(_:)) documente la surcharge locale de la couleur d’accent pour les contrôles. Une simple lecture des sources ou compilation ne démontre pas le rendu UIKit/SwiftUI réel ; History + et la croix de sa modale sont les deux reproductions physiques fournies par l’utilisateur et les premiers cas de recette.

Vérifications : lint strict et 6 tests metadata réussis ; premier build xtool 14,93 s réussi. Préflight : certificat identique, valide, présent chez Apple ; app existante 0.11.8 vérifiée. Génération metadata, build final, inspection, installation USB et postflight à consigner.

Recette : History + blanc, fermeture de New Workout blanche, coche Save toujours accentuée ; mêmes vérifications pour réglages et barres d’outils du coffre, état désactivé et menus destructifs rouges. Aucun média privé consulté pour les contrôles automatisés.

Livraison : génération metadata réussie, build final xtool 8,50 s et inspection unsigned 0.11.9 (43) réussis. Script USB code 0, build 2,20 s, installation/vérification 100 %. Postflight direct : version 0.11.9 (43), même identité et certificat ; profils app/widget CMS valides, aucune capacité nouvelle. Aucune validation visuelle automatisée possible sur Linux ; recette History + et croix attendue sur iPhone avant toute affirmation de résultat.
