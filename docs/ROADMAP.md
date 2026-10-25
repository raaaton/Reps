# Reps — jalons natifs

Référence : [plan global](../PLAN-REPS-NATIF.md). Chaque jalon exige compilation xtool, contrôles applicables, installation USB autorisée et **confirmation utilisateur sur iPhone** avant le suivant.

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
- [x] Créer et intégrer une icône personnalisée pour Reps : haltère cyan/argent en couches, rendu Kavi conservé. 0.11.11 implémentée ; validation visuelle iPhone attendue.
- [x] Échauffement automatique issu du premier exercice et étirement chronométré : 0.12.0 implémentée, recette iPhone attendue. La demande précise du 15 octobre remplace le choix initial d’un échauffement libre/différent.

Réorganisation demandée le12 octobre : Progression passe avant le coffre pour s’appuyer sur les données d’entraînement déjà livrées ; Animations/haptics vient après les nouveaux écrans pour harmoniser les transitions sur des flux stabilisés. Les bonnes pratiques natives et l’accessibilité restent obligatoires dès chaque jalon. Le détail des périmètres, exclusions et recettes est dans [le plan global](../PLAN-REPS-NATIF.md).

Le [brouillon](ideas/2026-10-12-progression-visualization-backup.md) conserve la discussion et les idées rejetées/non confirmées. Maintien/reprise reste potentiel ; notes techniques, versions courtes et qualificatifs Feeling sont exclus. L’ajout des jalons est une décision de planification, suivie de l’autorisation explicite d’implémenter le7 ; cette autorisation ne prouve pas chaque scénario iOS du6. Les numéros des comptes rendus historiques restent ceux de leur date.

Extension du7 demandée ensuite : import/export entraînement avancé avant coffre/animations, avec CSVfictif117séances/752séries. Reps0.7.1(17) installé ;107tests+6metadata/lint/build/inspectionunsigned/postflight réussis, revue statique indépendante et correctifs couverts. Blocage temporaire de revue levé sansbypass. RecetteiPhone import/export attendue. Jalon7 toujours en recetteiPhone,8/9 inchangés. Au10reste archive privée chiffrée du futurcoffre/finitions ; CSVn’inclutjamaisphotos.

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


Après0.11.1 l’utilisateur refuse la preuve et exige uniquement Import from Files / Export to Files.0.11.2(36) installée : choixformats/copieavantimport dans Export, démo/proof retirées du produit et type.repstest absent.146tests/6metadata/lint/xtool/pré-postflight réussis, mêmes app/certificat. Ne plus demander l’anciennepreuve ; pas de reprise10C sans nouveau périmètre autorisé. [ExecPlan](exec-plans/2026-10-13-simple-file-transfers.md).


Après0.11.2, utilisateur : « parfait. on a fini ? ». Présentation simplifiée acceptée. Fonctions principales livrées ; planinitial non entièrement clos : sauvegarde/restauration privée complète reste différée et auditfinal global accessibilité/performance/régressions non exécuté. Aucune intégration optionnelle ni reprise de prototype implicitement autorisée par cette question.

13 octobre — utilisateur : « oublie la sauvegarde truc et fait l’audit global ». Cette instruction remplace les mentions précédentes de sauvegarde différée. [Audit global](audits/2026-10-13-global-audit.md) et [ExecPlan](exec-plans/2026-10-13-global-audit.md) : corrections installées, validation physique finale encore attendue ; aucun autre chantier obligatoire.


Couleur d'accent demandée après l'audit : [ExecPlan0.11.4](exec-plans/2026-10-13-accent-color.md).155tests/6metadata/lint/xtool/revue et pré/postflight réussis, installation USB mêmeapp/certificat. Sept choix ; #46D7A7 nommé Mint plutôt que jaune pâle, puisqu'il s'agit d'un vert. Rendu clair/sombre/contraste augmenté, choix après relance et Live Activities déjà présentes à vérifier sur iPhone. Icône toujours à faire ; aucune reprise de sauvegarde.

0.11.5(39) installée : Icy Cyan seul/réglage retiré, filtre Workout Conditions supprimé dans tous les graphiques, totalrépétitions sur tous les points affichés, Pause SF blanche demandée dans app/Live Activities.155tests/6metadata/lint/xtool/revue/pré-postflight réussis, mêmes app/certificat. Période/lest et métadonnées historiques conservés, aucun nouveau périmètre. [ExecPlan](exec-plans/2026-10-13-fixed-cyan-unified-charts.md), recette iPhone attendue ; icône à faire, sauvegarde abandonnée.


0.11.6(40) installée : rougesSF+titresdestructifs, Cancelneutreblancsombre/noirclair après clarification, annotationgraphaupremierplan, Repetitions toutescharges sansLoadtoCompare.156tests/6metadata/lint/xtool/revue et pré/postflight réussis, mêmeapp/certificat. Recettephysique encoreattendue, notammentalertecoffre→background. [ExecPlan](exec-plans/2026-10-13-destructive-alerts-chart-overlay.md). Pas de nouvel ajout prévu ; icône en todo, sauvegarde abandonnée.


