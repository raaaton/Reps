# Jalon 3 — Séance complète et repos fiable

## Objectif et autorisation

Le retour « parfait » valide les retouches du jalon 2 et permet de poursuivre le plan global accepté. Réaliser uniquement préparation/démarrage/reprise, séries répétitions ou chronométrées, charge saisie par série, Feeling décimal par exercice, repos persistant, abandon confirmé et historique minimal. Ni inventaire/recommandations, édition manuelle historique, notifications, extension, Live Activities ou coffre.

## Décisions et interfaces

- Même actor SportRepository et même SQLite. Migration transactionnelle v1 → v2 sans toucher planning/catalogue/repos existants ; tables workouts, workout_exercises, workout_sets, workout_rests. Références catalogue/planning stockées sans FK destructive ; leurs suppressions ne modifient pas les instantanés d’une séance active ou historique. Une seule séance active via index partiel.
- Timestamps entiers en millisecondes ; journée locale capturée YYYY-MM-DD au démarrage, stable en historique. Repos calculé depuis deadline ; pause conserve remainingMS, reprise nouvelle deadline. Validation arithmétique sans overflow pour les réglages extrêmes. Horloge système comme référence durable, pas de compteur de ticks.
- startWorkout(scheduleID:now:calendar:restart:) reprend toute séance active, sinon valide le plan local du jour. Verrou d’une séance terminée ce jour sous ce planning ; restart explicitement confirmé crée une nouvelle ligne en conservant l’ancienne.
- WorkoutSession avec ordered exercises/sets et WorkoutPhase dérivé des seules données persistées : readySet, activeSet, resting, feeling, completed, cancelled. Les séries terminées sont des lignes durables ; Feeling marque l’exercice terminé, puis le flux avance. Aucun état fondé sur des booléens indépendants.
- beginSet exige IDs et numéro attendu ; répété sur la même série active conserve le timestamp. recordSet valide IDs/numéro attendu, reps > 0 ou durée chronométrée > 0, poids entier >= 0 ; série et repos créés dans la même transaction. Pas de repos après la dernière série d’un exercice : Feeling 0–10 à un chiffre décimal. Dernier Feeling termine la séance atomiquement.
- RestAction pause/resume/skip avec identifiant du repos ; actions périmées/idempotentes ne modifient pas un repos ultérieur. Abandon annule le repos et marque la séance annulée, sans supprimer les séries.
- WorkoutOverview = active session complète + résumés historique ; détails et dernière performance terminée lus à la demande. Éviter de charger tous les sets de tout l’historique au lancement. TrainingStore conserve l’overview et rafraîchit avec le snapshot de configuration ; formulaires bloqués pendant sauvegarde.
- Today ouvre préparation puis séance dans une présentation native plein écran avec navigation. Fermer la présentation conserve l’activité ; abandon séparé dans menu, confirmé. Saisie limitée à la série en cours ; chrono de série par timestamp persistant et redraw SwiftUI TimelineView. Charge manuelle en kg → grammes par parseur exact (virgule/point, 3 décimales), aucun inventaire anticipé.
- Repos : Pause/Reprendre + Passer le repos. Réconciliation chaque seconde tant qu’un repos tourne et que la scène est active, même après fermeture de la présentation, et au retour actif/lancement. Son bref local via AudioToolbox et succès haptique UIKit, une fois par transition d’expiration ; aucun mode d’arrière-plan. Retour après suspension peut produire le feedback, sans prétendre le faire dans une app suspendue.
- Version 0.3.0 (4), com.raaaton.sport et certificat existant conservés. Installation USB avant review, arrêt avant jalon 4 jusqu’au retour iPhone.

## Exécution

1. Tests puis migration/modèles/API minimales : préservation v1, instantanés, démarrage/reprise/verrou/redémarrage, IDs et index unique. Observer rouge puis vert.
2. Tests puis transitions : séries/réentrées, Feeling, timer pause/reprise/échéance/skip, abandon sans perte, erreurs transactionnelles et valeurs extrêmes. Suite complète verte.
3. SwiftUI préparation/série/repos/récapitulatif, historique/détail/dernière performance, store et feedback natif. Compiler xtool après intégration.
4. Tests complets, lint, bundle réel, revue indépendante du jalon. README/design/build/roadmap/sécurité à jour.
5. Préflight certificat et identité iPhone ; script USB ; postflight version/profil/certificat. Attendre recette utilisateur.

Pas de Git exploitable : pas de branche/commit/worktree fictif. Journal de ce fichier remplace les scripts de ledger dépendant de Git. Plan global et spécifications déjà approuvés ; aucune nouvelle demande de confirmation de leur périmètre. Limites signalées avant implémentation.

## Vérification et Review Focus

