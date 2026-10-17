# Sport — jalons natifs

Référence : [plan global](../PLAN-SPORT-NATIF.md). Chaque jalon exige compilation xtool, contrôles applicables, installation USB autorisée et **confirmation utilisateur sur iPhone** avant le suivant.

| Jalon | Périmètre | État |
| --- | --- | --- |
| 1 | SwiftUI, quatre onglets, navigation Réglages, build local | Validé sur iPhone par l’utilisateur |
| 2 | SQLite, planning et réglages métier | Validé sur iPhone en 0.2.1 par « parfait » |
| 3 | Séance complète, Feeling, repos persistant ; retouches UX et ajout/suppression historique avancés sur demande | Validé sur iPhone en 0.3.4 par « ok parfait on continue » ; 45 tests/lint/revue/contrôle bundle réussis ; identité/profil/certificat contrôlés |
| 4 | Prototype WidgetKit/ActivityKit/App Intents et signature | Confirmé en 0.4.3 par « parfait, on continue ». VoiceOver et scénarios de fin non spécifiquement rapportés |
| 5 | Filtres/édition historique existante, lest et progression | Confirmé sur iPhone en 0.5.0 par « continue au prochain jalon ». 65 tests hôte + 6 metadata, lint, revue indépendante et build réel réussis ; jalon 6 autorisé |
| 6 | Rappels et présentation finale Live Activities | 0.6.1 (15) installée et prochain jalon autorisé explicitement ; scénarios iOS individuels non rapportés restent à vérifier : 75 tests hôte + 6 metadata, lint, revue indépendante et builds réussis ; identité/profils/certificat contrôlés |
| 7 | Progression guidée et visualisation : objectifs persistés, Feeling 0,5/<8, saisie simplifiée, sac, correction en séance, graphiques/grille et bilan avec durée totale | Installé en 0.7.0 (16) ;96tests hôte+6metadata, lint/build/revue et postflight réussis ; même identité/certificat ; attente de confirmation iPhone avant jalon 8 |
| 8 | Coffre photo sécurisé (ancien jalon 7) | Coffre0.10.0 confirmé fonctionnel sur iPhone. Retouche0.10.1 validée ;0.10.5(33) installée : Play blanc/Séances/correctif de crash de listes après suppression ;146tests+6metadata/lint/xtool/revue/postflight réussis. Retour utilisateur « ok continue » après0.10.5 : poursuite autorisée ; pas de compte rendu individuel des gestes/zoom |
| 9 | Animations et haptics cohérents : transitions utiles, retours système, Reduce Motion, désactivation des retours ajoutés | Avancé avant le coffre sur demande du 13 octobre ; 0.9.0 (22) installée, 129 tests + 6 metadata/lint/xtool/revue/postflight réussis ; attente de recette iPhone |
| 10 | Finition, transferts et audit global ; sauvegarde privée retirée sur demande | Anglais/SF Symbols et transferts simplifiés acceptés. Audit/corrections0.11.3(37) installés :152tests/6metadata/lint/xtool/revue/pré-postflight réussis ; recette finale iPhone attendue. Sauvegarde privée/prototype abandonnés, aucune poursuite prévue |
| 11 | Échauffement unique basé sur le premier exercice, demi/full repos, étirement chronométré et conservation séparée des résultats | 0.12.0 (48) installée ; 169 tests + 6 metadata/lint/revue/xtool/pré-postflight réussis ; validation iPhone attendue |

Design Apple natif, accessibilité, hors-ligne et conservation des données sont transversaux. Les anciens plans Expo ne sont pas des preuves de livraison Swift.

## Todo — finition de l’interface

- [x] Passer toute l’app en anglais : écrans, erreurs, confirmations, notifications, Live Activities et libellés VoiceOver. Conserver les contenus personnels et les formats de données.
- [x] Remplacer les actions textuelles comme « Enregistrer » / « Modifier » par des SF Symbols adaptés, avec noms accessibles en anglais. Vérifier leur compréhension et leurs zones tactiles sur iPhone ; garder du texte si une action devient ambiguë.

Les deux demandes ci-dessus, rattachées au jalon 10, sont implémentées en0.11.0 et acceptées par l’utilisateur.

