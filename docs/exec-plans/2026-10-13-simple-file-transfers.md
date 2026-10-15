# Sport0.11.2 — transfert simplifié

Demande explicite : abandonner le test et ne garder que Import from Files / Export to Files dans Import and Export. Deux lignes natives : import direct, Menu Export pour CSV(historique)/JSON(entraînement et réglages), copie JSON avant import si disponible. Photos privées toujours exclues et exclusion affichée. Démo et prototype retirés de l’interface ; sources de la preuve archivées hors targets, type.sporttest retiré. Formats et transactions existants conservés, aucun vrai transfert/effacement exécuté par l’agent.

Preview/confirmation de remplacement restent avant toute écriture. Retour de réussite dans le footer existant, sans nouvelle alerte OK, progrès overlay pour ne pas ajouter de lignes. Copie de récupération existe toujours ; messages indiquent désormais Export to Files. Aucun changement du coffre, de ses clés ou des permissions.

Vérification : lint strict, tests métier/import/export existants, xtool réel, metadata/inspection, préflight/même identité/certificat puis installation USB et postflight. Recette : uniquement deux actions, exportCSV/JSON/anciennecopie, exclusionphotos, import→Annuler ou confirmer, régressions habituelles. Aucun essai synthétique obligatoire sur iPhone, sauvegarde privée portable différée.

Progression : simplification, vérifications et installation terminées ; confirmation iPhone attendue.


## Livraison0.11.2(36)

Deux actions demandées, aucune démo/proof dans l’app. Formats/Coreimport/export/coffre inchangés ; sauvegardeavantimport toujours exportable dans le menu Export. Sources synthétiques/8tests archivés hors targets, donc146tests métier/0échec (5,512s), pas de perte de couverture du produit livré avant la preuve. Lintstrict0 ; xtool21,44s puis final7,35s, metadata réelle/empaquetage1,98s,6testsmetadata/inspectionunsigned réussis. Aucun nouveau test artificiel de libellé/UI ni nouvelle revue indépendante pour cette simplification de présentation ; rendu/gestes restent à confirmer sur iPhone.

Préflight0.11.1 code0 : identité inchangée/certificat existant valide>24h et présentApple. device-run.sh code0, rebuild1,96s/install/vérification100%. Postflightdirect0.11.2 code0 : même app/widget, profilsvalides CMSvérifiés, certificatpréflight/localinchangé, permissionsinchangées. Type.sporttest absent de la build, aucun accès à des données personnelles/import/suppression réelle. Caches/HelloSport/SDK conservés.

Installée avant review ; vérifier seulement les deux actions, choixCSV/JSON/copied’avantimport et import→Annuler/confirmation. Exclusionphotos dans le footer. L’anciennepreuve n’a pas été validée et ne sera plus demandée ; pas de poursuite automatique de sauvegarde privée.


Retour : « parfait. on a fini ? ». Présentation acceptée ; ne pas en déduire chaque essai d’import/export/VoiceOver individuellement. Aucune poursuite de code demandée par cette question d’état.
