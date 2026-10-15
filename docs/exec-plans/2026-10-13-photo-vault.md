# Jalon 8 — coffre photo natif

## Objectif et autorisation
« Ok continue » après 0.9.4 autorise le prochain jalon du plan accepté : le coffre photo, après le jalon animations avancé. Garder quatre onglets, statistiques publiques séparées des photos privées. Swift/SwiftUI/SwiftPM/xtool Linux, identité Sport stable, aucun backend ou nouvelle dépendance. Les tâches de traduction/SF Symbols restent à la todo du10.

## Décision produit confirmée
PROJECT§10 prévoit un aperçu immédiatement masqué, un verrouillage en quittant le coffre et un délai de background facultatif immédiat/1/5min. docs/SECURITY exige de trancher le conflit historique de l’aperçu avant l’intégration. Réponse explicite de l’utilisateur : « Verrouillage immédiat + aperçu masqué ». Aucun délai 1/5min dans ce jalon. Le masque concerne uniquement le coffre ; pas d’écran de confidentialité général sur Sport. Ne pas promettre le blocage des captures d’écran par iOS.

## Déroulement
1. **Preuve API et appareil, sans vrais médias.** Compiler CryptoKit AES-GCM, LocalAuthentication/Keychain et PhotosPicker contre le SDK enregistré. Ensuite préparer une build de test avec seulement des données synthétiques pour vérifier création/lecture d’une clé biométrique, fermeture/reprise, ciphertext modifié refusé et absence de régénération automatique. Même identité, NSFaceIDUsageDescription explicite ; pas de permission Photos/caméra lors de cette preuve. Réutiliser une clé de prototype distincte de toute future clé réelle. Revue indépendante avant installation. Attendre confirmation physique de cette preuve avant de permettre des vrais imports.
2. **Stockage et galerie.** SQLite source de vérité, index du coffre indépendant des tables d’entraînement ; fichiers originaux/miniatures chiffrés et associés à des IDs aléatoires. Clé AES256 dans Keychain, protection whenPasscodeSetThisDeviceOnly + biometryCurrentSet, sans fallback code. Pas de synchronisation ni export de clé. État de coffre existant distingué d’une première création : clé inaccessible/absente avec données existantes => erreur fermée, aucun remplacement silencieux. Versionner le format, lier cryptographiquement contenu/ID/rôle, et gérer écritures/transactions/orphelins sans supprimer silencieusement des données existantes.
3. **Parcours natifs.** Progression→Photos privées→déverrouillage explicite, galerie datée et détail, import choisi par PhotosPicker, caméra à la demande, suppression confirmée, export vers Photos après confirmation/add-only. Les originaux Photos restent indépendants. Réglages du coffre : disponibilité biométrique, comportement accepté, suppression globale/reset explicite. Une sortie ou un verrouillage invalide l’authentification et les opérations asynchrones anciennes ; aucune publication de données déchiffrées par un callback périmé. Contrôler taille/pixels/orientation et fichiers temporaires ; aucun média/clé/chemin privé dans les logs.
4. **Recette et livraison.** Tests utiles pour états/concurrence, corruption/chiffrement natif sur iPhone, transactions/rollback, refus et annulation, import interrompu et relance. Lint et xtool réels, metadata/empaquetage et inspection app/widget. Revue sécurité indépendante, préflight identité/certificat/capacités, USB, postflight. Validation physique FaceID, permissions, aperçu multitâche, verrouillage pendant import/export et erreurs avant utilisation de médias réels. Ne jamais modifier les biométries de l’utilisateur pour un test sans accord.

## Limites et décisions techniques
- Les changements de scène liés au prompt Face ID ne doivent pas être confondus avec une sortie réelle : masque au passage inactive, verrouillage selon background/route acceptés, gestion explicite de l’authentification en cours.
- Les exports CSV/JSON entraînement existants continuent d’exclure les photos et clés. Archive privée portable appartient au jalon10, après validation du coffre.
- Compiler les APIs prouve leur disponibilité, pas leur exécution iOS, la sécurité des fichiers ou le rendu. Aucune donnée réelle ne sert à tester.
- Références primaires : Apple Accessing Keychain Items with Face ID or Touch ID ; Security biometryCurrentSet / kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly ; CryptoKit AES.GCM ; Bringing Photos picker to your SwiftUI app ; HIG Privacy.

