# Audit Sport avec les skills Emil Kowalski — 22 octobre 2026

Suite à l’accord utilisateur, les corrections sont appliquées en build 75 ; voir [l’ExecPlan et les preuves de livraison](../docs/exec-plans/2026-10-22-audit-corrections.md). Le texte ci-dessous conserve les observations de l’audit initial, avant correction.

## Périmètre et conclusion

Audit du **working tree**, basé sur `648683677f1c405131562b1bc52753fe21a6e72c`, avec les changements locaux existants jusqu’à la build déclarée 1.1.0 (74), dont Stretching global. Ce numéro est lu dans le projet ; l’installation actuelle sur iPhone n’a pas été contrôlée pendant cet audit.

Quatre défauts retenus : deux de cohérence des objectifs après édition de l’historique, un d’affichage des durées et un de signalement d’erreur caméra. Un risque de performance sur les historiques longs reste distinct de ces défauts. Aucun correctif applicatif appliqué.

Je ne recommande pas de refonte des animations. Le code utilise déjà des composants natifs, des transitions courtes, des graphiques stables pendant l’actualisation et des adaptations à Reduce Motion/VoiceOver. Corriger les incohérences de données et leur restitution est plus utile qu’ajouter du mouvement.

Il s’agit d’un audit des sources et des tests hôte, **pas d’une validation visuelle ou physique de l’app**, ni d’une certification de sécurité. Aucun média privé, base personnelle ou secret consulté. Aucun nouveau build iOS, provisioning, installation, commit ou push effectué.

## Skills installés et méthode

