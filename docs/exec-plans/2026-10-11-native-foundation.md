# Jalon 1 — Fondations SwiftUI / xtool

## Objectif et autorisation

Plan global : ../../PLAN-SPORT-NATIF.md. Jalon 1 autorisé le 11 octobre 2026 par « aller on commence alors ». Livraison limitée à une application Sport native avec quatre onglets, des états d'attente honnêtes et des destinations Réglages permettant de tester la navigation. Aucun domaine workout, stockage, permission, coffre, notification ou extension à ce stade.

## Décisions

- Priorité permanente : expérience proche des apps Apple, composants SwiftUI standards, typographie/couleurs système, SF Symbols, barre native Liquid Glass, Dynamic Type et navigation arrière native. Aucun faux effet de verre ou décoration de carte.
- Reprendre Package.swift, xtool.yml et le point d'entrée du squelette /home/raton/Documents/Code/iOS/HelloSport dans le workspace Sport ; préserver l'original et ses caches.
- iOS 26 minimum ; Swift language mode 6 via le manifeste Swift tools 6.0 conservé. Produit, target et nom affiché Sport, bundle configuré com.raaaton.sport.
- Aucune permission sensible au lancement. L'onglet Progression indique explicitement que les photos ne sont pas disponibles ; aucun bouton Face ID/import avant le coffre sécurisé.
- Interface française. Quatre NavigationStack indépendants dans un TabView natif. Les destinations Réglages sont des pages d'attente, pas des réglages qui font semblant de fonctionner. À propos lit la version réelle du bundle.
- Pas de Git exploitable dans ce workspace ; aucun reset, init, commit ou worktree artificiel. .agents est en lecture seule : ce plan suit son format dans docs/exec-plans/.
- Aucun domaine testable à ce jalon : ne pas écrire de tests qui répètent des labels SwiftUI. Vérifier à la place le véritable bundle compilé (identité, architecture, OS, absence de permissions/extension/provisionnement inattendu), puis le rendu et la navigation sur appareil.

## Étapes

1. Compiler le squelette inchangé sans signature.
2. Adapter sa configuration dans Sport et ajouter les vues de navigation/attente.
3. Exécuter swift format lint, xtool dev build et la vérification du bundle. Effectuer une revue indépendante.
4. Mettre à jour README, PROJECT, AGENTS et les documents de design/build/sécurité/roadmap sans déclarer les anciennes validations Expo valables pour Swift.
5. Avant toute installation, attendre la confirmation explicite de suppression de HelloSport sur l'iPhone. Ne jamais supprimer son code local.
6. Après installation autorisée, attendre le retour iPhone avant le jalon 2.

## Vérification appareil

- Sport se lance, affiche Aujourd'hui et les quatre onglets, sans demande de permission.
- Chaque onglet a un titre visible, sans recouvrement par l'Île dynamique ou la barre.
- Réglages > Planning et À propos : push natif, bouton/gestuelle de retour, état de navigation conservé lors d'un changement d'onglet.
- Mode clair/sombre, texte agrandi au maximum, VoiceOver, Réduire les animations et Réduire la transparence : contenu lisible et accessible, défilement si nécessaire.
- Aucun démarrage de séance, import de photo, contrôle de timer ou rappel faussement actif.

## Journal / preuves

- [x] Audit des documents Sport effectué lors de la préparation du plan.
- [x] Baseline : premier xtool dev build refusé par le sandbox (cache xtool en lecture seule). Nouvelle exécution autorisée par le reviewer automatique ; compilation réussie, 4,81 s, HelloSport.app produit. Aucun --sign ni installation.
- [x] Configuration et vues Sport : reprise/adaptation du manifeste, du YAML et du point d'entrée HelloSport ; quatre onglets natifs, sept destinations Réglages, version réelle. Aucun code métier/persistance/permission.
- [x] Compilation : premier build Sport réussi (8,51 s), puis build final incrémental après formatage réussi (2,25 s). Produit xtool/Sport.app ; caches conservés.
- [x] Lint : premier passage a identifié le style du template (indentation et longues lignes) ; normalisation avec swift format, puis lint --strict réussi sur Package.swift et Sources/.
- [x] Contrôle du vrai bundle : version 0.1.0 (1), Sport, com.raaaton.sport, Mach-O arm64 iPhoneOS 26, français ; aucun profil, signature, extension, mode d'arrière-plan ou permission sensible. Le vérificateur rejette trois copies temporaires volontairement invalides (mauvais identifiant, profil inattendu, binaire tronqué).
- [x] Documentation native actualisée, anciens README/AGENTS conservés dans docs/archive ; liens locaux vérifiés. Pas de tests Swift de domaine à ce stade, car aucun domaine implémenté.
- [x] Revue indépendante finale : aucun défaut concret bloquant trouvé dans le périmètre. Réserves appareil maintenues : ContentUnavailableView dans ScrollView, texte maximal, VoiceOver et conservation de navigation. La demande de mise à jour du journal était déjà traitée pendant la revue.
- [x] Confirmation explicite de suppression de HelloSport sur iPhone reçue le 11 octobre 2026. L’utilisateur demande désormais l’installation de chaque build de jalon avant sa review ; autorisation persistante enregistrée dans AGENTS.md.
- [x] Script USB terminé avec code 0 : provisioning, signature, installation et vérification terminés. L’utilisateur confirme sur iPhone « j’ai testé, c parfait » et autorise le jalon 2.

Jalon 1 validé par le retour explicite utilisateur du 11 octobre 2026. Les adaptations futures devront conserver cette navigation.

## Signature et limites

Le code local de xtool préfixe l’identité de provisioning par XTL-<identité>. Le bundle non signé garde com.raaaton.sport. L’identité effective a été contrôlée ; certificat local valide et présent chez Apple avant installation. Aucune révocation/remplacement. La version locale de xtool peut remplacer un certificat expiré : vérifier avant chaque déploiement et arrêter plutôt que laisser une révocation inattendue.

L’icône personnalisée est différée. L’utilisateur a testé la version et confirmé le bon fonctionnement sur iPhone. Ce retour global ne documente pas individuellement un audit VoiceOver ou de chaque taille d’accessibilité ; poursuivre ces vérifications aux jalons suivants.
