# Reps — sécurité

25 October — trimmed-video119: MP4 initialization metadata is restored inside the existing encrypted segment sink, before authenticated chunk sealing. Compressed media fragments, encryption, key/lease checks, permissions and strict duration/audio/transform/dimension/seek guards remain unchanged. Both original and rewritten initialization are capped at16MiB; checked box parsing supports the writer's32-bit headers and v0/v1 timing fields. DEBUG cache-triggered tests access only fixed bundled synthetic fixtures and their bounded synthetic cache outputs; no real vault media/database export. Independent code review finds no blocker; native119passes encrypted playback, tamper/reorder rejection and revocation plus both trimmed fixtures. The owner confirms the original-file import succeeds.

25 October — detailed video-import errors: original failures are retained per request in a memory-only actor and displayed only in the existing covered import form while the originating session/request remains valid. Lock clears the displayed error. Duration-validation values and localized/underlying system reasons are not added to persistent storage or application logs. Existing logs remain limited to pipeline identifiers/domain/code. Text selection allows explicit user copying; no automatic clipboard write, screenshot, export or upload is added. Crypto, database schema, key/lease rules and permissions are unchanged.

## État au 13 octobre 2026 — audit global

Sauvegarde privée portable et prototype abandonnés à la demande explicite de l'utilisateur. Les mentions historiques de ce chantier ne sont plus des travaux à poursuivre. CSV/JSON d'entraînement excluent toujours photos/clés ; aucune donnée personnelle exportée/importée pour l'audit.

Revue indépendante du coffre et du cycle de vie : aucun nouveau défaut étayé trouvé dans le code relu, sans certification du runtime iOS. Corrections0.11.3 limitées aux validations texte/dates, réveil du repos et accessibilité/langue ; chiffrement, clés, leases et permissions inchangés. Certificat existant et profilsvalides contrôlés avant/après installation. Les recettes FaceID/masquage/interruption restent physiques : [rapport global](audits/2026-10-13-global-audit.md).

## État actuel

Le jalon 2 conserve le planning, le catalogue d’exercices, les objectifs, les heures de rappel choisies et la durée de repos dans SQLite, dans Application Support du conteneur privé iOS. Migration version 1 transactionnelle ; pas de réinitialisation silencieuse. Les transactions et l’actor sérialisent les changements. Cette base de configuration n’est pas un coffre chiffré.

La suppression d’une séance/exercice est une action utilisateur confirmée depuis un swipe ou menu contextuel. Les conséquences sur les séances sont annoncées avant confirmation ; retrait des affectations et désactivation des séances privées d’exercice actif dans une même transaction. Aucun seed ne restaure les éléments supprimés au redémarrage. L’installation d’une mise à jour ne déclenche aucune suppression. Le schéma version 1 reste inchangé pour cette retouche.

Au jalon 3, les séances réalisées sont stockées dans SQLite en clair dans le conteneur privé, avec leurs instantanés, séries, charges, Feelings et états de repos. Migration v1 → v2 transactionnelle préservant la configuration. Aucun lien destructif vers le catalogue/planning ; abandon garde les séries, édition de configuration ne réécrit pas l’historique. Série et repos sont enregistrés atomiquement, une seule séance active. La base d’entraînement n’est pas un coffre chiffré. Les retouches 0.3.1 ajoutent saisie historique transactionnelle et suppression confirmée des séances terminales ; une séance active ne peut pas être supprimée. Les cascades restent limitées à la séance explicitement choisie. Aucun changement cryptographique ni nouvelle permission.

La retouche 0.3.4 ajoute une migration v2 → v3 transactionnelle : charge capturée avant une série chronométrée et fin figée d’une série ancienne en attente de saisie. Les colonnes nullable préservent les séances actives existantes sans inventer un lest ; historique/configuration inchangés. Aucune modification cryptographique ni capacité nouvelle.

Aucune photo n’est stockée ; aucune permission sensible, authentification ou requête réseau applicative. Le jalon 4 ajoute une alerte de fin ActivityKit planifiée, sans permission UserNotifications ni rappel général. Le cadenas de Réglages représente une future rubrique, pas une protection active. Les erreurs d’accès demandent de réessayer sans supprimer l’application.

## Exigences avant le coffre

- CryptoKit AES-256-GCM, clé aléatoire ; originaux et miniatures chiffrés dans le conteneur privé.
- Keychain protégé pour cet appareil et le jeu biométrique courant ; Face ID natif et NSFaceIDUsageDescription lors de l’intégration. Pas de demande au lancement général.
- Échec fermé si authentification/clé inaccessible ; aucune substitution ou régénération automatique.
- Nettoyer références/état déchiffrés au verrouillage, invalider les opérations asynchrones périmées ; protection iOS et suppression des fichiers temporaires contrôlés par Reps.
- Import Photos/caméra explicite et copie indépendante ; ne pas supprimer les originaux. Export confirmé avec permission d’ajout ; copie exportée hors coffre.
- Aucune clé, photo, miniature en clair, chemin privé ou résultat biométrique dans les logs, notifications ou captures générées.
- Réinitialisation et suppression globale exclusivement sur confirmation explicite.

Décision utilisateur du 13 octobre : verrouillage immédiat à la sortie du coffre ou au background, aperçu masqué dès inactive ; aucun délai de session 1/5min. La protection concerne le coffre seulement, pas un masque général sur Reps. Rendu de l’aperçu à vérifier physiquement, sans promettre le blocage des screenshots iOS. Ne pas changer les biométries personnelles pour un test sans accord spécifique.

## Vérifications requises

Revue indépendante, tests chiffrement/corruption/transitions/erreurs, compilation et essais Face ID/Photos sur iPhone avant utilisation réelle. Aucun test Face ID, chiffrement ou média n’est prétendu exécuté aux jalons 1–2.

## Signature

