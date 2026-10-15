# Brainstorm — Progression, assiduité et sauvegardes

Statut : brainstorming du12 octobre, décisions retenues intégrées au plan global sur demande explicite d’ajouter deux jalons. **Aucune implémentation commencée pour ces fonctionnalités.** Ce document conserve aussi les propositions rejetées ou encore ouvertes ; les périmètres d’exécution de référence sont maintenant PLAN-SPORT-NATIF.md et docs/ROADMAP.md. Ordre restant :6 Rappels/Live Activities→7 Progression→8 Coffre→9 Animations/haptics→10 Sauvegarde/finitions.

## Choix exprimés après la deuxième proposition

Ces choix cadrent les futures fonctionnalités, **sans démarrage de leur implémentation** :

- Retenir la saisie minimale et le lest préparé (idée1).
- Retenir la préparation du sac (idée2, intérêt confirmé avec réserve légère).
- Retenir la correction immédiate d’une série (idée3).
- Rejeter les qualificatifs/repères descriptifs Feeling (idée4). Garder une note numérique ; nouvelle saisie par pas de **0,5**, au lieu de0,1. Préserver les anciennes notes exactes, sans arrondi rétroactif. Avec ce pas,7,5 satisfait Feeling<8 et8,0 ne le satisfait pas.
- Retenir le bilan de progrès factuel (idée5).
- Rejeter les notes/repères techniques par exercice (idée6). « Les notes c’est mieux » est compris ici comme les scores Feeling numériques, car les notes textuelles de l’idée6 sont explicitement refusées.
- Rejeter les versions courtes de séance (idée7).
- Garder reprise/maintien (idée8) comme option potentielle, non confirmée.
- Ajouter la **durée totale de la séance**, du lancement à la fin, dans le récapitulatif. Temps écoulé réel comprenant repos, saisies, pauses, fermeture et arrière-plan ; ne pas le présenter comme temps d’effort seul. Timestamps persistés, pas de compteur indépendant. Une séance manuelle sans chronologie réelle n’affiche pas de durée inventée.
- Ajouter des **haptics** cohérents et discrets, à valider sur l’iPhone.

Ces décisions remplacent les recommandations initiales contradictoires ci-dessous, conservées comme historique de réflexion.

## Besoin exprimé / règle clarifiée

Visualiser les progrès, faciliter le choix du prochain objectif, grille de jours d’entraînement inspirée de GitHub, import/export de toutes les données.

L’utilisateur précise : quatre séries à douze répétitions, Feeling **strictement inférieur à 8**, proposer plus de lest puis augmenter l’objectif de lest. Ce seuil inclut 7,9 mais exclut 8,0 ; il remplacera le seuil livré ≤7 seulement lors d’une future implémentation acceptée. Pas de changement de moteur maintenant.

## Direction recommandée

Progression devient une vue d’ensemble avec résultats par exercice, assiduité et accès distinct au futur coffre photo protégé. Garder quatre onglets. Les graphiques et statistiques n’exigent pas Face ID ; seul l’accès aux photos l’exige. Cette organisation est inscrite au nouveau jalon 7 ; le coffre protégé arrive au8, sans authentification des statistiques ni affaiblissement de la confidentialité des photos.

Pour chaque exercice : objectif pour la prochaine séance, dernière performance, tendance et accès aux séries exactes. Les recommandations expliquent leur motif et offrent Adopter cet objectif ou Garder mon objectif. Choix confirmé puis persisté pour les prochaines séances ; une séance en cours garde ses instantanés. Modifier un objectif ne réécrit jamais l’historique. Si la composition visée disparaît de l’inventaire, demander un autre choix plutôt que modifier silencieusement le lest.

