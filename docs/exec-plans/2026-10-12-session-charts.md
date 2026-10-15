# Graphiques lisibles et utiles — correction du jalon7

Userfeedback : import fonctionne suriPhone, graphiques confus/amas de points ; demande review et courbes reliées. Corriger ce mêmejalon avant8/9. Documents Sport lus dans cette conversation, nouveauxformat/roadmap etdesignrelus. HIGCharts/charting-data : résumer, révélerdétails progressivement, lignes poursérie temporelle etlabelsaccessibles ; références AppleLineMark/interpolation consultées. Choix Sport : unevaleurperséance, pas moyenne/forceestimée ni liaisonentrechargesdifférentes. Exécutioninline déjàautorisée, pasgatenouvellepermission/plan ; Gitfakeinapplicable, baseline/tmp/sport-charts-before.

## Périmètre / design

- Courbe par mesure, unpoint par exercice/séance terminée : somme entière des répétitions oums, max de lest. Métriqueinitiale performance (répétitions/durée), période3mois, charge la plusrécente admissible de la période. Charges mixtes exclues des totaux à chargefixe, visibles danshistorique et vue lestmaximum.
- Conditions : nombre réel etnombreconfiguré de séries, plage/objectifduréearchivé, repos historique connu (nouveau champ optionnel ExercisePerformance.restSeconds). Manual reposinconnu, distinct desreposconnus ; aucun reposprésumédepuispréférencesactuelles. Changements deconditions jamaisreliés ; sélectionnative deconditions si plusieurs, explicationcontexte.
- Courbe séquentielle des séances sur axe « Séances » avec labelsdatesréelles, espacementségaux clairementindiqués : préserveplusieurs séancesmêmejour sansinventionheure ouUUIDtrier. Origine ordre exerciceHistory newestfirst inversé pourties de dates ; indexselection distinguechaqueséance.
- LineMark linear +petitpoint, axes/unitéssobres, dernierchiffre/date/nombrede séances/variationarithmétique. Aucun label« gainforce », « progressionassurée », calculpercent oucomparaisonfeelingcoaching. Selectiondernierpar défaut,détailssets/feeling/conditionsetNavigationLinkhistorique, accèsliste pourVO.
- Configuration/objectifs/historique/CSVJSON/rest/notifications inchangés ; aucuneschémamigration,nouvellepermission/dépendance/haptics/globaleanimation.

## Étapes

1. Tests avantAPI pour SessionTrends : unevaleurpersession, totals exacts, chargesmixtes, cancel/wrongmode/date/overflow, context(rest/sets/targets), ordresamday etchoixvisible. Tests vraiRepository : manualrestnil vsrestsnapshot connu aprèschangerpréférences. Implémenter Sources/SportCore/SessionTrends.swift, ajouteroptionnelrestSeconds à ExercisePerformance etquerylecture.
2. Prototype minimalLineMark/indexselectionaxesparxtool ; intégrerExerciseTrendChart etextraireExerciseProgressView deProgressionView. Conserveruneview lisible etrègleshorsUI, erreurs/retry, sélecteurspoids/contextnatives, details ethistorique.
3. Lint/suite/build, une revuefresh-contextindépendante mandatée executing-plans, correctionsimportantes reproduitesavantfix si possibles. Version0.7.2(18) ;metadata→packaging→6tests/inspection, préflightmême0.7.1/certificat→scriptUSB→postflight. Docsactualisées etSTOPpourtestiPhone.

## Review focus

- Mêmejour etdatehistoriqueéditée : ordredepuisrépertoirerespecté, pasUUID arbitraire/fakeheure, selectionindiceexacte.
- Manualreposinconnu/chargesmixtes/temporaireschangements deprogramme : pasrelierconditionsdifférentes ; choixparpériodeévitegraphvide avecdonnées.
- Overflow/setsinvalides/incomplets : pasagrégatinventé ; annulations exclues, totals décritscomme résultatconsigné pasforces.
- Changementd’exercice/mode/period/poids/contexte etdeleteimport : sélection réconciliée, aucunevaleurfantôme/Pickerhorschoix.
- Zéro/une/seulementrecordsancien/VO/grandtexte/clair-sombre : labelsexacts, axeindexexplicite etdetailsconsultablessansscrub.

## Ledger

- [x] Domaine/tests
- [x] Prototype/UI
- [x] Revue/contrôles/livraison/docs
- [ ] Confirmation physique

Domaine113tests GREEN, puis selectedWeightavantAPIcompileabsent (pasREDcomportemental), GREENsuite114tests. Metadatarests réellementlusSQL :manuelsnil,mesurés snapshotconservémêmeaprèsmodifierpréférences. Pasdeschémamigrationouformattransfert modifié. PrototypeLineMark/index/axisxtoolcode0,17,72s ; interfacecode0,19,06s. Lintstrictcode0. Projectionmiseencache calculée enTask.detached avecgardedecancellation, scrubneparcourtpastouteslesséries. Revision/metric/period/poidspilotentrecalcul ; changementmode réconciliePicker etclearingcontext. APIsUi compilées, validationphysiqueencoreàfaire. Baseline Sources/tmp/sport-charts-before/Sources ; revuefinaleencours.

Version0.7.2(18) préparée, préflightUSBcode0 :0.7.1installée,mêmeidentité etcertificatvalide>24h/préservéchezApple ; aucun provisioningnouveauappanticipé. Compilationnouveau trackingrequest etréconciliation demode en cours. Reviewfreshcontextautoriséeparskill executing-plans (pasd’implémenteuragents).

Revuefinale :0Critical,1Important (Réessayerlancetâcheindépendante, puis changementfiltrespeutpublieranciensrésultats),0Minor. CorrigéparretrydansclefTrendRequestetunseulchargement.task(id:), pluspublicationvisibleuniquementquandprojection.requestcorrespondaufiltreactuel. Pas de faux testsource/fakeSwiftUIsousLinux : bug/contrôlesdesannulationsSwiftUI relus statiquement et compilationréelle requise, essaiphysiquerapidefilter/retry encoreàfaire ; aucunRED→GREEN UI prétendu. Re-gradingImportantmaintenu ;pasde re-review.
Final:Ruling:declined — rendu/gestes/VO/grandtexteattendentrecetteiPhone ; nouveau modèlephysiologique horsscope, chiffresconsignésuniquement ;version/docs/USBverifiésiciavantlivraison. Coût : courbe ne démontrepasungainphysiologique, runtimeUIresteàconfirmer surappareil.

Livraison0.7.2(18) : correctionUI/résultatskeyedcompilextool12,41s code0 ; lintstrict code0. Domaineinchangé depuisGREEN114tests. Générationmetadata et6tests code0, empaquetage2,14s code0,inspectionunsignedcode0. Préflight0.7.1 code0,mêmeidentité etcertificat>24h/présentApple. ScriptUSBcode0,rebuild2,07s,installation/vérification100%. Postflightdirectcode0 :version18sousmêmeidentité, extensionunique,profilsvalidesCMSvérifiés,mêmecertificatquepréflight etlocalinchangé. Aucuneschémamigration/dépendance/permission/capacité/formatCSVJSON changé.
Docsexitactualisés. Confirmation iPhoneattendue : courbedernierchiffre/conditions/scrub/deuxséancesmêmejour/changementsrapides/VO/gros texte/clairsombre/import. Aucun8/9commencé.