Le build sans --sign ne provisionne pas. La suppression de HelloSport sur iPhone a été confirmée et Reps installé au jalon 1 ; son code local reste intact. Les déploiements suivants doivent mettre à jour la même identité effective xtool. Ne pas afficher les secrets, révoquer ou remplacer un certificat pour contourner une erreur ; vérifier la validité du certificat existant avant d’appeler le script de déploiement.


## Prototype ActivityKit

RestPauseIntent est compilé dans app et widget, avec métadonnées issues des vrais outputs Swift. LiveActivityIntent est destiné à l’exécution dans le processus app. RepsRuntime refuse l’accès SQLite si Bundle.main est un .appex, avant de créer un fichier ; aucune base parallèle silencieuse ni App Group. Une action valide écrit en transaction avant la mise à jour ActivityKit ; identifiant du repos et ancienne échéance/durée protègent des actions périmées. La projection ActivityKit lit SQLite sans consommer les événements de feedback de l’app.

Le nom d’exercice, la prochaine série et le repos sont volontairement visibles sur écran verrouillé/Dynamic Island ; aucune photo ni donnée du futur coffre. Seuls les instantanés utiles sont remis au widget. Aucun certificat nouveau attendu ; un profil enfant WidgetKit est nécessaire. Vérifier les deux profils et le même certificat après installation. Aucun changement cryptographique dans ce jalon.


Postflight0.4.0 exécuté : même identité Reps, profils app/enfant valides et CMS vérifiés ; tous deux utilisent le certificat contrôlé au préflight, certificat local inchangé. Aucun App Group/push détecté. Ces contrôles ne valident pas l’exécution physique des intents.


Correction0.4.1 : seul le script du projet est adapté pour sérialiser le marqueur SessionStarting confirmé dans les sorties Xcode de référence. Il requiert la conformité compilée réelle et refuse les champs inconnus. Le garde d’accès depuis extension reste présent ; aucun App Group, entitlement, certificat ou stockage supplémentaire. Essai iPhone du routage requis avant validation.


Postflight0.4.1 : mêmes identités app/enfant, deux profils valides/CMS vérifiés, même certificat existant et certificat local inchangé. Aucun App Group/push ; diagnostic action anonymisé uniquement.

Postflight 0.4.2 : même application et extension, profils valides/CMS vérifiés, même certificat existant qu’au préflight et certificat local inchangé. Aucun App Group/push ni nouvelle permission sensible. Le retour d’attente WidgetKit ne change ni stockage ni accès SQLite ; aucune modification cryptographique.


Postflight 0.4.3 : identité app/extension inchangée, profils valides/CMS vérifiés, même certificat existant qu’au préflight et certificat local inchangé. Aucune nouvelle permission sensible ou capacité. Modification limitée à la présentation des confirmations ; données et conséquences des actions conservées.

## Jalon 5 — entraînement, sans changement cryptographique

Migration v3 → v4 additive et transactionnelle : objets lestés, compositions JSON des séries et charges chronométrées. Seed uniquement lors de migration ; aucune restauration d’objet supprimé au redémarrage. Instantanés indépendants de l’inventaire ; suppression ou renommage d’un objet ne réécrit pas les performances. Une édition de charge libre retire la provenance au lieu d’inventer une composition.

Édition historique en transaction après comparaison de l’original complet : refus des séances actives, brouillons périmés et séances supprimées, aucun rétablissement silencieux. Statut, planning et timestamps d’origine conservés ; seule la date de classement choisie est remplacée. Les anciens instantanés servent pour les exercices archivés. Refus de valeurs invalides/futures et d’un inventaire excessivement complexe avant commit. Migration et reprise, rollback, instantanés et stale guards couverts par tests hôte ; revue indépendante réalisée. Aucune photo ni capacité, permission, dépendance ou accès réseau applicatif nouveau.

Postflight0.5.0 code0 : version13 confirmée directement sur iPhone sous la même identité effective ; profils app/enfant valides, CMS vérifiés, même certificat existant et certificat local inchangé. Une seule extension WidgetKit, aucune permission sensible, App Group ou push. Attendre la confirmation physique du jalon 5 avant le jalon 6.

## Jalon 6 — rappels locaux

Migration v4→v5 additive et transactionnelle : table de préférences opt-in initialement désactivées, heure photo 360 minutes. Configuration, historique et compositions conservés. UserNotifications local uniquement ; aucun push, App Group, backend, compte ou nouvelle dépendance. Permission demandée seulement à l’activation explicite ; refus renvoie aux réglages iOS sans répéter le prompt.

Seuls les IDs sport.local. sont gérés, les autres demandes sont conservées. Toute séance enregistrée pour un schedule/date retire le rappel du jour. Le synchroniseur sérialise les demandes et relit SQLite après les suspensions pour converger vers les données actuelles. Payload générique kind, sans média, chemin ou secret. Le rappel mensuel ouvre Progression uniquement ; aucune photo importée ou protection cryptographique annoncée.

Postflight 0.6.0 réussi : mêmes identités app/enfant, profils valides/CMS vérifiés, certificat existant et certificat local inchangés. Aucun App Group, push ni permission plist sensible ; seule la demande runtime Notifications est prévue, jamais au lancement. Livraison, autorisation et navigation réelles à confirmer sur iPhone avant jalon 7.

Postflight 0.6.1 : mêmes identités et certificat existant, profils app/extension valides et CMS vérifiés, certificat local inchangé. Retouche de présentation uniquement, aucune modification de stockage/permission/cryptographie ni capacité. Le brainstorming d’export futur n’implémente aucun accès aux médias ni aux clés.

Réorganisation du12 octobre : coffre au jalon 8 ; Progression publique au 7, retour tactile/visuel global au 9, sauvegarde complète au 10. La nouvelle navigation n’affaiblit pas le coffre : chiffrement/biométrie/verrouillage à chaque sortie du coffre et protection de background restent à concevoir et vérifier avant vrais médias. Les animations n’introduisent aucun délai de verrouillage. Export portable privé à prototyper/revoir après coffre, jamais de clé Keychain exportée ni de copie photo non protégée implicite. Aucun changement de sécurité ou de code réalisé par cette modification de plan.

