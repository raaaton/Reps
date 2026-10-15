# Animations et haptics — jalon 9 avancé

## Objectif et autorisation
Le 13 octobre, l’utilisateur demande explicitement de réaliser maintenant le jalon animations/haptics déjà défini, avec sobriété Apple et économie de tokens. Cette instruction avance le 9 avant le coffre (8), sans autoriser le coffre ou d’autres fonctionnalités. Exécution directe ; une seule revue finale ciblée. Références : plan global §9, PROJECT §21, brouillon progression du 12 octobre, HIG Motion/Playing haptics/Accessibility.

## Décisions
- Conserver navigation, feuilles, menus, boutons et gestes natifs. Pas de customisation des transitions système.
- Transitions de contenu brèves (environ 0,2–0,3 s, choix Sport), progression des séries, changements d’exercice/phase, objectif adopté, bilan et sélection de données. Aucun compteur fictif, confetti, cascade ou animation par seconde du chrono.
- Retours système après changement réellement sauvegardé, jamais au simple tap avant une écriture. Décompte/repos existants centralisés ; sélection de graphique limitée aux changements de point avec limitation de fréquence. Pas de doublon sur pickers/sliders/switches natifs.
- Option locale « Retours tactiles », persistante sur cet appareil, sans migration des données d’entraînement ni modification des exports. Réduire les animations désactive nos mouvements ; VoiceOver et valeurs textuelles restent disponibles. Aucun feedback ajouté en arrière-plan ou pendant une simple lecture/reprise.
- Coffre absent : aucune animation ni garantie de confidentialité concernant des médias. Widgets/Live Activities, signature, stockage et logique métier conservés.

## Étapes
1. Inventaire : seuls décompte et expiration repos utilisent UIKit ; aucune animation personnalisée existante. Préparer une politique de feedback testable et une implémentation native centralisée.
2. Intégrer sur les flux existants, sans retarder SQLite ni maintenir artificiellement une phase pour un effet. Conserver le contenu pendant le chargement du bilan pour éviter un flash de chargement.
3. Vérifier tests hôte, lint strict, xtool réel, génération metadata, empaquetage, tests metadata et inspection unsigned. Revue finale et corrections pertinentes.
4. Contrôler identité/certificat en lecture seule ; installer par device-run.sh, vérifier l’app/profils/certificat ; attendre test physique.

## Recette appareil
Répétitions puis série chronométrée (3–2–1, annulation, départ), coche enregistrée, repos pause/reprise/skip/expiration, Feeling/exercice suivant, bilan, adoption objectif, sélection de points/grille. Tester taps rapides, fermeture/réouverture et suspension, grand texte/VoiceOver, clair/sombre, Réduire les animations et Retours tactiles désactivés. Haptics et rendu ne sont pas exécutables sous Linux.

## Progression
- Documentation et flux actuels examinés ; sauvegarde de comparaison locale dans /tmp/sport-motion-before. Aucun Git reset, cache supprimé ni nouveau worktree : checkout natif existant.
- Implémentation terminée : transitions SwiftUI limitées aux états, coches SF Symbols, décompte numérique uniquement avant effort, objectif, changements de contenu Progression, bilan sans flash. Sélection du graphique directe sous le doigt (pas de retard animé ni courbe interpolée). Retours UIKit centralisés et option locale ; sélection plafonnée à un tap par 80 ms, aucun tap mis en attente.
- Tests : premier helper XCTest corrigé (erreur de compilation, pas un RED comportemental). Ensuite 5 assertions RED sur les événements absents ; politique implémentée, suite GREEN 129 tests / 0 échec. Relecture : cache de bilan ne masque plus une erreur de chargement, retry visible ; baseline avant action et tracker dédupliqué corrigent la course avec le polling. Test de double publication inclus ; suite finale 129 tests / 0 échec en 5,004 s. Lint strict code 0.
- Revue indépendante unique : 0 Critical, 1 Important (erreur bilan), 1 Minor (feedback/polling), tous deux corrigés ; pas de seconde revue prétendue. Les sensations, SwiftUI, clavier et accessibilité restent à tester physiquement.
- xtool réel : première compilation 21,76 s, corrections finales 19,02 s, codes 0. Génération App Intents depuis const-values réels, 6 tests metadata et inspection unsigned réussis. Empaquetage final réussi en 1,90 s ; inspection finale et 6 tests metadata code 0.
- Préflight lecture seule réussi : version installée 0.7.5, identité xtool exacte inchangée, certificat existant valide >24 h et présent chez Apple. Aucun provisioning tenté après le refus réseau du sandbox ; contrôle normal élevé autorisé ensuite. Installation USB code 0 (rebuild 1,90 s, vérification 100 %) puis postflight direct iPhone code 0 : 0.9.0 (22), même app/widget, profils valides/CMS vérifiés, certificat préflight et local inchangés, aucune capacité ajoutée.
- Ruling : préférence haptics dans UserDefaults uniquement pour cet appareil ; CSV/JSON entraînement et SQLite inchangés. Le coffre reste absent et hors périmètre. Le son de repos et les notifications iOS ne sont pas coupés par cette préférence. Les transitions de navigation/pickers/sliders restent celles du système.

- Travail livré ; recette physique en attente. Aucun prochain jalon commencé. Ruling revue : limitations de rendu/sensations/accessibilité acceptées comme recette iPhone obligatoire, aucune preuve simulée sous Linux.
