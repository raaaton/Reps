# Cumul sur période et remplacement CSV — retouches du jalon 7

## Autorisation et portée

Utilisateur demande le volume total, clarifie « seulement la période choisie » ; demande que l'importCSV remplace les données, clarifie « oui, remplacer tout l'historique » et conserve planning/catalogue/inventaire/réglages. Modifier ces deux flux existants, aucun jalon8/9. Installation USB autorisée avant recette. Documents Sport audités dans cette conversation, ExecPlans charts/transferts et sources pertinentes relus ; même exigences HIG/lint/tests/xtool/profils. Workflows brainstorming/TDD/executing-plans appliqués ; pas de gate nouvellepermission car demande explicite. BaselineSources /tmp/sport-cumulative-before, pasGit exploitable/reset/worktree/commit.

## Conception

Volume : total reps×lest ajouté des séances terminées de l'exercice sur1/3/12mois. Un point par séance affiche le cumul depuis le début de cette période ; le résumé affiche son total entier. Pas de filtre de contexte/rest/charge pour Volume, sinon un total pourrait omettre des séances. Conditions/charges mixtes incluses, bodyweight non inféré ; Répétitions à lest fixe/conditions et Durée par séance inchangées. Bulle date+cumul, détail cumul et volume de cette séance distingués. Doublechecked produit et addition ; erreur visible plutôt que total partiel si overflow. Suppression/correction/import révision recalcule, aucune écriture supplémentaire.

CSV : validation et aperçu contenant tout le fichier et nombre de séances actuelles remplacées. Bouton Remplacer/alerte nativecentrée explicite, Annuler sansécriture. Conflits avec vieux IDs deviennent remplacements autorisés ; doublons incohérents au sein du fichier restent refusés. Applycompare dataset original, refuse actif/stale, préserve config/préférences/goals. CopieJSON complète avantimport et suppression/insertionhistoriquetoutdansmêmtransaction ; rollbackpréserveancienhistoriqueetanciennecopie. Importidentiqueno-op n'écrasepascopierécupérable ; CSVvidevalidé peut viderl'historique seulementaprèsconfirmation explicite. JSONrestaurationglobaleinchangée. Photosprivéesexcluded etformatsinchangés, pasmigration/dépendance/permission.

## Étapes

1. Testscumul avantAPI puisassertionsRED surcumul/fenêtre/contexte/0/ordre/overflow ; domaineetUI cumultotal, bullesetdétail. Compilationxtoolréelle.
2. TestsCSVavantchangement : remplacementexact/sameIDdifferent/empty/idempotencecopie/active/stale/conservationconfig etrollbackaprèsDELETE/INSERT. Preview ettransaction ; UIconfirmationetmessages, docsformat/fixtureworkflow misàjour. Suitecomplète/lint/build.
3. Une revuefinaleindépendante mandatéeparskill, fiximportantspuissuite ; version0.7.4(20),metadata→package→6tests/inspection. Préflight0.7.3/mêmeappcertificat,device-run.sh puispostflight. Docs/recetteetSTOPpourconfirmationiPhoneavant8/9. Aucun import exécuté surlesdonnéesiPhoneparl'agent.

## Review focus

Cumul reset au début de période, touscontextes/charges inclus, pasbaselinevieilleperiode, selection/rawvsplottedtotal,bords/empty/une/samday, overflow necachepasunecontribution. CSV final exactement fichier, IDsold remplacés maisIDsconflictuelswithinfile refusés ; config/objectifs/rappels/permissions nonreset. Transactionbackup/delete/insertatomic, originaletcopy préservés àéchec ; no-opgardeanciennecopy, previewstale/active refusés, boutonsdoubleactions/Annuler/enclosure destructivecentrée. Retraitancientrainingsnapshots/goals/rests cascadecorrecte, statsetassiduitéactualisées aprèscommit.

## Ledger

- [x] Cumul/tests/UI
- [x] CSV remplacement/tests/UI
- [x] Revue/contrôles/livraison/docs
- [ ] Confirmation iPhone

Interfaces : cumulativeTotal en grammesrépétés → chart/resumé/bulle, total reste contributiondechaqueséance ; CSVpreview incoming complet + expectedoriginal → applytransaction etalerteUI. Pasdonnéespersonnellesenlog/capture/test. UIphysiqueàtester,mêmespermissions/capacités/configsfichiers.

Cumul : APIabsente compileRED puisprojectionnoncumulée6assertionsRED ; implémentationchecked. PremierGREENsuite121 avait1erreurfixture : minuitUTCcomparéauxdateslocalesParis excluait1octobre, pasdéfautproduit. FixturecalendrierUTCexplicitecorrigée ; aucunchangementdatesmétier. CSVtestsavantchangementobservésRED surappend/CSVvide/sameIDdifférent ; paramètresdalimiteajustésaufinalreplacement (pasmerged). Implémentationtransaction etbackup→GREEN123tests,0échec. No-op/previews/active/stale/config/goals/notifications/rollback/récupérationcouverts. UIxtool15,13scode0, lintstrictcode0 ; derniersajustementslibellé1mois etzerofootnote baséscumulàrecompiler.

Revuefinaleunique :0Critical,1Important,1Minor. Important : nopCSV dépendaitordrearray, perte decopierécupérationlorsréimportmêmesrecordsréordonnés. GradeImportantconfirmé ; testReorderedIdenticalCSVDoesNotReplaceExistingRecoveryobservéRED3assertions, fixerégalitéCSV parID/contentindépendantordre,JSON exact inchangé. Suiteaprèsfixàexécuter, pasdere-review.
Final: minor (deferred): étatvideVolume garde texteancien « Aucune séance comparable » etsuggestion autrelest/conditions alorsqueVolume n'a plus ces filtres ; autrepériodefonctionne. ÀharmoniserlorsprochainretourUI, aucun calculaltéré.
Final:Ruling: declined — gestes/alertes/bulles/accessibiliténepeuventêtreconfirméssousLinux ; compilation/signature/docsfinitionsvérifiéesparexécutantavantlivraison ; coffre/migrationsfutures horsscopeetaucunmediaajouté. Coût : renduàconfirmerphysiquementsurcettebuild, aucunjalon8/9validé.

Final: fixed nopCSVordre — testReorderedIdenticalCSVDoesNotReplaceExistingRecovery RED3assertions→GREEN ; suite124/124 sanséchec. ÉgalitéCSVparIDs/content, ordreoriginallaisseintact etanciennecopiepréservée ; JSONcontinueégalitéexacte. Lintstrictcode0 ; nouvellecompilationnativecode0 ; pasdere-review.

Livraison vérifiée : build correction3,35s code0, metadata/génération et6tests code0, packaging2,08s et inspectionunsignedcode0. Préflight0.7.3mêmeapp/certificatexistantvalide>24h/présentApple code0. ScriptUSB code0,rebuild2,09s,installation/vérification100%. Postflightdirectcode0 : Sport0.7.4(20), mêmeidentitéapp/enfant,profilsvalidesCMSvérifiés,certificatexistantetlocalinchangés. Aucune migration/capacité/permission/format/dépendance/cacheeffacé. Documents actualisés et défaut mineur d’état vide clairement consigné. Aucun import réel sur iPhone exécuté par l’agent, validation du rendu et des opérations de transfert requise ; STOP avant8/9.