## Jalon7 — progression publique

Migration5→6 additive et transactionnelle, objectifs catalogue et snapshots séance dans deux tables séparées. Les objectifs historiques survivent à la suppression du catalogue, ainsi qu’à une édition de séance. Adoption/édition compare le contexte et l’original ; une charge devenue indisponible bloque le lancement sans séance partielle, sauf alternative explicitement choisie pour cette séance. Correction active compare la série sauvegardée et conserve timestamps/état/repos ; provenance retirée si charge modifiée librement.

Statistiques locales sur la base d’entraînement existante, aucune photo, clé, permission sensible, capacité ou dépendance ajoutée. Objectifs et performances restent des données locales non chiffrées ; la destination Photos privées n’est pas un coffre opérationnel. Certificat et identité à contrôler avant/après mise à jour USB, pas de nouvelle app principale.

Postflight0.7.0 code0 : même identité effective, profils app/extension valides et CMS vérifiés, même certificat préflight et certificat local inchangé. Aucun App Group, push ou permission sensible. Aucun média/coffre ajouté. Validation physique de progression encore attendue.

## Transfert d’entraînement — vérification incomplète

CSV et JSON entraînement excluent photos/miniatures/clés/autorisationssystème. Fichiers exportés accessibles à l’emplacement choisi par l’utilisateur ; données d’entraînement nonchiffrées, aucune garantie de coffre. Schema7 ajoute import_recovery ; migration et import/restauration transactionnels, originalecomparéeavantcommit, backupprécédenteexportable. Photos du futurcoffre jamaistouchées par remplacement entraînement. Validationformat/champs/enums/IDs/relations/metrics/dates/capacités ; bornes de fichier et exporttableurprotégé. Revue statique indépendante effectuée, corrections écrites ; nouvelle suite/build restent bloquées par serviceautorreview. Aucun transfert réel ni installation0.7.1 effectué par l’agent ; test physique requis avant utilisation.

Blocagelevé sansbypass :107tests réels sans échec, notamment rollbackSQL après insertioncopie et écriture partielle, conflits/idempotence, payloadprivé/version rejetés, snapshots/charges/Feelingexact/repriseannulée/size/date. BuildiOSfinal et lintstrict réussis. Aucun scénarioFaceID/coffre ajouté ou prétendu testé.

Postflight0.7.1 réussi : même identité Reps/widget, profilsvalides CMSvérifiés,même certificatpréflight etlocalinchangé, aucune permission sensible/AppGroup/push. L’agent n’a importé aucune donnée de test surl’iPhone ; l’importdemande unaperçu et actionutilisateur. Recette sécuritédonnées/rollback/récupération suriPhone encore attendue, coffreabsent.

0.7.2 : correctiondevisualisation uniquement, aucuneécriture/migrationdansstatistiques, pasderestprésumépourmanuals,pasdeclé/photo/permission exposée. FormatsCSVJSONconservés etphotosexclues. Postflightversion18mêmeapp/widget,mêmescertificats,profilsvalidesCMSvérifiés,aucunAppGroup/push/permission. Publicationdeprojection aprèsfiltre protégée parcancellation/keyedrequest ; runtimeUIphysiqueencoreàtester.

0.7.3 : volume et annotations calculés en lecture seule depuis les séries existantes ; aucune migration, écriture de performance, donnée privée ou changement de formatCSV/JSON. Lest ajouté uniquement, aucun poids corporel inféré. Produits/sommes bornés par les gardes overflow ; les données originales restent intactes. Identité, certificat et profils à vérifier avant/après USB ; aucun nouveau droit ou permission. Photos privées toujours exclues des exports d’entraînement.

Postflight0.7.3réussi : mêmesidentitésapp/widget,profilsvalides/CMSvérifiés,certificatexistantetlocalinchangés ; aucunepermission,AppGroup,pushouphotoajouté. SourceSQLitraining/intégritéimports inchangées.

0.7.4 : CSV remplace l’historique seulement, selon confirmation explicite de l’utilisateur. Copie complète JSON, suppression des repos/séances et insertion des snapshots transactionnelles ; rollback et stale/active empêchent une perte partielle. Configuration/adoptedgoals/préférences et permissions conservées ; no-op ne détruit pas la copie précédente. JSON conserve sa restauration globale. Aucun média/photo/clé présent dans ces formats. Statistique cumulative en lecture seule, overflow signalé sans total tronqué. Revue finale/profils et recette physique à consigner avant déclaration de livraison.

Postflight0.7.4 réussi : même app et widget, profils valides/CMS vérifiés, même certificatpréflight et certificatlocalinchangé, aucune capacité nouvelle.124tests hôte confirment rollback, garde active/périmée, no-opréordonné et retour à la copie précédente parJSON. Aucun import appliqué sur les données personnelles de l’iPhone par l’agent ; import/restauration réels restent à tester par l’utilisateur.

0.7.5 : répartition entre résumé et valeurs des points seulement. Calculs exacts en lecture seule, sommes par contexte protégées contre overflow ; pas de photo, clé, écriture de données, format, permission ou entitlement ajouté. Historique et copies de récupérationCSV conservés. Contrôles de signature aprèsUSB à consigner après réussite.

Postflight0.7.5 réussi : mêmeidentité app/widget,profilsvalidesCMSvérifiés,certificatexistantpréflightetlocalinchangés. Aucun import, suppression de données, changement deformat ou permission déclenché par cette mise à jour.


0.9.0 : présentation et haptics au premier plan uniquement ; UserDefaults contient un booléen de préférence locale, aucun secret. SQLite, formats CSV/JSON, récupération, entitlements et permissions inchangés. Aucun média/coffre implémenté. La préférence ne touche ni notifications iOS ni son de repos. Préflight confirme la même app et le certificat existant ; postflight à consigner après installation.

