# Jalon 3 — Corrections après captures iPhone

## Objectif et autorisation

Demande explicite : coins arrondis même près des boutons, supprimer les commandes clavier répétées, remettre Préparer sous la durée de repos, progression des séries (choix confié à l’agent), confirmations de suppression centrées, puis proposer des améliorations UX/UI. Retouches du jalon 3 uniquement ; ses fonctionnalités restent en recette. Les propositions finales ne sont pas implémentées sans retour utilisateur.

## Décisions et diagnostic

- Captures : lignes opaques et bouton à fond de ligne transparent dans une même Section native produisent des angles droits au bord de la transition. Séparer contenus et actions dans des Sections ; conserver les arrondis système plutôt qu’un masque ou rayon artificiel.
- ActiveSetForm déclare sa toolbar clavier sur une Section contenant plusieurs lignes. Remonter la déclaration unique à WorkoutSessionView, avec un FocusState partagé. Une commande Masquer le clavier, distincte de Terminer la série, sans validation de performance.
- Aujourd’hui : Préparer prominent à nouveau juste après Entre les séries ; règles de reprise, verrou/recommencer et repos inchangées.
- Séries : points gris devenant bleus et cochés après enregistrement, liés à exercise.sets persistés, pas au chrono ni au bouton Commencer. Nombre variable, Dynamic Type, VoiceOver ; bar native en remplacement si trop de points pour la largeur ou un grand nombre de séries. Garder le texte Exercice N sur M, remplacer la barre de progression des exercices par celle des séries courantes.
- Suppression Planning/Exercices/Historique : alert SwiftUI centrée, Annuler/Supprimer, mêmes avertissements et conséquences, aucune écriture avant confirmation. Abandon/recommencer ne sont pas des suppressions et gardent leur flux existant.
- Version 0.3.2 (6), bundle/certificat conservés ; aucune donnée, migration, permission ou dépendance nouvelle.

## Exécution et vérification

1. Corriger structure des Sections et ownership de la toolbar ; progression SwiftUI et trois alertes.
2. Lint, 36 tests de régression SQLite existants, vraie compilation xtool et contrôle du bundle. Pas de tests factices du rendu iPhone ou de tests reproduisant des détails de vue.
3. Revue indépendante ciblée UI/confirmations ; documentation cohérente.
4. Préflight identité/certificat, script USB existant, postflight version/profil. En cas de crash usbmuxd, annuler proprement le processus et rétablir le service avec l’utilisateur si sudo exige son mot de passe ; aucune mise à jour système improvisée.
5. Demander retour iPhone sur champs/repos/Feeling arrondis, clavier unique (répétitions et charge), CTA sous repos, points 0→1→4 et reprise persistée, trois suppressions (annuler puis confirmer), clair/sombre et grand texte. Arrêter avant jalon 4.

## Progression

- [x] Captures, sources et spécifications relues ; choix présenté.
- [x] Corrections.
- [x] Compilation, régressions et revue.
- [x] Installation réelle et contrôles.
- [ ] Validation physique utilisateur.

## Journal des vérifications

Build xtool 6,17 s code 0, bundle réel 0.3.2 (6) conforme. Lint strict code 0. Suite SQLite hôte : 36 tests, 0 échec ; les vues iOS ne sont pas exécutées par ces tests. Revue indépendante demandée sur le périmètre des retouches.

Revue indépendante ciblée : aucun problème critique, important ou mineur identifié ; FocusState parent, Sections, points et trois alertes relus. Limites explicites : rendu/clavier/VoiceOver nécessitent iPhone. Préflight code 0 : Sport 0.3.1 sous la même identité effective, certificat local valide >24 h et présent chez Apple. Installation USB terminée code 0 : rebuild 1,13 s, installation/vérification 100 %. Postflight code 0 : 0.3.2 (6) sur le même bundle, profil valide/CMS vérifié et certificat existant inchangé. Aucun redémarrage manuel USB nécessaire pour cet essai. Rendu et fonctionnement physique attendent confirmation utilisateur.

## Propositions réservées au retour utilisateur

Réduire le vide vertical de l’en-tête pour afficher les champs et l’action avec moins de défilement ; réutiliser la charge de la série précédente du même exercice en la laissant modifiable ; proposer une séance du planning comme base de saisie historique, en gardant les performances vides. Ces idées ne sont pas implémentées.
