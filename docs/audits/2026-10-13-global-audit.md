# Audit global de Sport — 13 octobre 2026

## Conclusion et périmètre

Audit du produit Swift natif livré, puis corrections installées en **0.11.3 (37)**. Aucun nouveau blocage trouvé dans la revue statique après corrections. Il ne s'agit ni d'une certification de sécurité, ni d'une validation des interactions réelles : la recette iPhone ci-dessous reste à effectuer.

La sauvegarde privée portable est **abandonnée à la demande de l'utilisateur**. Aucun prototype à retester, aucun chantier de sauvegarde à poursuivre. Les exports CSV/JSON d'entraînement et leur copie avant import sont conservés ; ils excluent les photos privées. Aucun média réel, historique personnel ou secret n'a été utilisé pour les tests.

L'examen couvre configuration/SQLite, séance et repos, Live Activities, historique/archives, objectifs/progression, courbes/grille, rappels, transferts, coffre et cycle de vie, contrôles/texte/accessibilité/mouvement. Les documents historiques Expo ne servent pas de preuve de fonctionnement natif. Une seconde revue indépendante a couvert les risques de données/confidentialité puis les corrections.

## Défauts confirmés et corrigés

| Priorité | Observation | Correction et preuve |
| --- | --- | --- |
| Importante | Les saisies locales acceptaient des noms que les transferts refusaient : plus de 4 096 octets UTF-8 ou caractère nul. Un nom d'exercice, séance ou objet pouvait ainsi bloquer les exports et l'encodage de la récupération avant import. | Validation commune à l'écriture et au transfert, y compris identifiants limités à 256 octets. Refus avant mutation, sans troncature. Tests sur noms ASCII, multioctets, caractère nul, ajout/édition d'historique et limite valide conservée à l'identique. |
| Importante | Après une série enregistrée, un recul de l'horloge pouvait permettre une nouvelle série ou une annulation datée avant cette performance. | Comparaison aux dernières séries enregistrées et aux arrêts chronométrés réellement persistés. Départ futur du décompte exclu de ce contrôle : on peut toujours annuler pendant 3–2–1. Tests de refus sans mutation et d'annulation durant le décompte. |
| Performance | Pendant chaque repos, l'app rechargeait tout l'historique SQL chaque seconde et republiait l'état. Le travail augmentait avec l'historique alors que le compte à rebours se dessine déjà indépendamment. | Réveil à l'échéance absolue persistée. Nouvelle échéance, pause, arrière-plan et changement d'horloge annulent/reprogramment la tâche. Notifications des intents et réconciliation au retour conservées. Réessai borné si la lecture échoue à l'échéance. Compilation native vérifiée ; gain batterie/FPS non mesuré. |
| Mineure — accessibilité | Les cases de la grille d'assiduité étaient des zones de 18 pt sélectionnées par calcul de coordonnées. | Boutons SwiftUI avec cible d'au moins 28 pt, libellé date/état et défilement natif. La grille compacte utilise le minimum HIG plutôt que la cible recommandée de 44 pt ; l'accès alternatif par liste demeure. Essai tactile/VoiceOver requis. |
| Mineure — langue | Trois erreurs de validation et l'unité VoiceOver du sélecteur de lest étaient encore en français. | Textes en anglais ; noms personnels et formats inchangés. |

Les tests ciblés ont d'abord échoué sur les mutations invalides et les deux scénarios d'horloge, puis les six tests ont réussi après correction. Aucun schéma, format CSV/JSON, calcul de progression ou règle de purge n'a été changé.

## Résultats de la revue globale

**Conservation des données.** Transactions SQLite et migrations conservées. Les tests couvrent notamment rollback, répétition d'une action, instantanés de charge/objectifs, édition d'historique, purge ciblée d'archives et remplacement du seul historique par CSV. Aperçu/confirmation avant import et récupération de l'état précédent sont maintenus. Aucun import ni suppression de données personnelles n'a été exécuté par l'agent. Les noms invalides éventuellement déjà présents ne sont pas réécrits automatiquement ; ils peuvent encore nécessiter une correction explicite pour être exportés.

**Coffre et confidentialité.** Aucun nouveau défaut étayé trouvé dans les sources relues : chiffrement des originaux/miniatures/métadonnées, clé Keychain liée à l'appareil et à la biométrie, sessions/leases révoquées au verrouillage, absence de remplacement automatique d'une clé inaccessible. Pas d'appel de journalisation trouvé dans Sources. Les permissions restent Face ID, caméra à la demande et Photos add-only pour l'export confirmé ; import par PhotosPicker, sans accès général à la photothèque. Ces constats ne prouvent pas Face ID, les caches d'iOS ou le masquage visuel réel.

