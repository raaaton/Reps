# Jalon 4 — Prototype Live Activities sous xtool

## Objectif et autorisation

Après « ok parfait on continue », jalon 3 validé sur iPhone en 0.3.4. Réaliser le jalon 4 du plan global accepté : extension WidgetKit réelle, repos SQLite reflété dans Dynamic Island/écran verrouillé, Pause/Reprendre via LiveActivityIntent dans le processus de Sport, fin programmée locale iOS 26. Installer avant recette et arrêter jusqu’au retour physique. Le rendu final, rappels et coffre restent hors périmètre.

## Architecture et contraintes

Swift 6.4/SwiftPM/xtool, SDK réellement installé iPhoneOS 27.1, iOS 26 minimum. Même application com.raaaton.sport, nom Sport, nouvel identifiant enfant com.raaaton.sport.rest-widget pour la seule extension embarquée. Aucun App Group, push, backend ou certificat supplémentaire. Le profil enfant est attendu pour cette extension ; arrêter sur toute erreur de provisioning avant réparation. Conserver sources HelloSport et caches.

SportCore garde SQLite comme référence. SportLiveSupport partage attributs Codable, accès à la base et coordination ActivityKit ; RestPauseIntent est déclaré dans les targets app et widget depuis le même fichier lié symboliquement ; l’intent ouvre la même base dans le processus app, jamais dans l’extension. WidgetKit reçoit un instantané et n’écrit pas dans SQLite. Repos par échéance native, aucun timer indépendant. Pause/Reprendre précis et idempotents avec identifiant/état attendu ; cancel/skip terminent les activités et annulent toute fin en attente.

HIG [Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities) consultées : « Focus on simple, direct actions. » Un seul Pause/Reprendre en développé/verrouillé, pas de Stop ; compact/minimal sobres, lecture immédiate. REST/PAUSE et icône compacte selon exigences Sport. Marges système/adaptatives, minuterie Text(timerInterval:), aucune animation décorative. Liens vers la séance active.

APIs vérifiées dans SDK et documentation Apple : LiveActivityIntent peut s’exécuter dans le processus app ; Activity.request avec start/alertConfiguration est disponible iOS 26. Le comportement physique reste à éprouver. xtool local documente products/extensions/infoPath et sait provisionner les .appex. Son packer ne produit pas Metadata.appintents ; le générateur Linux déjà installé dans omarchy-apple-dev utilise les vrais swiftconstvalues. Valider ce chemin sur le prototype, sans réinstaller/modifier le toolchain ou inventer de métadonnées.

## Étapes et interfaces

- [x] Prototype de compilation : Package.swift/xtool.yml, SportRestWidget-Info.plist, Sources/SportLiveSupport/RestActivityAttributes.swift et RestPauseIntent.swift, Sources/SportRestWidget/SportRestWidget.swift. Compiler réellement l’extension et l’API de fin programmée avant intégration du repos.
- [x] Domaine et tests : RestActivitySnapshot dans SportCore, projection seulement pour le repos courant running/paused, commande avec état attendu dans changeRest. Tester absence/expiration/dernière série, pause/reprise/double commande périmée, relance et sauvegarde avant rendu.
- [x] Coordination : SportRuntime pour la même base et RestActivityCoordinator pour create/update/end, fin future annulée/réarmée à pause/reprise, déduplication/relecture après suspension ; erreur visible et entraînement conservé. Intents arrière-plan refusés dans un processus extension. Tests de décision pure lorsque possible ; aucun faux test ActivityKit sous Linux.
- [x] UI et lien : extension compact/minimal/expanded/Lock Screen, retour à la bonne séance, statut erreur/désactivation accessible. Pas de promesse de fin en suspension avant recette.
- [x] Build réel, métadonnées et bundle : scripts/build-live-metadata.py depuis swiftconstvalues, resources xtool pour app et extension, script de contrôle adapté aux seuls nouveaux éléments attendus. Suite hôte, lint, revue indépendante, xtool dev build et inspection .appex/Mach-O/plists/métadonnées.
- [x] Préflight certificat/identité, expliquer le profil enfant attendu, installation USB via script habituel, contrôle version/profils/certificat et absence App Groups/push. Sport 0.4.0 (9).
- [ ] Recette iPhone : série → repos, compact/appui long/verrouillage, pause/reprise app suspendue, échéance et alerte sans app, skip/abandon sans ancienne alerte, retour séance, relance, grand texte/VoiceOver/Always-On. Arrêt avant jalon 5.

