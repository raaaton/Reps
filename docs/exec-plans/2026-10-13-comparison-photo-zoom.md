# Sport0.10.2 — comparaison agrandie

## Périmètre autorisé

0.10.1 confirmée par « parfait ». Demande précise : toucher l’une des deux photos de comparaison pour l’agrandir, zoomer, puis toucher la photo pour alterner entre les deux. Vue plein écran SwiftUI, pincement1–4× et déplacement via ScrollView, toucher simple pour alterner. Zoom/cadre de défilement commun conservés ; pas d’alignement corporel artificiel ou changement d’originaux.

## Implémentation

Réutiliser uniquement les deux aperçus du store privé central, aucune copie d’image dans les routes. Route contient IDs et UUID de session. Masque commun sur la nouvelle surface, fermeture au lock, références centrales effacées en quittant la comparaison ; les conserver quand sa seule vue agrandie est présentée. Ne pas réinitialiser les dates sélectionnées au retour. Gestes SwiftUI déjà compilés dans le détail photo ; fournir aussi commandes de zoom/alternance nommées accessibles. Aucun stockage, permission, clé ou objectif modifié.

## Vérification et recette

Pas de test texte/gestes simulé sous Linux : tests métier existants, lint strict, build xtool réel, métadonnées/inspection, revue indépendante ciblée du lifecycle privé, préflight identité/certificat, installation USB puis postflight. Recette iPhone : ouverture depuis chaque photo, pincement/déplacement/toucher d’alternance, même zoom/position, retour gardant pose/dates, VoiceOver/grand texte/clair-sombre, background de la nouvelle vue et FaceID au retour. Attendre confirmation avant prochain jalon.

## Progression

Docs existantes et ExecPlan précédent relus ; HIG Gestures relu. Toucher pour alterner est un choix Sport explicitement demandé ; bouton alternatif accessible et indication discrète prévus. Implémentation en cours.


Implémentation terminée, revue indépendante ciblée sans constat actionable. Lint strict code0,140tests hôte/0échec (5,397s), xtool10,16s/code0. Générationmetadata puis empaquetage2,18s/code0 ; six testsmetadata et inspectionunsigned0.10.2/30 réussis. Préflightlecture seule0.10.1 : même identité/certificat existant valide>24h et présentApple. Aucun test UI artificiel ni succès de gestes prétendu ; installation en cours.


0.10.2(30) a été installée avant les nouvelles demandes :140tests/6metadata/lint/xtool10,16s puis empaquetage2,18s et USB2,13s codes0. Postflight direct même app/profilsvalides CMS/certificatinchangé. L’utilisateur rapporte ensuite le défaut d’ancrage du zoom ; cette livraison ne constitue pas une validation globale du parcours. Correctif et appui long autorisés en0.10.3, sans démarrer le10.