Postflight0.9.0 code0 : même identité effective app/widget, deux profils valides/CMS vérifiés, même certificatpréflight et certificatlocalinchangé. Aucune nouvelle permission/AppGroup/push. Aucun import ou suppression de données exécuté par l’agent.


0.9.1 (23) : lint strict code0, 129tests hôte/0échec (5,631 s), xtool réel10,95 s, génération metadata puis empaquetage1,89 s, 6tests metadata/inspection unsigned code0. Préflight0.9.0 identité exacte/certificat existant valide>24h et présentApple code0. device-run.sh code0, installation/vérification100%. Postflight direct0.9.1 même app/widget, profilsvalides CMSvérifiés, même certificatpréflight/localinchangé, aucune permission/AppGroup/push. Deux vues uniquement, aucune modification du domaine/SQLite/exports/haptics. Pas de test artificiel de texte UI ou de nouvelle revue indépendante pour cette correction de présentation limitée ; comportement et rapidité réels à confirmer sur iPhone.


Vérification 0.9.2 (24) : 129tests hôte/0échec (5,293s), lintstrict code0 ; xtool réel11,32s, génération metadata puis empaquetage1,94s codes0 ; 6tests metadata et inspection unsigned réussis. Préflight0.9.1 identité exacte et certificat existant valide>24h/présentApple code0. device-run.sh code0, installation/vérification100%. Postflight direct0.9.2 code0 : même app/widget, profils valides/CMS vérifiés, certificat préflight/local inchangés, aucune permission/AppGroup/push. Aucun changement SQLite/format/calcul/haptic. Contrôle statique des branches et guard de requête : résultat gardé même quand loading=true ou requête change, libellés issus de projection.request, publication groupée sans await et réponses périmées refusées. Rendu SwiftUI/scroll non testable Linux, recette iPhone en attente ; aucun test UI simulé.


0.9.3 (25) :131tests/0échec, lint strict code0, xtool17,43s puis générationmetadata/empaquetage1,94s,6testsmetadata/inspectionunsigned réussis. Préflight0.9.2 identité/certificat existants valides code0. device-run.sh code0, installation/vérification100% ; premier contrôle trop tôt pendant l’installation a lu l’ancienne version, puis contrôle réexécuté après terminaison. Postflight direct0.9.3 code0 : même app/widget/profilsvalides CMSvérifiés, certificatpréflight/localinchangés, aucune permission/AppGroup/push. Format d’affichage uniquement ; aucune migration/écriture personnelle/import/formattransfert modifié. Test physique et VoiceOver en attente.


0.9.4 (26) — lien natif Aujourd’hui/Repos :131tests/0échec (5,301s), lint code0, xtool réel5,96s, générationmetadata puis empaquetage1,92s codes0,6testsmetadata/inspectionunsigned réussis. Préflight0.9.3 identité/certificat existants valides code0. device-run.sh code0, installation/vérification100% ; postflightdirect0.9.4 même app/widget, profilsvalides CMSvérifiés, certificat préflight/local inchangés, aucune permission/AppGroup/push. Modification de navigation seulement, même RestSettingsView/RestEditor/store.saveRest ; aucun nouveau schéma/format. Rendu/navigation et modification/annulation à confirmer sur iPhone.


## Preuve native du coffre — 0.9.5 préparée

Utilisateur confirme verrouillage immédiat/aperçu masqué. Phase8A uniquement : clé synthétique dédiée, ACL Keychain whenPasscodeSetThisDeviceOnly + biometryCurrentSet, LAContext biométrique sans fallback code et lecture préauth sans nouveau prompt via interactionNotAllowed. Ciphertext AES-GCM de données constantes de test, protection complète et refus effectif de tag modifié à tester sur iPhone. Pas de photo, miniatures ou import réel ; aucune permission Photos/caméra/clé privée de production. Reset confirmé ne touche que namespace/fichier synthétiques. Callback périmé refusé, inactive masque sans annuler le prompt FaceID, background/sortie invalident le contexte et l’état. Revue/compilation/installation et validation physique doivent être consignées.


## Phase8A livrée — 0.9.5 (27)

133tests hôte/0échec (5,423s), lintstrict code0. API compile-only8,90s puis retrait/rebuild16,24s ; prototype natif21,11s, correction SDK/lifecycle6,43s, générationmetadata réelle et empaquetage2,22s codes0. Six tests metadata et inspection unsigned réussis ; une seule permission plist FaceID autorisée, aucune dans le widget. Revue sécurité indépendante unique :0Critical/Important/Minor dans le périmètre synthétique.

Préflight0.9.4 code0 : même identité exacte, certificat existant valide>24h et présentApple. device-run.sh code0, installation/vérification100%. Postflight direct0.9.5 code0 : même app/widget, profilsvalides CMSvérifiés, certificatpréflight/local inchangés ; aucune permission Photos/caméra, AppGroup ou push. Les scripts de contrôle temporaires précédents n’étaient plus disponibles ; contrôles recréés explicitement, aucun diagnostic ou provisioning ne les a contournés.

Coffre de production et import réels non intégrés. Chiffrement/Keychain/FaceID natifs s’exécutent seulement au tap utilisateur sur la preuve ; aucun succès runtime de ces API n’est présumé. Recette : FaceID initial/clés Créée puis Retrouvée après lock/relance, chiffrement/lecture Vérifiés et ciphertext modifié Refusé, annulation biométrique, sortie/background et aperçu masqué. Ne pas modifier les biométries personnelles. Arrêt avant8B jusqu’à confirmation physique.


## Coffre de production — 0.10.0