## Review focus et limites

1. Une action d’une ancienne présentation ne doit pas modifier un nouveau repos ni sa nouvelle échéance.
2. La synchronisation après await doit relire SQLite ; aucune projection ancienne ne remplace l’état récent.
3. Une activité supprimée par l’utilisateur ne doit pas être recréée par le polling à chaque seconde.
4. Les actions suspendues nécessitent discovery des vrais App Intents, bon processus et même base : compilation insuffisante.
5. Les fins planifiées doivent être annulées après pause/skip/abandon, et les activités persistantes réconciliées au retour. Limites de fermeture système à signaler sans les contourner par serveur.

## Résultats

- Prototype d’API/extension compilé avant intégration : xtool code 0, 5,43 s. App Intents : constantes static let pour Swift 6 ; aucune désactivation des contrôles de concurrence.
- Le générateur installé ne prend pas en charge AppIntentsPackage. Remplacé par déclaration du même intent dans les deux targets via symlink ; vrais swiftconstvalues des deux modules → Metadata.appintents, sans métadonnées écrites à la main.
- RED : cinq tests, sept assertions échouent sur projection absente/actions périmées ; GREEN : suite 51 tests, aucun échec. Six tests ActivityKit-domain supplémentaires au total, dont projection readonly qui ne consomme pas le signal de fin du son au premier plan. Ce dernier test n’a pas eu de RED comportemental (premier essai erreur de compilation, corrigée).
- SDK Activity non Sendable : pont de valeurs immuables et opérations async locales ; pas de @unchecked Sendable ni @preconcurrency.
- Build intégré final code 0, 13,05 s ; métadonnées générées et build d’empaquetage code 0, 1,90 s. Lint strict code 0 ; contrôle réel app/.appex Mach-O arm64 iOS 26, versions 0.4.0 (9), deux jeux de métadonnées conformes et son conservé code 0.
- Le timestamp des const-values reste ancien si leurs valeurs ne changent pas pendant un build incrémental ; le générateur vérifie leurs déclarations et doit être lancé après le build réussi, sans rejeter à tort ce timestamp.
- Pas de nouveau schéma SQLite (v3), App Group, push ou mode d’arrière-plan. Une activité de compte à rebours et une activité transitoire planifiée pour la fin utilisent la même échéance SQLite. Annulation et reprise tentent la réconciliation des deux.
- En suspension, la présentation de fin est programmée par iOS ; le compte à rebours standard devient stale/à zéro et est retiré lors de la prochaine réconciliation. L’arrêt exact de son affichage à l’échéance sans retour de l’app n’est pas garanti par ce prototype. Alertes, fermeture forcée, découverte des intents et permissions système restent à éprouver physiquement.
- Revue indépendante : risque de snapshot périmé après await corrigé par relecture SQLite avant toute programmation ; build correctif code0, 8,11s. Génération/contrôle bundle relancés code0. Relecture confirme correction ; aucun autre défaut certain bloquant l’installation du prototype. Risque de routage des intents documenté ci-dessous ; recette physique obligatoire.
- Préflight lecture seule code0 : Sport0.3.4 sous la même identité effective, certificat valide >24h et présent chez Apple. Installation consignée ci-dessous ; recette en attente.