- [x] Couleur d’accent : réglage sept choix livré en0.11.4 puis retiré sur demande en0.11.5 ; Icy Cyan4DD9E8 fixe désormais. Recette physique des retouches attendue.
- [x] Créer et intégrer une icône personnalisée pour Sport : haltère cyan/argent en couches, rendu Kavi conservé. 0.11.11 implémentée ; validation visuelle iPhone attendue.
- [x] Échauffement automatique issu du premier exercice et étirement chronométré : 0.12.0 implémentée, recette iPhone attendue. La demande précise du 15 octobre remplace le choix initial d’un échauffement libre/différent.

Réorganisation demandée le12 octobre : Progression passe avant le coffre pour s’appuyer sur les données d’entraînement déjà livrées ; Animations/haptics vient après les nouveaux écrans pour harmoniser les transitions sur des flux stabilisés. Les bonnes pratiques natives et l’accessibilité restent obligatoires dès chaque jalon. Le détail des périmètres, exclusions et recettes est dans [le plan global](../PLAN-SPORT-NATIF.md).

Le [brouillon](ideas/2026-10-12-progression-visualization-backup.md) conserve la discussion et les idées rejetées/non confirmées. Maintien/reprise reste potentiel ; notes techniques, versions courtes et qualificatifs Feeling sont exclus. L’ajout des jalons est une décision de planification, suivie de l’autorisation explicite d’implémenter le7 ; cette autorisation ne prouve pas chaque scénario iOS du6. Les numéros des comptes rendus historiques restent ceux de leur date.

Extension du7 demandée ensuite : import/export entraînement avancé avant coffre/animations, avec CSVfictif117séances/752séries. Sport0.7.1(17) installé ;107tests+6metadata/lint/build/inspectionunsigned/postflight réussis, revue statique indépendante et correctifs couverts. Blocage temporaire de revue levé sansbypass. RecetteiPhone import/export attendue. Jalon7 toujours en recetteiPhone,8/9 inchangés. Au10reste archive privée chiffrée du futurcoffre/finitions ; CSVn’inclutjamaisphotos.

Correctioncourbes du7 :0.7.2(18) installée,mêmeidentité etcertificat/postflightCMSvalides.114tests+6metadata/lint/build/inspection etrevueindépendante, courseRéessayercorrigée ; recettecourbesiPhoneattendue. Import0.7.1jugébonparutilisateur, sans validationglobale de chaquepermissionscénario. Courbesparsessions, contextehistoriquerest/sets/targets, aucune forceestimée.

Retouchecourbes7 :0.7.3(19)installée,118tests+6metadata/lint/build/revue/inspection/postflight réussis. Bulle date/valeuraupoint,Volume de lest rép×kg parséance (chargesmixtesincluses),tempsdetravailtotal statique touslestsetfiltre. Mêmecertificat/identité,aucunDB/formattransfert/permission changé. Recettephysique enattente,aucun8/9commencé. [ExecPlan](exec-plans/2026-10-12-chart-callouts-volume.md).

0.7.4(20) installée : cumul du volume sur la période choisie, remplacement complet de l’historique CSV explicitement confirmé (réglages conservés).124tests+6metadata/lint/build/revue/postflight réussis, même app/certificat. Conservation de la récupération lors de CSV réordonné corrigée et testée ; texte de l’état vide Volume différé. Recette physique en attente avant8/9. [ExecPlan](exec-plans/2026-10-12-cumulative-volume-csv-replacement.md).

0.7.5(21)installée : résuméVolume/Répétitions totalise la période (Reps dansfiltresaffichés), courbe/bulle/détail parséance ; ancienlibellé d’étatvide corrigé.126tests+6metadata/lint/xtool/revue/postflight réussis,mêmeapp/certificat. Utilisateur avait confirmé0.7.4 etreprécisé la présentation ; recette desretouchesattendueavant8/9. [ExecPlan](exec-plans/2026-10-12-period-summary-session-curves.md).


13 octobre : [animations/haptics](exec-plans/2026-10-13-motion-haptics.md) livrés en 0.9.0 (22), avant le coffre à la demande explicite de l’utilisateur. Même identité/certificat ; préférence locale, aucun schéma ni format d’export changé. Revue : erreur de bilan et course de feedback corrigées. Attendre validation physique ; coffre non commencé.