La preuve synthétique0.9.5 est validée sur iPhone ; les paragraphes précédents décrivent les livraisons historiques. Le coffre complet installé en0.10.0 utilise une base indépendante PhotoVault-v1/vault.sqlite. Originaux, miniatures, dates et types sont des BLOBs AES-256-GCM avec données associées version/clé/UUID/rôle ; ID aléatoire et identifiant de clé seuls en clair. Transactions atomiques et secure_delete vérifié actif. Répertoire et fichier principal protégés FileProtection.complete, répertoire exclu des sauvegardes système.

Clé aléatoire de production dans un namespace distinct du prototype, Keychain whenPasscodeSetThisDeviceOnly + biometryCurrentSet, non synchronisable, sans fallback code ni régénération automatique. Marqueur chiffré obligatoire ; clé perdue/inaccessible ou clé survivante sans base => refus fermé. Réinitialisation exclusivement confirmée ; elle ne touche ni historique, ni originaux Photos, ni certificat. Une archive privée portable reste au jalon10 ; CSV/JSON d’entraînement excluent entièrement le coffre.

Sortie/background révoquent le lease et effacent les références déchiffrées ; inactive masque toutes les surfaces du coffre sans animation, y compris feuilles/caméra. Callbacks épinglés à un UUID de session : une ancienne sélection ne peut entrer dans une session nouvelle. Vérifications avant/après lectures et avant publication. Pas de promesse d’effacement forensic de la mémoire, ni de blocage des screenshots iOS.

Import PhotosPicker : copie système dont la durée de vie est limitée à la closure FileRepresentation, taille contrôlée avant allocation ; aucune copie disque en clair créée par Reps. Caméra native photo uniquement, conversion en mémoire et retrait d’un temporaire reçu appartenant à tmp deReps ; aucun original externe supprimé, aucune sauvegarde Photos automatique. Les caches/fichiers internes d’iOS restent sous contrôle du système. JPEG/PNG/HEIC/HEIF, limite24MiB/64Mpx/1000photos, miniature500px, aperçu2400px et cache64images. Live Photos : image fixe seulement ; RAW/GIF/vidéo hors périmètre.

Export original confirmé vers Photos, avertissement copie hors coffre/synchronisation éventuelle ; permission add-only uniquement à ce moment. Un export accepté par Photos ou un commit chiffré commencé peut finir pendant lock sans publier d’image/résultat dans une session périmée. Pas de logs, captures ou fixtures de médias privés. 137 tests hôte, lint/xtool et revue indépendante sans constat ; contrôles identité/profils/certificat postinstallation réussis. Le runtime des nouveaux parcours/temporaires et le masquage physique restent à tester sur iPhone avec un média non privé. Voir l’ExecPlan pour les preuves et limites exactes.


## Comparaison privée — 0.10.1

Pose optionnelle ajoutée aux métadonnées AES-GCM existantes ; l’absence de champ dans0.10.0 reste valide et n’invente aucune classification. Édition atomique du BLOB metadata conserve originaux/type/miniatures et ne change ni clé ni schéma. Groupement de dates et candidats calculés uniquement à partir de métadonnées déverrouillées. Aucun export entraînement ne lit ces données.

Comparaison limitée à deux photos de même pose et de dates différentes ; deux aperçus2400px stockés uniquement dans le store privé central. Session/lease + UUID de requête et cancellation vérifiés entre chaque await/déchiffrement/pipeline/publication. Lock efface les références centrales et invalide toute publication ancienne ; fermeture/déletion/édition invalident la comparaison. Les nouvelles feuilles (jour, comparaison, date/pose) partagent le masque immédiat. AES-GCM, ACL Keychain et permissions inchangés ; ni logs médias ni captures générées. Revue indépendante statique sans constat Critical/Important/Minor,140tests hôte positifs ; masquage physique des feuilles empilées et interruptions restent à vérifier sur iPhone. Aucune garantie d’effacement forensic des buffers transitoires d’iOS.


## Vue agrandie de comparaison — 0.10.2

La route plein écran contient uniquement IDs et UUID de session, jamais UIImage ou bytes. Réutilisation des deux aperçus du store privé ; mask commun et garde session, fermeture à la perte d’accès. Le parent conserve le cache lorsqu’il présente cette vue interne, puis l’efface en quittant la comparaison ; lock du store efface toujours les références centrales. Aucun nouveau déchiffrement/copie disque, permission, clé, schema ou export. Revue indépendante ciblée sans constat ; runtime masque plein écran/gestes/retour à vérifier sur iPhone. La validation utilisateur de0.10.1 ne prouve pas cette nouvelle surface.


## Suppression par appui long — 0.10.3

Confirmation porte sur un snapshotIDs de la pile et l’UUID de session courante, supprimé au lock. Transaction unique : validationUUID/borne1000 et lease avant/après, rollback intégral sur erreur, autres photos et marqueur de clé conservés. Tests hôte du sous-ensemble, trigger SQL de refus après première suppression et leases révoqués/étrangers positifs. Aucun original Photos ni donnée d’entraînement touché.

Revue indépendante a signalé l’aperçu contextMenu implicite de la cellule privée hors du masque ; corrigé avec un preview neutre sans image/date, contrôlé dans les deux grilles et à la compilation finale. Nouveau wrapper de zoom utilise UIImage uniquement dans la vue native privée ; dismantle remet image/delegate ànil et efface le callback, couverture/session existantes conservées. Revue n’a relevé aucun autre problème étayé ; masque et gestes runtime restent recette iPhone. Aucune nouvelle permission, copie disque, clé ou migration.


## Purge des exercices archivés — 0.10.4

Exception explicitement demandée à la conservation historique : « Effacer aussi les anciennes performances ». La suppression habituelle du catalogue continue d’archiver ; la purge distincte et confirmée refuse un ID encore au catalogue ou dans une séance active. Transaction unique supprime les repos de ces seuls instantanés, séries/objectifs par cascade, puis séances entièrement vidées ; autres performances, timestamps et configuration préservés. Positions restantes renumérotées pour une exportation/restauration valide. Rollback, refus catalogue/actif, sous-ensemble, formats et repos/objectifs couverts par tests synthétiques ; jamais exécuté sur les données personnelles par l’agent.