Limite du générateur détectée par la revue : les swiftconstvalues déclarent bien LiveActivityIntent, mais le générateur ne sérialise un systemProtocols que pour WidgetConfigurationIntent ; les métadonnées de Pause/Reprendre ont ces champs vides. Les fixtures Apple locales ne couvrent pas LiveActivityIntent. Selon [Apple, configuration du runtime](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents), les métadonnées participent au choix du processus. supportedModes background ne prouve donc pas le routage vers Sport. Aucun champ inventé ni modification du toolchain : installation limitée à ce prototype de faisabilité, test impératif Pause/Reprendre app absente/en arrière-plan. Si cela échoue, arrêter avant intégration supplémentaire et conserver l’erreur ; le garde Bundle.main empêche d’ouvrir une base parallèle dans l’extension.


Installation USB exécutée : device-run.sh code0, build incrémental1,90s, installation et vérification100%. Postflight lecture directe appareil code0 : Sport0.4.0(9), même identité effective ; profils app et extension valides, signatures CMS vérifiées, certificat existant identique au préflight et certificat local inchangé. Aucun App Group/push. Recette physique WidgetKit/ActivityKit encore requise, notamment routage à froid des intents et alerte de fin ; aucun jalon5 commencé.


## Retours iPhone et correction 0.4.1

Retour utilisateur : rendu global apprécié mais timer trop éloigné du bord droit (compact, développé, Lock Screen), REST coupé au coin développé, Pause inopérant aux deux endroits. Ce retour ne valide pas le jalon4. Scope autorisé : corriger le routage de Pause/Reprendre et les alignements, sans commencer le jalon5.

Diagnostic USB réel, logs limités à RestPauseIntent et identités/chemins anonymisés : iOS sélectionne l’extension (45 appels observés), puis invoque perform ; metadata systemProtocols vide et allowedTargets null. La protection du processus extension bloque l’accès à la DB de Sport. Référence primaire téléchargée en lecture seule : vrai build Xcode MiniWatts1.5.0 (SHA vérifié), LiveActivityIntent compilé dans les deux targets avec SessionStarting et ses trois champs metadata. Adapter localement le script Sport depuis cette référence et la conformité compilée réelle ; ne pas modifier le toolchain global, ouvrir l’app au clic ou ajouter d’App Group. Test de bundle avant correction, puis tests de refus des inputs incohérents et build/lint/51 tests/installation/contrôle des deux profils.

Timer natif : supprimer l’intervalle depuis epoch qui réserve une largeur énorme ; alignement trailing, largeur typographique bornée au format minutes:secondes, compact réduit ; développé REST avec inset8 et timer symétrique8. Lock Screen conserve padding14. Tous les chiffres sont rendus par le timer natif, pas par un timer ajouté.


Correction0.4.1 : RED de bundle2échecs puis GREEN5contrôles ; revue détecte noms compilés tous deux manquants → nouveau test RED1échec puis garde strict et GREEN6contrôles. Generation relancée, contrôle réelunsigned code0. Build UI3,88s puis packaging1,84s code0 ; lint strict code0 ; suite hôte51tests aucun échec à17:53:15. Revue indépendante : fixture/Xcode/digest et logique de dimensionnement relus, aucun blocage ; cas malformed corrigé/testé. Timer overlay/VoiceOver et routage restant en recette réelle. Préflight lecture seule code0 : Sport0.4.0 même identité effective, certificat existant valide >24h et présent chezApple. Aucun schéma/capacité/appID modifié.


Sport0.4.1(10) installé : device-run.sh code0, build incrémental1,87s, installation/vérification100%. Postflight code0 : même identité effective, profils app/enfant valides et CMS vérifiés, même certificat qu’au préflight, certificat local inchangé. Aucun App Group/push ajouté. Test utilisateur du nouveau routage et des marges demandé avec capture limitée/anonymisée ; recette en attente.