Les 15 skills du [dépôt demandé](https://github.com/emilkowalski/skills) sont installés dans `/home/raton/.codex/skills/` : `animate-expo`, `animate`, `animation-performance`, `animation-vocabulary`, `apple-design`, `ask-sonner`, `break-ui`, `emil-design-eng`, `find-animation-opportunities`, `improve-animations`, `mobile-native`, `pick-ui-library`, `prototype`, `review-animations`, `write-swift`. Présence de chaque `SKILL.md` vérifiée après installation. Ils seront découverts automatiquement au prochain tour ; leurs fichiers ont été lus directement pour cet audit.

Références effectivement appliquées : `emil-design-eng` pour la cohérence/hiérarchie/feedback, `improve-animations` et son catalogue `AUDIT.md` pour la revue du mouvement, `apple-design` pour les principes d’interaction et `write-swift` pour les états, erreurs, concurrence et coûts. Références HIG locales consultées via `apple-hig`. La revue parallèle demandée par `improve-animations` a couvert interface/mouvement, domaine/données et coffre/services iOS ; chaque défaut retenu a été revérifié dans les sources.

Les prescriptions CSS/DOM/React/Expo ne constituent pas des règles SwiftUI. Aucun reproche fondé sur l’absence de cubic-bezier CSS, hover, Sonner, stagger décoratif ou bibliothèque Web. Les choix Sport documentés — cyan, glyphes de toolbar, grille depuis la première séance, fondu des graphiques — sont respectés.

## Défauts retenus

P2 = comportement à corriger ; P3 = défaut secondaire. Les colonnes After décrivent des propositions, **pas des changements réalisés**.

| Priorité | Before | After | Why / emplacement |
| --- | --- | --- | --- |
| P2 | Renommer une séance historique supprime aussi sa décision explicite de charge. | Préserver les décisions des exercices inchangés ; définir leur invalidation séparément lors d’une réelle correction de performance. | `Sources/SportCore/HistoricalWorkoutEditing.swift:106` supprime les exercices, donc leurs décisions par cascade (`TrainingSchema.swift:71`). La reconstruction restaure les objectifs historiques à la ligne 121, mais pas `workout_goal_decisions`. L’initialisation ultérieure d’une nouvelle affectation peut utiliser l’ancienne charge réellement soulevée au lieu de la hausse acceptée. |
| P2 | Ajouter, corriger ou supprimer une séance historique laisse les objectifs appris inchangés. | Réconcilier les exercices concernés dans la transaction de mutation, en préservant les personnalisations et les choix explicites de charge. | `Sources/SportCore/ManualWorkout.swift:149`, `:164` et `HistoricalWorkoutEditing.swift:135` terminent sans actualiser les objectifs. La source de suggestion peut désigner la nouvelle séance tandis que l’objectif adopté et la prochaine séance restent sur l’ancien résultat. |
| P2 | Les résultats chronométrés perdent leurs dixièmes à l’affichage. | Utiliser un formateur de performance conservant les dixièmes, distinct de celui des repos. | `Sources/Sport/Shared/WorkoutLabels.swift:75` appelle `time`, qui divise les millisecondes par 1000 à la ligne 50. Un résultat de 18,7 s affiche `0:18` ; 0,5 s affiche `0:00`. Cela touche l’historique, les séries enregistrées, le résultat précédent et le détail des séries sous les graphiques. Les données stockées restent exactes. |
| P3 | Une erreur de protection/suppression du temporaire caméra ressemble à une annulation. | Distinguer annulation, succès et erreur ; montrer un message générique sans chemin privé, tout en conservant le refus d’import en cas d’échec du nettoyage. | `Sources/Sport/Features/Vault/VaultCameraView.swift:41` renvoie `completion(nil)`, comme Cancel. `PhotoVaultView.swift:279` ferme la caméra et ne traite que les données non nulles : aucune erreur n’est présentée. Branche vérifiée statiquement, échec système non injecté sur iPhone. |

### Scénarios de vérification des corrections proposées

1. Reproduction exécutée : terminer une série de Chin-ups à 12 répétitions et 3,9 kg, accepter un objectif à 4,5 kg, puis seulement renommer la séance. Ajouter les Chin-ups à un autre workout : le nouvel objectif revient à 3,9 kg, tandis que l’affectation d’origine reste à 4,5 kg. Après correction, il doit conserver la décision à 4,5 kg. Vérifier également qu’un changement réel de performances suit une politique d’invalidation explicite.
2. Reproduction exécutée : terminer une série de Chin-ups à 8 répétitions, puis saisir une séance manuelle plus récente à 12 répétitions, Feeling 8,5. La source de suggestion passe à 12, mais l’objectif adopté et celui figé au lancement suivant restent à 8. Étendre la recette de correction à l’édition et à la suppression de la séance source, vérifiées ici par lecture du flux sans reproduction exécutée distincte. Aucun de ces tests ne doit modifier une séance déjà active.
3. Afficher des séries de 18 700 ms et 500 ms dans chaque écran utilisant `WorkoutLabels.performance`. Les dixièmes doivent rester visibles ; ne pas transformer les repos en compteurs à décimales.
4. Injecter un échec de nettoyage du temporaire caméra avec une image synthétique : aucun import, message visible, Cancel toujours silencieux. Ne pas exposer le chemin ni le détail système dans le message.

## Performance et accessibilité à vérifier sur appareil

**Grille d’assiduité : travail proportionnel à toute la durée historique.** `AttendanceViews.swift:17` utilise un `HStack` non paresseux ; `TrainingAnalytics.swift:44` produit un élément par jour depuis la première séance terminée ; `ProgressionView.swift:18` régénère ce calcul dans une Timeline de 60 secondes. Une entrée ancienne valide peut donc engendrer des milliers de boutons hors écran, même si le nombre de séances est faible. Le probe réel produit **20 752 jours** avec une unique séance au 1er janvier 1970, jusqu’au 22 octobre 2026. Aucun ralentissement ni coût mémoire iPhone mesuré. En cas de coût confirmé, rendre les colonnes paresseuses et mémoriser les jours par date/révision, en conservant le périmètre historique demandé.

**Grand texte : sélecteur de métrique.** `ExerciseProgressView.swift:63` garde trois segments, dont Repetitions et Added Weight, sans repli explicite comparable à `ChartPeriodPicker`. Tester le plus petit écran pris en charge aux tailles d’accessibilité, puis choisir un menu si les libellés sont tronqués. Ce n’est pas un défaut de rendu déjà observé.

**Caméra : encodage JPEG sur MainActor.** `VaultCameraView.swift:29` encode l’image complète avant le feedback d’import. Mesurer la latence/mémoire sur photo haute résolution ; ne pas promettre un gel à partir de cette seule lecture, ni déplacer le travail sans mesure et contrôle des règles de concurrence.

## Couverture de la revue

| Zone | Examen réalisé et limites |
| --- | --- |
| Today et préparation | Navigation, objectifs par workout, charges, échauffement et préférence Stretching ; rendu/clavier à tester sur iPhone. |
| Séance | États, sauvegarde des séries, Feeling, countdown, repos, correction, reprise, fin/annulation et support ; suite hôte réelle. |
| History | Ajout/édition/suppression, snapshots, archivage ; défauts de propagation/préservation ci-dessus. |
| Progress | Projections, sommes/moyennes, sélection, états vides, requêtes périmées, assiduité ; risques de grande grille/grand texte distincts. |
| Objectifs et inventaire | Séries indépendantes, dernières performances globales, charges exactes, décisions explicites, combinaisons bornées. |
| Body Weight | Persistance, édition, unités, périodes et rappels ; contrôles système et réception non exécutés sur appareil. |
| Transferts | JSON/CSV, validation, confirmation, récupération, transactions et exclusion du coffre ; aucune restauration personnelle exécutée. |
| Coffre | AES-GCM, séparation des contenus, ACL biométrique Keychain, leases et réponses périmées, verrouillage/masquage, previews, zoom, import/export ; aucun nouveau défaut de confidentialité étayé retenu. Face ID et masquage réel restent manuels. |
| Rappels et Live Activities | Synchronisation, routage, échéances et protection contre actions périmées ; livraison système/suspension/interactions physiques non validées. |
| Mouvement et retours | Transitions partagées de 0,25 s, fondu graphique de 0,15 s, absence d’animation du scrub, prise en compte Reduce Motion/VoiceOver/scène inactive, haptics facultatifs. Fluidité et perception non mesurées. |

## Vérifications exécutées ce jour

| Contrôle | Résultat |
| --- | --- |
| `swift test --package-path Tests/Host` | 281 tests, 0 échec, 6,970 s. SwiftPM signale des caches utilisateur non accessibles dans le sandbox ; les tests se terminent normalement. |
| `python3 -m unittest discover -s Tests/Metadata -v` | 6 tests, 0 échec. |
| `swift format lint --strict --recursive Package.swift Sources Tests/Host/Package.swift Tests/Host/Tests` | Code 0, aucun diagnostic. |
| `git diff --check` | Code 0. |
| Probe isolé sur le vrai SportCore + copie exacte de WorkoutLabels | Code 0 ; incohérences objectifs/décision et formatage reproduits, 20 752 jours calculés. |
| Compilation iOS / inspection d’un nouveau bundle | Non exécutées : audit sans correctif applicatif. Les builds historiques documentés ne sont pas une preuve de compilation actuelle. |
| Essais physiques | Non exécutés. |

Les tests existants couvrent notamment la propagation lors de la fin d’une séance et la migration depuis l’historique manuel. Ils ne couvrent pas les deux mutations d’historique décrites ici. Les tests hôte ne compilent pas les vues SwiftUI et ne peuvent donc pas détecter le formateur d’affichage défectueux.

### Preuve exécutée sur données fictives

Probe conservé temporairement dans `/tmp/sport-domain-audit-probe/Sources/Probe/main.swift`, avec sources SportCore liées au dépôt et formateur copié à l’identique. Base SQLite en mémoire uniquement. Compilation hôte isolée dans `/tmp` après blocage CFSocket du sandbox et revue automatique de l’escalade ; aucun build de l’app iOS. Exécutable relancé indépendamment par le contrôleur de l’audit, code 0 :

```text
A baseline adopted reps: [8]
A after newer manual adopted reps: [8] latest source reps: [12]
A next workout frozen reps: [8]
B accepted load: 4500
B after rename original assignment load: 4500 new assignment load: 3900
C performance duration 18700: 0:18 · 0 kg
C performance duration 500: 0:00 · 0 kg
D attendance cells for 1970-01-01 through 2026-10-22: 20752
```

Les charges de cette sortie sont en grammes ; les deux lignes C sont les chaînes réellement retournées par le formateur de l’app. Le nombre de cellules ne mesure pas le rendu SwiftUI.

## Recette iPhone ciblée

- Today → séance avec/sans Stretching, corrections et reprise après suspension : état et échéance cohérents, résultats exacts.
- History/Progress : dixièmes visibles, longues chaînes, plus grandes tailles de texte, VoiceOver, apparences claire/sombre et contraste augmenté.
- Graphiques : changements rapides de période/métrique, erreur d’actualisation, scrub sans retard ; tester grand historique fictif séparément des données personnelles.
- Coffre : galerie/détail/comparaison/menu/caméra, prompt de permission, inactive/arrière-plan ; masque immédiat et nouvel accès biométrique au retour selon l’état prévu.
- Live Activity : Pause/Resume répétés, expiration au premier plan et suspendue, retour vers le bon workout ; vérifier la livraison du rappel de test.

## Références et priorité recommandée

Apple HIG Motion : « Keep feedback animations brief and precise. » Les durées existantes sont des choix Sport et ne nécessitent pas de retouche arbitraire. [Source Apple](https://developer.apple.com/design/human-interface-guidelines/motion).

Apple HIG Typography : « Make sure your layout adapts to all font sizes ». Cela motive la recette du sélecteur, sans prétendre qu’il a déjà échoué. [Source Apple](https://developer.apple.com/design/human-interface-guidelines/typography).

Corriger d’abord la conservation des décisions et la cohérence des objectifs, puis les dixièmes affichés. Traiter ensuite l’erreur caméra. Profiler avant les optimisations de grille/caméra. Aucun nouveau mouvement décoratif recommandé ; aucun plan de correction lancé automatiquement.