Le zoom commun dans les deux surfaces privées garde UIImage centralisée et démontage UIKit, masque/session inchangés. Vue représentable fixée par GeometryReader, aucune réapplication de zoom dans layoutSubviews. Revue indépendante sans constat actionable ; masquage et ancrage runtime à confirmer sur iPhone. Pas de nouveau droit/clé/migration/format.


0.10.5 : diagnostic limité aux deux rapports de crash Reps sur l’iPhone, en lecture seule sans effacement ; aucune photo personnelle ni opération de purge de données exécutée par l’agent. Contournement de List, couleur Play et pluriel uniquement ; sécurité du coffre, capacités et déclarations sensibles inchangées.


0.11.0 : traduction et symboles uniquement. Fichiers VaultCryptography/VaultKeychain, schéma/seed et CSV de démonstration comparés identiques à0.10.5 ; aucune migration, clé, AAD, format, ACL ou capacité nouvelle. Buts des permissions anglais, mêmes permissions. Revue indépendante des changements persistants/cryptographiques sans constat ; quatre omissions de copie corrigées. Aucun média réel lu, importé ou supprimé par l’agent. La sauvegarde portable chiffrée n’est pas implémentée par cette finition.


## Preuve portable10B — 0.11.1

Seul échantillon constant, sans accès aux repositories/clé biométrique/photos. CommonCrypto PBKDF2-HMACSHA256600000, salt16bytes aléatoire Security, clé32bytes en mémoire ; AES-GCM nonce généré par CryptoKit et header36bytes commeAAD. Framing distinct REPSP01/.repstest, version/KDF fixes/longueurs/suffixes bornés avant dérivation ; limite65600bytes du prototype, pas une limite annoncée pour la future sauvegarde complète. Mot de passe UTF8 exact (confirmationcomparelesoctets), non persisté, références effacées au lancement/inactive/sortie ; pas de garantie forensic de purge mémoire/KDF instantanément interrompu. Aucun secret/path/image/résultat biométrique loggé.

Lectures Fichiers explicitement choisies, security-scope/release, FileHandle borné/chunké/fermé, contrôle de framing avant KDF. Revue indépendante a trouvé un callback Files hors garde ; corrigé via host/requestUUID immutable et gatevisible/active/token invalidéavantmutation. Trois régressions hôte RED(typeabsent) puis GREEN et revue corrective sans autre constat étayé. L’échantillon exporté est exclusivement chiffré et déclaré test ; aucun entraînement ou coffre remplacé. CryptoKit/CommonCrypto compilés mais tests natifs du vecteurRFC, roundtrip/nonce/PW/tag/AAD s’exécutent uniquement au tap sur l’iPhone, pas simulés sous Linux.


0.11.2 : prototype refusé par l’utilisateur et archivé hors app/tests, déclaration.repstest retirée. Aucun test natif de cette preuve n’est déclaré validé. Transferts CSV/JSON publics inchangés : photos/clés exclues, aperçu puis confirmation, transaction/rollback/copieavantimport conservés. Accès à cette copie sous Export to Files ; données personnelles et sécurité du coffre jamais modifiées par la simplification. Pas de nouvelle permission/clé/entitlement et aucun transfert réel effectué par l’agent.


## Préférence d'accent — 0.11.4

Préférence cosmétique UserDefaults, hors archive JSON d'entraînement comme les haptics. Champ optionnel de palette dans le ContentState ActivityKit : anciennes activités sans valeur restent Apple Blue. Aucun partage App Group, secret, donnée du coffre, migration ou permission ajoutée. Métier/repos/pause/reprise inchangés ; clés/leases/masquage non modifiés. Revue statique sans nouveau défaut ; contrôle postinstallation même app/certificat/profilsvalides. Recette physique demandée pour palette/activité et régressions habituelles.


## Cyan fixe et graphiques — 0.11.5

Réglage/lecture de préférence de couleur supprimés, anciennes valeurs UserDefaults inertes sans purge. Champ optionnel ActivityKit conservé pour compatibilité, rendu fixe cyan ; aucune nouvelle donnée partagée. Suppression du regroupement des graphiques purement visuelle, instantanés de conditions historiques conservés. Pas de changement de CryptoKit/Keychain/leases/migrations/permissions ou format de transfert.


## Confirmations neutres0.11.6

Les bindings/actions/instantanésUUID/leases des confirmations sont inchangés. Adaptateur transparentUIViewControllerRepresentable : uniquement style via propriété publiqueUIAlertController.view.tintColor, contrôleur faible, attente bornée60tentatives, annulation fermeture/dismantle/inactivité et isolationMainActor. Pas d'interception de boutons, présentation custom, lecture de titres/contenus ou log. Revue indépendante sans autre défaut étayé ; tests156/0échec, build sans avertissement et postflight même identité/certificat/profilsvalides. Masquage/fermeture pendant confirmation et FaceID au retour doivent être vérifiés sur appareil sans suppression réelle nécessaire. Aucune modification de chiffrement/Keychain/permissions/migrations.

0.12.0 : nouvelles données d’échauffement/étirement stockées uniquement dans la base d’entraînement (migration transactionnelle v8), sans permission/capacité ni modification du coffre. CSV support_json et récupération interne préservent ces résultats, avec validation de structure fermée, limites et chronologie ; aucune photo privée incluse. Les tests utilisent seulement des données temporaires.

1.0.3(57): Other extends the existing encrypted optional pose enum. Storage/encryption/key/lease/lifecycle/permissions and export exclusions are unchanged. Existing nil classifications stay nil; no metadata rewritten automatically. Tests use synthetic metadata only. This is classification scope, not a change of security boundary.