0.11.7(41) : retour utilisateur sur le point devant la bulle, correction par chartOverlay externe aux marques et Layout en une passe.17testsgraphiques/6metadata/lint/xtool/pré-postflight réussis, mêmeapp/certificat. Rendu/drag aux extrémités et grand texte à confirmer après installation ; [ExecPlan](exec-plans/2026-10-13-chart-callout-front.md).


15 octobre — retouche 0.11.8 (42) installée : symboles des actions Liquid Glass blancs, sauf coches ; menus destructifs rouges conservés. Lint, 6 metadata, xtool et pré/postflight réussis. Retour physique attendu. Échauffement configurable ajouté à la todo, icône existante conservée. [Compte rendu](exec-plans/2026-10-15-white-glass-symbols.md).

15 octobre — 0.11.8 installée mais correction blanche inefficace selon retour iPhone. 0.11.9 (43) remplace foregroundStyle par tint au niveau des contrôles natifs ; compilée/installée et contrôlée, même identité/certificat. Confirmation visuelle attendue. [Compte rendu](exec-plans/2026-10-15-native-toolbar-tint.md).

15 octobre — 0.11.9 blanche validée par « parfait ». Prototype 0.11.10 (44) installé avec l’icône Kavi exacte en couches pour comparer le rendu natif Linux sur iPhone ; lint/6metadata/xtool/inspection/pré-postflight réussis. Aucune icône finale Reps décidée, todo maintenue. [Compte rendu](exec-plans/2026-10-15-kavi-icon-probe.md).

15 octobre — icône Reps 0.11.11 (45) installée : Phosphor barbell-fill adapté, deux couches cyan/argent et verre Kavi, licence embarquée. actool/lint/6metadata/xtool/inspection et pré/postflight réussis, même app/certificat. Création terminée, validation visuelle iPhone attendue. [Compte rendu](exec-plans/2026-10-15-reps-app-icon.md).

15 octobre — 0.11.12 (46) installée : liserés fins et trois plans superposés de l’icône ; silhouette 0.11.11 appréciée mais relief à améliorer selon retour utilisateur. Lint/6metadata/actool/xtool/inspection/USB/postflight réussis, même app/certificat. Confirmation physique des retouches attendue. [Compte rendu](exec-plans/2026-10-15-icon-glass-overlap.md).

15 octobre — 0.11.13 (47) installée : haltère à 112,5 %, centré, matériaux conservés. actool/lint/6metadata/xtool/inspection/USB/postflight réussis ; même identité/certificat. Retour visuel attendu.

0.12.0 (48) — nouvel enchaînement autorisé le 15 octobre : un échauffement dérivé du premier exercice, demi/full repos puis travail, un étirement chronométré avant le bilan. Répétitions et durée/libre selon règles utilisateur, conservation SQLite/history/CSV sans pollution des performances. Implémentation et 169tests/lint/6metadata/revue effectués ; livraison et validation physique à consigner dans [ExecPlan](exec-plans/2026-10-15-warmups-stretches.md).

Livraison 0.12.0 confirmée par lecture appareil : version48, même identité/certificat, profils valides. Attendre le retour iPhone sur le nouveau déroulement ; les contrôles automatiques ne le valident pas.


1.0.0 (49) — distribution native publique préparée le 15 octobre : README anglais, historique Git Expo conservé, build Release local et IPA non signée inspectée, SHA256 fourni. 169tests/6metadata/lint/xtool réussis. Pas de fonctionnalité manquante dans le périmètre demandé ; le dernier enchaînement échauffement/étirement et les recettes manuelles d’accessibilité restent à confirmer sur iPhone. Sauvegarde portable abandonnée. Voir [publication 1.0.0](exec-plans/2026-10-15-version-one-release.md) et [limites des tests](TESTING.md).

1.0.0 (49) installée par le workflow USB existant ; contrôle après installation réussi, mêmes identité/certificat et profils app/widget valides. La version publique est une IPA Release non signée construite séparément, destinée à être re-signée par chaque destinataire.