**Interface et progression.** Navigation/List/Form/alertes système, actions SF Symbols accessibles et couleurs système conservées. Courbes reliées, bulles par séance, résumés sur la période et publication cohérente des résultats lors des filtres relus. Animations limitées avec prise en compte de Reduce Motion et VoiceOver ; retours haptiques configurables. Les parcours de zoom et de suppression avaient reçu des retouches précédentes : les réponses générales « continue » ne constituent pas une preuve individuelle de leur correction.

**Performance.** La boucle SQL inutile est supprimée. Calculs des graphiques et décodage réduit des aperçus restent hors du thread principal ; cache de miniatures borné, tailles d'import contrôlées. Pas de mesure sur appareil de mémoire, consommation, FPS ou réactivité sur un historique volumineux. La revue ne permet pas de promettre l'absence de ralentissements dans tous les cas.

**Limites conservées.** Transferts limités à 10 MiB, 10 000 séances et 100 000 séries ; photos jusqu'à 24 MiB/64 Mpx et 1 000 éléments. Le JSON restaure les données d'entraînement et leurs réglages métier, pas le coffre ni la préférence locale de retours haptiques. Les photos et leur clé ne sont pas transférables par CSV/JSON ; aucune sauvegarde privée portable n'est livrée. Pas de nouvel ajout Siri/Rappels/HealthKit ni d'intégration optionnelle.

## Vérifications réellement exécutées

| Contrôle | Résultat |
| --- | --- |
| Baseline `swift test --package-path Tests/Host` | 146 tests, 0 échec ; 5,302 s |
| Régression ciblée `--filter GlobalAuditTests` | Défauts reproduits avant correction ; 6 tests, 0 échec ensuite |
| Suite finale hôte | 152 tests, 0 échec ; 5,281 s |
| `swift format lint --strict --recursive …` | Code 0, aucun diagnostic |
| `xtool dev build` | Code 0 ; 21,50 s |
| Génération des métadonnées App Intents puis `xtool dev build` | Codes 0 ; empaquetage 2,12 s |
| Tests Python des métadonnées | 6 tests, 0 échec |
| `scripts/verify-foundation.py` | Code 0 : app/widget arm64, versions 0.11.3/37, déclarations et métadonnées attendues |
| Préflight en lecture seule | 0.11.2 installée sous l'identité existante, certificat valide et présent chez Apple |
| `~/omarchy-apple-dev/device-run.sh` depuis Sport | Code 0 ; rebuild 2,21 s ; installation/vérification 100 % |
| Postflight direct iPhone | 0.11.3/37 ; même identité effective et certificat ; profils valides avec CMS vérifié ; permissions inchangées |
| Revue indépendante des corrections | Aucun nouveau constat concret ; revue statique seulement |

Caches, squelette HelloSport, SDK et authentification conservés. Aucun certificat révoqué/remplacé, aucune quatrième application ajoutée.

## Recette iPhone avant clôture

1. Pendant une séance, laisser un repos expirer avec Sport ouvert. Tester Pause/Reprendre, puis quitter/revenir et essayer les commandes de Live Activity. La prochaine série doit rester accessible et le temps cohérent.
2. Avec grand texte, puis VoiceOver/Reduce Motion, parcourir Today, un graphique et les jours de la grille/liste : commandes lisibles, bon jour sélectionné, valeurs/unités annoncées, pas de flash pendant les changements de filtres.
3. Dans le coffre, vérifier zoom près d'un détail dans une photo **et** dans la comparaison. Passer en arrière-plan : aperçu masqué, Face ID requis au retour. Utiliser une image non privée si une nouvelle image est nécessaire ; aucune capture à transmettre.
4. Pour les suppressions, créer un exercice temporaire puis tester Annuler et confirmer sa suppression : pas de crash. Ouvrir un aperçu d'import puis Annuler ; aucune importation de test remplaçant les vraies données n'est nécessaire pour cet audit.

Après retour explicite sur ces parcours, l'audit pourra être clos. Aucun nouveau jalon ne démarre automatiquement.

## Références de conception

[Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Charts](https://developer.apple.com/design/human-interface-guidelines/charts), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion). Pages officielles consultées mais nécessitant JavaScript dans l'outil web ; contenu accessible via les références locales du skill apple-hig, capture du 12 septembre 2026. Le choix de 28 pt pour la grille compacte est un compromis Sport, pas la cible idéale de 44 pt recommandée par Apple.