Correction 0.9.1 (13 octobre) : transitions des filtres reprises sans animation globale de List. Bref fondu du graphique seul (0,15 s), axes/valeurs instantanés, identité par requête ; Reduce Motion/VoiceOver respectés. Données et haptics conservés. Recette iPhone après installation ; voir [ExecPlan](exec-plans/2026-10-13-chart-filter-motion.md).


### Chargement stable des graphiques — 0.9.2

Correction après retour iPhone : conserver les résultats et leur mesure/période pendant toute actualisation. Le bloc au-dessus de Prochaine séance ne disparaît plus pendant la requête ; les nouveaux résultats/libellés/contexte/sélection sont publiés ensemble. Indicateur en overlay sans ligne supplémentaire ; erreurs gardent le dernier résultat et proposent Réessayer. Réponses périmées/annulées refusées. Le premier chargement et les véritables états vides restent explicites. Calculs, données, haptics et bref fondu conservés ; rendu à confirmer après installation.


### Répétitions compactes — 0.9.3

Tous les tableaux d’objectifs utilisent la même notation : 10·10·10·10 devient4×10, 10·10·9·9 devient2×10 2×9. Seules les valeurs identiques adjacentes sont regroupées pour préserver l’ordre. Objectifs configurés :4×10 ou4×8–12. La vue partagée couvre Aujourd’hui, préparation, séance, propositions/prochaine séance et bilan ; détail et saisie par série restent accessibles, sans fusionner charges/compositions. VoiceOver explicite les groupes d’objectifs. Aucun stockage/format/algorithme de progression modifié. Rendu à confirmer sur iPhone.


0.9.4 (26) installée : accès direct au même écran Repos depuis Entre les séries sur Aujourd’hui ;131tests et contrôles build/metadata/lint/USB/postflight réussis. Retouche de navigation, aucune anticipation du coffre ou traduction/icônes de la todo. Recette iPhone attendue.


13 octobre — jalon8 autorisé par « ok continue ». Préparation/prototype compilé CryptoKit/Keychain/FaceID/PhotosPicker (xtool8,90s), aucun runtime ou import réel. Choix de verrouillage/aperçu encore requis avant intégration ; iPhone0.9.4 inchangé. [ExecPlan coffre](exec-plans/2026-10-13-photo-vault.md).


Jalon8 phaseA livré : [preuve native du coffre](exec-plans/2026-10-13-photo-vault.md). Choix utilisateur immédiat/aperçu masqué retenu, aucune vraie photo importable. Keychain/chiffrement/FaceID/aperçu runtime à confirmer par la recette avant8B. Même app et certificat vérifiés ; le10/traduction restent planifiés.


0.10.0(28) : coffre complet installé à la demande après validation8A. Même identité/certificat/profils contrôlés ; données chiffrées dans SQLite indépendant, verrouillage immédiat et aperçu masqué. CSV/JSON entraînement excluent toujours photos/clé ; archive privée portable, traduction et finition restent au10. Attendre le retour iPhone sur les nouveaux parcours. [ExecPlan](exec-plans/2026-10-13-photo-vault.md).


Retouche0.10.1 après validation0.10.0 : [piles et objectifs](exec-plans/2026-10-13-vault-comparison-goal-clarity.md). Périmètre explicitement approuvé ; aucune anticipation de sauvegarde privée/traduction du10. Installation USB effectuée, retour iPhone requis pour les nouvelles vues.


0.10.1 confirmé « parfait ».0.10.2 installé : [comparaison agrandie](exec-plans/2026-10-13-comparison-photo-zoom.md), périmètre demandé directement ; gestes et protection de la nouvelle surface à valider sur iPhone avant10.


0.10.3 : [appui long et zoom ancré](exec-plans/2026-10-13-vault-long-press-pinch-anchor.md), demandes ajoutées pendant la recette0.10.2. Installation réalisée, confirmation physique encore requise. Aucun jalon10 commencé.