Build61: training schema9 adds only operational workout_goal_decisions(exercise_id FK cascade), preserving explicit goal choices at completion. No vault, crypto, permissions or profile capability changes. Training exports still omit photos/keys; active exports remain blocked, and current goals plus results represent completed/cancelled user data without operational markers.


19 octobre — séries par workout : migration11 additive et transactionnelle des affectations, initialisée avec les nombres/objectifs existants. Aucun changement du coffre, de la clé, des permissions, capacités ou intégrations réseau. JSONv2 conserve ces réglages et continue d'exclure photos/clés ; anciens JSONv1 validés contre les doublons avant conversion. Historique et séances actives restent indépendants des affectations.


19octobre — Body Weight : mesures stockées en clair dans la base d'entraînement privée de l'app, comme l'historique repsif, distinctes du coffre. Migration12 additive/transactionnelle, aucune modification des clés/biométries/chiffrement. ArchiveJSONv3 inclut pesées/préférences, exclut toujours photos/clés ; anciens formats conservent les données absentes. Les notifications poids contiennent du texte générique, aucune valeur. PermissionUserNotifications existante, opt-in explicite ; aucune nouvelle capacité/dépendance/requête réseau. Annuler les formulaires ne modifie rien ; corrections/suppressions/imports utilisent transactions et gardes périmées.


Build70: future-goal reconciliation is a transactional training-database change (schema13), including upgrade of previously accepted exercise changes. It retains load compositions, active/history snapshots and transfer recovery data. No vault, biometric, cryptographic, notification payload or app-capability change.


Build71: schema14 transactionally refreshes future training goals from existing completed exercise history and captures explicit goal decisions as training payloads. Historical/active snapshots are untouched; forced propagation and migration failures roll back. Per-set duration targets are non-vault training data and travel only in the versioned training JSON. No vault media/key, permission, capability or logging change. Device checks read only Reps app/profile metadata, never personal training or photos.


Build72: schema15updates future training goal payloads only, using existing history inside the migration transaction. No schema columns, backup-format, personal-device data export, vault, permission, identity or capability changes. Historical/active snapshots stay intact.


## Global Stretching — build 73

Transactional SQLite migration 15→16 adds stretching_enabled, default on. Only newly created workout support snapshots use it; active/history data are not rewritten. Training JSON v5 includes the flag; v1–4 decode with stretching enabled when absent. CSV imports preserve the current preference; recovery archives include it. Warm-up-only snapshots are valid in training exports/imports. No cryptographic, permission, capability, certificate or network-runtime change.
## Audit corrections — 22 October, build 75

Camera cancellation remains silent; encoding/temporary-file-cleanup failures return a generic import error only while the originating vault session remains valid. Cleanup failure still refuses import. No path or system error detail is displayed; no key, AES-GCM, file-protection policy, permission or export-policy change. Existing uncommitted Stretching work remains intact. Independent review covered the callback/session guards and found no remaining actionable issue; actual camera/lifecycle/masking/Face ID checks remain physical-device work. No private media or personal database was used by this audit or its tests.

## Skills content and links — 1.2.0 — build 78

Skills add only local training text, configuration and results; no new permissions, private media, vault keys or authentication changes. Built-in text is available offline. An explicit demonstration action opens an HTTPS source in the external browser, which may make its own network requests; Reps does not prefetch links or embed third-party video. Custom source URLs are validated before storage/import. JSON transfer remains closed to unknown fields and excludes private photos.

## Skills AI handoff — build 80

On explicit Generate, Reps copies only the prepared roadmap prompt and requested skill name to the system clipboard and asks iOS to open the chosen provider app. No training history, photos, keys or private records are included. Reps makes no model API call and embeds no secret. Website fallback is an explicit user action. Clipboard response is read only on Paste Response. Bounded JSON validation rejects unknown keys, malformed fields, unsafe/non-YouTube links, duplicate step names and inconsistent goal ordering before any storage write. Generated guidance needs user review; model claims or link availability are not independently verified at generation time.

## Public photo activity — 1.2.5 (87), 24 October

User explicitly authorizes photo dates and quantities to be visible without Face ID. Vault schema1→2 adds nullable day_key beside the existing encrypted BLOBs; migration never decrypts or rewrites original, thumbnail or metadata ciphertext. Public activity selects only day_key and COUNT(*), returning aggregate dates/counts without IDs, poses, types or media. Existing AES-GCM AAD, Keychain ACL, biometrics, file protection, backup exclusion, revocable leases and private cleanup remain unchanged. Training CSV/JSON still exclude photo activity, media and keys.

Legacy rows remain unindexed until a normal successful vault unlock. The authenticated metadata already decoded by that flow supplies dates; backfill compares exact IDs and ciphertext snapshots in a transaction, refusing stale/incomplete/duplicate/unauthorized snapshots. Inserts and metadata edits store the date atomically with their encrypted data; deletions/reset remove the same row. A lock can prevent later publication of private results but public date/count refresh remains permitted. No automatic unlock, image read, thumbnail generation, key replacement, real-photo test or personal-database inspection is performed by the agent.

Independent static security/code review found no actionable issue. Synthetic SQLite tests verify preservation, locked aggregate reads, stale/revoked guards and forced rollback, including second-row backfill failure. Physical Face ID, background masking and media viewing still require user validation. Device provisioning checks inspect app/profile metadata only.

## Streak presentation —1.2.6/1.2.7

The white glyph and current streak use existing public attendance metadata only. No new vault reads, crypto/Keychain/Face ID changes, permission, capability or personal-data export. The persisted Days/Largest Unit choice is a presentation preference in UserDefaults, following haptics; it does not carry workouts, photos or keys and is excluded from training JSON. Streak remains derived from existing training records and current planning, without database mutation.

## Private movement videos —1.3.0

