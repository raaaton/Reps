# Jalon 6 — Rappels locaux et Live Activities

## Objectif / autorisation

« Continue au prochain jalon » valide 0.5.0 sur iPhone et autorise le jalon6 du plan global accepté. PROJECT.md §12–13 et PLAN-SPORT-NATIF.md sont la spécification ; anciens plans Expo de notifications/planning lus comme références métier uniquement. Exécution directe avec writing-plans/executing-plans, tests de domaine avant implémentation, revue indépendante finale. Pas de nouvelle permission de travail : autorisation du jalon et des installations déjà explicite. Ne pas commencer coffre/jalon7.

## Conception et décisions

SQLite reste source de vérité ; migration additive v4→v5 pour préférences opt-in (séances et photos désactivées, heure photo360minutes). Horaires par séance existants conservés, jamais inventés. Rappels de séances concrets pour aujourd’hui et27jours suivants, seulement futurs, actifs avec exercices actifs et heure choisie ; toute séance enregistrée de même schedule/date les supprime, indépendamment du statut. IDs sport.local.workout.<id>.<date>. Photo mensuelle répétée le1er à l’heure choisie, ID sport.local.photos.monthly ; texte générique sans média. Maximum29requests (un créneau/jour), aucune push/capacité/dépendance nouvelle.

Calendrier grégorien, fuseau local, addition de jours calendaires (pas86400secondes). Heure inexistante DST reportée en conservant minutes, heure répétée première occurrence. Pas de doublon avant l’heure choisie. Réconciliation sérialisée coalescée : relire DB après chaque requête concurrente ; diff des requêtes Sport seulement, conserver les étrangères, erreurs visibles, retry au retour. Préférences restent hors de l’état d’autorisation système ; pas de demande depuis sync/foreground. Refus→lien Réglages iOS, pas de prompt répété.

UserNotifications natif : prototype de compilation minimum avec SDK réel avant UI. Requêtes calendrier, pas de serveur/app-group. Delegate installé au lancement, banner/list sans sound/badge au premier plan ; taps reconnus naviguent Aujourd’hui ou Progression, jamais un média. Réglages natifs Toggle/DatePicker, état autorisation, erreur de synchronisation et nombre de demandes à venir ; avertissement honnête que le coffre arrive au jalon7. Rebuild lancement/foreground/significant-time-change et mutations planning/historique/séance. Horizon28jours nécessite rouvrir Sport pour renouveler les séances ; mensuel répétitif indépendant de cet horizon. Aucun BGTask ni promesse de service permanent.

Live Activities : conserver rendu/alignements appréciés et Pause/Reprendre. Extraire politique pure de retrait : repos différent/absent, completion périmée/pause, doublons. Retenter après échec au foreground. Timer natif conserve deadlineSQLite ; valeur VoiceOver explicite en pause. En suspension, iOS programme la présentation de fin et rend le countdown stale ; arrêt exact et latence restent limites physiques, aucun timer indépendant ajouté.

## Tâches / interfaces / vérification

1. Domaine : NotificationPreferences(workoutsEnabled,photosEnabled,photoMinutes), ReminderOccurrence(id,kind,title,body,dateComponents,repeats), ReminderContext(training,preferences,startedDays). repository.reminderContext() transaction ; saveNotificationPreferences(validated) ; ReminderPlanner.plan(context,now,calendar) et managed IDs. Tests migration4 indépendante, seedoff/reprise/rollback ; planner future/horizon/suppression/statuts/archivé/monthly/DST/fuseau/désactivation ; premier run doit échouer avant implémentation (API absente = compilation manquante, pas RED comportemental).
2. Prototype et runtime : LocalReminderCoordinator @MainActor avec delegate UserNotifications, permission explicite, requests calendrier après plan pure, diff sans supprimer étrangers, pending refreshsérialisé. Compilable sous xtool avant UI. Tests politique de diff/routage et authorization gating purs, erreurs d’adaptateur/délai système à valider iPhone.
3. Intégration : NotificationsSettingsView, TrainingStore sync après commit/reload, SportApp delegate/foreground/temps significatif, SportTabView taps. Planning indique le rôle réel du rappel ; pas d’UI coffre. Politique Live Activities testée, retry foreground, valeur pause accessible. Suite complète/lint/build.
4. Revue indépendante finale mandatée par executing-plans ; corriger importants par tests RED→GREEN ; version0.6.0(14) app/enfant ; build→metadata→packaging→6testsmetadata/inspectionunsigned. Préflightidentité/certificat, device-run.sh USB, postflight mêmescertificat/profils/identity. Documentation et recette, STOP avantjalon7.

## Review focus

- Migration4→5 préserve tous snapshots/configurations/version future refusée.
- Activation sans permission et refus : aucun prompt au lancement, aucune request malgré préférenceON ; modifier permission au retour resynchronise.
- DST/fuseau/calendrier non grégorien, prochaine date mensuelle et horizon : pas d’instant passé ni doublon, pas de weekday inventé.
- Mutations pendant awaits : une sync ancienne ne réinstalle pas le rappel d’une séance démarrée ; foreignIDs intactes, retry d’échec visible.
- Coldtap/notification foreground : route générique only, aucun média ni contournement coffre ; repos Live Activity pause/skip/expiry/dismissal conservés.

## Progress / ledger