0.10.4 : [archives et zoom commun](exec-plans/2026-10-13-archives-attendance-zoom.md). L’utilisateur signale que0.10.3 zoomait encore au coin dans les deux vues ; pas de validation du zoom revendiquée. Purge des archives avec anciennes performances explicitement confirmée, retour iPhone attendu.


Retouche0.10.5(33) installée : Play blanc, Séances au pluriel, contournement ciblé de l’assertion List observée dans deux rapports iPhone.146tests/6metadata/lint/xtool/revue et pré/postflight même identité/certificat réussis. Aucun changement des règles d’archivage/purge ni de sécurité ; confirmation de suppression sans crash encore attendue. [ExecPlan](exec-plans/2026-10-13-exercise-deletion-list-crash.md).


13 octobre, après0.10.5 : retour utilisateur « ok continue ». Poursuite vers le jalon10 autorisée ; aucun scénario individuel de suppression/zoom/VoiceOver n’est déclaré testé à partir de cette réponse. Cadrage de la sauvegarde portable du coffre et ordre sauvegarde/finition en cours, avant nouveau code.


Jalon10A choisi par l’utilisateur : anglais et SF Symbols avant sauvegarde.0.11.0(34) installée,146tests/6metadata/lint/xtool/revue et pré/postflight réussis, mêmes identité/certificat. Todo anglais/commandes implémentée ; validation physique/accessibilité encore attendue. Sauvegarde complète non commencée. [ExecPlan](exec-plans/2026-10-13-english-symbol-actions.md).


10A accepté « ok parfait continue ».10B[preuve portable](exec-plans/2026-10-13-portable-backup-probe.md) installée0.11.1(35) sous mêmes app/certificat ; tests d’un échantillon constant uniquement.154tests/6metadata/lint/xtool/revue après correctioncallback et postflight réussis. Testscryptographiques/Files réels à effectuer sur iPhone ; vraie sauvegarde/restauration du coffre/historique non livrée,10C attend cette validation.


Après0.11.1 l’utilisateur refuse la preuve et exige uniquement Import from Files / Export to Files.0.11.2(36) installée : choixformats/copieavantimport dans Export, démo/proof retirées du produit et type.sporttest absent.146tests/6metadata/lint/xtool/pré-postflight réussis, mêmes app/certificat. Ne plus demander l’anciennepreuve ; pas de reprise10C sans nouveau périmètre autorisé. [ExecPlan](exec-plans/2026-10-13-simple-file-transfers.md).


Après0.11.2, utilisateur : « parfait. on a fini ? ». Présentation simplifiée acceptée. Fonctions principales livrées ; planinitial non entièrement clos : sauvegarde/restauration privée complète reste différée et auditfinal global accessibilité/performance/régressions non exécuté. Aucune intégration optionnelle ni reprise de prototype implicitement autorisée par cette question.

13 octobre — utilisateur : « oublie la sauvegarde truc et fait l’audit global ». Cette instruction remplace les mentions précédentes de sauvegarde différée. [Audit global](audits/2026-10-13-global-audit.md) et [ExecPlan](exec-plans/2026-10-13-global-audit.md) : corrections installées, validation physique finale encore attendue ; aucun autre chantier obligatoire.


Couleur d'accent demandée après l'audit : [ExecPlan0.11.4](exec-plans/2026-10-13-accent-color.md).155tests/6metadata/lint/xtool/revue et pré/postflight réussis, installation USB mêmeapp/certificat. Sept choix ; #46D7A7 nommé Mint plutôt que jaune pâle, puisqu'il s'agit d'un vert. Rendu clair/sombre/contraste augmenté, choix après relance et Live Activities déjà présentes à vérifier sur iPhone. Icône toujours à faire ; aucune reprise de sauvegarde.

0.11.5(39) installée : Icy Cyan seul/réglage retiré, filtre Workout Conditions supprimé dans tous les graphiques, totalrépétitions sur tous les points affichés, Pause SF blanche demandée dans app/Live Activities.155tests/6metadata/lint/xtool/revue/pré-postflight réussis, mêmes app/certificat. Période/lest et métadonnées historiques conservés, aucun nouveau périmètre. [ExecPlan](exec-plans/2026-10-13-fixed-cyan-unified-charts.md), recette iPhone attendue ; icône à faire, sauvegarde abandonnée.