Règle proposée : toutes les séries requises atteignent le maximum choisi et Feeling<8 ; proposer la plus petite charge disponible strictement supérieure à la plus lourde réellement utilisée. Pour l’actuel4×8–12 : quatre séries≥12, aucune série manquante. Charge mixte : maximum réel comme garde conservateur, composition et delta visibles ; aucune nouvelle charge inventée. Exemple avec inventaire initial :4×12 à3,9kg, Feeling7,5→proposer4,5kg (+0,6kg). Acceptation explicite. Le nombre de confirmations/performances requis est à décider ; une seule performance répond à la demande actuelle, pas deux imposées sans accord. Pour les durées, objectifs futurs modifiables à définir ; ne pas appliquer automatiquement la même règle de lest.

## Graphiques utiles

Swift Charts natif envisagé, à prototyper avec xtool avant intégration. Courbes/points, périodes1mois/3mois/1an, toucher/glisser pour lire date et séries ; unités, résumé textuel et VoiceOver. Source : [HIG Charts](https://developer.apple.com/design/human-interface-guidelines/charts), [Charting data](https://developer.apple.com/design/human-interface-guidelines/charting-data), [Swift Charts interactivity](https://developer.apple.com/videos/play/wwdc2023/10037/).

- Lest enregistré au fil des séances ; distinguer plage/séries quand les charges diffèrent plutôt que présenter le maximum comme charge de toute la séance.
- Répétitions par série à lest comparable ; nouvelle charge plus lourde et répétitions moindres ne doivent pas apparaître comme une régression globale.
- Durée par série pour les exercices chronométrés, avec moyenne clairement nommée et accès aux valeurs exactes.
- Records factuels contextualisés (charge + répétitions, meilleure durée) et comparaison à la dernière séance comparable. Aucune estimation de croissance musculaire/force maximale ou score mélangeant exercices et métriques.

Commencer par deux graphiques pertinents par exercice plutôt qu’un dashboard de nombreuses statistiques. Feeling reste un contexte subjectif ; pas un score universel de progression.

## Grille d’assiduité

Un carré par jour, bleu séance terminée, marque distincte séance partielle/abandonnée avec séries, case neutre aucun entraînement enregistré. Toucher ouvre les séances du jour, plusieurs séances n’augmentent pas artificiellement un score. Une séance manuelle terminée compte, doublons du jour regroupés ; aucune validation factice.

Ne pas traiter les jours de repos comme des échecs ou valoriser une série de jours consécutifs malgré planning3jours/semaine. Résumé séances réalisées par semaine utile ; taux séances faites/prévues seulement avec historique du planning. Le planning actuel est mutable et ses versions ne sont pas conservées : impossible de qualifier honnêtement tous les anciens jours vides de séances manquées. Définir d’abord une règle de snapshot du planning si ce taux doit exister.

## Import/export

Distinguer sauvegarde complète restaurable et CSV lisible dans Numbers. CSV seul ne conserve pas toutes les relations, instantanés, réglages et futurs médias.

Sauvegarde locale versionnée via Fichiers : planning, catalogue, inventaire, réglages, historique, compositions et objectifs futurs. Plus tard, médias du coffre dans archive portable chiffrée ; ne pas exporter une clé Keychain biométrique ni une DB brute accompagnée d’images en clair. Prototype de format portable et récupération indispensable avant toute promesse de restaurer les photos sur un autre appareil. Mot de passe perdu et biométrie invalidée doivent être expliqués.

Import : validation du format/version/intégrité, aperçu du contenu et conflits, annulation sans écriture. Restaurer une sauvegarde avec sauvegarde de l’état précédent et confirmation explicite ; fusion éventuelle à traiter séparément (IDs stables, doublons, conflits d’édition). Permissions Notifications/Face ID accordées à nouveau sur l’appareil cible, jamais restaurées comme si elles étaient des données. Repos et séances actifs : politique de reprise à définir, aucune ancienne Live Activity ou notification de fin rejouée.

## Priorités proposées / questions ouvertes

1. Sauvegarde/restauration des données d’entraînement : protéger ce qui existe avant d’accumuler plus de données. Partie photo après coffre sécurisé.
2. Objectifs de lest persistés et adoption explicite des propositions, règle<8 clarifiée.
3. Graphiques par exercice et comparaison contextualisée.
4. Grille d’assiduité, sans faux jours manqués historiques.

Points encore à détailler avant les ExecPlans : répartition d’un objectif précis de répétitions, règle de progression des durées, graphique principal ; formats de sauvegarde, fusion et reprise de séance active à l’import. L’ordre des jalons et la destination Progression/Photos sont maintenant inscrits au plan global. Aucun schéma ni écran créé dans cette discussion.

## Deuxième échange — faciliter le quotidien, au-delà des graphiques

L’utilisateur confirme qu’il souhaite un objectif précis proposé pour la prochaine séance, avec liberté de modification. Il demande de nouvelles idées propres à l’assistant, et pas seulement l’approfondissement de ses propositions initiales. Les pistes ci-dessous sont **à discuter**, sans approbation d’implémentation.

### Pistes prioritaires proposées

1. **Lest déjà choisi, saisie minimale** : préparer le choix depuis l’objectif adopté, puis conserver la charge réelle de la série précédente dans l’exercice, en laissant changer la composition. Repères de dernière performance à côté des champs plutôt qu’un historique qu’il faut ouvrir. Répétitions et Feeling ne deviennent jamais des performances sauvegardées sans validation. Action explicite « Objectif réalisé » éventuellement proposée, avec Autre résultat à portée.
2. **Préparation du sac avant la séance** : liste des objets nécessaires pour les charges prévues, compositions et modifications à effectuer entre exercices. Équipement manquant ce jour = choix contextuel, sans désactiver globalement l’inventaire ni inventer une charge. Utile pour le matériel réel de Sport (sac/livres).
3. **Correction immédiate d’une série** : corriger répétitions/lest pendant le repos sans terminer la séance ou retrouver un éditeur d’historique. Ne pas relancer le chrono/repos en corrigeant un nombre. Les propositions futures utilisent les données corrigées.
4. **Feeling plus cohérent** : repères descriptifs courts sur l’échelle (subjective), et dernier Feeling avec sa charge pour comparaison. Ne pas convertir cette note en mesure clinique, RIR ou diagnostic. Ne pas ajouter un questionnaire avant chaque exercice.

La réduction de saisie et les valeurs raisonnables préremplies sont des principes d’interface Apple : [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data). Présenter les informations utiles dans leur contexte plutôt que des alertes répétées correspond à [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback). Le détail Sport reste un choix de produit, non une règle Apple sur l’entraînement.

### Pistes complémentaires à évaluer

5. **Bilan court des progrès réellement mesurés** : répétitions supplémentaires à la même charge, même résultat avec effort déclaré moindre, nouvelle charge adoptée. Afficher valeur et contexte. Pas de score universel, pas de message rouge automatique quand les répétitions baissent après une hausse de lest.
6. **Repères techniques personnels** : note brève par exercice, visible à la préparation (« réglage habituel », « variante choisie »), rappel facultatif sans ressaisie ; ne pas mélanger les variantes de l’exercice dans les comparaisons. Aucun programme technique automatiquement prescrit.
7. **Version courte prédéfinie** : proposer une séance courte que l’utilisateur a lui-même composée pour les jours contraints. Conserver séparément objectifs/résultats pour éviter une hausse de lest fondée sur deux séries alors que la règle habituelle en exige quatre. Idée potentiellement utile mais plus complexe ; après amélioration du parcours courant.
8. **Reprise et maintien explicites** : après une interruption, montrer quand la dernière séance a eu lieu et offrir de garder/modifier l’objectif, sans imposer automatiquement une hausse. Permettre « maintenir aujourd’hui » pour une séance ; ce choix ne supprime pas l’objectif à long terme et n’étiquette pas la séance comme un échec.
9. **Repérer une répétition du même résultat** : constat factuel de plusieurs séances comparables inchangées, contextualisé par Feeling/charge/repos/variante. Pas de diagnostic de stagnation ni changement automatique de programme sur une seule mauvaise séance. À évaluer après données et objectifs comparables ; potentiel de bruit si mal calibré.

Recommandation de priorité parmi ces nouvelles pistes : réduction de saisie/repères visibles, préparation du sac, correction immédiate, Feeling compréhensible. Version courte, reprise et constats de stagnation demandent davantage de décisions et peuvent attendre. Rien n’est ajouté au code ni aux jalons en cours.

## Haptics et récapitulatif de fin — proposition à détailler

Le code actuel contient déjà des haptics pour le décompte/départ des séries de durée et la fin de repos au premier plan. Leur présence dans le code ne prouve pas la perception physique ni l’exécution en suspension. Le travail futur complète cette couverture, sans doublonner les feedbacks automatiques des composants système.

- Validation d’une série : retour bref après sauvegarde réellement réussie.
- Séance terminée : feedback de succès après commit, récapitulatif durée totale / résultat factuel / prochain objectif adopté.
- Adoption d’un objectif : retour discret de validation ; sélection de valeur selon comportement système, pas de vibration pour chaque dixième/pixel.
- Décompte et fin de repos : conserver/rationaliser les événements existants ; aucune vibration à chaque seconde du repos ou du chrono.
- Haptics désactivables, aucune information uniquement tactile. Pas de promesse de vibration background/Live Activity avant prototype/essai iPhone.

Référence : [Apple Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics), patterns système selon signification, événements courts et cohérents, usage modéré et optionnel. Ce n’est pas un motif pour ajouter des haptics partout. L’emplacement exact de chaque retour reste un choix de Sport à confirmer lors de la conception.

## Animations — fluidité globale sobre

Nouvelle demande utilisateur : belles animations globalement, sans excès, résultat ultra clean. Cela rejoint la priorité Apple native ; aucune animation implémentée dans cette discussion.

Proposition : garder les transitions système de navigation/feuilles/contrôles ; animer seulement les changements d’état utiles avec des transitions cohérentes et courtes. Séries : remplissage/coche de progression après sauvegarde, passage série→repos→exercice suivant sans déplacement brutal. Objectif adopté : mise à jour discrète du résultat et de sa valeur. Récapitulatif : apparition sobre des résultats, sans confettis ni animation de compteur qui fabrique une performance. Graphiques : continuité lors du changement de période et sélection, à prototyper via Swift Charts. Grille : sélection/mise à jour légère, pas de cascade des365cases à chaque ouverture.

Ne pas animer tous les éléments/taps, chaque seconde d’un timer ou chaque frappe. Aucun rebond décoratif permanent, zoom spectaculaire, faux verre ou ouverture ralentie. Ne pas bloquer les interactions ni retarder une écriture pour attendre une animation. Harmoniser transitions avec haptics pertinents, sans doubler les feedbacks système. Respecter Réduire les animations avec remplacement sobre ou instantané ; aucun résultat perceptible uniquement par mouvement/couleur/haptique.

Référence [HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion) : mouvement utile pour état/feedback/instruction, motifs connus du système et accessibilité. Rendu, interruption rapide des transitions, Dynamic Type et confort à valider physiquement sur iPhone lors de l’implémentation ultérieure.

## Position retenue dans le plan global

Sur demande explicite de l’utilisateur, deux jalons sont ajoutés :7 Progression après validation du6,9 Animations/haptics après7 et8 Coffre. Ancien7 Coffre→8, ancien 8 Finition→10 avec import/export complet prévu une fois les modèles et médias disponibles. Les priorités proposées plus haut étaient une discussion ; elles ne remplacent pas cet ordre décidé. Maintien/reprise demeure hors périmètre confirmé. Chaque étape exige son ExecPlan avant code, compilation xtool, contrôles et installation USB, puis confirmation physique avant la suivante.
