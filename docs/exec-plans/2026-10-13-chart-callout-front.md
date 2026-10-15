# Sport0.11.7 — bulle devant les points

Retour iPhone : le point passe encore au-dessus de la previewcard. Correction limitée au graphique partagé : bulle retirée du PointMark et affichée dans chartOverlay, au-dessus de toutes les marques (points/courbe/ligne). ChartProxy fournit l'ancrage ; Layout SwiftUI mesure/place en une passe, limite la largeur260pt et rabat la bulle dans le cadre aux extrémités/en haut. Fond opaque/couleurs/date/valeur inchangés. Aucun state de taille différé, animation supplémentaire, geste ou calcul modifié. Overlay noninteractif/masquéVoiceOver ; valeurs accessibles restent sur les vrais points.

Vérifications : lint, testsSessionTrends applicables, xtool réel et métadonnées/inspection, préflightinstallation/postflight. Pas de nouveau test simulantSwiftUI ni suite complète sans changement de métier. Rendu/drag/clamping et grand texte doivent être confirmés sur iPhone.

Recette : drag sur un maximum près du haut et sur les premières/dernières séances : la bulle doit couvrir point et ligne, rester dans le graphique et afficher le bon résultat. Tester grand texte et changements rapides de métrique/période ; interactions et données inchangées. Aucun autre périmètre, permission ou donnée du coffre modifié.


Livraison : lintstrict0,17testsSessionTrends/0échec0,222s (156suite complète précédente inchangée, non relancée sans justification),6metadata/0échec, xtool11,15s puis empaquetage2,58s et verify-foundation0. Préflight0.11.6 mêmeapp/certificatvalide. device-run.sh0/rebuild2,59s/install-vérification100%, postflightdirect0.11.7 mêmeidentité/certificat/profilsCMSvalides/permissionsinchangées. Aucun accès aux données/photos personnelles ni nouvelle dépendance. Installation avant review ; couche et geste à confirmer physiquement.
