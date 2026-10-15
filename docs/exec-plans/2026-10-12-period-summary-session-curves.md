# Totaux de période, courbes et bulles par séance

## Objectif et autorisation

L'utilisateur confirme0.7.4 puis précise : Volume conserve le total en haut, mais courbe/bulle montrent uniquement chaque séance ; Répétitions affiche le total en haut et garde la courbe par séance. Rester dans le jalon7, pas8/9. Clarification de période précédente1/3/12mois conservée. Répétitions totalise les séances affichées selon lest/contexte choisis, annoncé à l'utilisateur ; pas de modification silencieuse du graphique demandé inchangé. Installation USB autorisée avant review. Documents Sport déjàaudités dans cetteconversation, dernierExecPlan/sourcesrelus ; workflowsHIG/brainstorming/TDD/executing-plans repris, pasde gatepermissionredondante. Baseline /tmp/sport-summary-before ; Git inapplicable, pasworktree/reset/commit.

## Conception

Valeur du point, de sa bulle, de VoiceOver et du détail = résultat de la séance (volume=sumreps×grammes). Résumé Volume = somme sur toute la période ; toutesconditions/lests inclus, poidsducorpsnoninféré. Résumé Répétitions = somme des séances affichées, mêmesfiltres quecourbe ; cache des totaux parcontexte, pasdereduceentier àchaquescrub. Titre/units distinguent total versus parseance. Détailleselection seulementsession, retirerligne cumulative qui encourageconfusion. Graphe conserveordre/lineaire/dates/nativeannotation/overflowfit, pasnouvellesAPI/UIcustomgesture. Temps/Lest/CSV/JSON/config/objectifspasmodifiés. Libelléd'étatvideVolumeajustédanscefluxpourneplusproposerunfiltreabsent (mineurconnu0.7.4).

## Étapes / validation

1. Reproduiretestpointvolume noncumulé avantfix ; teststotalrep/filtre/overflow avanthelper, calc checked ; résumémisenprojectionparcontexte etUI. Lint/suite/xtoolbuild réel.
2. Une revuefinaleindépendante unique mandatéeparskill ; importantsfixésavecrégression, aucune re-review. Version0.7.5(21), metadata→package→6tests/inspectionunsigned, préflightmême0.7.4/certificat,device-run.sh etpostflight. Docs etrecette ; STOPpourconfirmationiPhoneavant8/9.

## Review focus

Grandtotal versuspoint/bulle/detail/VoiceOver jamaisconfondus ; repstotal respecte pointsvisiblesetcontextes/charges/période, aucun overflow ou cacheobsolète, changementsrapides de filtre/scrub/revision. Retirer cumulative display partouttoutengardantcalculsommeexacte. Unpoint/zero/empty/3mois etfiltresunivoques ; grapherepsn'estpaschangé, sommedepériodepas«gainforce». RuntimeUIgestes/rendunepeuventêtreprouvésLinux.

## Ledger

- [x] Tests/domaine/interface
- [x] Revue/build/contrôles/livraison/docs
- [ ] Confirmation iPhone

Interfaces : point.total→curve/bulle/detail ; cumulpériode→résuméVolume ; sommes points regroupéscontext→résuméReps. Aucun stockage/migration/capacité/permission/formattransfert. Hors8/9 ; confirmationssignaturesetrecettephysiqueobligatoires.

PointvolumeobservéRED : valeurs90/120/408cumulées au lieu90/30/288perséance ; .value etannotations désormaislisent .total brut, cumulativeTotal réservé au résumépériode. Helperssommes avantAPI observéscompilemissing (pasREDcomportemental), calculchecked/cacheparcontexte→GREEN126tests,0échec (/tmp/sport-summary-green.log), lintstrictcode0. Totauxrep88/32dansconditions distinctes,120ensemble ; courbe48/40conservée, charge/période/cancel exclus, empty/overflow testés. Données/transferts/permissionssanschangement. Bulle/détail/VOrelus, renduàtester.

Revuefinaleunique :0Critical/Important/Minor ; cache/filtres/totaux/selection etdomain relus. Tests126GREEN constatés au journal, pasréexécutés parreviewer. Final:Ruling: runtimeUI/geste/VoiceOver/grandtextenepeuventêtrejugésLinux — restentrecetteiPhone ; build/version/signature/docs contrôlésparl'exécutant ; CSV/JSON/goals/stockageinchangés. Coût : rendu/gestesrestentàconfirmer,aucun8/9validé. UIcompile14,46s code0, lintstrictcode0 ; packaging/deliveryàconsigner. Ancienmineurd'étatvideVolume résolu danslenouveauflux, pasnouveauFindingdéféré.

Livraison0.7.5(21) : buildUI14,46s/version2,32s/générationmetadata/packaging2,07s codes0,6testsmetadata/inspectionunsignedcode0. Préflight0.7.4mêmeapp/certificatexistant>24h/présentApplecode0. ScriptUSBcode0,rebuild2,06s,installation/vérification100%. Postflightdirectcode0 :mêmeidentitéapp/widget,profilsvalidesCMSvérifiés,mêmecertificatpréflightetlocalinchangé ;pasnouvellespermissions/dépendances/capacités/migration/format/cacheeffacé. README/PROJECT/ROADMAP/DESIGN/BUILD/SECURITY/plan actualisés. Aucunminor restant identifiédanscettecorrection, ancienétatvideharmonisé. Recette totalsdifférentsdespoints/drag/période/contextes/VO/grandtexte/clairsombreattendue ; STOPavant8/9.