Vault schema2→3adds encrypted movements, encrypted video metadata/thumbnail and1MiBAES-GCMchunks. Existing photo ciphertext and biometric Keychain namespace/key are retained. AAD separates movement metadata, video metadata, thumbnail and each video ID/chunk index. The encrypted manifest authenticates total byte count/type/duration/movement; repository checks sizes, positions, complete chunk set and ownership before atomic publication. Unpublished imports are removed after interruption/reopen; revoked sessions may clean only their own unpublished rows. Reset cascades all media but Delete All Photos remains photo-only.

Photos-provider clear URLs are consumed only within FileRepresentation. Reps writes only encrypted temporary staging under a fresh ephemeral key in a complete-protection, backup-excluded temporary folder. Each block is authenticated and reencrypted under the existing vault key before publication. Player loaders request encrypted SQLite chunks, decrypt in bounded memory and never write a clear video file. Lock revokes leases, cancels requests, pauses/replaces player items, clears references and closes readers. PiP and external playback are disabled. No new Keychain namespace, broad Photos/microphone permission, entitlement, remote media service or dependency is introduced.

Movement names, source Skill IDs and video dates stay encrypted and are absent from Consistency and training CSV/JSON. The existing public photo-day index remains photo-only. System-managed Photos copies and user-owned originals are outside Reps's control. Reps does not promise to prevent OS screenshots. An inaccessible biometric key remains fail-closed and is never regenerated automatically.

Independent review identified reset confirmation scope and inactive navigation-title exposure; both are corrected. Native synthetic build91actually verified AES-GCM tamper/reorder rejection, two encrypted AVPlayers, seeking,0.5xplayback and lease revocation, using a random non-Keychain test key and generated test pattern. Readback verified the unique run token/build and accessed only the fixed synthetic report. No private media or biometric enrollment was inspected/changed. Personal Photos import, Face ID interruptions, app-switcher masking and controls remain physical acceptance checks after final delivery.

## Vault video correction prototype (24 October 2026)

The privacy mask keeps system Photos/AVKit presenters mounted during temporary inactivity; it never begins authentication or recreates a lease on return. A non-key, noninteractive opaque window covers native full-screen video and private navigation bars; background still invalidates the lease, loaders and playback. Comparators cancel pending preparation when covered.

Permanent audio removal is being validated using AVAssetReader compressed video samples and AVAssetWriter segmented output into an AES-GCM sink, with no Reps-owned plaintext output URL. Input segments are capped at8MiB between sync samples (oversized/unsupported sources fail safely), output callbacks at16MiB, and sink buffering at1MiB. Existing encrypted originals remain published until validated replacements commit in a lease-checked transaction with source-metadata comparison. Native95 and96synthetic validation passed, including actual provider capability capture, encrypted-source remux and encrypted-candidate orientation/duration/seek validation. Audio removal runs after explicit Face ID; failure or interruption retains unconverted encrypted originals and retries on a later unlock. All playback stays muted during conversion. At the5000-video limit, one source-checked incomplete replacement is allowed without increasing the published limit.


## Reps rename compatibility —24 October 2026

Reps keeps the installed app/widget identifiers com.raaaton.sport and com.raaaton.sport.rest-widget. Keychain services, vault Sport/vault/v1 AAD and Sport vault v1 verification bytes, database sport.sqlite, preference/reminder namespaces and JSON sport.training/CSV sport_csv_version are permanent compatibility identifiers, not display branding. Existing media, keys and training require no migration. Internal Swift modules Sport/SportRestWidget/SportLiveSupport also retain identity for system-serialized ActivityKit/AppIntent types; products, executables, folders and visible names use Reps. Both reps:// and legacy sport:// workout links are accepted. No certificate/capability/schema change or private-device-data read is part of this rename. Historical Git commits/tags and build artifacts retain their original bytes.

## Inventory quantities —1.4.0(100)

Training schema18 adds only weight_items.quantity with a1…1000SQL constraint/default1. Training JSON7 adds inventory/component counts; reads1…6 default missing counts to1. Unknown/private JSON fields remain rejected. Component grams continue to be subtotals; imports reject invalid/nonintegral counts, nondivisible subtotals, overflow and duplicate component identifiers. CSV component JSON retains counts. Existing vault schema, encryption, Keychain identity, privacy lifecycle, entitlements and permissions are unchanged.

## Minimum-object choices —1.4.1(101)

No schema, archive, vault, permission or cryptographic change. Bounded-count generation caps future compositions at10physical weight objects excluding the bag, retaining4095totals and200000component-work bounds. Independent exact inventory validation rejects duplicate/missing bag, disabled/renamed/missing items, weight mismatches, overflow and overquantity/over10new choices. Backup validation retains older self-consistent snapshots above10without making them selectable.

## Configurable weight-object limit — 1.5.0 (102)

Training schema 19 adds only preferences.maximum_weight_objects (default 10, SQL range 1–1,000). JSON 8 includes maximumWeightObjects; versions 1–7 default to 10, while closed-shape unknown/private field rejection remains. JSON restores the preference; CSV replacement preserves it. Proposed changes regenerate bounded loads before any write, so invalid or overly complex settings roll back atomically. Older migration helpers use the default before the column exists. Active/history compositions and all vault/keychain/identity/capability behavior are unchanged.

## Editable backpack — 1.5.1 (107)

SQLite20 adds preferences.backpack_weight_grams with default3000 and positive SQL constraint. JSON9 includes backpackWeightGrams;1…8default3000, unknown/private fields remain rejected, CSV retains current preference. Candidate generation/validation occurs before the transactional preference write, rejecting invalid/overflowing totals atomically. Legacy goal migration helpers read the default before the column exists. Snapshots retain original component grams; vault encryption, privacy, device identity/certificates/capabilities are unchanged. Public release packaging continues to reject profiles, signing credentials, private data and databases.

1.5.2(108) only makes destructive swipe backgrounds explicitly red. Existing confirmation and busy-state protections, draft cleanup/last-step guards, storage, vault/keychain behavior, identity and capabilities are preserved.
