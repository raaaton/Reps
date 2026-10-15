# Jalon 2 — Planning et persistance locale

## Objectif

Autorisé par le retour utilisateur « j’ai bien l’app sur mon tel, j’ai testé, c parfait. tu peux continuer ». Le jalon 1 est validé. Remplacer les attentes Planning, Exercices, Repos et Aujourd’hui par une configuration locale persistante. Aucun démarrage de séance, timer en marche, historique, lest, notification programmée ou coffre.

## Décisions et interfaces

- SQLite natif via le module système CSQLite, sans dépendance externe. SportCore porte modèles Sendable, validation et repository actor ; Sport conserve SwiftUI.
- Une base sport.sqlite dans Application Support, migrations PRAGMA user_version transactionnelles, clés étrangères et seed stable/idempotent. Erreurs affichées ; aucune réinitialisation silencieuse.
- Trois séances existantes seulement : mardi Legs/Bulgarians, samedi Push/Push-ups/Pike Push-ups, dimanche Pull + Abs/Chin-ups/L-sit. Une séance réserve son jour même si elle est désactivée. Nom, jour libre, activation, sélection et ordre des exercices éditables. Sauvegarde atomique ; Annuler ne modifie rien.
- Catalogue initial : quatre séries par exercice ; 8–12 répétitions pour les quatre premiers, durée cible facultative pour L-sit. Édition nom/type/objectifs et activation ; ajout d’exercices. Pas de suppression destructive. Une désactivation ne doit pas vider une séance active ; expliquer l’action préalable nécessaire.
- Repos global 180 secondes par défaut, réglable en minutes/secondes. Pas de timer exécuté.
- Temps de rappel facultatif par séance enregistré à la minute avec DatePicker natif, après choix explicite de l’heure ; aucune heure attribuée par l’activation seule. Indiquer que l’envoi de notifications arrive ultérieurement, sans permission anticipée.
- TrainingSnapshot = exercices, séances ordonnées et repos. L’app lit ce snapshot depuis un TrainingStore MainActor, rafraîchi au chargement, au retour actif et après chaque sauvegarde réussie. Les formulaires éditent un brouillon local, affichent les erreurs et bloquent les doubles enregistrements.
- Aujourd’hui utilise la date locale et les séances actives, avec objectifs réels. Jour sans séance = repos ; aperçu hebdomadaire natif, sans bouton de démarrage avant le jalon 3.
- Package de tests hôte indépendant avec liens vers les mêmes sources SportCore/CSQLite : aucune duplication métier et aucune tentative d’exécuter SwiftUI iOS sous Linux.
- Identifiant d’app stable ; version 0.2.0, build 2. Installation avant review selon l’autorisation persistante ; vérifier mise à jour en place et certificat existant.

## Étapes

1. Marquer le jalon 1 validé et écrire ce plan.
2. Écrire/exécuter des tests Swift XCTest d’intégration SQLite avant implémentation du repository : seed, réouverture, modifications durables, collisions, transactions et validation.
3. Implémenter SportCore et faire passer les tests sur Linux.
4. Ajouter formulaires/listes SwiftUI natives, Aujourd’hui, chargement/erreurs et rafraîchissement. Compiler avec xtool et corriger les erreurs réelles.
5. Lint, tests complets, contrôle du bundle, revue indépendante, documentation.
6. Installer la build USB et attendre le retour iPhone avant le jalon 3.

## Vérification

- Tests : seed 3 séances/5 exercices/repos 180 sans doublon ; édition jour/nom/ordre/activation conservée à la réouverture ; brouillons invalides rejetés sans écriture partielle ; jour occupé, doublons/IDs inconnus, séance active vide, exercice inactif ; validation répétitions/durée ; création exercice ; repos et heure rappel persistés ; migration/newer version ; date locale lundi/dimanche.
- swift test --package-path Tests/Host ; swift format lint ; xtool dev build ; script de contrôle adapté à la version réelle.
- iPhone : Aujourd’hui/planning cohérents, déplacement/renommage/désactivation, choix/réordonnancement, Annuler, objectifs, ajout exercice, repos, heure minute précise, fermeture forcée/réouverture, clair/sombre et grandes tailles de texte. Les fonctions du jalon 1 doivent rester correctes.

## Journal

