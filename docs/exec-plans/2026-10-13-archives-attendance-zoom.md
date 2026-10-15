# Sport0.10.4 — archives, lisibilité et diagnostic zoom

## Demandes et décisions explicites

Exercices archivés visibles dans Réglages et supprimables par swipe/appui long confirmé, depuis Réglages/Progression. Clarification utilisateur : « Effacer aussi les anciennes performances ». Suppression définitive de ces seuls instantanés/séries, pas des autres exercices ; séances devenues entièrement vides retirées, conséquence annoncée dans l’alerte. Ne pas purger un exercice encore au catalogue ou présent dans une séance active. Suppression habituelle du catalogue garde sa règle d’archivage.

Liste d’assiduité : retirer jours neutres, garder terminés/partiels et état vide honnête. Renommer Planning en Séance dans Réglages et liens textuels associés. Bouton Préparer : supprimer insets de ligne pour rejoindre la largeur du groupe Entre les séries, style natif conservé.

Zoom0.10.3 jugé encore incorrect sur iPhone, utilisateur précise « Les deux ». Détail classique restait en MagnifyGesture avec multiplication de frame, cause du défaut initial confirmée dans son code. Comparaison native avait un override layoutSubviews qui réappliquait zoomScale/offset lors de variations de taille ; hypothèse d’interférence avec pincement, non reproduite sous Linux. Nouveau contrôle commun : viewport fixé par GeometryReader et configureViewport appelé exclusivement lors de l’update SwiftUI pour une nouvelle taille ; aucun setter de zoom pendant layoutSubviews natif. Pinch/pan iOS restent seuls propriétaires pendant leur geste. Doubletap natif au point touché dans détail, toucher d’alternance en comparaison, commandes accessibles. Masque/dismantle conservés.

## Vérification

Tests métier avant purge : retrait ciblé/session mixte conservée, séance entièrement vidée supprimée, snapshots/config/CSVJSON valides, catalogue et séance active refusés, rollback SQLite sur erreur et rest/goal associés. Pas de test simulé de gestes iOS. Lint, suite hôte et xtool ; revue indépendante de purge et viewport privé ; metadata/inspection, identité/certificat préflight0.10.3, installation USB/postflight. Recette : Annuler/purger archive, autres séries préservées après relance/export, jours neutres absents, largeur visuelle, pincement excentré sur les deux écrans puis alternance/background. Aucune réussite native du zoom revendiquée avant confirmation iPhone.

## Progression

Documents Sport/ExecPlans et modèles/source relus. Demandes complémentaires constituent le périmètre autorisé ; le10 reste non commencé. Implémentation en cours.


Trois tests initiaux : sept assertions RED observées avant purge, puis145tests/0échec. Ajout d’une régression pertinente pour repos/objectif historiques en FK après ce passage ; pas de RED prétendu pour ce test additionnel. Buildxtool29,77s/code0, lintstrict0. Revue indépendante finale ciblée : aucun constat actionable ; nativepinch/largeur/confirmation non testés sous Linux. Détail et comparaison sont maintenant sur un viewport SwiftUI fixé, sans override layoutSubviews ni setter de zoom au cours de ce layout. Le défaut natif signalé reste à confirmer par essai physique, pas déclaré résolu.


## Livraison0.10.4(32)

146tests hôte/0échec (5,819s), lintstrict code0. Sept assertions RED avant purge dans trois tests initiaux ; ajout ultérieur du scénario FK repos/objectif passé sans RED prétendu. Couverture : suppression ciblée, retrait sessions vidées, performances/configurations restantes préservées, catalogue/actif refusés, rollback et CSVJSON valides. xtool29,77s/code0, générationmetadata depuis constvalues puis empaquetage2,16s/code0, six testsmetadata et inspectionunsigned réussis. Revue indépendante sans constat actionable ; pas de runtime pinch/alertes/largeur testé sous Linux.

Préflightlecture seule0.10.3 code0 : même identité effective, certificat existant valide>24h/présentApple. device-run.sh code0, rebuild2,17s, installation/vérification100%. Postflight direct0.10.4 code0 : mêmes app/widget, profilsvalides CMSvérifiés, certificatpréflight/local inchangés, aucune permission ou capacité nouvelle. Aucun cache/SDK/HelloSport supprimé ni purge réelle de données utilisateur exécutée par l’agent.

Build installée avant review. Attendre confirmation sur archives/assiduité/largeur et surtout les deux parcours de zoom, dont le défaut0.10.3 est explicitement rapporté. Le contrôle commun fixe le viewport SwiftUI et supprime les setters lors de layoutSubviews ; cela reste une hypothèse/correction à vérifier sur appareil, pas une preuve de réussite native. Jalons futurs, sauvegarde privée et traduction inchangés.
