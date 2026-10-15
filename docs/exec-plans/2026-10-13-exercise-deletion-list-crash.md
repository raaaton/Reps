# Sport 0.10.5 — suppression et lisibilité

## Objectif

Demandes autorisées : Play blanc sur Préparer la séance, catégorie Réglages → Séances au pluriel, crash après suppression d’exercice. Aucun changement des règles d’archivage/purge, de coffre, du zoom ni des jalons futurs.

## Diagnostic et décision

Deux rapports Sport du 13 octobre (13:24:49 et 13:24:55) lus via USB sans effacement : EXC_CRASH/SIGABRT, NSAssertionHandler puis UICollectionView/SwiftUI.performBatchUpdates ; l’un identifie Invalid_Number_Of_Items_In_Section. L’utilisateur confirme que la suppression est persistée. Aucun motif textuel détaillé dans les rapports. Les vues Exercices/Progression changent les lignes, dont passage catalogue → archives et disparition d’une section, avec archives relues après publication du catalogue. Le défaut démontré porte sur le batch de List ; l’enchaînement exact reste à vérifier sur iPhone.

Contournement ciblé : identité de la List basée uniquement sur les IDs ordonnés catalogue/archives. Une composition différente recrée le conteneur natif au lieu de lui appliquer ce batch. Identité constante pour objectifs/feeling/horloge/assiduité ; confirmations, navigation et éditeur restent hors de la List recréée. Compromis : scroll peut revenir en haut après ajout/suppression ; pas de délai artificiel, UUID aléatoire, remise à zéro d’historique ou changement SQL. Référence : [SwiftUI id](https://developer.apple.com/documentation/swiftui/view/id(_:)).

## Étapes et vérification

1. Icône explicitement blanche ; rubrique et renvois au pluriel, noms de séance singuliers conservés.
2. Identité structurale sur les deux listes concernées.
3. Lint strict, tests métier existants (transactions/purge/rollback), compilation xtool et métadonnées. Aucun test hôte ne peut reproduire UICollectionView iOS ; pas de test artificiel de source ni de succès natif prétendu.
4. Revue ciblée, préflight identité/certificat lecture seule, installation USB0.10.5(33), postflight app/widget/profils.
5. Recette iPhone : Annuler puis supprimer catalogue/archives depuis swipe et appui long, notamment dernière ligne/dernière archive ; relancer et vérifier performances restantes. Play visible, rubrique Séances, régressions entraînement/Live Activities. Arrêt avant tout autre jalon, jusqu’au retour physique.

## Progression

Diagnostic et implémentation terminés ; vérifications techniques et installation réelles réussies, recette iPhone attendue.


## Livraison 0.10.5 (33) — 13 octobre

Deux rapports Sport réellement lus via USB confirment EXC_CRASH/SIGABRT sur assertion de batch UICollectionView/SwiftUI, dont nombre de lignes invalide. Motif textuel détaillé absent. Identité structurelle catalogue/archives sur les seules List Exercices/Progression ; aucune règle SQL ni donnée modifiée par le correctif. Revue indépendante sans constat actionable, limite runtime rappelée.

146 tests hôte/0 échec (5,153s), lint strict code0. xtool12,24s/code0, metadata générées depuis constvalues réels, empaquetage2,15s/code0, six tests metadata et inspection unsigned0.10.5(33) réussis. Aucun test hôte ne valide le batch UIKit natif.

Préflight lecture seule0.10.4 code0 : même identité Sport et certificat existant valide>24h/présent Apple. device-run.sh code0, rebuild2,12s, installation/vérification100%. Postflight direct code0 :0.10.5(33) même app/widget, profils valides CMS vérifiés, certificat préflight/local inchangé ; permissions inchangées. Aucun cache/HelloSport/SDK supprimé, aucune purge d’exercice ou photo personnelle exécutée par l’agent.

Build installée avant demande de review. À confirmer sur iPhone : Play blanc lisible, Réglages → Séances, Annuler puis supprimer depuis swipe/appui long dans catalogue/archives, dernière ligne et dernière archive, données restantes après relance. La liste peut revenir en haut après une modification de composition. Crash non déclaré résolu physiquement ; zoom0.10.4 reste non validé explicitement, jalons suivants non commencés.


Retour suivant : « ok continue ». Acceptation de la livraison et autorisation de poursuivre ; aucun détail individuel de suppression/dernière archive ou zoom fourni, donc ne pas inventer de validation séparée.