- [x] Plan et documentation pertinente lus ; baseline iPhone validée par l’utilisateur.
- [x] Tests et SportCore : tests écrits avant les sources métier. Première tentative hôte bloquée par le sandbox avec `CFSocket could not create wakeup socket pair`, interrompue ; aucun résultat rouge d’assertion revendiqué. Exécution hors sandbox : 8 puis 10 tests SQLite réussis, dont reprise après erreur injectée au milieu de remplacement et deux éditions concurrentes du même jour. Bases de tests temporaires uniquement.
- [x] SwiftUI et compilation xtool : premier build iOS réussi 6,12 s ; correction finale du choix explicite d’heure et mode Modifier compilée en 3,32 s. Aucun simulateur/runtime SwiftUI Linux ; contrôles physiques restent requis.
- [x] Revue indépendante : P2 sur l’heure 18:00 inventée corrigé, puis revue ciblée confirmant sa résolution ; aucun autre blocage concret. Lint strict et contrôle du véritable bundle non signé 0.2.0 (2) réussis. Vérification préalable : certificat existant valide > 24 h et présent chez Apple ; Sport 0.1.0 sur iPhone sous la même identité effective xtool, mise à jour en place attendue.
- [x] Installation USB : script terminé code 0, build incrémental 0,92 s, provisioning/signature/installation/vérification 100 %. Contrôle direct iPhone : Sport 0.2.0 (2) sous la même identité effective ; profil valide, CMS vérifié, certificat existant utilisé et certificat local inchangé. Aucun nouvel App Group, push, permission sensible ou extension. Un premier contrôle supposait à tort que xtool signait le bundle local ; sources IntegratedInstaller.swift confirmant la copie temporaire, puis vérification directe appareil. Aucune seconde installation ni réparation de signature.
- [x] Retour iPhone version 0.2.0 : « tout est fonctionnel », puis demande de retouches couleurs et gestion des séances/exercices. Le jalon 2 reste ouvert pour ces modifications avant tout jalon 3.

Dernier contrôle des tests après ajout des assertions Aujourd’hui/fuseau, absence d’heure inventée et séries invalides : 10 tests, 0 échec (build 1,35 s). Lint strict, contrôle unsigned et liens des docs réussis. Réserves manuelles : mode Modifier/réordonnancement, feuilles et DatePicker, clavier/grand texte/VoiceOver, Annuler, persistance après fermeture forcée. Arrêt au jalon 2 jusqu’au retour explicite iPhone ; aucun travail du jalon 3 engagé.

## Retouches autorisées après le retour iPhone

La demande explicite du 11 octobre élargit les décisions initiales « trois séances seulement / pas de suppression » : ajout de séances via +, suppression séances/exercices par swipe ou appui long, noms en couleur primaire système et jours gris. Ce changement reste dans le jalon 2, sans séance réalisée, timer ou fonctionnalité du suivant.

- Création distincte de l’édition via saveSchedule(creating: true) ; identifiant unique, jour libre, validation d’au moins un exercice actif pour une séance activée. 0 à 7 séances ; Annuler n’écrit rien.
- Suppression de séance : cascade des affectations, exercices conservés. Suppression d’exercice : retrait des affectations et désactivation des séances sans exercice actif, annoncées dans la confirmation. Transaction et ordre restant préservés.
- Schéma SQLite version 1 inchangé ; aucune réinitialisation ou seed à la relance. Les suppressions sont des actions futures dans l’interface, pas des opérations effectuées sur les données iPhone par l’agent.
- Listes natives, buttonStyle plain pour les labels et automatic pour les boutons de swipe ; swipe trailing sans full swipe immédiat, contextMenu, confirmationDialog, états vides. Détail de séance supprimée explicite au retour d’un autre onglet.
- Version 0.2.1 (3), même app/certificat ; installation avant review.

Preuves : six nouveaux tests d’intégration écrits puis observés rouges (création absente et suppressions non implémentées). Implémentation puis suite complète : 16 tests, 0 échec, build hôte 1,58 s. Lint strict réussi. Build xtool réussi 4,81 s ; contrôle unsigned réel 0.2.1 (3) réussi. Revue indépendante : aucun blocage concret, limites physiques sur couleurs/gestes/+ et confirmations.

- [x] Installation USB 0.2.1 : script code 0, build incrémental 0,99 s, installation/vérification 100 %. Lecture directe iPhone : version 0.2.1 (3), un seul bundle Sport correspondant, identité inchangée ; profil valide, CMS vérifié, certificat identique à celui d’avant déploiement, certificat local inchangé. Aucune extension, permission sensible, App Group ou push ajouté. Liens des documents vérifiés.
- [ ] Retour iPhone sur les retouches : couleurs clair/sombre, création +/Annuler, swipe et menu long, Annuler suppression, conséquences sur séances, conservation après relance.

### Validation finale

L’utilisateur confirme « parfait » après installation 0.2.1 (3). Le jalon 2 et ses retouches sont validés sur iPhone ; le jalon 3 peut commencer.