- [x] Task1 domaine, tests et migration
- [x] Task2 prototype SDK réel, runtime
- [x] Task3 UI/intégration et régression
- [x] Task4 revue/build/install/docs
- [ ] Confirmation iPhone utilisateur

Preflightinterfaces : Task1 produit contexteSQLite et specs immuables consommés parTask2 ; Task2 produit permission/sync/tap consommés parTask3. Task3 triggerssync après transactions, ActivityKit partage seulement repos existant. Aucun conflit détecté. Pas de Git utilisable ; aucun init/worktree/reset/commit : comparaisonSources /tmp/sport-jalon6-before et ledger ici, .agentsreadonly. Pas de nouvelle gate skill d’approbation, conformément à l’autorisation préexistante du plan/jalon.

Task1 complet : migration test RED version4≠5 et table absente, GREEN suite71. Nouveaux tests planner/préférences écrits avant API : échec compilation API absente, pas RED comportemental. Couverture horizon, heure passée/inconnue/désactivation, séances actives/abandonnées/suppression, DSTgap/fold et calendrier bouddhiste ; sauvegarde/réouverture/rollback. Versions attendues des fixtures anciennes adaptées à5, assertions de conservation intactes.
Task2 complet : runtime UserNotifications prototype réel code0,15,55s ; autorisation, calendartrigger, pending/add et delegate async compilés avecSDK. Synchroniseur dans SportCore via transport injectable, relectures DB/serializewaiters, source de calendrier pure ; tests avant APIs (compile manquante, pas RED comportemental), suite74 GREEN. Injection de transport limitée aux appels système iOS indisponibles sur Linux, résultats vérifiés sur la politique réelle.
Task3 en cours : UI intégrée, erreur de compilation TrainingLabels.clock absent corrigée avec format natif Date.formatted ; build à relancer. Politique de retrait LA testée avant APIs (compile manquante, pas RED comportemental) ; suite75 GREEN. Demande utilisateur additionnelle : une seule coche de fin à gauche, retirer la coche de droite ; rendu timer complet EmptyView. Valeur VoiceOver explicite en pause, zéro changement des marges appréciées. Retry ActivityKit au foreground. Confirmation des rappels/VoiceOver/coche sur iPhone encore obligatoire.

Task3 complet : UI xtool code0,8,83s ; suite75 sanséchec etlintstrictcode0. Aucun test source-miroir du retrait d’icône ; présentation compilée, à vérifier sur appareil.
Task4 revue : reviewer indépendant comparebaselineSources /tmp/sport-jalon6-before ; aucun Critical/Important/Minor, Declined to judge vide. Exécution indépendante75tests,0échec. LivraisonsUserNotificationsréelles, triggersnatifsau changementfuseau, tapàfroid, VoiceOver etrendu sontlimitesphysiquesrequises.
Versionapp/enfant0.6.0(14), buildversion2,06s→générationmetadata→packaging2,09s codes0 ;6testsmetadataetinspectionunsignedcode0. Préflightcode0 :0.5.0 installée, identitéexactecomparéeauTeamIDactifdeXtool, même certificat valide>24h etprésentremote. Premiercheckdeprofilcacheétaituneassumptioninvalide : aucunprofiln’eststockédanscecache ; remplacéparcomparaisonauthstatus/TeamIDenlectureseule, aucunprovisioningexécutéavantGREEN.

Task4 livraison complète : script USB code 0, rebuild 2,09 s, installation/vérification 100 %. Postflight direct iPhone code 0 : 0.6.0 (14), même identité, profils app/enfant valides/CMS vérifiés, même certificat existant et certificat local inchangé. Aucun App Group/push/permission plist sensible ajouté. README, BUILD, DESIGN, SECURITY et ROADMAP actualisés ; recette détaillée dans README. STOP avant jalon 7 jusqu’à confirmation physique utilisateur. Aucun test de livraison/permission iOS, de tap à froid ni du rendu prétendu exécuté.

## Retouche Notifications 0.6.1 (15), 12 octobre 2026

Demande immédiate : retirer la ligne Autorisation iOS considérée comme diagnostic. Suppression de la ligne et de son formateur ; aide/lien Réglages iOS seulement si permission refusée. Aucun changement de permission, opt-ins, planification, moteur de progression, stockage ou Live Activities. Le reste de la demande est un brainstorming pour plus tard, conservé dans docs/ideas/2026-10-12-progression-visualization-backup.md comme proposition non implémentée. Clarification utilisateur du futur seuil Feeling<8 (et non ≤7 actuellement livré), aucune modification du moteur maintenant.

Lint strict code0 ; 75 tests hôte sans échec ; build xtool6,12s puis génération metadata et packaging2,07s codes0 ;6testsmetadata et contrôle unsigned code0. Préflight code0 : ancienne0.6.0, même identité exact TeamID et certificat existant valide>24h/présentchezApple. Aucune revue indépendante supplémentaire ni test miroir du texte pour cette suppression limitée à la présentation. Test iPhone à confirmer après installation, aucune validation globale du jalon6 déduite de cette demande.

Retouche0.6.1 installée : device-run.sh code0, rebuild2,01s, installation/vérification100%. Postflight direct code0 : version15, identité/configuration inchangées, profils app/enfant valides/CMS vérifiés, certificat existant et certificat local inchangés. Arrêt avant jalon7 ; retouche et rappels à valider physiquement.
