# Sauvegarde portable complète et coffre optionnel

Date : 2 novembre 2026. Statut : conception à relire avant implémentation.

## Objectif et décisions utilisateur

Conserver les actions Import from Files et Export to Files. Ajouter un toggle natif Include Private Vault dans le parcours d’export. L’utilisateur choisit son mot de passe à chaque export incluant un coffre non vide. Aucun compte, serveur, clé privée à gérer ou mot de passe pour les exports d’entraînement seuls.

Le résultat attendu est une sauvegarde restaurable sur le même iPhone ou un autre, comprenant les données d’entraînement existantes et, sur demande, l’intégralité des données publiées du coffre.

## Règles de l’export

- Toggle désactivé : JSON TrainingArchive actuel, sans mot de passe. Aucun contenu privé, clé ou métadonnée du coffre dans ce fichier.
- Toggle activé, coffre inexistant ou réellement vide : même JSON, sans mot de passe. Une clé/ligne technique initialisée sans contenu ne constitue pas un coffre non vide.
- Toggle activé, coffre non vide : authentification Face ID explicite puis saisie et confirmation du mot de passe ; export d’une seule archive chiffrée, entraînement compris.
- Un coffre contenant des mouvements personnalisés sans média est non vide : leurs noms restent privés et doivent être inclus et chiffrés.
- Une erreur d’accès au coffre ne signifie jamais qu’il est vide. Refuser l’export complet en cas de clé inaccessible, annulation biométrique ou lecture incomplète ; ne jamais basculer silencieusement vers un export partiel.
- Le toggle est initialement désactivé et conservé pendant la présence de l’écran, sans préférence persistante ajoutée implicitement.
- L’interface décrit clairement le contenu et le caractère chiffré ou non avant l’enregistrement dans Files.

## Contenu et cohérence

Réutiliser TrainingArchive pour catalogue, planning, inventaire, objectifs, poids, Skills, historique, états actifs et réglages déjà exportés. Aucun élargissement implicite aux permissions iOS ou aux préférences locales qui ne font pas partie de cette archive.

Le coffre complet contient les originaux photo, miniatures, dates, poses et autres métadonnées, les mouvements personnalisés et liés aux Skills, les vidéos publiées avec leurs miniatures, manifestes et tous les blocs. Conserver les identifiants et associations. Les écritures temporaires/incomplètes ne sont pas du contenu publié ; bloquer l’export complet pendant un import ou une conversion du coffre afin de ne pas omettre un média en cours.

Créer un instantané cohérent des deux dépôts : coordonner les mutations pendant la capture, puis traiter l’instantané sans bloquer le MainActor. Ne pas charger toutes les vidéos ou l’archive complète en mémoire.

## Chiffrement et format

Format binaire portable versionné, distinct du JSON historique. Utiliser CryptoKit AES-256-GCM avec une clé d’archive aléatoire indépendante du Keychain biométrique. Protéger cette clé par une clé dérivée du mot de passe, avec sel aléatoire et paramètres versionnés, bornés et authentifiés. Aucun algorithme cryptographique maison.

Option native proposée pour la dérivation : PBKDF2-HMAC-SHA256 via CommonCrypto, coût minimal de 600000 itérations ; confirmer les recommandations actuelles, les vecteurs connus et la latence réelle iPhone avant de figer le format. Un mot de passe long reste nécessaire ; le coût de dérivation ne compense pas un mot de passe faible. Ne jamais enregistrer le mot de passe ou sa confirmation.

Le format doit authentifier son en-tête, son manifeste, l’identité, le rôle, l’ordre et la longueur des éléments/blocs, et la fin complète de l’archive. Utiliser des nonces uniques par clé ; borner tailles, compteurs, paramètres KDF et arithmétique avant allocation ou travail coûteux. Refuser corruption, troncature, blocs réordonnés/dupliqués, références orphelines, données finales superflues et versions inconnues.

Réencrypter le contenu du coffre vers la clé d’archive en mémoire bornée ; ne pas exporter sa clé Keychain actuelle, même enveloppée. À la restauration, réencrypter pour une clé locale protégée par le Keychain et le jeu biométrique courant de l’iPhone destinataire. Une clé locale existante inaccessible reste un échec fermé, jamais un motif de régénération silencieuse.

Aucun média, miniature ou métadonnée privée en clair dans les fichiers temporaires, journaux ou noms de fichiers. Les instantanés et fichiers de staging sensibles restent chiffrés, protégés et exclus des sauvegardes système. Nettoyage après réussite, annulation, erreur et reprise après interruption. Le fichier final chiffré choisi dans Files est une exportation explicite.

## Import et remplacement

