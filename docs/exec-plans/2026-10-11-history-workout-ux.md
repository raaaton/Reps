# Jalon 3 — Retouches historique et séance

## Objectif et autorisation

Demande explicite après installation 0.3.0 : ajouter et supprimer des séances historiques comme dans Planning/Exercices, mettre Préparer la séance en avant et améliorer l’interface du suivi. Cette demande avance uniquement l’ajout/suppression manuels prévus au jalon 5. Le jalon 3 reste en recette ; ne pas commencer les extensions, progression, notifications ou coffre.

## Décisions

- Historique : + en barre supérieure ; feuille native Annuler/Enregistrer, nom, date passée ou aujourd’hui, exercices du catalogue, séries réellement réalisées, charge et Feeling par exercice. Brouillon local ; valeurs de performance laissées vides, aucun résultat inventé. Une première série vide par exercice, ajout/suppression libres des séries. Séance manuelle indépendante du planning, sans chrono/repos ni verrou de la séance du jour. Date seule enregistrée au début du jour local ; aucune durée totale de séance déduite.
- Écritures transactionnelles dans les tables v2 existantes, sans migration inutile. Instantanés des exercices et ordre conservés. Identifiant de brouillon stable pour éviter un doublon après une reprise de sauvegarde. Refuser les exercices supprimés ou dont le mode de suivi a changé pendant la saisie. Interdire suppression d’une séance active. Supprimer les repos liés avant les cascades ; préserver planning/catalogue et autres séances.
- Balayage gauche et appui long → Supprimer avec confirmation native. Aucun effacement au swipe complet ; commandes bloquées pendant l’écriture.
- Aujourd’hui : action principale avant les objectifs, bouton système prominent pleine largeur. Préparation : démarrage également prominent. Suivi : progression de l’exercice, série actuelle, action dominante, chronos lisibles avec Dynamic Type ; séries sauvegardées et performances précédentes repliables. Garde les transitions métier existantes et les champs natifs.
- Version 0.3.1 (5), même bundle effectif et certificat. Installation USB avant review ; validation physique toujours requise.

## Exécution et vérifications

1. Tests SQLite rouges puis verts : insertion durable ordonnée, validation sans perte, idempotence, rollback, suppression terminale et refus d’une active, références indépendantes et dernière performance actualisée.
2. Formulaires/listes et retouches SwiftUI ; compilation réelle xtool et correction des diagnostics.
3. Suite hôte complète, lint strict, contrôle du bundle, revue indépendante ciblée données et UX ; docs à jour.
4. Préflight identité/certificat, script USB existant, postflight version/profil ; arrêt pour retour iPhone.

Tests appareil : ajouter une séance passée avec répétitions et durée, annuler sans création, rouvrir les détails, supprimer par les deux gestes (annuler puis confirmer), vérifier une séance active préexistante, préparer/démarrer/repos/Feeling, clavier, grand texte et clair/sombre. Linux ne vérifie pas ces rendus/gestes.

## Progression

- [x] Spécifications, flux et conventions Apple relus ; périmètre présenté.
- [x] Domaine et tests.
- [x] Interface et compilation.
- [x] Revue et vérifications finales.
- [x] Installation réelle.
- [ ] Retour utilisateur iPhone.

### Vérifications réelles

Cinq scénarios rouges avec les API provisoires, puis six tests historique verts. Test Feeling explicite rouge, puis validation exacte ajoutée ; suite finale de 36 tests code 0 (0,083 s). Huit tests couvrent historique/saisie ; 28 tests existants restent verts. Lint strict et contrôle unsigned du bundle code 0. Build final xtool code 0 (5,93 s). Erreur de gestion du catch corrigée après assertion du compilateur Swift 6.4 ; aucun toolchain modifié. Revue indépendante a demandé suppression du Feeling 5/10 par défaut, correction relue sans blocage. Données SQLite v2 existantes réutilisées ; pas de migration car aucun schéma ne change. Fiche historique et dernières performances se mettent à jour après ajout/suppression, y compris navigation conservée dans un autre onglet. Les comportements UI/gestes/accessibilité attendent toujours le test iPhone.

### Installation 0.3.1 interrompue par le transport USB

Préflight code 0 : Sport 0.3.0 sous la même identité effective, certificat existant valide >24 h et toujours présent chez Apple. Script USB : détection/pairing OK, rebuild 1,00 s, puis attente de connexion. Service usbmuxd failed/core-dump ; journal 16:13:04 : `Sending to client fd 12 failed: -1 Broken pipe`, puis `free(): invalid pointer`, ABRT6. Même forme de pile free/abort qu’au précédent blocage, cause précise du défaut non démontrée. Déploiement en attente interrompu proprement par SIGINT : `Waiting for device to be connected… Cancelled.` Le code de sortie 0 de cette annulation ne prouve aucune installation. Aucun core extrait ni changement du système. Redémarrage réversible `sudo -n systemctl restart usbmuxd.service` soumis au reviewer et exécuté : `sudo: a password is required`. Demande manuelle envoyée : redémarrer le service, garder iPhone USB déverrouillé, confirmer ; ensuite reprendre préflight/script/postflight. Aucun déploiement 0.3.1 ni test UI déclaré réussi.

### Reprise et installation 0.3.1 confirmée

L’utilisateur confirme « c fait » après redémarrage local du service. Préflight répété code 0 : ancienne version 0.3.0, identité effective et certificat inchangés. Script USB répété code 0 : build incrémental 1,04 s, provisioning/signature puis installation et vérification 100 %. Postflight direct sur appareil code 0 : Sport 0.3.1 (5), même identité effective, profil valide avec CMS vérifié, certificat du profil et certificat local identiques au préflight. Aucun App Group, push, extension ou permission sensible ajouté. Revue finale sans blocage ; 36 tests, lint et contrôle unsigned réussis. Le redémarrage permet ce déploiement mais ne résout pas la cause du crash récurrent usbmuxd ; aucune modification du daemon/toolchain faite. Arrêt avant jalon 4 ; rendu, gestes, clavier et déroulement à confirmer par l’utilisateur sur iPhone.
