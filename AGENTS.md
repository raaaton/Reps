# Reps — instructions du projet natif

Reps est le nouveau nom de Sport depuis1.3.3. La même identité installée et l’autorisation de livraison existante sont conservées ; ce renommage ne constitue pas une première installation.

## Produit et expérience

Reps est une application personnelle iPhone, locale et hors ligne, en Swift/SwiftUI. La demande du 11 octobre 2026 remplace Expo/React Native/TypeScript, dont les instructions sont conservées dans docs/archive/AGENTS-expo.md.

**Priorité permanente : l’expérience qu’aurait une app Apple dédiée à ce besoin.** Respecter au maximum les [Human Interface Guidelines Apple](https://developer.apple.com/design/human-interface-guidelines), référence explicite demandée par l’utilisateur. Consulter les chapitres concernés avant toute décision UI ; distinguer leurs recommandations des choix propres à Reps. Utiliser composants natifs, hiérarchie sobre et interactions familières. SwiftUI ne suffit pas : vérifier le résultat sur iPhone à chaque jalon. Respecter Dynamic Type, VoiceOver, zones sûres, apparences système, SF Symbols, gestes et transitions standard. Aucun faux verre, dégradé gratuit ou carte décorative répétée.

Évaluer les idées de manière critique ; signaler les solutions inutiles ou disproportionnées. Préserver vocabulaire et règles métier ; ne pas changer silencieusement le périmètre.

Règle de couleur des libellés : dans le contenu et les actions, les SF Symbols accompagnant le texte principal utilisent le bleu accent, avec le texte inchangé. Préserver le rouge destructif et le contraste des symboles sur fond accent ou destructif. Dans les menus natifs, utiliser des symboles UIKit précolorés en rendu original lorsque le style SwiftUI est ignoré. Les icônes seules conservent leur style. Garder les quatre onglets natifs, y compris leurs couleurs de sélection.

## Stack et environnement

- Swift 6.4, SwiftUI, Swift Package Manager, xtool Linux ; iOS 26 minimum.
- Reprendre le vrai squelette retrouvé dans ~/Documents/Code/iOS/HelloSport. Conserver son source local et ses caches.
- Conserver/adopter Package.swift, xtool.yml et Sources/. Pas de projet Xcode comme build principal, npm, Expo, React Native, CocoaPods, CI macOS ou SideStore.
- Utiliser le SDK déjà enregistré, sans réinstallation ; SDKSettings.json indique actuellement iPhoneOS 27.1.
- Limiter les dépendances ; vérifier toute nouvelle dépendance contre le SDK et xtool.
- Nom affiché Reps ; identifiant configuré stable com.raaaton.sport. Contrôler l’identifiant effectif après provisioning xtool.
- Vues petites, organisation par fonctionnalité, logique hors des écrans, transitions explicites et concurrence Swift 6 maîtrisée.

## Travail par jalon

1. Lire les documents Reps et l’ExecPlan avant édition ; les validations historiques ne prouvent pas l’état Swift.
2. Implémenter uniquement le jalon validé. Suivre .agents/PLANS.md ; nouveaux ExecPlans dans docs/exec-plans/, car .agents/ est en lecture seule dans ce workspace.
3. Exécuter lint Swift, tests applicables et **xtool dev build**. Conserver les caches et rapporter les résultats réels.
4. Avant installation, vérifier identité, capacités et effets de provisioning. **Avant la première installation Reps, demander confirmation de la suppression de HelloSport sur l’iPhone. Jamais de suppression de son code local.**
5. Utiliser ~/omarchy-apple-dev/device-run.sh depuis Reps quand les conditions sont réunies. En cas d’erreur de signature/provisioning, arrêter et rapporter le message exact ; ne pas révoquer/remplacer certificats ou profils pour contourner l’erreur.
6. Installer chaque build prête à tester sur l’iPhone avant de demander une review utilisateur (instruction explicite du 11 octobre 2026). L’autorisation de ce workflow persiste : ne pas redemander une permission d’installation à chaque jalon, sauf effet inattendu ou blocage de signature. Rapporter modifications, vérifications, limites et checklist appareil ; attendre le retour explicite sur iPhone avant le jalon suivant. Une compilation n’est pas une validation iPhone.

En mode auto_review, soumettre directement les escalades nécessaires au reviewer après un blocage réel du sandbox. Ne pas changer le mode de permission. Ne pas réinitialiser le dépôt, supprimer des données ou nettoyer les caches.

## Versions

- Correctif sans nouvelle fonctionnalité : incrémenter le patch (`X.Y.Z` → `X.Y.Z+1`).
- Petits ajouts de fonctionnalités, réglages, améliorations UI et corrections : incrémenter uniquement le patch. Une fonctionnalité supplémentaire ne justifie pas à elle seule un minor. Réserver le minor à une évolution produit substantielle ; en cas de doute, choisir le patch. Correction explicite de l’utilisateur le24octobre2026 : Backpack éditable/regroupement/checkmarks relève de1.5.1, pas1.6.0.
- Demander l’accord explicite de l’utilisateur avant toute version majeure (`X+1.0.0`).
- Créer un commit dédié à chaque changement qui mérite une nouvelle sous-version (`X.Y.Z+1`), après vérification. Respecter les autorisations de push de la session.
- Une demande utilisateur de push GitHub inclut la publication de la release correspondant à la version poussée. Construire et vérifier l’IPA Release unsigned, publier uniquement l’IPA et vérifier la release/tag/source/asset ; ne pas redemander si une release est souhaitée.
- Incrémenter le numéro de build indépendamment, à chaque nouvelle livraison iPhone. Garder les versions de l’app, du widget et de l’inspection cohérentes.

## Données et métier

- SQLite sera la source de vérité ; migrations et transactions obligatoires. Aucun backend, compte, analytics, publicité ou dépendance aux apps Apple pour fonctionner.
- Préserver l’historique après redémarrage et changements de planning/inventaire ; instantanés des charges/compositions.
- Machine à états explicite : inactif, séance/série active, série terminée, repos, exercice terminé, séance terminée ou annulée. Annuler ne supprime pas les séries sauvegardées.
- Repos par échéance absolue persistée, pause/reprise/skip et feedback ; exact malgré suspension. Les Live Activities reflètent cet état sans timer indépendant.

## Confidentialité

- Aucun import de vraie photo avant un coffre sécurisé.
- CryptoKit AES-GCM pour originaux et miniatures ; clé aléatoire dans le Keychain protégée par biométrie courante et cet appareil ; LocalAuthentication natif.
- Aucun secret, chemin privé, image ou résultat biométrique dans les logs, notifications ou captures générées. Effacer l’état déchiffré au verrouillage. Ne jamais régénérer automatiquement une clé inaccessible.
- Changements sécurité : implémentation, revue indépendante, tests documentés et validation physique iPhone obligatoires.
- Prototype de toute API/extension incertaine avant intégration complète ; produits SwiftPM et configuration xtool/plist pour les extensions.

## Documentation

PROJECT.md décrit le produit cible ; README et docs/ROADMAP.md décrivent ce qui est livré/validé. Maintenir docs/DESIGN.md, docs/SECURITY.md, docs/BUILD.md et l’ExecPlan. Actualiser README en fin de jalon. Les archives Expo sont conservées comme historique, jamais comme instructions de build courantes.