Retour sur0.4.1 : « ça marche mais y’a pas mal de délais ». Capture de trois interactions : perform invoqué dans processus app, action terminée sans erreur en175/203/229ms ; validation chrono côtéiOS environ3,06s après la fin pour deux actions,12ms pour la troisième. Le marqueur SessionStarting apparaît bien dans le log action ; le défaut de routage est corrigé sur appareil. Ces timestamps ne prouvent pas l’instant exact de rendu écran. Ne pas inventer une animation, supprimer l’alerte ou ouvrir Sport pour contourner le délai.

Retouche0.4.2(11) : invalidatableContent natif sur les seuls statut/timer essentiels des deux présentations, conformément à la documentation Apple interactivité WidgetKit, afin d’indiquer attente d’un contenu à jour. Aucun raccourci d’écriture ni minuteur ajouté ; impossible d’affirmer une réduction du délai système sans nouvel essai. Compiler, réinstaller avantreview, arrêt avantjalon5.

Résultats 0.4.2 : build UI 3,88 s puis empaquetage 1,90 s, codes 0 ; six tests metadata, lint strict et inspection unsigned codes 0. Aucun changement de domaine depuis les 51 tests hôte réussis à 17:53:15. Revue indépendante sans blocage introduit ; durée annoncée par VoiceOver et accessibilité du compteur en overlay restent à tester, notamment en pause où le libellé n’a pas de valeur explicite. Préflight lecture seule réussi : même identité et certificat valide >24 h, présent chez Apple. Script USB code 0, rebuild 1,85 s. Postflight code 0 : Sport 0.4.2 (11), identité inchangée, profils app/enfant valides avec CMS vérifiés et même certificat existant, certificat local inchangé. Aucun App Group/push ni permission sensible. Recette du retour d’attente et délai ressenti encore requise ; jalon 4 non validé, arrêt avant jalon 5.

## Uniformisation des confirmations 0.4.3 (12)

Retour utilisateur sur 0.4.2 : « parfait ». Nouvelle demande limitée : utiliser partout l’alerte native centrée, notamment pour abandonner une séance, plutôt que la confirmation ancrée avec une flèche. Inventaire complet de Sources : deux `confirmationDialog` restants (abandon et recommencer) ; suppressions et erreurs déjà en `alert`. Choix Sport demandé par l’utilisateur ; les HIG autorisent une alerte pour confirmer/annuler une action destructive sans choix supplémentaires, mais recommandent une action sheet pour plusieurs choix liés à une action intentionnelle. Aucun nouveau dialogue pour une action courante.

Étapes : remplacer ces deux présentations par `alert`, utiliser Annuler pour renoncer à l’abandon, conserver les messages et opérations existants ; version app/extension 0.4.3 (12). Aucun changement de données, domaine ou capacités. Vérification prévue : inventaire des confirmations, lint, suite hôte existante, compilation xtool, régénération des métadonnées puis empaquetage/tests metadata/inspection bundle, préflight et installation USB puis postflight. Recette : Annuler conserve la séance/repos ; Abandonner garde les séries et arrête le repos ; Annuler le redémarrage ne crée rien, Recommencer garde la séance précédente. Aucun jalon 5 commencé.


Résultats 0.4.3 : inventaire après édition sans `confirmationDialog` ; lint strict code 0 ; suite hôte 51 tests sans échec ; xtool UI 5,87 s puis génération/empaquetage 1,91 s, codes 0 ; six tests metadata et inspection unsigned codes 0. Préflight réussi sur 0.4.2, même identité/certificat existant valide et présent chez Apple. Script USB code 0, build 1,88 s ; postflight 0.4.3 (12) code 0 : même identité, profils app/enfant valides avec CMS vérifiés, même certificat existant et certificat local inchangé. Aucun App Group/push ni permission sensible. Vérification directe du remplacement et des callbacks, pas de nouvelle revue indépendante pour ces deux changements de présentation. Retour « parfait » sur 0.4.2 consigné sans prétendre que VoiceOver/Always-On/tous scénarios de fin ont été testés. Arrêt jusqu’à recette iPhone des confirmations, aucun jalon 5 commencé.