0.11.6(40) installée : rougesSF+titresdestructifs, Cancelneutreblancsombre/noirclair après clarification, annotationgraphaupremierplan, Repetitions toutescharges sansLoadtoCompare.156tests/6metadata/lint/xtool/revue et pré/postflight réussis, mêmeapp/certificat. Recettephysique encoreattendue, notammentalertecoffre→background. [ExecPlan](exec-plans/2026-10-13-destructive-alerts-chart-overlay.md). Pas de nouvel ajout prévu ; icône en todo, sauvegarde abandonnée.


0.11.7(41) : retour utilisateur sur le point devant la bulle, correction par chartOverlay externe aux marques et Layout en une passe.17testsgraphiques/6metadata/lint/xtool/pré-postflight réussis, mêmeapp/certificat. Rendu/drag aux extrémités et grand texte à confirmer après installation ; [ExecPlan](exec-plans/2026-10-13-chart-callout-front.md).


15 octobre — retouche 0.11.8 (42) installée : symboles des actions Liquid Glass blancs, sauf coches ; menus destructifs rouges conservés. Lint, 6 metadata, xtool et pré/postflight réussis. Retour physique attendu. Échauffement configurable ajouté à la todo, icône existante conservée. [Compte rendu](exec-plans/2026-10-15-white-glass-symbols.md).

15 octobre — 0.11.8 installée mais correction blanche inefficace selon retour iPhone. 0.11.9 (43) remplace foregroundStyle par tint au niveau des contrôles natifs ; compilée/installée et contrôlée, même identité/certificat. Confirmation visuelle attendue. [Compte rendu](exec-plans/2026-10-15-native-toolbar-tint.md).

15 octobre — 0.11.9 blanche validée par « parfait ». Prototype 0.11.10 (44) installé avec l’icône Kavi exacte en couches pour comparer le rendu natif Linux sur iPhone ; lint/6metadata/xtool/inspection/pré-postflight réussis. Aucune icône finale Sport décidée, todo maintenue. [Compte rendu](exec-plans/2026-10-15-kavi-icon-probe.md).

15 octobre — icône Sport 0.11.11 (45) installée : Phosphor barbell-fill adapté, deux couches cyan/argent et verre Kavi, licence embarquée. actool/lint/6metadata/xtool/inspection et pré/postflight réussis, même app/certificat. Création terminée, validation visuelle iPhone attendue. [Compte rendu](exec-plans/2026-10-15-sport-app-icon.md).

15 octobre — 0.11.12 (46) installée : liserés fins et trois plans superposés de l’icône ; silhouette 0.11.11 appréciée mais relief à améliorer selon retour utilisateur. Lint/6metadata/actool/xtool/inspection/USB/postflight réussis, même app/certificat. Confirmation physique des retouches attendue. [Compte rendu](exec-plans/2026-10-15-icon-glass-overlap.md).

15 octobre — 0.11.13 (47) installée : haltère à 112,5 %, centré, matériaux conservés. actool/lint/6metadata/xtool/inspection/USB/postflight réussis ; même identité/certificat. Retour visuel attendu.

0.12.0 (48) — nouvel enchaînement autorisé le 15 octobre : un échauffement dérivé du premier exercice, demi/full repos puis travail, un étirement chronométré avant le bilan. Répétitions et durée/libre selon règles utilisateur, conservation SQLite/history/CSV sans pollution des performances. Implémentation et 169tests/lint/6metadata/revue effectués ; livraison et validation physique à consigner dans [ExecPlan](exec-plans/2026-10-15-warmups-stretches.md).

Livraison 0.12.0 confirmée par lecture appareil : version48, même identité/certificat, profils valides. Attendre le retour iPhone sur le nouveau déroulement ; les contrôles automatiques ne le valident pas.


1.0.0 (49) — distribution native publique préparée le 15 octobre : README anglais, historique Git Expo conservé, build Release local et IPA non signée inspectée, SHA256 fourni. 169tests/6metadata/lint/xtool réussis. Pas de fonctionnalité manquante dans le périmètre demandé ; le dernier enchaînement échauffement/étirement et les recettes manuelles d’accessibilité restent à confirmer sur iPhone. Sauvegarde portable abandonnée. Voir [publication 1.0.0](exec-plans/2026-10-15-version-one-release.md) et [limites des tests](TESTING.md).