- Tests hôte : upgrade v1 avec réglages personnalisés, aucun reseed ; création atomique/order/uniqueness ; ID/numéro attendus et double action ; durée/réps/poids/Feeling invalides ; fin dernière série directement Feeling, fin dernier exercice ; timer expire en suspension, pause conserve temps, stale action ne cible pas le suivant ; cancel conserve données ; restart même jour conserve précédente ; suppression configuration ne touche pas active/historique ; erreur insert set/rest roll back ; heure/millisecondes overflow ; dernière performance exclut annulées/incomplètes.
- Vérifier que changements du jour/plan pendant préparation restent validés au démarrage ; qu’une séance commencée hier reprend ; qu’une base v1 ne perd rien et une base future échoue fermée. Historique chargé en résumés ; UI défile avec clavier et grand texte.
- Exécuter swift test --package-path Tests/Host, lint strict, xtool dev build, contrôle bundle/migration. Revue indépendante finale sur transactions, concurrence, snapshot vs live catalogue, transitions terminales, feedback lifecycle, liens entre présentation et store.
- iPhone : commencer/répétitions/durée/Feeling, poids décimal, dernière série, pause/reprise/skip, expiration verrouillé puis retour, fermeture forcée/reprise, fermeture présentation sans abandon, abandon confirmé/annulé et conservation, terminer/recommencer confirmé, historique, régression planning/suppression et clair/sombre/grand texte. Aucun rendu ou geste déclaré testé par build.

## Journal

- [x] Jalon 2 validé par l’utilisateur ; plan global, spécifications workout/rest et sources actuelles relus.
- [x] Domaine et migration.
- [x] Transitions et tests.
- [x] SwiftUI et xtool.
- [x] Vérifications/revue/docs.
- [x] Installation USB et contrôles.
- [ ] Retour iPhone.

### Preuves avant installation

- Tests écrits avant le domaine ; huit tests rouges (APIs provisoires échouant explicitement), puis 24 tests complets verts. Quatre scénarios supplémentaires vrais SQLite : 12 tests workout verts, suite complète de 28 exécutée sans échec avant déploiement (0,07 s, build hôte 0,42 s). Lint strict et contrôle unsigned du bundle/ressource code 0.
- xtool réel a détecté les surcharges Section et une NavigationLink incorrecte remontée sous une erreur d’inférence de TimelineView. Corrections compilées : code 0, 4,65 s, vrai bundle Sport.app généré avec Sport_Sport.bundle/RestComplete.wav.
- Revue indépendante : trois P2 corrigés et relus sans blocage : générations de configuration et workout séparées pour éviter que le polling jette des réglages sauvegardés ; valeurs accessibles des chronos ; date historique affichée depuis la journée locale figée. Intercalation SwiftUI, VoiceOver et changement de fuseau restent à tester physiquement, aucun test UI Linux inventé.
- Polling déplacé de l’écran du repos à la scène active de l’app : fermer l’écran/changer d’onglet ne doit pas empêcher l’expiration pendant que Sport est au premier plan. App suspendue : échéance SQLite reconciliée au retour ; aucun son promis pendant suspension, ni Live Activity intégrée prématurément.

### Blocage USB externe à la build

Préflight code 0 : Sport 0.2.1 sous la même identité effective, certificat existant valide >24 h et présent chez Apple. Script USB exécuté : détection/pairing réussis et rebuild code 0 (1,05 s), puis attente silencieuse. Diagnostic en lecture seule : iPhone visible via lsusb ; usbmuxd.service failed/core-dump (6/ABRT), crash à 15:37:20, journal `free(): invalid pointer`. Pile libc free/abort + usbmuxd non symbolisé ; thread libusb en poll. Mémoire disponible 7,1 GiB ; cause précise du défaut non prouvée. Aucun core extrait, aucune réinstallation ou changement de configuration.

Notre processus xtool bloqué a été terminé pour empêcher une installation concurrente. Redémarrage réversible du service soumis au reviewer automatique et exécuté avec `sudo -n` : échoue `sudo: a password is required`. Demande d’action locale : `sudo systemctl restart usbmuxd.service`, puis confirmation. L’installation 0.3.0 et son postflight ne sont pas encore réussis ; aucune validation iPhone du jalon 3. Ne pas lancer le jalon 4. Reprendre préflight/script/postflight après restauration USB.

### Récupération et installation réelle

L’utilisateur confirme « c fait » après redémarrage usbmuxd. Nouveau préflight code 0 : app toujours 0.2.1 sous la même identité et certificat existant valide. Nouvelle exécution du script USB code 0 : build 1,04 s, provisioning/signature, installation et vérification 100 %. Postflight code 0 : Sport 0.3.0 (4) lu sur iPhone, identité effective inchangée, profil valide et CMS vérifié, certificat local et du profil identiques au préflight ; aucun App Group/push/extension/permission sensible nouveau. Le crash de transport est levé pour cette installation ; sa cause précise n’est pas attribuée au code Sport.

Jalon 3 livré pour recette ; fonctionnement UI/son/haptique réel, VoiceOver et relance à valider par l’utilisateur. Arrêt avant jalon 4.

### Retouches demandées pendant la recette

Après livraison 0.3.0, demande utilisateur d’ajout/suppression historique et amélioration UX de séance. Périmètre avancé et exécution dans [ExecPlan historique/UX](2026-10-11-history-workout-ux.md). Sport 0.3.1 (5) installé réellement après récupération USB ; même app et certificat, postflight valide. Le jalon 3 reste en recette, sans démarrage du jalon 4.
