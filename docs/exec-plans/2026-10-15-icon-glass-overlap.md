# Sport 0.11.12 — relief et liserés de l’icône

Retour : silhouette 0.11.11 appréciée, mais perçue comme plate ; demande de fine bordure et de chevauchements visibles. Changement limité à l’icône et sa version 0.11.12 (46).

La silhouette précédente fusionnait les poids principaux avec la poignée et laissait un espace entre les poids extérieurs : deux groupes sans réel chevauchement. Nouveau dessin SVG : poignée complète à l’arrière, paire de poids argentés au milieu, paire cyan devant. Les poids se recouvrent de 16 unités SVG de chaque côté, et la poignée passe sous les deux paires. Trois groupes Icon Composer séparés, dans l’ordre frontal natif confirmé par le compilateur. Transparence modérée et ombres de groupe pour matérialiser les intersections, fin liseré clair sur chaque forme. La bordure concerne les formes de l’haltère : le masque extérieur de l’icône reste fourni par iOS, sans squircle prédessinée.

Conserver le fond, l’inclinaison −32°, le cadrage et les couleurs appréciés. Aucun filtre de flou ou effet verre bitmap ajouté ; matériaux natifs décrits dans le catalogue. Source/licence Phosphor et source Kavi de référence conservées. Aucune donnée ni logique Swift modifiée.

Vérifications : lint strict et 6 tests metadata réussis ; compilation actool, inspection PNG final, build xtool, inspection bundle/licence, préflight app/certificat, installation USB et postflight prévus. Ne pas conclure sur le relief natif sans retour iPhone. Recette : chevauchements cyan/argent, liseré discret, absence de découpe/crénelage ; vérifier apparences utilisées sur l’écran d’accueil.

Livraison : actool code 0, PNG de secours réel inspecté. Lint strict et 6 metadata réussis ; xtool 2,10 s, inspection unsigned app/widget/catalogue/licence réussie. Script USB code 0 (rebuild 2,13 s), installation/vérification 100 %. Postflight direct : Sport 0.11.12 (46), même identité/certificat, profils CMS valides, aucune capacité ajoutée. Données et médias personnels non consultés. Rendu de profondeur et bordures à confirmer physiquement.

Retouche 0.11.13 (47) : demande d’agrandir tout le SVG à 110–115 %. Choix 112,5 % : échelle des trois couches 1,18 → 1,3275, même centre, proportions et matériaux. Aucun autre changement. Compilation d’icône, contrôle visuel du PNG puis xtool/inspection/installation et postflight prévus. Lint et 6 metadata réussis.

Livraison 0.11.13 : actool réussi, aperçu final inspecté sans découpe, lint strict/6metadata réussis. xtool 2,10 s et inspection app/widget/icône/licence code 0 ; device-run.sh code 0 (2,07 s), installation/vérification 100 %. Postflight direct : 0.11.13 (47), même identité/certificat, profils CMS valides. Aucun autre périmètre modifié. Confirmation visuelle de taille attendue.
