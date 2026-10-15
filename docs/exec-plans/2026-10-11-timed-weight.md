# Jalon 3 — Lest des séries chronométrées

## Objectif et autorisation

Demande explicite : pouvoir renseigner le lest avant ou après une série de durée, sans devoir le saisir pendant l’effort. Choix annoncé : avant le démarrage des nouvelles séries ; après l’arrêt pour une série déjà active sans charge capturée dans la version précédente. Installation USB autorisée avant la recette. Aucun jalon suivant commencé.

## Contexte et décisions

- Conserver le décompte 3–2–1 et la durée qui l’exclut. Sections/champs/boutons SwiftUI natifs, groupement et hiérarchie issus des HIG Layout/Buttons déjà consultées. Le placement du lest est un choix Sport.
- Enregistrer atomiquement le lest manuel en grammes avec le départ programmé ; affichage en lecture seule pendant le chrono. 0 kg reste le poids du corps. Répétitions inchangées.
- Migration SQLite v2 → v3 transactionnelle : charge de la série en cours nullable, fin de chrono nullable. Préserver configuration, historique, états et timestamps existants ; aucune charge inventée pour les séries de l’ancienne version.
- Pour une ancienne série sans charge, arrêter/persister le chrono puis demander le lest. Une fermeture ne redémarre pas ce chrono et la saisie n’allonge ni la durée ni le repos, calculé depuis la fin de l’effort.
- Annuler le décompte efface sa charge capturée ; doubles actions/périmées protégées. Aucune dépendance, permission ou capacité ajoutée ; version 0.3.4 (8), identité conservée.

## Étapes et vérification

1. Observer l’échec du test de migration attendue, puis couvrir charge exacte/reprise, doublons, annulation, ancienne série arrêtée puis saisie tardive, migration sans perte et refus d’actions invalides.
2. Implémenter la migration, transitions et formulaires limités à cette demande.
3. Suite hôte, lint strict, xtool dev build réel, contrôle du bundle et revue indépendante.
4. Actualiser docs, vérifier identité/certificat/profil, installer par script USB et contrôler version sur iPhone.
5. Arrêter pour recette : lest non nul/virgule avant décompte, pas de saisie pendant l’effort, charge/durée dans historique après reprise, annulation et répétitions inchangées.

## Progression

- [x] Périmètre et décisions annoncés ; docs et code relus.
- [x] Tests, migration et interface.
- [x] Vérifications et revue.
- [x] Installation USB et contrôles.
- [x] Validation physique iPhone : retour utilisateur « ok parfait on continue ».

## Résultats exécutés

Test RED de migration : 1 assertion en échec (v2 au lieu de v3). Suite GREEN : 45 tests sans échec, dont cinq nouveaux tests lest et migration d’une fixture v2 indépendante. Lint strict code 0. Build xtool réel code 0, 7,52 s, APIs et interface compilées pour le SDK iOS enregistré. Contrôle du bundle unsigned code 0, version 0.3.4 (8), aucune nouvelle capacité. Revue indépendante en lecture seule : aucun problème critique, important ou mineur identifié. Préflight code 0 : Sport 0.3.3 sous la même identité effective, certificat existant valide >24 h et présent chez Apple. Script USB code 0, build incrémental 1,04 s, installation/vérification 100 %. Postflight code 0 : Sport 0.3.4 (8) installé sous la même identité effective, profil valide/CMS vérifié, certificat existant inchangé. Aucun redémarrage USB requis. Aucun résultat visuel iPhone affirmé ; arrêt pour recette utilisateur.