Les anciens JSON/CSV conservent leur fonctionnement : aperçu, confirmation et remplacement de leur périmètre ; ils ne modifient jamais le coffre. L’absence de coffre dans une archive ne demande pas d’effacer le coffre présent.

Une archive complète exige son mot de passe. Vérifier et authentifier tout son contenu en staging chiffré avant de proposer l’aperçu. L’aperçu affiche les quantités entraînement/photos/vidéos/mouvements et les données actuelles qui seront remplacées, uniquement dans une présentation privée couverte. Un coffre existant requiert son authentification avant remplacement ; un coffre neuf requiert une protection biométrique disponible.

L’import complet est une restauration par remplacement, pas une fusion. Confirmation destructive explicite pour entraînement et coffre ; Annuler ne change rien. Conserver la récupération des données remplacées sous protection locale, jamais de copie privée en clair.

Les deux bases SQLite indépendantes et le Keychain imposent un coordinateur de restauration et un journal de reprise durable. Préparer/valider les candidats et la protection locale avant publication. Pendant la publication, interdire lecture/mutation applicative ; après échec ou arrêt forcé, revenir à l’ancien état complet ou terminer le nouvel état complet avant de rouvrir l’app. Ne jamais exposer un entraînement restauré avec un coffre seulement partiellement restauré. Une nouvelle clé préparée ne remplace pas une clé active avant la publication, et une clé encore nécessaire à la récupération ne doit pas être supprimée.

Bloquer l’import si une activité locale est active, comme actuellement. Invalider les aperçus périmés et vérifier que les données n’ont pas changé avant commit. Après restauration, actualiser magasins, activité photo publique et intégrations existantes depuis l’état publié.

## Cycle de vie et interface

Composants natifs SwiftUI, textes anglais selon l’app existante, SecureField pour mot de passe et confirmation, état occupé/progression et annulation. Ne pas ajouter d’écran de preuve synthétique dans le produit.

Le passage en arrière-plan annule le traitement privé, révoque l’accès et efface les références UI/secrets ; aucun résultat périmé ne réapparaît. Distinguer l’inactivité temporaire d’un sélecteur système de l’arrière-plan réel pour ne pas casser Files ou Face ID. Le document final déjà remis à Files est chiffré. Pas de promesse d’effacement forensic de la mémoire ni de blocage des captures iOS.

Mot de passe perdu : archive irrécupérable. Expliquer cette conséquence dans le formulaire d’export.

## Composants concernés

- DataTransfer : choix d’inclusion, formulaire sécurisé, document/fichier par URL pour gros volumes, aperçu privé et détection des formats.
- RepsCore : manifeste/validation bornée, inventaire complet et instantanés du coffre, coordinateur et reprise des restaurations ; conserver TrainingArchive compatible.
- Adaptateurs iOS : crypto portable/KDF, streaming, authentification et préparation des clés locales ; réutiliser les leases et masques existants.
- Documentation : README, SECURITY, DESIGN, TESTING et ExecPlan ; remplacer les anciennes exclusions globales du coffre par les nouvelles règles d’export explicite.

## Vérification requise

Tests comportementaux sur bases temporaires : export sans coffre, coffre vide, mouvements seuls, toutes catégories avec associations ; compatibilité JSON/CSV ; round-trip et conservation exacte ; aperçu périmé ; interruption/rollback/reprise à chaque étape de publication et préparation Keychain ; manque d’espace et annulation.

Preuve native synthétique des APIs CryptoKit/CommonCrypto : vecteur KDF connu, deux exports différents, bon/mauvais mot de passe, altérations de l’en-tête/manifeste/contenu, ordre/troncature/fin, streaming d’une vidéo et révocation. Ne jamais employer ni lire les médias ou bases privés de l’utilisateur pour les vérifications agent.

Revue indépendante de sécurité obligatoire selon AGENTS.md. Lint strict, tests hôte/métadonnées pertinents, xtool dev build, inspection app/widget et livraison sur le même iPhone selon le workflow existant. Aucun push/release demandé ici.

Recette utilisateur : toggle, export JSON sans mot de passe et préservation du coffre lors de son import ; export complet, annulation et mauvais mot de passe ; restauration sur données de test, photos/vidéos/mouvements et associations ; arrière-plan, relance, Face ID, gros volumes, Dynamic Type et VoiceOver. Compilation et tests synthétiques ne prouvent pas cette recette physique.

## Points à résoudre pendant le prototype

Figer framing/limites, coût KDF mesuré et protocole durable exact de publication/reprise avant production. Le choix de fichiers protégés, le comportement Files et les clés préparées doivent être testés avec les véritables APIs iOS sur données synthétiques. Aucune intégration de vraies données privées avant réussite et revue de ces garanties.
