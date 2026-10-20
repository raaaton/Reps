# Body Weight et périodes 3/6/12 mois

## Objectif et autorisation

Plan en conversation explicitement approuvé puis demandé en implémentation le19octobre2026. Ajouter Body Weight entre Consistency et Exercises dans Progress : une pesée par jour, kg, graphique/calendrier réel et historique modifiable ; périodes3Months/6Months/1Year partout, défaut3mois. Rappel hebdomadaire opt-in avec jour/heure explicites, supprimé si pesée renseignée le jour prévu ;28jours renouvelés comme rappels existants. HIG consultés pour chaque écran, pas simplement composants SwiftUI.

## Architecture et interfaces

BodyWeightMeasurement(id,dayKey,grams) Codable/Sendable ; BodyWeightInput parse virgule/point,1...3décimales, entiergrammes positif. Migration12 additive : body_weight_measurements et préférences weight_enabled/weight_weekday/weight_minutes. Repository CRUD avec original pour rejeter édition/suppression périmée, dateunique/nonfuture. DatePicker existant→édition affichée plutôt qu'upsert aveugle. TrainingStore publie mesures triées/date et demande de saisie issue notification. Les mesures restent indépendantes du lest d'exercice.

ChartPeriod partagé3/6/12 et composant natif adaptatif ; dernière mesure/delta de période, aucun cumul de kg. Données v3 dans JSON ; provenance des anciens v1/v2 conservée pour préserver poids/rappel absents lors de restauration ; CSV conserve poids/rappel. Prévisualisation et recovery prennent ces données en compte, validation transactionnelle et stricte.

Rappel : ISOweekday1...7 et minute0...1439 facultatifs tant que désactivé ; obligatoires avant activation. Occurrences sport.local.bodyweight.DATE,28jours, pas de poids dans contenu. Routing vers Progress/saisie, ouverture coffre inchangée. Notificationtest reste isolée. Refus système expliqué, aucune capacité nouvelle.

## Étapes et responsabilités

1. Parent : tests persistance/parse/import avant code, migration, stockage, transferts, store, intégration.
2. Agent weight_reminders : tests et implémentation prefs/planner/repository/routing/paramètres natifs.
3. Agent weight_ui : tests ChartPeriod/BodyWeightTrend, graphiques/éditeur/liste, intégration Progress et filtres existants.
4. Parent : intégration, suite complète, revue indépendante de l'ensemble incluant matriceHIG, correctifs prouvés.
5. Lint/metadata/xtool/inspection, préflight, installationUSB autorisée/postflight même identité/certificat, docs et recette physique. Aucun push avant retour.

## HIG par surface

Progress : Lists and tables/Navigation (ligne et NavigationStack). BodyWeight : Layout/Buttons (hiérarchie et+). Graphiques : Charts/Charting data, axeYadaptatif et vrai temps, points accessibles, inspection facultative. Périodes : Segmented controls/Pickers et menu si espace insuffisant. Saisie : Entering data/Text fields/Pickers, numériqueétiqueté/annuler/sauver/validation. Réglages : Settings/Toggles/Pickers. Rappels : Notifications/Privacy, courts sans valeur. Toutes surfaces : DynamicType, VoiceOver, apparencessystème, vraiscontrôles etSF Symbols, aucune carte ou verre décoratif.

## Vérification et limites

Tests réels SQLite : réouverture, une/date, staleguards, suppression/collision/transactions, datefuture/virgule/point/bornes, migrations11→12 etfixturesanciens. Transferts : v3roundtrip, v1/v2/CSVconservent poids/rappel, corruption/doublons/rollback/récupération. Rappels : semaine/DST/pesée déjàsaisie/opt-in/refus/routing/syncisolé. Périodes :3/6/12mois, moisfin/bissextile, empty/onepoint/delta. Builds Linux ne prouvent pas rendu/gestes/notifications physiques.

## Ledger

- [x] Plan/spec et HIG lus ; baseline67 installée précédemment,219tests passaient avant ce jalon.
- [x] Répartition de fichiers distincts et contrats partagés envoyés aux agents.
- [x] Modèle/persistance/transferts/store :9tests ciblés passent.
- [x] Rappels et UI :14tests rappels existants/nouveaux et5tests périodes/trends passent.
- [x] Suite complète : 242 tests hôte, 6 metadata, lint strict ; revue indépendante et corrections validées.
- [x] Builds xtool et inspection du bundle 1.1.0 (68).
- [x] Installation USB et postflight : 1.1.0 (68), même identité/certificat/capacités.
- [ ] Recette iPhone.

Ruling: conserver le checkout courant et les changements66/67 déjà installés — ils appartiennent à cette même demande utilisateur et doivent être inclus dans la prochaine build ; aucun reset/worktree/caches supprimés ni commit automatique.

Premier contrôle complet :238tests/0échec, lint strict propre, xtool66.98s réussi. Tests écrits avant APIs ont échoué à la compilation pour API manquante ; aucune assertion rouge comportementale revendiquée pour ces premiers runs. Revue indépendante : deuxP2 UI (Add→occupé→libre déplaçait une pesée, rappel caché derrière modalProgress) ; correctif groupé confié à weight_ui. Aucun autre défaut concret dans stockage/transferts/rappels.


Contrôle final : 242 tests / 0 échec (7,585 s), lint strict propre, six tests metadata et inspection unsigned réussis. Build final xtool 51,39 s, puis intégration des métadonnées 3,95 s. Les deux P2 sont corrigés et la nouvelle revue les confirme résolus : Add revient à une nouvelle saisie sur une date libre ; la notification attend la fermeture de la feuille ou du coffre avant de naviguer. Quatre tests couvrent les transitions de cible d'édition. Aucun autre défaut concret signalé par la revue indépendante. Installation USB réussie (code 0, installation/vérification 100 %). Postflight direct : exactement un Sport 1.1.0 (68), identité effective identique, certificat exact inchangé, profils CMS app/widget valides et capacités conservées. Rendu physique et notifications encore à valider ; aucun commit/push/release.