Publication 1.0.0 terminée : [Release publique](https://github.com/raaaton/Reps/releases/tag/v1.0.0), IPA locale Release + SHA256. Téléchargement depuis GitHub, comparaison octet pour octet et nouvelle inspection réussis. Ancien historique Git conservé, aucun force-push.


17 octobre — 1.0.1 (50), correctif local autorisé après utilisation : repos entre exercices, objectifs alignés sur résultats réels, proposition de baisse du lest au-dessus de 9, arrêt exact de l’étirement et son de fin au premier plan, Pause/coches noirs sur cyan, Customize sans croix, graphiques chronométrés toutes charges. 182 tests métier et 6 metadata passent ; lint et build xtool réels réussis. Installation/contrôles finaux et retour iPhone à consigner dans [ExecPlan](exec-plans/2026-10-17-workout-refinements.md). Aucun push ni release avant le retour utilisateur.

1.0.1 (50) installée et contrôlée après déploiement : même identité/certificat, profils app/widget valides et capacités inchangées. Métadonnées et inspection finale réussies. Attente du retour iPhone ; aucune publication GitHub.

Retour utilisateur « cb push » : correctif installé 1.0.1 accepté et publication GitHub autorisée. Construction locale de l’IPA Release et vérifications avant publication ; seule l’IPA sera jointe, sans fichier checksum. Ce retour global ne constitue pas un relevé individuel de chaque recette d’accessibilité ou d’exécution en arrière-plan.

1.0.1 publiée après accord utilisateur : [Release](https://github.com/raaaton/Reps/releases/tag/v1.0.1), IPA construite localement, seul asset téléchargeable. Téléchargement distant identique au fichier local et inspection réussie.

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

Publication autorisée par « push » après61 : commit sourcea685dbb et tagv1.0.3 poussés normalement, Release https://github.com/raaaton/Reps/releases/tag/v1.0.3 publiée avec uniqueReps-1.0.3.ipa. BuildRelease locale/199tests/6metadata/lint/inspection réussis ; téléchargement GitHub identique octet pour octet et nouvelle inspection unsigned réussie. Aucun fichier checksum, aucun certificat/profil privé/donnée personnelle publié.

18octobre — local1.0.4(62) : objectifs chronométrés éditables depuis Progress/Today, durée positive ou Untimed, durée+lest atomiques et instantanés existants conservés. Accès natif aux réglages iOS des notifications. Time Sensitive demandé mais bloqué par signature gratuite selon le tableau Apple ; aucun entitlement ajouté.203tests métier/6metadata/strictlint/build xtool/inspection unsigned réussis. InstallationUSB en cours ; aucun push.

Livraison62confirmée : script0, installation/vérification100%, postflight même identité unique/version1.0.4(62)/certificat inchangé. Review iPhone attendue ; Time Sensitive reste bloqué par signature gratuite, aucune publication.

Build63 : Send Test Notification dans Settings/Notifications, notification locale unique après10s ; permissions standard, aucun changement des préférences, notification isolée de la synchronisation et du compteur de rappels.204tests métier passent ; lint propre. Build xtool initial12.26s réussi ; contrôles finaux et installation en cours.

Livraison63confirmée : device-run.sh code0, installation/vérification100%, postflight version1.0.4(63), identité unique attendue et certificat inchangé.204tests métier/6metadata/lint/build/inspection réussis. Réception réelle du test, refus de permission et visibilité écran verrouillé à confirmer sur iPhone. Aucun push.

Publication1.0.4(63) autorisée par push : commitc58b94a/tagv1.0.4 publiés, uniqueassetReps-1.0.4.ipa.204tests/6metadata/lint/Release xtool/inspection réussis ; asset GitHub retéléchargé identique et inspecté. Modifications distantes README préservées. Aucun checksum, profil, certificat ou donnée privée publié.

Local1.0.5(64) : isométriques arrondis au dixième à l’affichage et en stockage, anciennes séries migrées avec transaction SQLite10 ; nouveaux résultats/corrections/imports normalisés par triggers. Horodatages et échéances restent précis.208tests métier/6metadata/lint/xtool/inspection réussis ; scriptUSB0, installation/vérification100%. Review iPhone attendue, aucun push.

Correction65 : temps total isométrique de la période au lieu de la seule dernière séance ; courbe/bulles par séance conservées, arrondi au dixième maintenu.17tests de graphiques passent. Compilation et livraison en cours, aucun push.

Livraison65 :17tests graphiques/6metadata/lint/xtool13.07s/inspection unsigned réussis ; scriptUSB0 et installation/vérification100%. Le chiffre principal est la somme de période et les points restent par séance. Review iPhone requise, aucun push.

Publication1.0.5(65) autorisée par ok push : commit2061397/tagv1.0.5 publiés, Release avec uniqueReps-1.0.5.ipa.208tests/6metadata/lint/Release xtool/inspection réussis ; asset retéléchargé identique et inspecté unsigned. Aucun checksum ni donnée privée publié.


19 octobre — 1.0.6(66) : nombre de séries dans chaque exercice d'un Workout, retiré du catalogue. Objectifs par workout et nombres actuels conservés, migration11 transactionnelle ; anciens historiques/séances actives figés. JSONv2 avec conversion des anciens v1.219tests métier/6metadata/lint/xtool/inspection unsigned réussis, revue indépendante corrigée ; installation USB en cours. Recette iPhone nécessaire avant GitHub. [ExecPlan](exec-plans/2026-10-19-workout-set-count.md).

Livraison1.0.6(66) confirmée : device-run.sh code0, installation/vérification100%, postflight direct version66/identité unique inchangée/certificat exact inchangé/profils CMS app-widget valides et capacités conservées.219tests métier/6metadata/lint/build/inspection réussis. Attente du retour iPhone ; aucun push/release.

Build67 livrée : device-run.sh code0, installation/vérification100%. Postflight direct confirme un seul Reps1.0.6(67), même identité effective, certificat exact inchangé, profils CMS app/widget valides et mêmes capacités.219tests métier/6metadata/lint strict/xtool15.89s puis2.90s/inspection réussis, revue ciblée sans défaut concret. Rendu menu/Custom/grands textes/VoiceOver à confirmer sur iPhone. Aucun commit/push/release.


19 octobre — 1.1.0 (68) : Body Weight dans Progress, mesures journalières en grammes entiers, graphique Swift Charts et historique modifiable ; rappel hebdomadaire opt-in dans Notifications. Périodes partagées 3 Months / 6 Months / 1 Year sur tous les graphiques. Migration SQLite 12, archives JSON v3 ; anciens JSON/CSV conservent les pesées et leur rappel. 242 tests hôte, 6 metadata, lint strict et inspection unsigned réussis ; xtool final 51,39 s puis intégration metadata 3,95 s. Revue indépendante incluant les HIG, deux défauts corrigés et recontrôlés. Installation USB réussie (device-run.sh code 0, installation et vérification à 100 %). Postflight direct : un seul Reps 1.1.0 (68), même identité effective, certificat exact inchangé, profils CMS app/widget valides et capacités conservées. Recette visuelle et notifications sur iPhone attendue. Aucun push/release. [ExecPlan](exec-plans/2026-10-19-body-weight.md).


Build 69 — Progress affiche l'objectif exact de la séance principale pour chaque exercice, choisi selon le volume cible total. Priorité explicite aux objectifs de répétitions lestés ; à vide, somme des répétitions ; isométrique, séries × durée. Six tests de sélection observés rouges puis verts ; suite complète 248/0 échec, lint strict, 6 metadata, revue indépendante ciblée sans défaut concret, xtool 63,67 s puis intégration metadata 5,49 s et inspection unsigned réussis. Préflight : un seul Reps 1.1.0 (68), même identité effective et certificat existant encore valide. Installation USB réussie (code 0, installation/vérification à 100 %). Postflight : un seul Reps 1.1.0 (69), même identité effective et certificat exact inchangé, profils CMS app/widget valides et capacités conservées ; aucun commit/push/release. Rendu/grands textes/VoiceOver à vérifier sur iPhone.


Build70 — Une modification d'exercice acceptée adapte automatiquement les objectifs futurs de tous ses workouts ; migration13 transactionnelle des anciens objectifs désynchronisés et normalisation de l'aperçu JSON. Composition de lest conservée exactement : indisponibilité toujours à valider. Progress affiche Review needed si un objectif assigné nécessite une vérification. Séances actives/historique inchangés. 257 tests hôte/0 échec, 6 metadata, lint strict et inspection unsigned réussis ; xtool61,12 s puis intégration metadata4,90 s. Revue indépendante ciblée sans défaut concret. Préflight : version69, identité unique et certificat existant inchangés. Installation USB70 réussie (code 0, installation/vérification 100 %). Postflight : un seul Reps1.1.0(70), identité effective et certificat exact inchangés, profils CMS app/widget valides et capacités conservées. Recette physique en attente ; aucune publication GitHub. [ExecPlan](exec-plans/2026-10-19-goal-review.md).


20 October — build71: curves use averages per actual working set; callouts/details retain workout totals and add set count. Future targets follow the latest completed session containing each exercise across all workouts, including actual per-set duration at100ms precision. Counts stay assignment-specific; truncate/repeat last target, seed new assignments, preserve explicit different-load choices. Transactional schema14 applies the baseline once to existing history; JSONv4 retains timed targets.270host tests/6metadata/lint/build/unsigned inspection and independent review pass. USB delivery in progress; device feedback pending, no push/release. [ExecPlan](exec-plans/2026-10-20-per-set-charts-latest-exercise-goals.md).

Build71 USB delivery confirmed: device-run.sh code0, installation/verification100%, direct postflight oneReps1.1.0(71), same effective identity/exact certificate, app/widget CMS profiles valid and capabilities identical. Physical chart/goal feedback pending; no commit/push/release.


20October build72: learned goals average actual reps/seconds upward to whole units. Corrected mixed-load session exclusion: Bulgarians12at6.6kg +10/12/11at7.5kg ->11reps at7.5kg. Latest exercise session remains source; each workout retains its own count. Exact history/chart data unchanged; schema15 repairs future goals once.275host tests/6metadata/lint/build/inspection/review pass; USB installation in progress and physical review pending. [ExecPlan](exec-plans/2026-10-20-ceiling-average-goals-mixed-loads.md).

Delivery blocked before installation: usbmuxd crashed withSIGABRT (`free(): invalid pointer`) while the phone remains visible inlsusb. xtool finished compilation2.39s, then waited for the device; the waiting attempt was stopped gracefully. No provisioning/signature error was reported, no certificate changed. Direct diagnostic confirms usbmuxd.service failed(core-dump); `sudo -n systemctl restart usbmuxd` returned `sudo: a password is required`. User must run `sudo systemctl restart usbmuxd`, then resume the standard USB delivery/postflight. Device last confirmedReps71; do not claim72installed.

Build72 delivery confirmed after user restartedusbmuxd: standard device-run.sh code0, installation/verification100%, oneReps1.1.0(72) under same effective identity. Exact existing certificate and app/widget CMS profiles validated, capabilities unchanged.275host tests/6metadata/lint/build/inspection/review remain the local verification evidence; physical goals/screens await user feedback. No push/release.


21 October — build 73: global Stretching toggle in Settings → Training, default on. Off removes stretches from preparation and all new workouts; warm-ups remain, last Feeling completes the workout. Active/history snapshots retained; SQLite schema16, JSONv5 with legacy defaults, CSV preservation. 281 host tests, strict lint, 6 metadata tests and real xtool app/widget inspection pass. USB delivery and physical review tracked in the execution record.


USB delivery confirmed: device-run.sh exited0 (final rebuild7.43s), install/verification100%. Direct device postflight confirms one Reps1.1.0(73), same effective identity, exact cached signing certificate unchanged, app/widget CMS profiles valid and ordinary entitlements retained (no App Group/push). Physical toggle/flow review awaits the user; no GitHub push or release.


Build74: removed only the description beneath Stretching at the user’s request. Strict lint/6metadata, xtool10.99s+2.47s, unsigned inspection and USB install (code0, verification100%) pass. Device postflight confirms74, same identity/certificate and valid app/widget CMS profiles with retained capabilities. Physical rendering awaits user review.
## 22 October — audit corrections, build 75

Approved audit fixes cover inherited goals after history mutations, preservation of unchanged explicit load decisions, displayed duration tenths and visible generic camera failures. Long-history attendance uses lazy columns/cached off-main calculation; chart metric controls adapt to large text/available width. No new animation or dependency. Nine new regressions plus the existing suite: 290 host tests, six metadata, strict lint, real xtool build and unsigned app/widget inspection pass; independent review approved after three additional edge-case fixes. USB delivery confirmed: code0, install/verification100%, direct postflight oneReps1.1.0(75), unchanged identity/signer/certificate/entitlements and valid installed app/widget CMS profiles. Physical review remains pending; see [ExecPlan](exec-plans/2026-10-22-audit-corrections.md). No GitHub push/release before user feedback. Camera encoding remains a device-profiling item; no unmeasured performance claim.

## 22 October — selective revert, build 76

User explicitly selected only three reversions: no future-goal recalculation from history mutations, whole-second recorded labels and the original eager consistency grid/minute calculation. Retained: Stretching/schema16, explicit load-decision preservation, generic camera errors and adaptive metric menu. 284 host tests, six metadata, strict lint, real xtool build/inspection and scoped independent review pass. No data downgrade, push or release. USB installation confirmed (code0, installation/verification100%); direct postflight confirms build76, unchanged identity/certificate/capabilities and valid app/widget CMS profiles. Physical feedback pending; see [ExecPlan](exec-plans/2026-10-22-selective-audit-revert.md).

## Skills milestone — 1.2.0 — build 78, local implementation

Four roadmaps and optional extensions, personal skills, per-workout blocks and standalone practice implemented locally. Schema17 and archive6 preserve definitions, step selections, achievements, settings, snapshots and active state. CSV force-history replacement detaches and retains prior skill practices with their original workout provenance. No automatic progression certification or new app-wide privacy behavior.

Host/build evidence is recorded in the Skills ExecPlan. USB delivery and physical feedback are separate gates; this entry does not assert device acceptance. No push or release performed.

## Skills interface refinement — 1.2.0 (79)

Implemented from physical-device screenshots: clear current-step Practice action, numbered roadmap and separate extensions, per-step guidance/progress screen, native management menu, Skills between Consistency and Body Weight, red destructive glyphs and US copy. Installation and physical feedback tracked in exec-plans/2026-10-23-skills-interface-polish.md.

## Skills complete follow-up — 1.2.0 (80)

Implemented: centralized scoped controls, typed Add to Workout and isolated settings block drafts, history swipe/context deletion, ordered manual progression reconciliation, context-menu step statuses, YouTube demonstrations, reduced overview text, archived-skills access/permanent deletion, computed main/all-goal completion with native success feedback, external AI creation modeled on verified Kavi source, and confirmed progression reset. No schema or archive-version change: existing step/extension and progress payloads support the behavior. Physical acceptance remains pending.

## Skills targeted follow-up — 1.2.0 (81)

Implemented white neutral glass plus/cancel symbols, centered inline Skills title, archive placement and icon-only swipe/long-press deletion. AI creation now mirrors Kavi's actual multi-screen flow with direct paste-to-editable-review, preserved drafts and visible errors. Wrapped JSON acceptance has domain regression coverage. Physical acceptance remains pending; no push or public release.

## Corrective version — 1.2.1 (82)

The existing Skills UI/AI-flow corrections are delivered under patch1.2.1, with no further functional changes. Patch/minor increments follow fixes/important features; major increments require explicit user approval. Physical acceptance remains pending.

## Device-reported Skills corrections — 1.2.2 (83)

Correct nested neutral toolbar glass, use direct provider-logo file loading, preserve destructive menu symbol color, and make step achievements independent of current selection. Generation prompts require demonstration research rather than default null links. Exact ChatGPT import failure awaits a supplied response; physical UI acceptance remains pending.

Build83 follow-up: user-supplied ChatGPT formatting now has a reproduced regression and string-aware import normalization.334 host tests pass; original clipboard acceptance still requires iPhone testing.

## Accent labels — 1.2.3 (85)

Shared content/action label styling applies adaptive blue SF Symbols beside normal text throughout the app. Native tabs explicitly excluded by the user; destructive and prominent contrast preserved. No domain changes; delivery evidence in the accent-labels ExecPlan.

## Native Skills menu correction — 1.2.4 (86)

Ordinary Skills menu entries use original accent-colored SF Symbol images after physical feedback showed native menus retaining white template icons. White menu triggers and working red destructive entries preserved. No domain changes; physical acceptance pending.

## Consistency photo activity — 24 October 2026

1.2.5(87) implements the approved grid refinement: no legend, missed-day crosses, camera symbols on progress-photo dates, completed-workout background retained. Photo-only dates/counts join the public calendar through an index in the existing encrypted vault database; originals/thumbnails remain protected by AES-GCM and Face ID. Earlier dates populate during the next normal vault unlock. Local tests/build/review pass; USB delivery and physical acceptance are tracked in the [ExecPlan](exec-plans/2026-10-24-attendance-photo-activity.md). Baseline1.2.4 was pushed first as4907c05 at the user's request; the verified refinement receives a separate versioned commit/push.

USB delivery confirmed: device-run.sh exits0; installation/verification100%. Direct postflight verifies one Reps1.2.5(87), unchanged identity/signer/entitlements/exact existing certificate and valid CMS-verified app/widget profiles. Physical calendar, Face ID and media-viewing acceptance remains pending. No public IPA Release.

## White photo-day camera — 1.2.6 (88)

User-requested white camera.fill in Consistency, including completed dates. Visual-only retouch, separate versioned commit before the streak feature. Strict lint, nine metadata/style checks, real xtool build, regenerated/embedded App Intents metadata and unsigned app/widget inspection pass. Standard USB delivery tracked in the photo-activity ExecPlan; no new domain tests or private-data access. Physical rendering remains user validation.

## White camera and current streak —24October2026

The user requests two distinct commits. First: white photo-day camera,1.2.6(88), committed3c393ca and installed; postflight confirms same identity/signer/exact certificate/capabilities and valid app/widget profiles. Second:1.2.7(89) current streak and Days/Largest Unit preference. Dynamic weekly threshold, calendar-day duration, rest/today and photo exclusions are covered by355passing tests and an independent review. Real iOS build and inspection pass; second USB delivery and physical acceptance are tracked in the [ExecPlan](exec-plans/2026-10-24-workout-streak.md). No new GitHub push or public Release requested in this turn.

Streak89delivery confirmed: device-run.sh exits0, installation/verification100%; direct postflight verifies one Reps1.2.7(89), unchanged identity/signer/entitlements/exact certificate and valid CMS-verified app/widget profiles. Physical summary, native picker, relaunch preference and camera appearance await user review. Two dedicated local commits requested; no new push/public Release.

## Direct streak-unit menu —1.2.8(90)

At the user's request, tap the right-hand streak value (e.g.33days) directly to open a native menu containing the Days/Largest Unit picker with current selection. Settings no longer contains the Progress/Streak Units section or its footer. The existing preference key, saved choice, formatting and streak rules are retained. StreakSummaryRow owns the same @AppStorage value and exposes a VoiceOver label/value/hint; the native left-label/right-value row layout remains. Physical menu behavior and text size checks remain required.

## Private movement videos —1.3.0

User-approved Private Vault Physique/Movements, Following Skill folders and vault-only custom movements, dated video import and aligned comparison are implemented. Vault migration/chunked encryption preserve photos and the existing key.370host tests and the native synthetic encrypted-player probe pass; independent review findings are fixed. Build91was a restricted-import prototype, installed with verified same identity/certificate/capabilities. Final build92activates imports after native proof; delivery and physical acceptance are tracked in the [ExecPlan](exec-plans/2026-10-24-vault-movement-videos.md). No GitHub publication authorized.

Final92delivery confirmed: standard USB helper exits0/install+verification100%; direct postflight validates the same identity/exact certificate/capabilities and both app/widget CMS profiles. Import is enabled after successful native proof. Actual personal import and UI/Face ID acceptance remain user checks, not inferred from build or installation.

## Private video corrections —1.3.1

Native transitions restored, privacy presenters preserved during temporary inactivity with direct active recovery and an opaque UIKit snapshot shield, day stacks with contextual/swipe deletion, paired preroll/host-clock start with bounded preparation and privacy interruption cancellation. Permanent video-only passthrough encrypts segmented output without a Reps-owned clear video file; validated replacements preserve old clips until CAS commit, including a full5000-clip vault.373host tests,9metadata checks, strict lint and independent security review pass. Native95/96synthetic audio/provider/seek/alignment/revocation checks pass. Final97delivery and extended native/physical results are tracked in the [ExecPlan](exec-plans/2026-10-24-vault-video-corrections.md). No publication authorized.

Final1.3.1(97)installed and postflight verified under unchanged identity/signature/capabilities. Native97extended synthetic probe passes; physical warning recovery, animations, fullscreen snapshot, accessibility and existing-photos acceptance remain pending. No GitHub publication.

## Added-weight spacing —1.3.2

New load choices and progression proposals use at least500g spacing, keeping the lightest exact combination; existing valid selected/goal/historical loads are preserved. Filtering is a projection after exact generation, retaining sums made from small items and existing complexity bounds.378host tests, strict lint,9metadata/style checks, real xtool build and app/widget inspection pass. USB delivery and physical feedback tracked in [ExecPlan](exec-plans/2026-10-24-load-spacing.md); no push authorized.

1.3.2(98)installed successfully and direct identity/signature/profile postflight passes. Physical list and prior-selection review pending; no push/release.


## Reps rename —1.3.3

User explicitly requested Reps throughout app, filesystem and GitHub. Native branding/products/files, icon identifiers, help/export names and active docs use Reps; repository renamed to raaaton/Reps,23historical release titles/assets renamed without changing binary bytes or tags. Same device identity/Keychain/AAD/SQLite/backup identifiers and system-serialized module identities preserved, with additive reps:// and legacy sport:// support. Real local root moved to iOS/Reps with compatibility alias for existing tools; Codex's running sidebar registration remains cached until refreshed/reopened. Reps1.3.3(99)installed, identity/signature postflight and native synthetic probe pass. Source push is explicitly authorized for this rename, no new IPA Release.

## Portrait and available item quantities —1.4.0

Implemented approved portrait lock and per-item unit weight/available quantity. Count-based exact-total generation groups interchangeable copies, retains500g offered-choice spacing and preserves active/history snapshots. SQLite18/JSON7 retain existing quantities as1; backward import remains supported.385host tests,13metadata/style/branding checks, strict lint, actual native build/metadata/unsigned inspection and independent review pass. USB delivery and physical review are tracked in the [ExecPlan](exec-plans/2026-10-24-portrait-weight-quantities.md). No push/public release.

USB delivery confirmed: device-run.sh exits0, install/verification100%. Direct postflight validates exactly one Reps1.4.0(100), identical effective bundle identity/signer/exact cached certificate/entitlements, and valid CMS-verified app/widget profiles. Actual rotation, quantity editor/layout/accessibility and personal-data review remain physical user checks. No GitHub push/public release.

## Minimal weight objects —1.4.1

At equal total, prefer the least physical copies; cap new compositions at10weight objects excluding the backpack. Ascending totals,500g offered spacing and portrait remain. Existing feasible alternatives stay usable without history/active rewrites. No schema/backup-format change.394host tests,13metadata/style checks, lint, actual build/metadata/inspection and independent review pass. USB delivery and physical review tracked in the [ExecPlan](exec-plans/2026-10-24-minimal-weight-objects.md). No push/release.

USB delivery confirmed: standard device-run.sh exits0, install/verification100%, final incremental build3.25s. Direct postflight validates exactly one Reps1.4.1(101), identical effective bundle identity/signer/exact cached certificate/entitlements and valid CMS-verified app/widget profiles. Physical minimum-object list/cap/previous-selection/portrait review remains user feedback. No GitHub push or public release.

## Object priority and configurable maximum — 1.5.0

Physical copy count now takes priority across nearby different weights before the 500 g choice filter; retained choices still display by ascending weight. Maximum Objects in Settings → Added Weight sets 1–1,000 copies, default 10 excluding the bag. SQLite 19 / JSON 8 preserve the preference, older archives default to 10 and CSV retains it. Inventory and recorded/active snapshots stay unchanged. 402 host tests, strict lint, 13 metadata checks, native build/inspection and independent review pass. USB delivery and physical acceptance remain tracked in the [ExecPlan](exec-plans/2026-10-24-weight-object-priority-setting.md). No GitHub publication.

USB delivery confirmed: device-run.sh exits 0, install/verification 100%, final deployment rebuild 3.35 s. Direct postflight verifies exactly one Reps 1.5.0 (102), identical effective bundle identity/signer/exact existing certificate/entitlements and valid CMS-verified app/widget profiles. Final native checks after disabling Cancel during saving took 10.91 s + 2.71 s. Physical Maximum Objects editing/persistence, object-first near-weight choices and portrait remain user review. No GitHub push or public release.

## Added Weight descriptions — 1.5.0 (104)

Retain approved 1.5.0 and its Maximum Objects modal; remove explanatory footers from Added Weight and its forms. Core rules/history/active data/portrait remain identical. Lint, 13 metadata checks, actual build/inspection and independent review pass. Phone preflight confirms 1.5.0 (102); cleaned104delivery and physical review tracked in the [ExecPlan](exec-plans/2026-10-24-added-weight-description-cleanup.md). No publication.

Delivery blocked before replacement: usbmuxd crashed at 21:49:32 with SIGABRT / free(): invalid pointer; systemd reports failed(core-dump). Build104helper completed its incremental build (2.58 s) and waited without successful installation. sudo -n systemctl restart usbmuxd requires a password. Pending delivery interrupted gracefully with SIGINT. Last direct installed identity verification remains Reps1.5.0(102), not104. User next action: sudo systemctl restart usbmuxd, then resume normal helper and postflight. No certificate/profile changes, GitHub push or release.

Delivery resumed after the user restarted usbmuxd. Fresh preflight confirmed the same identity/certificate/capabilities and valid CMS app/widget profiles. Normal device-run.sh exits0, installation/verification100%, final rebuild2.88s. Direct postflight verifies exactly one Reps1.5.0(104), unchanged effective identity/signer/exact cached certificate/entitlements and valid CMS-verified app/widget profiles. Source inspection, not device automation, verifies the original Maximum Objects modal and the five descriptions removed; physical UI review remains the user check. No GitHub push or public release.

## Editable backpack and unified group — 1.5.1 (107)

Backpack and Maximum Objects share one native rounded section. Both open saved-draft editors; bag kilograms are editable. All three Added Weight editors save with the standard checkmark. Quantity, object-first spacing, configurable maximum and portrait remain. SQLite20/JSON9preserve legacy defaults and recorded compositions.

409host tests,13metadata checks, native builds and independent review cover the implementation. Physical UI acceptance remains user review. Corrected1.5.1release/delivery evidence is tracked in the [ExecPlan](exec-plans/2026-10-24-editable-backpack-release.md). User corrected minor inflation: small feature/UI additions use patch versions.

Completed delivery/publication: Reps1.5.1(107) is installed; direct app inventory and CMS postflight verify one Reps app, unchanged effective identity/signer/exact certificate/entitlements and valid app/widget profiles. Installed via xtool dev run --configuration release --usb (exit0, install/verification100%). Physical UI is still user review.

GitHub release https://github.com/raaaton/Reps/releases/tag/v1.5.1 is latest, with one unsigned Reps-1.5.1.ipa asset. Main and annotated tag initially point to exact built source81e92e6ee4d50a1ae51094a6f84ff02bbfdf0e41. Downloaded IPA is byte-identical, SHA256f83c98ddf9e592f0aa1f7be09ab21e90caea2fb717375bf7409077ab2072010d, and passes full unsigned/version107/portrait/app-widget inspection. No checksum attachment. The user explicitly authorized deletion of mistakenv1.6.0release/tag after automatic review required consent; both were deleted and remote tag absence/latest1.5.1were verified. Subsequent commits only record this delivery/publication evidence.

## Red deletion swipe backgrounds — 1.5.2 (108)

All15trailing-swipe deletion sites use explicit red tint:11native buttons and4instances of the existing red Skills helper. Includes workout history, recorded-workout exercise/set drafts, inventory, bodyweight, exercise/workout settings, archived results/Skills, private video rows and implicit skill-step/workout-assignment deletions. Keep onDelete/onMove for Edit mode, last-step protection, set-count cleanup, confirmation/busy states and existing full-swipe behavior.

Strict Swift lint,13metadata/style tests, complete native app/widget build and compiler metadata, portrait-only unsigned bundle inspection and whitespace checks pass. Normal device-run.sh delivery exits0, installation/verification100%; direct postflight confirms exactly one Reps1.5.2(108), unchanged effective identity/signer/exact cached certificate/entitlements and CMS-valid app/widget profiles. No domain logic/schema/security change; no redundant domain test run for the UI tint fix. Rendered red backgrounds in light/dark appearances and all actual swipes remain physical user review. Local commit only; no new GitHub push/release requested. Evidence:/tmp/reps-152-{lint,build,metadata,tests,inspection,install}.log and /tmp/reps-152-{preflight,postflight}.json.

## Pending local correction — 25 October

1.5.6 (116): correct remux session bounds for Photos-trimmed clips; the user's detailed report identifies a 338 ms excess, reproduced by packet analysis of a cropped synthetic fixture. Local checks pass; native probe execution is blocked by the CoreDevice service, and actual-file acceptance remains pending. [Plan](exec-plans/2026-10-25-trimmed-video-timeline.md).

1.5.5: preserve and display detailed video-import errors directly in the form, including original provider-wrapped failures and duration comparisons. 411 host tests, 13 metadata checks and native build/inspection pass; final build 114 delivery tracked in [the current plan](exec-plans/2026-10-25-visible-video-errors.md). Original-video acceptance remains unresolved; 112's precise-timing hypothesis did not resolve the user's error.

1.5.3 (109): video-import error-presentation conflict corrected; native build, lint, 409 host tests and 13 metadata checks pass. USB delivery succeeded after the user's reconnect; direct postflight confirms 1.5.3 (109) with unchanged identity/signer/entitlements. Original-video reproduction and import compatibility remain unverified. [Plan](exec-plans/2026-10-25-video-import-crash.md).