## Progression réelle
- Plan global, exigences coffre/crypto/aperçu et navigation existante relus. SDK Darwin existant confirmé,8,3Go disponibles ; aucune installation de toolchain ou suppression de cache.
- Prototype de compilation uniquement, jamais appelé, ajouté temporairement au target Sport puis retiré. xtool dev build code0,8,90s. CryptoKit AES.GCM, ACL biométrique Keychain, LAContext async et loadTransferable(Data.self) compilent et lient avec le SDK actuel. Source conservée dans docs/prototypes/VaultAPICompileProbe.swift.
- Aucun appel FaceID, SecItemAdd/CopyMatching, chiffrement runtime ou accès Photos exécuté ; aucune clé/photo créée, aucune signature/provisioning/installation effectuée. L’iPhone reste0.9.4.
- Choix confirmé ; preuve physique en cours de préparation, intégration des vrais médias non commencée. Prototype retiré des Sources et rebuild normal de la version0.9.4 réussi ; inspection unsigned inchangée.


## Phase8A — progression

Gate de session : deux tests comportementaux écrits avant correction,5assertions RED (callbacks après lock/ancienne tentative), puis GREEN suite133tests/0échec en5,423s. Ces tests portent uniquement sur la machine à états, pas FaceID ou CryptoKit.

Prototype natif compilé21,11s,code0. Avertissement SDK sur kSecUseAuthenticationUIFail déprécié : remplacé par LAContext.interactionNotAllowed après préauth biométrique, suivant le diagnostic du SDK ; build final en cours. ZStack stable porte le lifecycle ; aucun Group dont le remplacement du contenu lors du prompt pourrait déclencher le verrouillage. Strict lint en cours de finalisation, revue sécurité indépendante demandée.

FaceID/Keychain/chiffrement runtime et aperçu ne sont pas encore validés. Photos privées reste une preuve synthétique clairement identifiée ; elle n’autorise aucun import et ne constitue pas encore un coffre de production.

Revue sécurité indépendante finale :0Critical/Important/Minor ; aucune exécution native revendiquée par la revue. Build corrigé6,43s code0, lintstrict code0. Préflightlectureseule0.9.4 identité exacte/certificat existant valide>24h/présentApple code0. Seule nouvelle déclaration plist autorisée :NSFaceIDUsageDescription ; contrôle unsigned/postflight exigent exactement celle-ci et aucune permission dans le widget. Génération/empaquetage puis installation en cours.


## Phase8A livrée — 0.9.5 (27)

133tests hôte/0échec (5,423s), lintstrict code0. API compile-only8,90s puis retrait/rebuild16,24s ; prototype natif21,11s, correction SDK/lifecycle6,43s, générationmetadata réelle et empaquetage2,22s codes0. Six tests metadata et inspection unsigned réussis ; une seule permission plist FaceID autorisée, aucune dans le widget. Revue sécurité indépendante unique :0Critical/Important/Minor dans le périmètre synthétique.

Préflight0.9.4 code0 : même identité exacte, certificat existant valide>24h et présentApple. device-run.sh code0, installation/vérification100%. Postflight direct0.9.5 code0 : même app/widget, profilsvalides CMSvérifiés, certificatpréflight/local inchangés ; aucune permission Photos/caméra, AppGroup ou push. Les scripts de contrôle temporaires précédents n’étaient plus disponibles ; contrôles recréés explicitement, aucun diagnostic ou provisioning ne les a contournés.

Coffre de production et import réels non intégrés. Chiffrement/Keychain/FaceID natifs s’exécutent seulement au tap utilisateur sur la preuve ; aucun succès runtime de ces API n’est présumé. Recette : FaceID initial/clés Créée puis Retrouvée après lock/relance, chiffrement/lecture Vérifiés et ciphertext modifié Refusé, annulation biométrique, sortie/background et aperçu masqué. Ne pas modifier les biométries personnelles. Arrêt avant8B jusqu’à confirmation physique.


## Phase8B — version0.10.0 demandée

L’utilisateur confirme la preuve8A suriPhone (« c validé ») et demande explicitement0.10 pour l’ajout du coffre complet. Prochaine livraison0.10.0(28). Galerie datée/importPhotos/caméra/exportconfirmé/suppression/date/Settings/reset et verrouillage immédiat constituent le périmètre accepté.

