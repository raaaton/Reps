# Sport — jalon10B : preuve portable du chiffrement

## Objectif et autorisation

10A accepté par « ok parfait continue ». Le jalon10 prévoit explicitement prototype et revue indépendante du format portable privé avant intégration. La préparation précédente annonçait preuve synthétique, export/import Fichiers et mauvais mot de passe/fichier modifié avant vraies photos. Livrer cette seule preuve0.11.1(35), sans appeler les repositories d’entraînement/coffre ni le Keychain. Attendre validation physique avant10C (archive complète/restauration atomique).

## Design et limites

Destination temporaire Settings → Import and Export → Encrypted Backup Test. Form natif, SecureField, commandes explicites, labels anglais et VoiceOver ; booleans Verified affichés uniquement après tests CryptoKit/CommonCrypto réellement exécutés. Export/import d’un échantillon constant .sporttest avec mot de passe choisi, jamais de vraies données ; fichier et UI l’annoncent. Le mot de passe est seulement en mémoire, effacé sur départ/inactive ; callbacks annulés/périmés ne republient rien. Pas de clé biométrique copiée, photo en clair, nom privé ou mot de passe dans les logs.

Format de preuve distinct de la future sauvegarde : magic SPORTP01, version1 uint32 big-endian, rounds600000 uint32, salt16bytes, longueur sealed uint32, puis AES-256-GCM combined nonce/ciphertext/tag. Header36bytes authentifié comme AAD, sealed29..65564bytes, fichier borné65600bytes. Paramètres inconnus/longueurs/trailingbytes refusés avant KDF ; pas de travail contrôlé arbitrairement par un fichier. PBKDF2-HMAC-SHA256 natif CommonCrypto600000, salt aléatoire Security, nonce aléatoire CryptoKit. Choix natif sans dépendance nouvelle ; mesurer latence sur appareil avant retenir dans le format final. Ne pas présenter PBKDF2 comme plus fort qu’Argon2, ni le seuil de longueur comme garantie de force.

Preuve native : vecteur RFC7914 §11 (32 premiers bytes), roundtrip exact, deux chiffrements distincts, mauvais mot de passe refusé, tag changé refusé, mauvais AAD refusé. La validation d’un fichier sélectionné ne réussit que si le contenu déchiffré est l’échantillon exact. UI reste disponible pendant KDF hors MainActor ; cancellation entre étapes, pas de garantie d’effacement forensic mémoire.

## Implémentation et vérifications

- [x] Tests hôte framing avant code, refus de versions/KDF/tailles/troncatures/slices ; GREEN réel. Ils ne simulent pas AES/KDF iOS.
- [x] Prototype APIs natif compilé xtool ; Store avec génération/task/cancellation et formulaire/filetype explicitement synthétiques.
- [x] Revue sécurité indépendante, lint, suite hôte, xtool, metadata/inspection.
- [x] Préflight/même identité/certificat, installation USB/postflight.
- [ ] Test iPhone : Run Encryption Checks, exporter avec mot de passe de test, quitter/revenir/importer, mauvais puis bon mot de passe, Annuler Fichiers, interruption pendant travail ; historique/coffre inchangés. Arrêt avant10C.

## Références

[CommonCrypto Apple](https://developer.apple.com/documentation/devicemanagement/creating-and-using-bypass-codes), [CryptoKit AES-GCM AAD](https://developer.apple.com/documentation/cryptokit/aes/gcm/seal(_:using:nonce:authenticating:)), [vecteurs PBKDF2 RFC7914 §11](https://www.rfc-editor.org/rfc/rfc7914.html#section-11), [OWASP paramètre PBKDF2-SHA256](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). L’exemple Apple bypass n’est pas une recommandation de rounds pour cette archive ; ses50000 ne sont pas repris. OWASP est une référence de coût de dérivation, pas une preuve de sûreté complète d’un backup.

## Progression

Documents/flux actuels relus ; aucune édition des règles ou données. Implémentation de la preuve en cours.


## Livraison0.11.1(35) — preuve10B

Huit nouveaux tests de framing/génération présentés avant implémentation : RED réels par types absents, puis GREEN. Suite finale154tests/0échec (5,163s), lintstrict0. Aucun test hôte ne prétend exécuter AES/CommonCrypto/iOS. PrototypeAPI xtool21,68s, intégration7,99s, correctioncallback18,62s, source finale6,65s codes0 ; générationmetadata réelle puis empaquetage1,98s/code0. Six testsmetadata/inspectionunsignedEnglish/app35/widget35/type.sporttest réussis. Revue de sécurité : Important callbacks hors garde corrigé, relu sans autre constat étayé. Dernières gardes de doubletap/effacement et confirmationUTF8 compilées/lintées avant livraison.

Préflight lecture seule0.11.0 code0 : même identité, certificat existant valide>24h et présent Apple. device-run.sh code0, rebuild2,03s, installation/vérification100%. Postflight direct code0 :0.11.1(35) même app/widget, profilsvalides CMSvérifiés et certificat préflight/local inchangé. Nouveau type de document seulement ; mêmes permissions FaceID/camera/Photos add-only, aucun AppGroup/push. Aucun cache/SDK/HelloSport supprimé ni donnée personnelle/photo lue/importée/supprimée par l’agent.

La build est installée avant review. Aller à Settings → Import and Export → Encrypted Backup Test. Exécuter Run Encryption Checks ; tous les contrôles doivent passer réellement. Exporter avec un mot de passe de test ≥12 caractères et confirmation ; quitter/revenir/choisir le fichier, saisir mauvais puis bon mot de passe (sans confirmation pour vérifier). Tester Annuler, retour/suspension pendant opération et réouverture ; aucune donnée Sport ne change. Si iOS met le picker en inactive, la présentation est annulée par sécurité : cycle à vérifier physiquement avant intégration. Fichier.sporttest synthétique uniquement, sauvegarde de vraies données non livrée ; runtimecrypto/nativeFiles attendent le retour utilisateur avant10C.


## Retrait explicite après livraison

Utilisateur : « oublie ça là c nul », demande seulement deux actions Import from Files / Export to Files. Prototype non validé physiquement ; retiré du produit et conservé hors targets dans docs/archive/portable-backup-probe. Ne pas relancer sa recette ni reprendre10C à partir de cette livraison. Voir le correctif0.11.2.
