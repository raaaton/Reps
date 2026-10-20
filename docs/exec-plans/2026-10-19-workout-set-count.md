# Nombre de séries par workout

## Objectif et décisions

Demande utilisateur et fonctionnement approuvés le 19 octobre : définir les séries dans chaque exercice affecté à un workout, plus dans le formulaire du catalogue. Même exercice : deux séries mardi, quatre samedi. Conserver les nombres existants, les historiques et les séances déjà démarrées. Les objectifs par série doivent suivre l'affectation afin qu'un workout ne remplace pas les objectifs d'un autre. Les autres propriétés d'exercice restent partagées.

## Implémentation

1. Tests SQLite réels avant code : indépendance, reprise, gel des instantanés, fin après le bon nombre, objectifs, rollback, archives.
2. Migration11 additive : nombre et objectif sur schedule_exercises, initialisés depuis le catalogue et les objectifs existants. TrainingExercise.setCount reste un champ de compatibilité des anciens fichiers et des instantanés ; les affectations font autorité.
3. Formulaire Workout : champ Sets par exercice. Retirer Sets et les résumés de séries du catalogue ; objectifs contextualisés dans Today/préparation/progression/historique. Formulaires natifs et labels VoiceOver.
4. Archives JSONv2 pour nouvelles affectations ; lecture v1 avec reprise des valeurs existantes. CSV historique inchangé.
5. Tests complets, lint, metadata, xtool réel et inspection du bundle, puis installation USB autorisée avec contrôles identité/certificat. Attendre recette iPhone avant GitHub.

## Vérification et limites

Baseline :208tests hôte réussis. Nouveaux tests lancés avant API : échec de compilation attendu sur les champs/API absents, pas un échec comportemental revendiqué. Vérifier aussi migration10 et vieux backups, rollback, suppression/réordonnancement, durée/Untimed, préparation et progression à comptes distincts. Les tests Linux ne valident pas SwiftUI ni les interactions physiques.

## Progression

- [x] Périmètre approuvé, documents et flux existants explorés.
- [x] Baseline208tests.
- [x] Implémentation ;219tests hôte passent. Revue indépendante : trois corrections vérifiées (crash doublons JSONv1, export des objectifs incompatibles, identité du contexte Today). Tests de non-régression du crash et de l’export observés rouges puis verts.
- [x] Lint strict,6metadata, xtool28.77s puis15.22s et inspection unsigned66 réussis.
- [x] Installation : device-run.sh code0, installation/vérification100%. Postflight direct : un seul Sport1.0.6(66), même identité effective, certificat exact local inchangé, profils CMS app/widget valides et capacités identiques.
- [ ] Retour iPhone.

La première tentative de tests ciblés a été bloquée par CFSocket dans le sandbox ; exécution élevée nécessaire ensuite. Le premier essai des6metadata a échoué parce que le bundle xtool n’existait pas encore ; après compilation/intégration les6 passent. Le premier build sandbox a été refusé pour cache xtool en lecture seule ; build réelle élevée réussie sans changement de toolchain/caches.

Livraison66 terminée. Les219tests/6metadata/lint strict/build/inspection passent. Revue indépendante finale : trois findings résolus, aucun autre défaut concret. Aucun commit/push/tag/release. Prochaine étape : recette physique des nombres par workout et objectifs ; ne pas déduire de ces contrôles une validation SwiftUI.


## Retouche visuelle approuvée — build67

Capture iPhone66 : trois lignes et steppers répétés jugés trop lourds. Après consultation des chapitres Apple HIG Pickers/Pop-up buttons/Menus/Lists/Layout/Text fields, l'utilisateur approuve un menu natif affichant la sélection, sous-titre bref, aucune ligne Sets séparée ni footer explicatif. Presets1...8 en ordre croissant avec coche, Custom… pour toute autre valeur1...1000 (valeur personnalisée actuelle également cochée dans le menu). Alerte système avec clavier numérique, Cancel sans changement, Apply désactivé hors bornes. Édition dans le brouillon du workout ; aucun changement de persistance/progression/permissions.

WorkoutExerciseRow : nom prioritaire, métrique secondaire sans per set redondant, sélection à droite ; empilement pour largeur insuffisante et tailles d'accessibilité, contrôle système avec surface44pt et label VoiceOver nommant l'exercice. Le mode Edit conserve retrait/réordonnancement. Choix spécifiques Sport : presets et disposition ; Apple recommande le pop-up pour une sélection mutuellement exclusive et permet Custom pour les valeurs rares. Sources : https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons et /layout.

Vérification prévue : lint/build xtool/metadata/inspection, suite219tests existants (les règles métier ne changent pas), revue ciblée et mise à jour USB67 avec pré/postflight. Pas de test hôte prétendant exécuter SwiftUI ; recette physique menu/coche/Custom/Cancel/grands textes/VoiceOver nécessaire. Pas de GitHub avant retour.

Build67 :219tests métier/0échec, lint strict propre, première compilation xtool15.89s réussie. Revue ciblée indépendante : aucun défaut concret ; menu→alerte Custom, grands textes en mode Edit et gestes de déplacement/retrait restent à tester sur iPhone. Aucun test artificiel de texte/source UI ajouté pour cette retouche de présentation.

Build67 livrée : device-run.sh code0, installation/vérification100%. Postflight direct confirme un seul Sport1.0.6(67), même identité effective, certificat exact inchangé, profils CMS app/widget valides et mêmes capacités.219tests métier/6metadata/lint strict/xtool15.89s puis2.90s/inspection réussis, revue ciblée sans défaut concret. Rendu menu/Custom/grands textes/VoiceOver à confirmer sur iPhone. Aucun commit/push/release.


## Progress main workout goal — build 69

User requested replacing Goal and Progress when an exercise has multiple workout goals. Clarification: prefer weighted repetition goals to bodyweight goals; ranking identifies the main workout, whose exact goal remains the displayed subtitle. Pure TrainingSnapshot.primaryGoal selects compatible assigned goals by sum(repetitions) × load, sum(repetitions) at bodyweight, or sets × duration for isometrics. Stable first-workout ties; no invented duration for untimed goals; missing/stale goals skipped. No persistence, coaching, historical metric or detail-screen changes. Existing native GoalDescription retains Dynamic Type/VoiceOver; HIG Lists and tables/ Typography consulted.

Six behavioral regression tests observed red (seven assertion failures against extracted former behavior), then green; full 248 tests pass (9.687 s), strict lint clean. Revue indépendante ciblée sans défaut concret ; 6 metadata et inspection unsigned réussis. xtool 63,67 s puis intégration metadata 5,49 s. Préflight version68/identité unique/certificat existant valide inchangés. Installation USB69 réussie (code 0, installation/vérification à 100 %). Postflight direct : un seul Sport 1.1.0 (69), même identité effective et certificat exact, profils CMS app/widget valides et capacités conservées. Rendu physique/VoiceOver toujours à valider. Keep current checkout and earlier user changes; no reset, commit or push.