Ruling : originaux/miniatures/métadonnées stockés comme BLOBs AES-GCM dans une base SQLite dédiée à l’intérieur d’un répertoire protégé, plutôt que fichiers séparés + index. Cela garde la source de vérité SQLite et rend chaque insertion/suppression/date atomique sans transaction distribuée fichier/base. Dates et types sont eux-mêmes chiffrés ; seul l’ID aléatoire est en clair. Clé de production distincte du namespace de la preuve. ExportCSVJSON entraîne seulement les tables d’entraînement, sans média/clé/métadonnée du coffre. Répertoire exclu des sauvegardes système car clé ThisDeviceOnly ; archiveportable privée différée au10.

Imports FileRepresentation : APIApple documente une copie du fournisseur lorsque shouldAttemptToOpenInPlace=false et un fichier garanti seulement dans la closure. Lire taille avant allocation et bytes dans cette closure, aucun fichier en clair créé par Sport ; copie gérée par le système. Caméra système native UIImagePickerController, photo uniquement, aucune sauvegarde Photos automatique ; nettoyer tout URL temporaire camera reçu qui appartient à tmp deSport, sans toucher un original externe. ImageIO valide type/pixels et génère une miniature500px et aperçu2400px en mémoire. Limites24Mo/64Mpx/1000photos ; cacheminatures borné.

Lease révocable vérifié avant/après lectures/écritures et publications ; aucun callback d’une ancienne sélection/caméra ne peut entrer dans une nouvelle session. Un commit chiffré déjà commencé ou un exportPhotos déjà accepté peut finir pendant le verrouillage, mais aucune image ni résultat ne sont republiés dans une session périmée. Les exports hors coffre sont explicites et confirmés ; autorisationPhotos add-only seulement alors.

Développement : SQLiteBLOB binaire ajouté,3tests comportementaux transactions/leases/rollback/reset passent. Premier run compilait mal l’initactor capturantself, corrigé par base locale construite avant affectation. Pas de RED comportemental prétendu pour ce run. Nouvelle galerie et store en compilationAPI ; revue sécurité finale et recette réelle obligatoires avant conclusion.


## Coffre complet — 0.10.0 (28), installé le 13 octobre

Preuve8A0.9.5 validée explicitement par l’utilisateur ; version0.10 demandée pour la galerie réelle. 137 tests hôte/0échec (5,318s), lint strict code0. Tests : BLOBs binaires, reprise, leases révoqués/étrangers, doublons/rollback, reset et limites avant allocation ; ils n’exécutent pas CryptoKit/FaceID/SwiftUI. Le test des données surdimensionnées a d’abord échoué avec deux assertions, puis passé après les gardes SQL. Un dernier passage a révélé quatre échecs : PRAGMA secure_delete renvoie une ligne, corrigé en query avec vérification de sa valeur ; toute la suite repassée ensuite.

xtool compile réellement les APIs natives ; build complet12,10s, correction finale3,74s puis metadata depuis constvalues réels et empaquetage2,20s, codes0. Six tests metadata et inspection du bundle0.10.0/28 réussis. Revue de sécurité indépendante : aucun constat Critical/Important/Minor ; statique, sans exécution native. Gardes supplémentaires avant déchiffrement/pipeline ImageIO et révocation de session vérifiées à la compilation finale.

Préflight lecture seule0.9.5 code0 : même identité effective et certificat existant valide au-delà de24h/présent chez Apple. device-run.sh code0, installation et vérification100%. Postflight direct code0 :0.10.0(28), même app/widget, profils valides CMS vérifiés, certificat préflight/local inchangés. Seules déclarations sensibles : FaceID, caméra et Photos add-only ; aucune permission générale Photos, AppGroup ou push. Aucun cache, SDK ou source HelloSport supprimé ; aucun média personnel importé par l’agent.

Recette physique obligatoire avant le jalon10 : utiliser d’abord une photo non privée, puis FaceID/annulation, import/date/zoom/export confirmé, caméra/refus, suppression/Annuler, relance, aperçu masqué depuis galerie/détail/feuilles/caméra et verrouillage pendant une opération. Une opération Photos déjà acceptée ou un commit chiffré en cours peut finir après lock, mais aucun résultat privé n’est republié. Vérifier aussi historique et Pause/Reprendre des Live Activities. Aucun succès de ces parcours ne se déduit du build ; attendre le retour utilisateur.
