# Jalon 3 — Finition HIG et décompte chronométré

## Objectif et autorisation

L’utilisateur confirme les corrections 0.3.2 puis demande une série de petites améliorations UX/UI fondées sur les HIG Apple et un 3–2–1 avant les exercices de durée. Périmètre : présentation des écrans existants et départ des séries chronométrées ; aucun jalon ActivityKit/photo/lest commencé. Installation USB autorisée avant chaque recette.

## Contexte et décisions

- HIG officielles consultées : [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons). Règles : importance visuelle, éléments liés regroupés, détails révélés progressivement, composants et styles système, Dynamic Type. Le 3–2–1 est un choix Sport, pas une règle Apple.
- Conserver Préparer après la durée du repos, les groupes arrondis et les alertes centrées demandés et confirmés.
- Réduire les espacements entre sections de séance avec les API SwiftUI natives ; titre moins lourd, détails secondaires regroupés, textes courts, retour d’enregistrement par indicateur natif, champs numériques et commandes clavier cohérents. Regrouper aussi résumé et reprise sur Aujourd’hui sans mélanger une ligne transparente avec un fond opaque.
- Décompte de trois secondes à chaque nouvelle série de durée, jamais pour les répétitions. Enregistrer dès le tap l’heure prévue du départ dans set_started_at existant, puis dériver l’état explicite countdown jusqu’à cette échéance. Le chrono et la durée sauvegardée excluent les trois secondes. Même échéance après fermeture, suspension et relance ; aucune tâche de sommeil ne devient la source de vérité. Les séries déjà actives avant mise à jour gardent leur timestamp.
- Annuler le décompte revient à prêt sans série ni repos ; action identifiée exercice/numéro et impossible après le départ réel. Feedback haptique et annonce VoiceOver au premier plan seulement. Pas de notification d’arrière-plan promise.
- Pas de nouvelle colonne/schema, permission, entitlement ou dépendance. Version prévue 0.3.3 (7), identité Sport et certificat conservés.

## Étapes

1. Tests du départ décalé, durée excluant préparation, refus de validation prématurée, relance, doubles commandes, annulation et répétitions inchangées ; observer les assertions échouer avant implémentation.
2. Implémenter le décompte dans le domaine puis la vue et les finitions cohérentes des écrans.
3. Exécuter tests hôte, lint strict, xtool dev build et contrôle du bundle ; revue indépendante puis corrections éventuelles.
4. Actualiser les spécifications et le README, préflight identité/certificat, installation USB et postflight.
5. Arrêter pour validation iPhone : 3–2–1 puis chrono zéro, annulation/reprise, durée historique sans préparation, répétitions inchangées, clavier, grand texte/VoiceOver/clair-sombre. Toute animation et tout haptique restent à vérifier physiquement.

## Progression

- [x] Demande, code, spécifications et HIG relus ; périmètre annoncé.
- [x] Tests et implémentation.
- [x] Vérifications et revue.
- [x] Installation et contrôles.
- [ ] Recette iPhone.

## Vérifications exécutées

RED : deux nouveaux tests exécutés, huit assertions en échec sur départ immédiat et inclusion des trois secondes. GREEN : suite complète 40 tests, aucun échec, après départ programmé et protection expectedStart contre une ancienne annulation. Build final xtool 6,02 s code 0 ; lint strict et contrôle unsigned code 0. Revue indépendante sans problème critique/important ; assertion de test liée à l’heure réelle remplacée par phase(at:) aux bornes, 16 tests chronométrage réexécutés sans échec. Préflight code 0 : Sport 0.3.2 sous la même identité effective, certificat local valide >24 h et présent chez Apple. Script USB code 0, rebuild 1,09 s, installation/vérification 100 %. Postflight code 0 : Sport 0.3.3 (7), même identité effective, profil valide/CMS vérifié et certificat existant inchangé. Rendu, feedback et parcours restent à confirmer sur iPhone. Les haptics/VoiceOver et vues iOS ne sont pas exécutés sous Linux.