1.0.0 (49) installée par le workflow USB existant ; contrôle après installation réussi, mêmes identité/certificat et profils app/widget valides. La version publique est une IPA Release non signée construite séparément, destinée à être re-signée par chaque destinataire.

Publication 1.0.0 terminée : [Release publique](https://github.com/raaaton/Sport/releases/tag/v1.0.0), IPA locale Release + SHA256. Téléchargement depuis GitHub, comparaison octet pour octet et nouvelle inspection réussis. Ancien historique Git conservé, aucun force-push.


17 octobre — 1.0.1 (50), correctif local autorisé après utilisation : repos entre exercices, objectifs alignés sur résultats réels, proposition de baisse du lest au-dessus de 9, arrêt exact de l’étirement et son de fin au premier plan, Pause/coches noirs sur cyan, Customize sans croix, graphiques chronométrés toutes charges. 182 tests métier et 6 metadata passent ; lint et build xtool réels réussis. Installation/contrôles finaux et retour iPhone à consigner dans [ExecPlan](exec-plans/2026-10-17-workout-refinements.md). Aucun push ni release avant le retour utilisateur.

1.0.1 (50) installée et contrôlée après déploiement : même identité/certificat, profils app/widget valides et capacités inchangées. Métadonnées et inspection finale réussies. Attente du retour iPhone ; aucune publication GitHub.

Retour utilisateur « cb push » : correctif installé 1.0.1 accepté et publication GitHub autorisée. Construction locale de l’IPA Release et vérifications avant publication ; seule l’IPA sera jointe, sans fichier checksum. Ce retour global ne constitue pas un relevé individuel de chaque recette d’accessibilité ou d’exécution en arrière-plan.

1.0.1 publiée après accord utilisateur : [Release](https://github.com/raaaton/Sport/releases/tag/v1.0.1), IPA construite localement, seul asset téléchargeable. Téléchargement distant identique au fichier local et inspection réussie.

18 octobre — 1.0.2 (51), retouche Lock Screen : teinte de fond explicitement transparente via API ActivityKit/SwiftUI native. Lint, build xtool réel, génération/intégration metadata, inspection et 6 tests metadata réussis ; contrôles appareil et retour visuel à consigner dans [ExecPlan](exec-plans/2026-10-18-lockscreen-transparency.md). Pas de publication GitHub avant retour.

Installation1.0.2 bloquée au provisioning Apple :409 ENTITY_ERROR, « There are no current IOS devices on this team matching the provided device IDs. » Arrêt avant toute réparation de signature/enregistrement ; build locale prête mais non installée, retour visuel impossible à ce stade.

18 octobre — export direct ajouté à la build locale1.0.2 : un fichier JSON avec entraînement/réglages actuels, sans choix CSV/JSON/ancienne copie. Photos exclues explicitement, import CSV/JSON inchangé. 14 tests de transfert, lint et build xtool réussis ; contrôle metadata/bundle en cours. Installation toujours bloquée par le refus de provisioning Apple409 signalé précédemment ; aucune réparation ni nouvelle tentative de signature. [ExecPlan](exec-plans/2026-10-18-direct-training-export.md).

Export direct : intégration metadata, inspection du bundle1.0.2(51) et 6 tests metadata finaux réussis. Prêt localement ; non installé après le précédent blocage de provisioning, aucun push.

Blocage409 résolu après autorisation explicite : enregistrement du seul iPhone connecté rétabli auprès d’Apple (201). Déploiement USB standard1.0.2(51) réussi, postflight même identité/certificat exact/profils app-widget valides et capacités inchangées. Les deux retouches (Live Activity transparente et export JSON direct) sont installées ; attente du retour utilisateur avant GitHub. [Diagnostic](exec-plans/2026-10-18-device-registration-repair.md).

18 octobre — 1.0.3(52) : première proposition de lest après travail complet à vide avec Feeling<8, objectif aux reps minimales ; points des jours programmés manqués après première séance terminée, suppression Partial (planning courant, aujourd’hui exclu) ; confirmation native avec teinte neutre isolée. 188 tests métier et6 metadata passent, lint/build/inspection réels réussis. Déploiement USB en cours, validation iPhone requise avant GitHub. [ExecPlan](exec-plans/2026-10-18-attendance-confirmations.md).

Livraison1.0.3(52) : installation/vérification100%, postflight identité et certificat exact inchangés/profils valides. Retour iPhone attendu ; aucun push/release.

Retouche1.0.3(53) : emojis🏋️‍♂️/📸 dans les titres des rappels entraînement/photo, aucun changement des horaires ou permissions. 9 tests de rappels,6 metadata, lint/build/inspection réussis ; installation USB en cours, pas de push.

Retouche1.0.3(54) : grille depuis la semaine de première séance terminée, compteur de semaines correspondant, texte explicatif supprimé. Emojis53 conservés.189tests métier et6metadata passent ; lint, build xtool et inspection réels réussis. Installation USB en cours.

Livraison54 terminée : script code0, installation/vérification100%, postflight confirme version/identités/certificat exact/profils valides. En attente du retour iPhone ; aucun push.

Retouches55–56 : cases neutres décoratives à gauche pour remplir la largeur, compteur réel conservé puis déplacé en troisième position de la légende. Lint/build xtool/inspection/6testsmetadata réussis,55installée et56en cours. Aucun changement métier, dernier full run189tests en54 ; aucun push.

Déploiement56 bloqué par usbmuxd en échec (iPhone USB visible, inventaire apps indisponible). sudo-n requiert mot de passe local ; redémarrage manuel demandé.55confirmée installée ;56ne peut pas encore être déclarée installée. Aucun certificat modifié pour contourner ce problème.

Après redémarrage usbmuxd confirmé,56installée et postflight valide. Retouche57 ajoute Other aux poses photo (ajout/édition/comparaison), conserve anciennes métadonnées et place Not Assigned en dernier ;191tests métier/6metadata/lint/build/inspection réussis. Aucun changement chiffrement/clé/permissions ; installation57en cours, aucun push.

Livraison57 : script0, installation/vérification100%, postflight direct version57/mêmes identités et certificat exact/profils valides. Review iPhone attendue ; aucune publication GitHub.

18octobre — build58 : repos réglable par roulettes SwiftUI natives minutes/secondes, pas30s et valeurs historiques exactes conservées. Save0:00 désactivé, même éditeur Today/Settings, séances en cours inchangées.10tests Planning,6metadata, lint/build/inspection réussis ; installationUSB en cours. [ExecPlan](exec-plans/2026-10-18-rest-duration-picker.md). Aucun push.

Build58livrée : script0, installation/vérification100%, postflight confirme version58, mêmes identités/certificat exact/profils valides. Interaction native à confirmer sur iPhone. Aucun push/release.

Build60 : validation directe des hausses/baisses de lest en une popup à la fin de séance, adoption transactionnelle explicite pour prochaine séance ; fond Accent natif restauré aux8boutons checkmark, symbole noir.196tests métier/6metadata/lint/build/inspection réussis, revue ciblée sans P1/P2 ; installationUSB en cours, aucun push. [Objectifs](exec-plans/2026-10-18-direct-load-goal-confirmation.md), [boutons](exec-plans/2026-10-18-accent-confirmation-buttons.md).

Livraison60confirmée : script0, installation/vérification100%, postflight version60/mêmes identités/certificat exact/profils valides. Review iPhone requise sur popup/adoption/Cancel et noir-sur-Accent. Aucun push/release.

Correction61 : popup dès Next Exercise/Continue to Stretching, Update Goal/Keep Current Goal avant transition ; aucun popup final. Marqueur transactionnel schema9 conserve les deux choix à la fin, après reprise ou stretching.199tests/strictlint/xtool21.05s réussis, revue ciblée sans P1/P2 ; contrôles finaux/install en cours. [ExecPlan](exec-plans/2026-10-18-exercise-goal-decision.md). Aucun push.

Livraison61confirmée : script0, installation/vérification100%, postflight61/mêmes identités et certificat exact/profils valides.199tests et6metadata réussis ; validation iPhone requise avant tout push.
